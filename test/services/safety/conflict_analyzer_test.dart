import 'dart:convert';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/model/error/app_error.dart';
import 'package:coconut_wallet/model/node/cpfp_history.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/node_provider/transaction/mempool_api_service.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/services/safety/conflict_analyzer.dart';
import 'package:coconut_wallet/services/safety/sweep_builder.dart';
import 'package:coconut_wallet/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../mock/wallet_mock.dart';

String _hash(int i) => i.toRadixString(16).padLeft(64, '0');

class _Mempool extends Fake implements MempoolApi {
  final Map<String, Map<String, dynamic>> txs = {};
  final Map<String, List<Map<String, dynamic>>> outspends = {};
  bool offline = false;
  int txCalls = 0, outspendCalls = 0;

  @override
  Future<Map<String, dynamic>> fetchTx(String txid, {Duration timeout = const Duration(seconds: 15)}) async {
    txCalls++;
    if (offline || !txs.containsKey(txid)) throw Exception('HTTP 404');
    return txs[txid]!;
  }

  @override
  Future<List<Map<String, dynamic>>> fetchOutspends(
    String txid, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    outspendCalls++;
    if (offline) throw Exception('offline');
    return outspends[txid] ?? const [];
  }
}

class _Node extends Fake implements NodeProvider {
  final Map<String, String> raw = {};
  final calls = <String>[];

  @override
  Future<Result<String>> getTransaction(String txHash) async {
    calls.add(txHash);
    return raw.containsKey(txHash) ? Result.success(raw[txHash]!) : Result.failure(ErrorCodes.nodeUnknown);
  }
}

class _Wallets extends Fake implements WalletProvider {
  final Map<String, TransactionRecord> records = {};
  List<UtxoState> utxos = [];

  @override
  TransactionRecord? getTransactionRecord(int walletId, String transactionHash) => records[transactionHash];

  @override
  List<UtxoState> getUtxoList(int walletId) => utxos;
}

TransactionRecord _record(String txid, {int fee = 1000, double vSize = 100, int blockHeight = 0, CpfpHistory? cpfp}) =>
    TransactionRecord(
      txid,
      DateTime(2026, 10, 1),
      blockHeight,
      TransactionType.sent,
      null,
      -50000,
      fee,
      const [],
      const [],
      vSize,
      DateTime(2026, 10, 1),
      cpfpHistory: cpfp,
    );

UtxoState _stolen(String spentBy, {int i = 0}) => UtxoState(
  transactionHash: _hash(100 + i),
  index: 0,
  amount: 400000,
  derivationPath: "m/84'/1'/0'/0/$i",
  blockHeight: 0,
  to: '',
  timestamp: DateTime(2026, 10, 1),
  status: UtxoStatus.outgoing,
  spentByTransactionHash: spentBy,
);

const _payTo = 'bcrt1qxa3vg30kvqsd73knsv0dj8z26jx223chv8fzcx';

/// 실제로 파싱되는 거래(서버가 돌려줄 원본). [rbf]면 모든 입력 0xfffffffd
Transaction _attackTx({required bool rbf}) {
  final wallet = WalletMock.createSingleSigWalletItem();
  final utxo = _stolen('', i: 0);
  final tx = Transaction.forSweep([utxo], _payTo, 2, wallet.walletBase);
  if (rbf) tx.inputs[0] = TransactionInput.forPayment(utxo.transactionHash, utxo.index, sequence: 0xfffffffd);
  return tx;
}

/// [inputs]를 쓰는 실제 거래(출력 1개)
Transaction _spend(List<UtxoState> inputs) =>
    Transaction.forSweep(inputs, _payTo, 2, WalletMock.createSingleSigWalletItem().walletBase);

/// [tx]의 출력 하나를 입력으로(값은 그 출력 금액)
UtxoState _output(Transaction tx, {int index = 0}) => UtxoState(
  transactionHash: tx.transactionHash,
  index: index,
  amount: tx.outputs[index].amount,
  derivationPath: "m/84'/1'/0'/0/9",
  blockHeight: 0,
  to: '',
  timestamp: DateTime(2026, 10, 1),
);

