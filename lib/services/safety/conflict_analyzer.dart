import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/node_provider/transaction/mempool_api_service.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/services/safety/sweep_builder.dart';

typedef SweepDescendant = ({String txid, int fee, double vSize});
typedef _Root = ({int fee, double vSize, bool confirmed, bool signalsRbf, bool verified, TransactionRecord? record});

/// 사건 거래(충돌)의 수수료·크기·RBF 신호·자손을 모은다. 결과는 [SweepBuilder.plan]에 그대로 넣는다.
/// 네트워크 실패·형식이 틀린 응답은 다시 시도하지 않는다(로컬 값 + descendantsComplete=false, 사용자가 다시 분석).
///
/// 수수료 신뢰 규칙: 사건 거래와 자손을 서버(일렉트럼) 원본 거래(txid를 해시로 확인)로 받아 입력 값 − 출력으로 직접 센다.
/// 입력 값은 내 UTXO, 아니면 일렉트럼 이전 거래의 그 출력(feeVerified, 대체 하한 20% 예외의 근거). 상대가 자기 입력이나
/// 외부 입력을 단 CPFP 자식을 붙여도 확인은 꺼지지 않는다. 못 세면 mempool.space 값을 쓰되, 로컬 기록 수수료보다 크게는 믿지 않는다.
/// 부풀린 외부 값은 대체 하한을 키워 코인을 수수료로 태우게 하고, 작게 잡았을 때의 최악은 전송 거절이다
class ConflictAnalyzer {
  ConflictAnalyzer({required NodeProvider nodeProvider, required WalletProvider walletProvider, MempoolApi? mempoolApi})
    : _nodeProvider = nodeProvider,
      _walletProvider = walletProvider,
      _mempoolApi = mempoolApi ?? MempoolApi();

  final NodeProvider _nodeProvider;
  final WalletProvider _walletProvider;
  final MempoolApi _mempoolApi;

  static const _maxMoney = 21000000 * 100000000;
  static const _maxBlockWeight = 4000000;

  /// 분석 한 번에 받는 일렉트럼 원본 거래 수(같은 txid는 한 번). ponytail: 상대가 서로 다른 이전 거래의 입력을 이보다 많이
  /// 달면(그만큼 수수료를 낸다) 확인이 꺼져 20% 상한으로 돌아간다. 필요하면 한도를 올리거나 일괄 조회로
  static const maxServerFetches = 100;

  /// 수수료를 알 수 없는 거래는 빠진다(대체할 수 없음 → 남은 코인만 옮김).
  /// 자손은 모든 사건 거래를 합친 한 예산([SweepBuilder.maxDescendants], 사건 거래 포함)으로 찾고, 넘으면 그만 찾는다
  Future<List<SweepConflict>> analyze(int walletId, List<String> incidentTxids) async {
    final utxos = _walletProvider.getUtxoList(walletId);
    final server = _ServerTxs(_nodeProvider, {for (final u in utxos) '${u.transactionHash}:${u.index}': u.amount});
    final roots = <String, _Root>{};
    for (final txid in incidentTxids.toSet()) {
      final root = await _root(walletId, txid, server);
      if (root != null) roots[txid] = root;
    }
    final pending = {
      for (final e in roots.entries)
        if (!e.value.confirmed) e.key,
    };
    final evicted = {...pending};
    final conflicts = <SweepConflict>[];
    for (final MapEntry(key: txid, value: root) in roots.entries) {
      if (root.confirmed) {
        conflicts.add(
          SweepConflict(
            txid: txid,
            fee: root.fee,
            vSize: root.vSize,
            signalsRbf: root.signalsRbf,
            confirmed: true,
            feeVerified: root.verified,
          ),
        );
        continue;
      }
      final (descendants, complete) = await _descendants(walletId, txid, root.record, utxos, evicted, pending);
      // 자손도 일렉트럼 원본으로 센다(mempool.space만 아는 자손은 여기서 걸린다). 하나라도 못 세면 이 충돌은 미확인
      final verified = root.verified ? await server.feesOf(descendants) : null;
      conflicts.add(
        SweepConflict(
          txid: txid,
          fee: root.fee,
          vSize: root.vSize,
          signalsRbf: root.signalsRbf,
          descendants: verified ?? descendants,
          descendantsComplete: complete,
          feeVerified: verified != null,
        ),
      );
    }
    return conflicts;
  }

  Future<_Root?> _root(int walletId, String txid, _ServerTxs server) async {
    final record = _walletProvider.getTransactionRecord(walletId, txid);
    Map<String, dynamic>? remote;
    try {
      remote = await _mempoolApi.fetchTx(txid);
    } catch (_) {}
    final checked = remote == null ? null : _feeOf(remote, txid);
    final raw = await server.get(txid);
    final own = raw == null ? null : await server.feeOf(raw);

    final int fee;
    final double vSize;
    if (own != null) {
      fee = own.fee;
      vSize = own.vSize;
    } else if (checked != null) {
      final localFee = record?.fee ?? 0;
      fee = localFee > 0 && checked.fee > localFee ? localFee : checked.fee;
      vSize = checked.vSize;
    } else if (record != null && record.fee >= 0 && record.vSize > 0) {
      fee = record.fee;
      vSize = record.vSize;
    } else {
      return null;
    }
    final status = checked == null ? null : remote!['status'];
    final confirmed = (record?.blockHeight ?? 0) > 0 || (status is Map && status['confirmed'] == true);
    // nSequence는 서버 원본 거래에서. 못 읽으면 신호 없음으로 본다(안내가 보이는 쪽)
    final signalsRbf = raw != null && raw.inputs.any((i) => i.sequence < 0xfffffffe);
    return (
      fee: fee,
      vSize: vSize,
      confirmed: confirmed,
      signalsRbf: signalsRbf,
      verified: own != null,
      record: record,
    );
  }

  /// mempool.space 거래 응답에서 (수수료, vsize). txid가 다르거나 정수·범위가 아니면 null(H7)
  static ({int fee, double vSize})? _feeOf(Map<String, dynamic> tx, String txid) {
    final fee = tx['fee'], weight = tx['weight'];
    if (tx['txid'] != txid || fee is! int || weight is! int) return null;
    if (fee < 0 || fee > _maxMoney || weight <= 0 || weight > _maxBlockWeight) return null;
    return (fee: fee, vSize: weight / 4);
  }

  /// 로컬(CPFP 기록·충돌이 만든 우리 UTXO를 쓴 거래) + mempool.space outspends.
  /// [evicted]는 모든 사건 거래가 함께 쓰는 예산이다. 넘으면 바로 멈추고, 넘은 만큼 담긴 결과로 plan이 막는다.
  /// 다른 사건 거래를 만나면 목록에 넣되(그 거래가 이 충돌을 통해 밀려남을 알리려고) 그 아래는 그 거래가 찾는다
  Future<(List<SweepDescendant>, bool)> _descendants(
    int walletId,
    String root,
    TransactionRecord? rootRecord,
    List<UtxoState> utxos,
    Set<String> evicted,
    Set<String> roots,
  ) async {
    final found = <String, SweepDescendant>{};
    final counted = <String>{}; // 이 충돌이 예산에 처음 넣은 txid
    bool overBudget() => evicted.length > SweepBuilder.maxDescendants;
    void add(SweepDescendant d) {
      found[d.txid] = d;
      if (evicted.add(d.txid)) counted.add(d.txid);
    }

    final localQueue = [root];
    while (localQueue.isNotEmpty && !overBudget()) {
      final parent = localQueue.removeAt(0);
      final children = <String>{
        if (parent == root && rootRecord?.cpfpHistory != null) rootRecord!.cpfpHistory!.childTransactionHash,
        for (final u in utxos)
          if (u.transactionHash == parent && u.spentByTransactionHash != null) u.spentByTransactionHash!,
      };
      for (final child in children) {
        if (child == root || found.containsKey(child) || overBudget()) continue;
        final r = _walletProvider.getTransactionRecord(walletId, child);
        if (r == null || r.vSize <= 0 || r.fee < 0) continue; // 네트워크 조회가 채운다
        add((txid: child, fee: r.fee, vSize: r.vSize));
        if (!roots.contains(child)) localQueue.add(child);
      }
    }
    final local = Map.of(found);
    if (overBudget()) return (found.values.toList(), true);

    try {
      final visited = {root};
      final queue = [root];
      while (queue.isNotEmpty) {
        for (final o in await _mempoolApi.fetchOutspends(queue.removeAt(0))) {
          if (o['spent'] != true) continue;
          final child = (o['txid'] as String).toLowerCase(); // fetchOutspends가 형식을 확인했다
          if (!visited.add(child)) continue;
          if (!found.containsKey(child)) {
            // 찾기용 mempool.space 값. analyze가 이 자손을 일렉트럼 원본(txid 확인)과 입력 값(내 UTXO·일렉트럼 이전 거래)으로
            // 다시 세서 바꾼다(_ServerTxs.feesOf). ponytail: 일렉트럼이 못 주거나 해시가 다르면 이 값이 남아 하한이 부풀 수 있지만,
            // 그 충돌은 미확인이라 20% 상한·0.01 BTC 경고가 받친다(다시 분석하면 다시 받는다)
            final checked = _feeOf(await _mempoolApi.fetchTx(child), child);
            if (checked == null) throw const FormatException('Invalid descendant');
            add((txid: child, fee: checked.fee, vSize: checked.vSize));
          }
          if (overBudget()) return (found.values.toList(), true);
          if (!roots.contains(child)) queue.add(child);
        }
      }
      return (found.values.toList(), true);
    } catch (_) {
      // 네트워크에서 더한 자손은 예산에서 되돌린다(로컬만 남김)
      evicted.removeAll(counted.where((txid) => !local.containsKey(txid)));
      return (local.values.toList(), false);
    }
  }
}