void main() {
  setUpAll(() => NetworkType.setNetworkType(NetworkType.regtest));

  late _Mempool mempool;
  late _Node node;
  late _Wallets wallets;
  late ConflictAnalyzer analyzer;

  setUp(() {
    mempool = _Mempool();
    node = _Node();
    wallets = _Wallets();
    analyzer = ConflictAnalyzer(nodeProvider: node, walletProvider: wallets, mempoolApi: mempool);
  });

  test('수수료·크기는 mempool.space 우선, RBF 신호는 서버 원본 거래(txid 일치)에서', () async {
    final attack = _attackTx(rbf: true);
    final txid = attack.transactionHash;
    node.raw[txid] = attack.serialize();
    wallets.records[txid] = _record(txid, fee: 2820, vSize: 99);
    mempool.txs[txid] = {
      'txid': txid,
      'fee': 2820,
      'weight': 564,
      'status': {'confirmed': false},
    };

    final conflicts = await analyzer.analyze(1, [txid, txid]);
    expect(conflicts.length, 1);
    final c = conflicts.single;
    expect(c.fee, 2820);
    expect(c.vSize, 141);
    expect(c.signalsRbf, isTrue);
    expect(c.confirmed, isFalse);
    expect(c.descendants, isEmpty);
    expect(c.descendantsComplete, isTrue);
  });

  test('mempool.space 수수료가 로컬(일렉트럼 기준)보다 크면 로컬 값으로 제한', () async {
    final txid = _hash(7);
    wallets.records[txid] = _record(txid, fee: 1410, vSize: 141);
    mempool.txs[txid] = {'txid': txid, 'fee': 900000, 'weight': 564};
    expect((await analyzer.analyze(1, [txid])).single.fee, 1410);
  });

  test('RBF 신호 없음 / 서버 원본 txid 불일치 / 서버 실패 → signalsRbf false', () async {
    final plain = _attackTx(rbf: false);
    final txid = plain.transactionHash;
    mempool.txs[txid] = {'txid': txid, 'fee': 2820, 'weight': 564};

    node.raw[txid] = plain.serialize();
    expect((await analyzer.analyze(1, [txid])).single.signalsRbf, isFalse);

    node.raw[txid] = _attackTx(rbf: true).serialize(); // 다른 txid
    expect((await analyzer.analyze(1, [txid])).single.signalsRbf, isFalse);

    node.raw.clear();
    expect((await analyzer.analyze(1, [txid])).single.signalsRbf, isFalse);
  });

  test('mempool 실패 → 로컬 수수료, 자손은 로컬(CPFP·우리 UTXO 재귀)만 + descendantsComplete false, 다시 시도 안 함', () async {
    final txid = _hash(1), cpfpChild = _hash(2), spender = _hash(3), grandchild = _hash(4);
    mempool.offline = true;
    wallets.records[txid] = _record(
      txid,
      fee: 1410,
      vSize: 141,
      cpfp: CpfpHistory(
        walletId: 1,
        parentTransactionHash: txid,
        childTransactionHash: cpfpChild,
        originalFee: 10,
        newFee: 20,
        timestamp: DateTime(2026),
      ),
    );
    wallets.records[cpfpChild] = _record(cpfpChild, fee: 3000, vSize: 150);
    wallets.records[spender] = _record(spender, fee: 500, vSize: 110);
    wallets.records[grandchild] = _record(grandchild, fee: 700, vSize: 110);
    wallets.utxos = [
      _stolen(txid),
      // 충돌이 만든 우리 출력 → spender가 씀 → spender의 출력 → grandchild가 씀
      UtxoState(
        transactionHash: txid,
        index: 1,
        amount: 1000,
        derivationPath: "m/84'/1'/0'/1/0",
        blockHeight: 0,
        to: '',
        timestamp: DateTime(2026),
        status: UtxoStatus.outgoing,
        spentByTransactionHash: spender,
      ),
      UtxoState(
        transactionHash: spender,
        index: 0,
        amount: 600,
        derivationPath: "m/84'/1'/0'/1/1",
        blockHeight: 0,
        to: '',
        timestamp: DateTime(2026),
        status: UtxoStatus.outgoing,
        spentByTransactionHash: grandchild,
      ),
    ];

    final c = (await analyzer.analyze(1, [txid])).single;
    expect(c.fee, 1410);
    expect(c.vSize, 141);
    expect(c.descendantsComplete, isFalse);
    expect({for (final d in c.descendants) d.txid: d.fee}, {cpfpChild: 3000, spender: 500, grandchild: 700});
    expect(mempool.outspendCalls, 1);
    expect(mempool.txCalls, 1);
  });

  test('mempool outspends로 자손을 끝까지 따라가고, 자식 수수료는 fetchTx', () async {
    final txid = _hash(1), c1 = _hash(2), c2 = _hash(3);
    mempool.txs[txid] = {'txid': txid, 'fee': 1410, 'weight': 564};
    mempool.txs[c1] = {'txid': c1, 'fee': 5000, 'weight': 440};
    mempool.txs[c2] = {'txid': c2, 'fee': 800, 'weight': 600};
    mempool.outspends[txid] = [
      {'spent': true, 'txid': c1, 'vin': 0},
      {'spent': false},
    ];
    mempool.outspends[c1] = [
      {'spent': true, 'txid': c2, 'vin': 0},
    ];

    final c = (await analyzer.analyze(1, [txid])).single;
    expect(c.descendantsComplete, isTrue);
    expect(c.descendants.map((d) => (d.txid, d.fee, d.vSize)).toSet(), {(c1, 5000, 110.0), (c2, 800, 150.0)});
  });

  test('자손 한도(사건 거래 포함 25) 초과 → 거기서 멈추고 SweepBuilder가 tooManyDescendants', () async {
    final txid = _hash(1);
    mempool.txs[txid] = {'txid': txid, 'fee': 1410, 'weight': 564};
    mempool.outspends[txid] = [
      for (var i = 0; i < 40; i++) {'spent': true, 'txid': _hash(1000 + i)},
    ];
    for (var i = 0; i < 40; i++) {
      mempool.txs[_hash(1000 + i)] = {'txid': _hash(1000 + i), 'fee': 300, 'weight': 440};
    }

    final c = (await analyzer.analyze(1, [txid])).single;
    // 사건 거래 1 + 자손 25 = 26 > 25에서 멈춤
    expect(c.descendants.length, SweepBuilder.maxDescendants);
    expect(mempool.txCalls, 1 + SweepBuilder.maxDescendants);

    final wallet = WalletMock.createSingleSigWalletItem();
    final plan = SweepBuilder.plan(wallet: wallet, utxos: [_stolen(txid)], conflicts: [c], fastFeeRate: 2);
    expect(plan.blocker, SweepBlocker.tooManyDescendants);
  });

  test('확정된 충돌은 confirmed(자손 조회 안 함), 수수료를 모르는 거래는 빠짐', () async {
    final remoteConfirmed = _hash(1), localConfirmed = _hash(2), unknown = _hash(3);
    mempool.txs[remoteConfirmed] = {
      'txid': remoteConfirmed,
      'fee': 1410,
      'weight': 564,
      'status': {'confirmed': true, 'block_height': 120},
    };
    wallets.records[localConfirmed] = _record(localConfirmed, blockHeight: 119);

    final conflicts = await analyzer.analyze(1, [remoteConfirmed, localConfirmed, unknown]);
    expect(conflicts.map((c) => c.txid), [remoteConfirmed, localConfirmed]);
    expect(conflicts.every((c) => c.confirmed), isTrue);
    expect(mempool.outspendCalls, 0);

    final wallet = WalletMock.createSingleSigWalletItem();
    final plan = SweepBuilder.plan(
      wallet: wallet,
      utxos: [_stolen(remoteConfirmed)],
      conflicts: conflicts,
      fastFeeRate: 2,
    );
    expect(plan.blocker, SweepBlocker.conflictConfirmed);
  });

  test('H4: 자손 예산은 모든 사건 거래가 함께 쓴다(충돌마다 20개여도 합쳐서 막힘)', () async {
    final r1 = _hash(1), r2 = _hash(2);
    for (final (r, base) in [(r1, 1000), (r2, 2000)]) {
      mempool.txs[r] = {'txid': r, 'fee': 1410, 'weight': 564};
      mempool.outspends[r] = [
        for (var i = 0; i < 20; i++) {'spent': true, 'txid': _hash(base + i)},
      ];
      for (var i = 0; i < 20; i++) {
        mempool.txs[_hash(base + i)] = {'txid': _hash(base + i), 'fee': 300, 'weight': 440};
      }
    }

    final conflicts = await analyzer.analyze(1, [r1, r2]);
    final union = {for (final c in conflicts) c.txid, for (final c in conflicts) ...c.descendants.map((d) => d.txid)};
    expect(union.length, SweepBuilder.maxDescendants + 1);
    expect(conflicts[1].descendants.length, lessThan(20)); // 예산을 넘자 그만 찾음

    final wallet = WalletMock.createSingleSigWalletItem();
    final plan = SweepBuilder.plan(
      wallet: wallet,
      utxos: [_stolen(r1), _stolen(r2, i: 1)],
      conflicts: conflicts,
      fastFeeRate: 2,
    );
    expect(plan.blocker, SweepBlocker.tooManyDescendants);
  });

  group('H7: 형식이 틀린 mempool 응답', () {
    test('사건 거래 수수료가 음수·소수·txid 불일치면 로컬 값으로', () async {
      for (final bad in [
        {'fee': -5, 'weight': 564},
        {'fee': 2820.5, 'weight': 564},
        {'fee': 2820, 'weight': 0},
        {'fee': 2820, 'weight': 564, 'txid': _hash(99)},
      ]) {
        final txid = _hash(10);
        wallets.records[txid] = _record(txid, fee: 1410, vSize: 141);
        mempool.txs[txid] = {'txid': txid, ...bad};
        final c = (await analyzer.analyze(1, [txid])).single;
        expect((c.fee, c.vSize), (1410, 141.0), reason: '$bad');
      }
    });

    test('자손 응답의 txid가 다르거나 수수료가 틀리면 조회 실패(로컬만, 미완료)', () async {
      final txid = _hash(1), child = _hash(2);
      mempool.txs[txid] = {'txid': txid, 'fee': 1410, 'weight': 564};
      mempool.outspends[txid] = [
        {'spent': true, 'txid': child, 'vin': 0},
      ];
      for (final bad in [
        {'txid': _hash(3), 'fee': 300, 'weight': 440},
        {'txid': child, 'fee': -1, 'weight': 440},
        {'txid': child, 'fee': 300.5, 'weight': 440},
      ]) {
        mempool.txs[child] = bad;
        final c = (await analyzer.analyze(1, [txid])).single;
        expect(c.descendantsComplete, isFalse, reason: '$bad');
        expect(c.descendants, isEmpty);
      }
    });

    test('fetchOutspends: 형식 확인(HTTP 클라이언트)', () async {
      final txid = _hash(1);
      Future<List<Map<String, dynamic>>> fetch(int status, String body) => MempoolApi(
        client: MockClient((request) async {
          expect(request.url.path, endsWith('/api/tx/$txid/outspends'));
          return http.Response(body, status);
        }),
      ).fetchOutspends(txid);

      final ok = await fetch(
        200,
        jsonEncode([
          {
            'spent': true,
            'txid': _hash(2),
            'vin': 1,
            'status': {'confirmed': false},
          },
          {'spent': false},
        ]),
      );
      expect(ok.map((o) => o['spent']), [true, false]);

      for (final body in [
        '[{"spent": true}]',
        '[{"spent": "yes"}]',
        '[{"spent": true, "txid": "abc", "vin": 0}]',
        '[{"spent": true, "txid": "${_hash(2)}", "vin": -1}]',
        '{"spent": false}',
        '[1]',
      ]) {
        await expectLater(fetch(200, body), throwsFormatException, reason: body);
      }
      await expectLater(fetch(200, ''), throwsException);
      await expectLater(fetch(500, '[]'), throwsException);
      await expectLater(
        MempoolApi(client: MockClient((_) async => http.Response('[]', 200))).fetchOutspends('x'),
        throwsArgumentError,
      );
    });

    test('실제 MempoolApi로 형식이 틀린 outspends면 로컬만 + 미완료', () async {
      final txid = _hash(1);
      final api = MempoolApi(
        client: MockClient((request) async {
          if (request.url.path.endsWith('/outspends')) return http.Response('[{"spent": true}]', 200);
          return http.Response(jsonEncode({'txid': txid, 'fee': 1410, 'weight': 564}), 200);
        }),
      );
      final c =
          (await ConflictAnalyzer(
            nodeProvider: node,
            walletProvider: wallets,
            mempoolApi: api,
          ).analyze(1, [txid])).single;
      expect(c.fee, 1410);
      expect(c.descendantsComplete, isFalse);
    });
  });

  group('lead: 충돌·자손 수수료를 일렉트럼 원본으로 직접 셈(feeVerified, 20% 예외 근거)', () {
    SweepPlan floorPlan(SweepConflict c) => SweepBuilder.plan(
      wallet: WalletMock.createSingleSigWalletItem(),
      utxos: wallets.utxos,
      conflicts: [c],
      fastFeeRate: 0,
    );

    test('입력이 모두 내 UTXO면 (입력 합 − 출력 합, 서버 원본 크기)를 mempool 값보다 우선', () async {
      final attack = _attackTx(rbf: true);
      final txid = attack.transactionHash;
      node.raw[txid] = attack.serialize();
      wallets.utxos = [_stolen(txid)];
      // 부풀린 수수료·줄인 크기(대체 하한을 키우는 값)는 쓰지 않는다
      mempool.txs[txid] = {
        'txid': txid,
        'fee': 300000,
        'weight': 4,
        'status': {'confirmed': false},
      };

      final c = (await analyzer.analyze(1, [txid])).single;
      expect(c.feeVerified, isTrue);
      expect(c.fee, 400000 - attack.outputs.single.amount);
      expect(c.vSize, attack.getVirtualByte());
      expect(c.signalsRbf, isTrue);
      expect(c.confirmed, isFalse);
    });

    test('외부 입력의 이전 거래를 일렉트럼이 못 주거나 사건 원본을 못 읽으면 feeVerified false(기존 규칙)', () async {
      final attack = _spend([_stolen('', i: 0), _stolen('', i: 1)]);
      final txid = attack.transactionHash;
      node.raw[txid] = attack.serialize();
      wallets.utxos = [_stolen(txid)]; // 두 번째 입력은 이 지갑 것이 아니고, 이전 거래도 서버에 없음
      mempool.txs[txid] = {'txid': txid, 'fee': 2820, 'weight': 564};
      var c = (await analyzer.analyze(1, [txid])).single;
      expect((c.feeVerified, c.fee, c.vSize), (false, 2820, 141.0));

      node.raw.clear();
      wallets.utxos = [_stolen(txid), _stolen(txid, i: 1)];
      c = (await analyzer.analyze(1, [txid])).single;
      expect((c.feeVerified, c.fee), (false, 2820));
    });

    test('(a) 상대가 자기 입력을 달아도 그 이전 거래(txid 확인)의 출력 값으로 세면 확인 → 하한 예외', () async {
      final prev = _spend([_stolen('', i: 5)]);
      final attack = _spend([_stolen('', i: 0), _output(prev)]);
      final txid = attack.transactionHash;
      node.raw
        ..[txid] = attack.serialize()
        ..[prev.transactionHash] = prev.serialize();
      wallets.utxos = [_stolen(txid)];
      mempool.txs[txid] = {'txid': txid, 'fee': 2820, 'weight': 564};

      final c = (await analyzer.analyze(1, [txid])).single;
      expect(c.feeVerified, isTrue);
      expect(c.fee, 400000 + prev.outputs.single.amount - attack.outputs.single.amount);
      expect(c.vSize, attack.getVirtualByte());
      expect(SweepFee.isFloorExempt(floorPlan(c)), isTrue);
    });

    test('(b) 외부 입력이 있는 CPFP 자식도 이전 거래를 받아 세면 확인, 부모 출력은 이미 받은 원본으로(다시 안 받음)', () async {
      final root = _attackTx(rbf: true);
      final rootTxid = root.transactionHash;
      final prev = _spend([_stolen('', i: 6)]);
      final child = _spend([_output(root), _output(prev)]);
      final childTxid = child.transactionHash;
      node.raw
        ..[rootTxid] = root.serialize()
        ..[childTxid] = child.serialize()
        ..[prev.transactionHash] = prev.serialize();
      wallets.utxos = [_stolen(rootTxid)];
      mempool.txs[rootTxid] = {'txid': rootTxid, 'fee': 1410, 'weight': 564};
      // mempool.space의 자식 값(부풀림)은 일렉트럼 원본으로 센 값으로 바뀐다
      mempool.txs[childTxid] = {'txid': childTxid, 'fee': 900000, 'weight': 40};
      mempool.outspends[rootTxid] = [
        {'spent': true, 'txid': childTxid, 'vin': 0},
      ];

      final c = (await analyzer.analyze(1, [rootTxid])).single;
      expect(c.feeVerified, isTrue);
      expect(c.descendants.single, (
        txid: childTxid,
        fee: root.outputs.single.amount + prev.outputs.single.amount - child.outputs.single.amount,
        vSize: child.getVirtualByte(),
      ));
      expect(node.calls.where((id) => id == rootTxid).length, 1);
      expect(node.calls.where((id) => id == prev.transactionHash).length, 1);
      expect(SweepFee.isFloorExempt(floorPlan(c)), isTrue);
    });

    test('(c) mempool.space만 아는 자손(일렉트럼이 못 줌)이면 미확인 → 예외 아님, 그 자손은 mempool 값', () async {
      final root = _attackTx(rbf: true);
      final rootTxid = root.transactionHash;
      final ghost = _hash(77);
      node.raw[rootTxid] = root.serialize();
      wallets.utxos = [_stolen(rootTxid)];
      mempool.txs[rootTxid] = {'txid': rootTxid, 'fee': 1410, 'weight': 564};
      mempool.txs[ghost] = {'txid': ghost, 'fee': 50000, 'weight': 440};
      mempool.outspends[rootTxid] = [
        {'spent': true, 'txid': ghost, 'vin': 0},
      ];

      final c = (await analyzer.analyze(1, [rootTxid])).single;
      expect(c.feeVerified, isFalse);
      expect(c.descendants.single, (txid: ghost, fee: 50000, vSize: 110.0));
      expect(SweepFee.isFloorExempt(floorPlan(c)), isFalse);
    });

    test('(d) 일렉트럼이 준 이전 거래의 해시가 txid와 다르면 미확인 → 예외 아님', () async {
      final prev = _spend([_stolen('', i: 5)]);
      final attack = _spend([_stolen('', i: 0), _output(prev)]);
      final txid = attack.transactionHash;
      node.raw
        ..[txid] = attack.serialize()
        ..[prev.transactionHash] = _spend([_stolen('', i: 7)]).serialize(); // 다른 거래로 바꿔치기
      wallets.utxos = [_stolen(txid)];
      mempool.txs[txid] = {'txid': txid, 'fee': 2820, 'weight': 564};

      final c = (await analyzer.analyze(1, [txid])).single;
      expect((c.feeVerified, c.fee), (false, 2820));
      expect(SweepFee.isFloorExempt(floorPlan(c)), isFalse);
    });
  });
}