/// 분석 한 번에 쓰는 일렉트럼 원본 거래(txid를 해시로 확인)와 입력 값 세기. 같은 txid는 한 번만 받는다
class _ServerTxs {
  _ServerTxs(this._node, this._own);

  final NodeProvider _node;

  /// 내 UTXO 값('txid:vout' → sats)
  final Map<String, int> _own;
  final _cache = <String, Transaction?>{};

  /// 원본 거래. 못 읽거나 해시가 txid와 다르거나 한도를 넘으면 null(→ 미확인, 다시 분석하면 다시 받는다)
  Future<Transaction?> get(String txid) async {
    if (_cache.containsKey(txid)) return _cache[txid];
    if (_cache.length >= ConflictAnalyzer.maxServerFetches) return null;
    Transaction? tx;
    try {
      final result = await _node.getTransaction(txid);
      if (result.isSuccess) {
        final parsed = Transaction.parse(result.value);
        if (parsed.transactionHash == txid) tx = parsed;
      }
    } catch (_) {}
    return _cache[txid] = tx;
  }

  /// (입력 합 − 출력 합, 원본 vsize). 입력 값은 내 UTXO, 아니면 일렉트럼 이전 거래의 그 출력. 하나라도 못 세면 null
  Future<({int fee, double vSize})?> feeOf(Transaction tx) async {
    var fee = 0;
    for (final input in tx.inputs) {
      var amount = _own['${input.transactionHash}:${input.index}'];
      if (amount == null) {
        final prev = await get(input.transactionHash);
        if (prev == null || input.index >= prev.outputs.length) return null;
        amount = prev.outputs[input.index].amount;
      }
      fee += amount;
    }
    for (final output in tx.outputs) {
      fee -= output.amount;
    }
    final vSize = tx.getVirtualByte();
    return fee < 0 || vSize <= 0 ? null : (fee: fee, vSize: vSize);
  }

  /// 자손마다 일렉트럼 원본으로 (수수료, 크기). 일렉트럼이 모르는 자손이 있거나 하나라도 못 세면 null
  Future<List<SweepDescendant>?> feesOf(List<SweepDescendant> descendants) async {
    final counted = <SweepDescendant>[];
    for (final d in descendants) {
      final raw = await get(d.txid);
      final own = raw == null ? null : await feeOf(raw);
      if (own == null) return null;
      counted.add((txid: d.txid, fee: own.fee, vSize: own.vSize));
    }
    return counted;
  }
}
