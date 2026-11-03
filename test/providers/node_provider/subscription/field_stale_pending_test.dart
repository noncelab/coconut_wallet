// Field reports after v1.0.0 (Discord 11/1-11/3):
// R1: an outgoing tx confirmed long ago still shows as 보내는 중 (pending) in the wallet and the UTXO list.
// R2: endless updating (무한 업데이트) around exchange batch withdrawals (many inputs and outputs).
//
// Harness from pending_utxo_after_send_test.dart (fix/pending-utxo-repro e75d70b9): the real isolate-side sync
// (SubscriptionService -> ScriptSyncService -> Balance/Transaction/UtxoSyncService) on the in-memory Realm, against
// a fake Fulcrum backend. New here: state goes through the real IsolateStateManager -> port -> NodeStateManager, so
// NodeSyncState / WalletUpdateInfo / WalletFetchProgress are what the app's main isolate would see. A reconnect
// recreates both (node_provider.dart:450 + a new isolate). Each test prints one `FIELD_OBS {json}` line; R1 tests
// assert the desired outcome (a failure is a reproduction), R2 tests assert only what they measure.
import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/node/isolate_state_message.dart';
import 'package:coconut_wallet/model/node/resync_progress.dart';
import 'package:coconut_wallet/model/node/subscribe_stream_dto.dart';
import 'package:coconut_wallet/model/node/wallet_fetch_progress.dart';
import 'package:coconut_wallet/model/node/wallet_update_info.dart';
import 'package:coconut_wallet/model/wallet/balance.dart';
import 'package:coconut_wallet/model/wallet/singlesig_wallet_item.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/providers/node_provider/balance_sync_service.dart';
import 'package:coconut_wallet/providers/node_provider/isolate/isolate_enum.dart';
import 'package:coconut_wallet/providers/node_provider/network_service.dart';
import 'package:coconut_wallet/providers/node_provider/state/isolate_state_manager.dart';
import 'package:coconut_wallet/providers/node_provider/state/node_state_manager.dart';
import 'package:coconut_wallet/providers/node_provider/subscription/script_callback_service.dart';
import 'package:coconut_wallet/providers/node_provider/subscription/script_sync_service.dart';
import 'package:coconut_wallet/providers/node_provider/subscription/subscription_service.dart';
import 'package:coconut_wallet/providers/node_provider/transaction/transaction_record_service.dart';
import 'package:coconut_wallet/providers/node_provider/transaction/transaction_sync_service.dart';
import 'package:coconut_wallet/providers/node_provider/utxo_sync_service.dart';
import 'package:coconut_wallet/repository/realm/address_repository.dart';
import 'package:coconut_wallet/repository/realm/model/coconut_wallet_model.dart';
import 'package:coconut_wallet/repository/realm/service/realm_id_service.dart';
import 'package:coconut_wallet/repository/realm/subscription_repository.dart';
import 'package:coconut_wallet/repository/realm/transaction_draft_repository.dart';
import 'package:coconut_wallet/repository/realm/transaction_repository.dart';
import 'package:coconut_wallet/repository/realm/utxo_repository.dart';
import 'package:coconut_wallet/repository/realm/wallet_repository.dart';
import 'package:coconut_wallet/services/electrum_service.dart';
import 'package:coconut_wallet/services/model/response/block_timestamp.dart';
import 'package:coconut_wallet/services/model/response/electrum_response_types.dart';
import 'package:coconut_wallet/services/network/socket/socket_manager.dart';
import 'package:coconut_wallet/utils/electrum_utils.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import '../../../mock/script_sync_service_mock.dart';
import '../../../mock/wallet_mock.dart';
import '../../../services/network/socket/socket_manager_test.mocks.dart';
import '../transaction/rbf_service_test.mocks.dart';

const _walletId = 1;
final _external = WalletMock.createMultiSigWalletItem().walletBase.getAddress(0);
final _ports = <ReceivePort>[];

/// One Fulcrum backend as seen through the app's current socket.
class _Backend {
  final txs = <String, Transaction>{};
  final heights = <String, int>{}; // tx in this backend's chain (>0) or mempool (0)
  final _outputs = <String, List<(String, int)>>{}; // hash -> (address, amount) per output
  final listeners = <String, Function(String, String?)>{}; // scripthash subscriptions of the current socket
  final missingHeaders = <int>{};
  bool headersMissingOnce = false; // missingHeaders are served again after the first request that hit them
  bool Function(String method, String key) fault = (_, __) => false;
  Duration faultDelay = Duration.zero; // a failing request first hangs this long (a timeout instead of an error)
  int faultsHit = 0;
  final calls = <String>[]; // '$method:$key' of every request
  Duration latency = Duration.zero;

  void put(Transaction tx, [int? height]) {
    final hash = tx.transactionHash;
    txs[hash] = tx;
    _outputs[hash] = [for (final o in tx.outputs) (o.scriptPubKey.getAddress(), o.amount)];
    if (height != null) heights[hash] = height;
  }

  (String, int)? _prevout(TransactionInput input) {
    final outs = _outputs[input.transactionHash];
    return outs == null || input.index >= outs.length ? null : outs[input.index];
  }

  bool _spent(String hash, int index, {bool confirmedOnly = false}) => heights.entries.any(
    (s) =>
        (!confirmedOnly || s.value > 0) &&
        txs[s.key]!.inputs.any((input) => input.transactionHash == hash && input.index == index),
  );

  List<GetTxHistoryRes> history(String address) {
    final result = [
      for (final entry in heights.entries)
        if (_outputs[entry.key]!.any((o) => o.$1 == address) ||
            txs[entry.key]!.inputs.any((i) => _prevout(i)?.$1 == address))
          GetTxHistoryRes(height: entry.value, txHash: entry.key),
    ];
    int order(GetTxHistoryRes h) => h.height > 0 ? h.height : 1 << 30;
    return result..sort((x, y) => order(x).compareTo(order(y)));
  }

  String? status(String address) {
    final entries = history(address);
    return entries.isEmpty ? null : entries.map((h) => '${h.txHash}:${h.height}').join('|');
  }

  List<ListUnspentRes> unspent(String address) => [
    for (final entry in heights.entries)
      for (var n = 0; n < _outputs[entry.key]!.length; n++)
        if (_outputs[entry.key]![n].$1 == address && !_spent(entry.key, n))
          ListUnspentRes(height: entry.value, txHash: entry.key, txPos: n, value: _outputs[entry.key]![n].$2),
  ];

  GetBalanceRes balance(String address) {
    var confirmed = 0, unconfirmed = 0;
    for (final entry in heights.entries) {
      final inMempool = entry.value <= 0;
      final outs = _outputs[entry.key]!;
      for (var n = 0; n < outs.length; n++) {
        if (outs[n].$1 != address) continue;
        if (inMempool) {
          unconfirmed += outs[n].$2;
        } else if (!_spent(entry.key, n, confirmedOnly: true)) {
          confirmed += outs[n].$2;
        }
      }
      if (inMempool) {
        for (final input in txs[entry.key]!.inputs) {
          final prevout = _prevout(input);
          if (prevout?.$1 == address) unconfirmed -= prevout!.$2;
        }
      }
    }
    return GetBalanceRes(confirmed: confirmed, unconfirmed: unconfirmed);
  }

  String rawTx(String hash) {
    if (!heights.containsKey(hash)) throw StateError('No such mempool or blockchain transaction');
    return txs[hash]!.serialize();
  }

  void notify(String address) => listeners[address]?.call('scripthash', status(address));

  void serve(MockElectrumService electrum) {
    Future<T> answer<T>(String method, String key, T Function() body) async {
      calls.add('$method:$key');
      await Future<void>.delayed(latency);
      if (fault(method, key)) {
        faultsHit++;
        await Future<void>.delayed(faultDelay);
        throw StateError('injected $method($key) failure');
      }
      return body();
    }

    String arg(Invocation call, int i) => call.positionalArguments[i] as String;
    when(electrum.getBalance(any, any)).thenAnswer((c) => answer('getBalance', arg(c, 1), () => balance(arg(c, 1))));
    when(electrum.getHistory(any, any)).thenAnswer((c) => answer('getHistory', arg(c, 1), () => history(arg(c, 1))));
    when(
      electrum.getUnspentList(any, any),
    ).thenAnswer((c) => answer('listunspent', arg(c, 1), () => unspent(arg(c, 1))));
    when(electrum.getTransaction(any)).thenAnswer((c) => answer('getTransaction', arg(c, 0), () => rawTx(arg(c, 0))));
    // Mirrors ElectrumService.getPreviousTransactions (electrum_service.dart:247-299): one getTransaction per distinct
    // parent, all in flight at once (Future.wait), and [] when any of them fails.
    when(electrum.getPreviousTransactions(any, existingTxList: anyNamed('existingTxList'))).thenAnswer((c) async {
      final tx = c.positionalArguments[0] as Transaction;
      final existing = (c.namedArguments[#existingTxList] as List<Transaction>?) ?? const <Transaction>[];
      final known = existing.map((t) => t.transactionHash).toSet();
      final hashes = tx.inputs.map((i) => i.transactionHash).where((h) => !known.contains(h)).toSet();
      try {
        final fetched = await Future.wait(
          hashes.map((hash) async => Transaction.parse(await answer('getTransaction', hash, () => rawTx(hash)))),
        );
        return [...fetched, ...existing];
      } catch (_) {
        return <Transaction>[];
      }
    });
    // ElectrumService.fetchBlocksByHeight swallows per-height failures and returns a partial map.
    when(electrum.fetchBlocksByHeight(any)).thenAnswer(
      (c) => answer('headers', '', () {
        final requested = c.positionalArguments[0] as Set<int>;
        final missing = requested.where(missingHeaders.contains).toSet();
        faultsHit += missing.length;
        if (headersMissingOnce) missingHeaders.removeAll(missing);
        return {
          for (final h in requested)
            if (!missing.contains(h)) h: BlockTimestamp(h, DateTime.utc(2026, 10, 27).add(Duration(minutes: h))),
        };
      }),
    );
    when(
      electrum.subscribeScriptForWallet(any, any, walletId: anyNamed('walletId'), onUpdate: anyNamed('onUpdate')),
    ).thenAnswer(
      (c) => answer('subscribe', arg(c, 1), () {
        listeners[arg(c, 1)] = c.namedArguments[#onUpdate] as Function(String, String?);
        return status(arg(c, 1));
      }),
    );
    when(electrum.unsubscribeScript(any, any)).thenAnswer((c) async {
      listeners.remove(arg(c, 1));
      return true;
    });
    when(electrum.broadcast(any)).thenAnswer(
      (c) => answer('broadcast', '', () {
        final tx = Transaction.parse(arg(c, 0));
        put(tx, 0);
        return tx.transactionHash;
      }),
    );
  }
}

/// One isolate session (IsolateInitializer wiring) plus the main isolate's NodeStateManager fed by its messages.
class _Session {
  final SubscriptionService node;
  final IsolateStateManager isolateState;
  final NodeStateManager main;
  _Session(this.node, this.isolateState, this.main);

  factory _Session.start(MockElectrumService electrum) {
    final main = NodeStateManager(
      () {},
      StreamController<NodeSyncState>.broadcast(),
      StreamController<Map<int, WalletUpdateInfo>>.broadcast(),
      StreamController<Map<int, ResyncProgress>>.broadcast(),
      StreamController<Map<int, WalletFetchProgress>>.broadcast(),
    );
    final port = ReceivePort();
    _ports.add(port);
    // IsolateManager's updateState handling (isolate_manager.dart:256-268).
    port.listen((message) {
      final payload = (message as List)[1] as List;
      main.handleIsolateStateMessage(IsolateStateMessage(payload[0] as IsolateStateMethod, payload.sublist(1)));
    });
    final state = IsolateStateManager(port.sendPort);
    final realmManager = ScriptSyncServiceMock.realmManager!;
    final addresses = AddressRepository(realmManager);
    final transactions = TransactionRepository(realmManager);
    final utxos = UtxoRepository(realmManager);
    final callbacks = ScriptCallbackService();
    final wallets = WalletRepository(realmManager, TransactionDraftRepository(realmManager));
    final sync = ScriptSyncService(
      state,
      BalanceSyncService(electrum, state, addresses, wallets),
      TransactionSyncService(
        electrum,
        transactions,
        TransactionRecordService(electrum, addresses),
        state,
        utxos,
        callbacks,
      ),
      UtxoSyncService(electrum, state, utxos, transactions, addresses),
      addresses,
      callbacks,
    );
    return _Session(
      SubscriptionService(electrum, state, addresses, SubscriptionRepository(realmManager), sync),
      state,
      main,
    );
  }

  /// IsolateController.subscribeWallets for one wallet, then NodeProvider's failure handling (node_provider.dart:777).
  Future<bool> subscribe(WalletItemBase wallet) async {
    isolateState.initWalletUpdateStatus(wallet.id);
    isolateState.setNodeSyncStateToSyncing();
    final result = await node.subscribeWallet(wallet);
    await _settle();
    if (result.isFailure) main.setNodeSyncStateToFailed();
    return result.isSuccess;
  }
}

/// Lets queued port messages reach the main-side NodeStateManager.
Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 30));

/// Lets the subscription stream enqueue pushed statuses, then waits for the wallet queue to drain.
Future<void> _drain(_Session session) async {
  await Future<void>.delayed(Duration.zero);
  await session.node.runExclusive(_walletId, () async {});
  await _settle();
}

Transaction _tx(List<(String, int)> inputs, List<(String, int)> outputs) => Transaction.withInputsAndOutputs(
  [for (final (hash, index) in inputs) TransactionInput.forPayment(hash, index)],
  [for (final (address, amount) in outputs) TransactionOutput.forPayment(amount, address)],
  AddressType.p2wpkh,
);

/// Wallet (receive/change addresses) plus the backend that knows its history.
class _Case {
  final electrum = ScriptSyncServiceMock.electrumService;
  final backend = _Backend();
  final SinglesigWalletItem wallet = WalletMock.createSingleSigWalletItem(id: _walletId);
  late final String input; // address holding the coin the app spends
  late final String change;
  String? neighbour;
  late final Transaction faucet, funding, spend;
  late final bool sweep, unconfirmedFunding;
  int _payments = 0;

  String get coin => getUtxoId(funding.transactionHash, 0);
  UtxoRepository get utxos => ScriptSyncServiceMock.utxoRepository;
  List<String> get spendAddresses => sweep ? [input] : [input, change];

  /// [withNeighbour]: a second receive address; by default receive 0, and the coin sits on receive 1 (newest used).
  /// [neighbourIsNewer] swaps them. [dormantNeighbour]: the neighbour was funded and emptied (confirmed).
  /// [sweep]: the spend has no change output, so only the input address gets a push.
  /// [unconfirmedFunding]: the coin is still unconfirmed when it is spent (CPFP or a spend from another app).
  Future<void> init({
    bool withNeighbour = false,
    bool dormantNeighbour = false,
    bool neighbourIsNewer = false,
    bool sweep = false,
    bool unconfirmedFunding = false,
  }) async {
    this.sweep = sweep;
    this.unconfirmedFunding = unconfirmedFunding;
    final realm = ScriptSyncServiceMock.realmManager!.realm;
    realm.write(() {
      realm.add(
        RealmWalletBase(
          wallet.id,
          wallet.colorIndex,
          wallet.iconIndex,
          wallet.descriptor,
          wallet.name,
          WalletType.singleSignature.name,
        ),
      );
    });
    await ScriptSyncServiceMock.addressRepository.ensureAddressesInit(walletItemBase: wallet);
    ScriptSyncServiceMock.walletRepository.updateWalletBalance(wallet.id, Balance(0, 0));

    final base = wallet.walletBase;
    if (withNeighbour) neighbour = base.getAddress(neighbourIsNewer ? 1 : 0);
    input = base.getAddress(withNeighbour && !neighbourIsNewer ? 1 : 0);
    change = base.getAddress(0, isChange: true);

    faucet = _tx([('00' * 32, 0)], List.filled(8, (_external, 5000000)));
    funding = _tx([(faucet.transactionHash, 0)], [(input, 1000000), (_external, 3999000)]);
    spend = _tx([
      (funding.transactionHash, 0),
    ], sweep ? [(_external, 999000)] : [(_external, 300000), (change, 699000)]);
    backend
      ..put(faucet, 10)
      ..put(funding, unconfirmedFunding ? 0 : 100)
      ..put(spend);
    if (dormantNeighbour) {
      final neighbourIn = _tx([(faucet.transactionHash, 2)], [(neighbour!, 200000), (_external, 4799000)]);
      backend
        ..put(neighbourIn, 90)
        ..put(_tx([(neighbourIn.transactionHash, 0)], [(_external, 199000)]), 95);
    }
    backend.serve(electrum);
  }

  /// What the isolate receives from the main isolate: a copy with used indexes as persisted.
  SinglesigWalletItem walletCopy() {
    final copy = WalletMock.createSingleSigWalletItem(id: _walletId);
    final (receive, change) = ScriptSyncServiceMock.addressRepository.getUsedIndexes(_walletId);
    copy.receiveUsedIndex = receive;
    copy.changeUsedIndex = change;
    return copy;
  }

  String _utxo(String id) => ScriptSyncServiceMock.utxoRepository.getUtxoState(_walletId, id)?.status.name ?? 'deleted';
  String coinState() => _utxo(coin);

  /// Pull-to-refresh / resume with a failed state / connectivity change: NodeProvider.reconnect() replaces the isolate
  /// (and the main NodeStateManager) and resubscribes.
  Future<(_Session, bool)> reconnect() async {
    backend.listeners.clear();
    final session = _Session.start(electrum);
    final ok = await session.subscribe(walletCopy());
    return (session, ok);
  }

  /// A later unrelated push that resubscribes: someone pays the next fresh receive address.
  Future<String> nextIncomingPush(_Session session) async {
    final (receive, _) = ScriptSyncServiceMock.addressRepository.getUsedIndexes(_walletId);
    final address = wallet.walletBase.getAddress(receive + 1);
    final payment = _tx([(faucet.transactionHash, 3 + _payments++)], [(address, 40000), (_external, 4959000)]);
    backend.put(payment, 0);
    backend.notify(address);
    await _drain(session);
    return payment.transactionHash;
  }

  /// What the user sees. shows_sending: the spend is still 보내는 중 in the tx list (record at height 0) or the spent
  /// coin is still 'outgoing' in the UTXO list.
  Map<String, Object?> ui(_Session session) {
    final record = ScriptSyncServiceMock.transactionRepository.getTransactionRecord(_walletId, spend.transactionHash);
    return {
      'coin': coinState(),
      'spend_height': record?.blockHeight,
      if (!sweep) 'change_utxo': _utxo(getUtxoId(spend.transactionHash, 1)),
      'shows_sending': coinState() == 'outgoing' || record?.blockHeight == 0,
      ..._indicators(session),
    };
  }
}

/// UI flags derived from the main-side state.
/// tx_list_updating: WalletFetchProgress completed < dispatched; the transaction list shows "업데이트 중" for it when
/// NodeSyncState is not failed (transaction_list_view_model.dart:71-82, :251) and then hides its pull-to-refresh
/// (transaction_list_screen.dart:104-114). utxo_refresh_noop: the UTXO overview's refresh returns at once while the
/// utxo element is waiting/syncing (utxo_overview_view_model.dart:98, :329).
Map<String, Object?> _indicators(_Session session) {
  final progress = session.main.fetchProgressByWallet[_walletId];
  final info = session.main.state.registeredWallets[_walletId];
  final nodeSync = session.main.state.nodeSyncState;
  final deficit = progress != null && progress.completed < progress.dispatched;
  return {
    'tx_list_updating': deficit,
    'tx_list_spinner_shown': deficit && nodeSync != NodeSyncState.failed,
    'fetch_progress': progress == null ? '-' : '${progress.completed}/${progress.dispatched}',
    'node_sync': nodeSync.name,
    'utxo_refresh_noop': info != null && (info.utxo == WalletSyncState.waiting || info.utxo == WalletSyncState.syncing),
    'wallet_state':
        info == null
            ? '-'
            : [info.subscription, info.balance, info.transaction, info.utxo].map((e) => e.name).join('/'),
  };
}

/// Records which wallet each live push reaches instead of syncing it.
class _InertSync extends ScriptSyncService {
  final List<int> pushes;
  _InertSync(this.pushes)
    : super(
        ScriptSyncServiceMock.stateManager,
        ScriptSyncServiceMock.balanceSyncService,
        ScriptSyncServiceMock.transactionSyncService,
        ScriptSyncServiceMock.utxoSyncService,
        ScriptSyncServiceMock.addressRepository,
        ScriptSyncServiceMock.scriptCallbackService,
      );

  @override
  Future<void> syncScriptStatus(SubscribeScriptStreamDto dto) async => pushes.add(dto.walletItem.id);
}

/// Exchange batch withdrawal: [inputs] foreign inputs (one parent tx each) and [outputs] outputs, [ours] paying us.
class _Batch {
  final List<Transaction> parents;
  final Transaction tx;
  final List<String> ours;
  final String hash;
  final Set<String> parentHashes;
  _Batch(this.parents, this.tx, this.ours)
    : hash = tx.transactionHash,
      parentHashes = parents.map((p) => p.transactionHash).toSet();

  factory _Batch.build(_Case c, {int ours = 1, int inputs = 150, int outputs = 300}) {
    final mine = [for (var i = 1; i <= ours; i++) c.wallet.walletBase.getAddress(i)];
    final parents = [
      for (var i = 0; i < inputs; i++) _tx([('11' * 32, i)], [(_external, 2000000 + i), (_external, 1000 + i)]),
    ];
    final tx = _tx(
      [for (final p in parents) (p.transactionHash, 0)],
      [for (var k = 0; k < outputs - ours; k++) (_external, 10000 + k), for (final a in mine) (a, 250000)],
    );
    for (final p in parents) {
      c.backend.put(p, 50);
    }
    c.backend.put(tx); // the backend serves it once a pass gives it a height
    return _Batch(parents, tx, mine);
  }

  Map<String, int> count(List<String> calls) {
    final counts = <String, int>{};
    for (final call in calls) {
      final at = call.indexOf(':');
      final method = call.substring(0, at), key = call.substring(at + 1);
      final kind =
          method != 'getTransaction'
              ? method
              : key == hash
              ? 'raw_batch'
              : parentHashes.contains(key)
              ? 'raw_prev'
              : 'raw_other';
      counts[kind] = (counts[kind] ?? 0) + 1;
    }
    return counts..['total'] = calls.length;
  }

  Map<String, Object?> state(_Session session) {
    final record = ScriptSyncServiceMock.transactionRepository.getTransactionRecord(_walletId, hash);
    return {
      'record_height': record?.blockHeight,
      'record_inputs': record?.inputAddressList.length,
      'record_fee': record?.fee,
      'utxos': [
        for (final u in ScriptSyncServiceMock.utxoRepository.getUtxoStateList(_walletId))
          if (u.transactionHash == hash) u.status.name,
      ],
      ..._indicators(session),
    };
  }
}

void _report(String variant, String order, Map<String, Object?> observed) {
  // ignore: avoid_print
  print('FIELD_OBS ${jsonEncode({'variant': variant, 'order': order, ...observed})}');
}

void main() {
  setUp(ScriptSyncServiceMock.init);
  tearDown(() {
    for (final port in _ports) {
      port.close();
    }
    _ports.clear();
    ScriptSyncServiceMock.realmManager?.dispose();
    ScriptSyncServiceMock.realmManager = null;
  });

  /// Synced wallet, the app broadcasts its own spend and both statuses are pushed and synced on a healthy socket:
  /// the coin is 'outgoing' and the spend is recorded at height 0 (보내는 중).
  Future<(_Case, _Session)> pendingSend({
    bool withNeighbour = false,
    bool dormantNeighbour = false,
    bool neighbourIsNewer = false,
    bool sweep = false,
    bool unconfirmedFunding = false,
    void Function(_Case c)? duringSendPush,
    bool requireOutgoing = true,
  }) async {
    final c = _Case();
    await c.init(
      withNeighbour: withNeighbour,
      dormantNeighbour: dormantNeighbour,
      neighbourIsNewer: neighbourIsNewer,
      sweep: sweep,
      unconfirmedFunding: unconfirmedFunding,
    );
    final s = _Session.start(c.electrum);
    expect(await s.subscribe(c.wallet), isTrue);
    expect((await NetworkService(c.electrum).broadcast(c.spend)).isSuccess, isTrue);
    duringSendPush?.call(c);
    for (final address in c.spendAddresses) {
      c.backend.notify(address);
    }
    await _drain(s);
    c.backend
      ..fault = ((_, __) => false)
      ..faultDelay = Duration.zero;
    if (requireOutgoing) expect(c.coinState(), 'outgoing', reason: 'precondition: the send was synced');
    return (c, s);
  }

  /// The spend confirms in block 102 and the server pushes [order]; then two recovery probes.
  Future<Map<String, Object?>> confirmAndProbe(_Case c, _Session s, List<String> order, {void Function()? arm}) async {
    final b = c.backend;
    b.heights[c.spend.transactionHash] = 102;
    if (c.unconfirmedFunding) b.heights[c.funding.transactionHash] = 102;
    arm?.call();
    final faultsBefore = b.faultsHit;
    for (final address in order) {
      b.notify(address);
    }
    await _drain(s);
    final observed = <String, Object?>{'faults_hit': b.faultsHit - faultsBefore, ...c.ui(s)};
    b
      ..fault = ((_, __) => false)
      ..faultDelay = Duration.zero
      ..missingHeaders.clear();

    // Probe 1: the next push that resubscribes (an unrelated incoming payment to a fresh receive address).
    final payment = await c.nextIncomingPush(s);
    observed['after_next_push'] = {
      ...c.ui(s),
      'new_payment_recorded':
          ScriptSyncServiceMock.transactionRepository.getTransactionRecord(_walletId, payment) != null,
    };
    // Probe 2: reconnect (resume with a failed state, pull-to-refresh, >5 min background on develop).
    final (s2, ok) = await c.reconnect();
    observed['after_reconnect'] = {'subscribe_ok': ok, ...c.ui(s2)};
    return observed;
  }

  void expectConfirmed(Map<String, Object?> observed) {
    expect(observed['coin'], 'deleted', reason: 'the spent coin must leave the UTXO list once the spend confirms');
    expect(observed['spend_height'], 102, reason: 'the spend must stop showing as 보내는 중');
  }

  group('R1 stale 보내는 중 after confirmation', () {
    // (a) control
    for (final changeFirst in [false, true]) {
      final order = changeFirst ? 'change-first' : 'input-first';
      test('[a-healthy] $order', () async {
        final (c, s) = await pendingSend();
        final observed = await confirmAndProbe(c, s, changeFirst ? [c.change, c.input] : [c.input, c.change]);
        _report('a-healthy', order, observed);
        expectConfirmed(observed);
      });
    }

    // (b) one transient failure while the confirmation push runs (the change and input are the newest used
    // addresses, so on develop both pushes take the extension path first).
    const onceFaults = ['balance-once', 'history-once', 'raw-once', 'header-once'];
    void Function() armOnce(_Case c, String kind) => () {
      final hit = <String>{};
      bool first(String id) => hit.add(id);
      final b = c.backend;
      switch (kind) {
        case 'balance-once':
          b.fault = (m, _) => m == 'getBalance' && first('b');
        case 'history-once':
          b.fault = (m, _) => m == 'getHistory' && first('h');
        case 'raw-once':
          b.fault = (m, k) => m == 'getTransaction' && k == c.spend.transactionHash && first('r');
        case 'header-once':
          b
            ..missingHeaders.add(102)
            ..headersMissingOnce = true;
      }
    };
    for (final kind in ['balance-once', 'raw-once']) {
      for (final changeFirst in [false, true]) {
        final order = changeFirst ? 'change-first' : 'input-first';
        test('[b-two-pushes-$kind] $order', () async {
          final (c, s) = await pendingSend();
          final observed = await confirmAndProbe(
            c,
            s,
            changeFirst ? [c.change, c.input] : [c.input, c.change],
            arm: armOnce(c, kind),
          );
          _report('b-two-pushes-$kind', order, observed);
          expect(observed['faults_hit'], 1);
          expectConfirmed(observed);
        });
      }
    }
    for (final kind in onceFaults) {
      test('[b-single-push-$kind] sweep: only the input address is pushed', () async {
        final (c, s) = await pendingSend(sweep: true);
        final observed = await confirmAndProbe(c, s, [c.input], arm: armOnce(c, kind));
        _report('b-single-push-$kind', 'input-only', observed);
        expect(observed['faults_hit'], 1);
        expectConfirmed(observed);
      });
    }

    // (c) a balance failure retained from earlier in the session (dormant check on resume, address list screen).
    Future<void> poisonDormant(_Case c, _Session s) async {
      c.backend.fault = (m, k) => m == 'getBalance' && k == c.neighbour;
      await s.node.syncDormantAddresses(c.walletCopy());
      c.backend.fault = (_, __) => false;
      await _settle();
      expect(c.backend.faultsHit, 1, reason: 'precondition: the dormant-address balance check timed out');
    }

    for (final changeFirst in [false, true]) {
      final order = changeFirst ? 'change-first' : 'input-first';
      test('[c-dormant-check-failed] $order: coin on the newest receive address', () async {
        final (c, s) = await pendingSend(withNeighbour: true, dormantNeighbour: true);
        await poisonDormant(c, s);
        final observed = await confirmAndProbe(c, s, changeFirst ? [c.change, c.input] : [c.input, c.change]);
        _report('c-dormant-check-failed', order, observed);
        expectConfirmed(observed);
      });
    }
    test('[c-dormant-check-failed-coin-not-newest] input-first', () async {
      final (c, s) = await pendingSend(withNeighbour: true, dormantNeighbour: true, neighbourIsNewer: true);
      await poisonDormant(c, s);
      final observed = await confirmAndProbe(c, s, [c.input, c.change]);
      _report('c-dormant-check-failed-coin-not-newest', 'input-first', observed);
      expectConfirmed(observed);
      expect(observed['change_utxo'], 'unspent', reason: 'the change must stop showing as 받는 중');
    });
    test('[c-viewed-address-check-failed] input-first (address_list_view_model.dart:191)', () async {
      final (c, s) = await pendingSend();
      final page = await ScriptSyncServiceMock.addressRepository.getWalletAddressList(c.wallet, 0, 10, false, false);
      final viewed = page.firstWhere((a) => a.index == 5);
      c.backend.fault = (m, k) => m == 'getBalance' && k == viewed.address;
      await s.node.syncViewedAddresses(c.walletCopy(), page);
      c.backend.fault = (_, __) => false;
      expect(c.backend.faultsHit, 1, reason: 'precondition: one viewed-address balance check failed');
      final observed = await confirmAndProbe(c, s, [c.input, c.change]);
      _report('c-viewed-address-check-failed', 'input-first', observed);
      expectConfirmed(observed);
    });

    // (d) the socket died silently in the background: the confirmation pushes are lost, then the reconnect batch
    // hits one transient failure.
    for (final kind in onceFaults) {
      test('[d-dead-socket-reconnect-$kind]', () async {
        final (c, _) = await pendingSend();
        final b = c.backend;
        b.listeners.clear(); // pushes from now on go nowhere
        b.heights[c.spend.transactionHash] = 102;
        armOnce(c, kind)();
        final (s1, ok1) = await c.reconnect();
        final observed = <String, Object?>{'faults_hit': b.faultsHit, 'subscribe_ok': ok1, ...c.ui(s1)};
        b
          ..fault = ((_, __) => false)
          ..missingHeaders.clear();
        final payment = await c.nextIncomingPush(s1);
        observed['after_next_push'] = {
          ...c.ui(s1),
          'new_payment_recorded':
              ScriptSyncServiceMock.transactionRepository.getTransactionRecord(_walletId, payment) != null,
        };
        final (s2, ok2) = await c.reconnect();
        observed['after_second_reconnect'] = {'subscribe_ok': ok2, ...c.ui(s2)};
        _report('d-dead-socket-reconnect-$kind', '-', observed);
        expect(observed['faults_hit'], 1);
        expectConfirmed(observed);
      });
    }

    // (e) can the input address be unsubscribed as dormant while the spend is pending?
    test('[e-dormant-check-while-pending] confirmed coin spent', () async {
      final (c, s) = await pendingSend();
      await s.node.syncDormantAddresses(c.walletCopy());
      final subscribed = c.backend.listeners.containsKey(c.input);
      final observed = {
        'input_subscribed_before_confirmation': subscribed,
        ...await confirmAndProbe(c, s, [c.input, c.change]),
      };
      _report('e-dormant-check-while-pending', 'input-first', observed);
      expect(subscribed, isTrue);
      expectConfirmed(observed);
    });
    test('[e-unconfirmed-coin-sweep] coin spent before it confirmed (CPFP / other app), no change', () async {
      final (c, s) = await pendingSend(sweep: true, unconfirmedFunding: true);
      final subscribed = c.backend.listeners.containsKey(c.input);
      final observed = {
        'input_subscribed_before_confirmation': subscribed,
        ...await confirmAndProbe(c, s, [c.input]),
      };
      _report('e-unconfirmed-coin-sweep', 'input-only', observed);
      expect(subscribed, isTrue);
      expectConfirmed(observed);
    });
    test('[e-unconfirmed-coin-sweep-parent-unfetchable] its parent cannot be fetched while the spend syncs', () async {
      final (c, s) = await pendingSend(
        sweep: true,
        unconfirmedFunding: true,
        // e.g. a large exchange withdrawal that times out (5 s) and the mempool.space fallback fails
        duringSendPush: (c) => c.backend.fault = (m, k) => m == 'getTransaction' && k == c.funding.transactionHash,
        requireOutgoing: false,
      );
      final coinAfterSend = c.coinState();
      final subscribed = c.backend.listeners.containsKey(c.input);
      final record = ScriptSyncServiceMock.transactionRepository.getTransactionRecord(
        _walletId,
        c.spend.transactionHash,
      );
      final observed = {
        'coin_after_send': coinAfterSend,
        'input_subscribed_before_confirmation': subscribed,
        'parent_record_kept':
            ScriptSyncServiceMock.transactionRepository.getTransactionRecord(_walletId, c.funding.transactionHash) !=
            null,
        'spend_record_type': record?.transactionType.name,
        'spend_record_inputs': record?.inputAddressList.length,
        ...await confirmAndProbe(c, s, [c.input]),
      };
      _report('e-unconfirmed-coin-sweep-parent-unfetchable', 'input-only', observed);
      expect(subscribed, isTrue);
      expectConfirmed(observed);
    });
  });

  group('Codex cross-checks', () {
    // (b) getPreviousTransactions drops every parent when one fails (electrum_service.dart:269-298).
    test('[x-send-parent-unfetchable] the funding tx cannot be fetched while the app\'s own send syncs', () async {
      final (c, s) = await pendingSend(
        duringSendPush: (c) => c.backend.fault = (m, k) => m == 'getTransaction' && k == c.funding.transactionHash,
      );
      final records = ScriptSyncServiceMock.transactionRepository;
      final pending = records.getTransactionRecord(_walletId, c.spend.transactionHash)!;
      final observed = <String, Object?>{
        'pending_type': pending.transactionType.name,
        'pending_amount': pending.amount,
        'pending_fee': pending.fee,
        'pending_inputs': pending.inputAddressList.length,
        ...await confirmAndProbe(c, s, [c.input, c.change]),
      };
      final settled = records.getTransactionRecord(_walletId, c.spend.transactionHash)!;
      observed['type_after_confirmation_and_reconnect'] = settled.transactionType.name;
      observed['amount_after_confirmation_and_reconnect'] = settled.amount;
      _report('x-send-parent-unfetchable', 'input-first', observed);
      expect(pending.transactionType.name, TransactionType.sent.name, reason: 'the app\'s own send is not a receipt');
      expect(settled.transactionType.name, TransactionType.sent.name);
    });

    // (c) dormant unsubscribe is global (subscription_service.dart:219-226 -> electrum_service.dart:345-354 ->
    // socket_manager.dart:61-63), through the real ElectrumService and SocketManager over a fake socket.
    test('[x-twin-wallet-dormant-unsubscribe] a hot wallet going dormant silences its watch-only twin', () async {
      final incoming = StreamController<Uint8List>();
      final methods = <String>[];
      final socket = MockSecureSocket();
      final factory = MockSocketFactory();
      when(
        socket.listen(
          any,
          onError: anyNamed('onError'),
          onDone: anyNamed('onDone'),
          cancelOnError: anyNamed('cancelOnError'),
        ),
      ).thenAnswer((call) => incoming.stream.listen(call.positionalArguments[0] as void Function(Uint8List)));
      when(socket.close()).thenAnswer((_) async {});
      when(socket.writeln(any)).thenAnswer((call) {
        final request = jsonDecode(call.positionalArguments[0] as String) as Map<String, dynamic>;
        final method = request['method'] as String;
        methods.add(method);
        final result = method == 'blockchain.scripthash.unsubscribe' ? true : null;
        Timer.run(
          () => incoming.add(utf8.encode(jsonEncode({'jsonrpc': '2.0', 'id': request['id'], 'result': result}))),
        );
      });
      when(factory.createSecureSocket(any, any)).thenAnswer((_) async => socket);
      final electrum = ElectrumService(socketManager: SocketManager(factory: factory, maxConnectionAttempts: 3));
      expect(await electrum.connect('localhost', 50002), isTrue);

      final pushes = <int>[];
      final service = SubscriptionService(
        electrum,
        ScriptSyncServiceMock.stateManager,
        ScriptSyncServiceMock.addressRepository,
        SubscriptionRepository(ScriptSyncServiceMock.realmManager!),
        _InertSync(pushes),
      );
      final hot = WalletMock.createSingleSigWalletItem(id: 1);
      final twin = WalletMock.createSingleSigWalletItem(id: 2); // watch-only copy (wallet_provider.dart:490-500)
      final address = hot.walletBase.getAddress(0);
      expect(twin.walletBase.getAddress(0), address);
      await service.subscribeAddress(hot, 0, address, false);
      await service.subscribeAddress(twin, 0, address, false);
      final hash = ElectrumUtil.addressToReversedScriptHash(hot.walletBase.addressType, address);
      Future<List<int>> push(String status) async {
        pushes.clear();
        incoming.add(
          utf8.encode(
            jsonEncode({
              'jsonrpc': '2.0',
              'method': 'blockchain.scripthash.subscribe',
              'params': [hash, status],
            }),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return [...pushes];
      }

      final before = await push('status-1');
      await service.unsubscribeAddress(hot, address); // what _unsubscribeIfDormant does for the hot wallet
      final after = await push('status-2');
      _report('x-twin-wallet-dormant-unsubscribe', '-', {
        'pushes_before': before,
        'pushes_after_hot_unsubscribed': after,
        'server_unsubscribe_sent': methods.contains('blockchain.scripthash.unsubscribe'),
      });
      await electrum.close();
      await incoming.close();
      expect(before, [1, 2]);
      expect(after, [2], reason: 'the twin still needs pushes for the address');
    });
  });

  group('R2 exchange batch withdrawal (150 inputs, 300 outputs)', () {
    Future<(_Case, _Session, _Batch)> batchCase({int ours = 1}) async {
      final c = _Case();
      await c.init();
      final s = _Session.start(c.electrum);
      expect(await s.subscribe(c.wallet), isTrue);
      return (c, s, _Batch.build(c, ours: ours));
    }

    /// One pass: the server pushes our output addresses; returns requests per kind, wall time and the end state.
    Future<Map<String, Object?>> pass(_Case c, _Session s, _Batch batch, {required int height}) async {
      final b = c.backend;
      b.heights[batch.hash] = height;
      final before = b.calls.length;
      final clock = Stopwatch()..start();
      for (final address in batch.ours) {
        b.notify(address);
      }
      await _drain(s);
      return {'ms': clock.elapsedMilliseconds, 'requests': batch.count(b.calls.sublist(before)), ...batch.state(s)};
    }

    // Wall time at 0 ms vs 100 ms per request gives the sequential round trips (the 150 parent fetches are in flight
    // together, so they cost one round trip when the server answers them in parallel).
    for (final ours in [1, 2]) {
      for (final ms in [0, 100]) {
        final variant = 'r2-healthy-${ours}out-${ms}ms';
        test('[$variant] request count and time', () async {
          final (c, s, batch) = await batchCase(ours: ours);
          c.backend.latency = Duration(milliseconds: ms);
          final mempool = await pass(c, s, batch, height: 0);
          final confirmed = await pass(c, s, batch, height: 103);
          _report(variant, '-', {'mempool': mempool, 'confirmed': confirmed});
          expect(mempool['record_inputs'], 150);
          expect(confirmed['record_height'], 103);
        });
      }
    }

    test(
      '[r2-pending-batch-refetch-fails] another unconfirmed tx syncs while the pending batch tx times out',
      () async {
        final (c, s, batch) = await batchCase();
        final mempool = await pass(c, s, batch, height: 0);
        c.backend.fault = (m, k) => m == 'getTransaction' && k == batch.hash;
        await c.nextIncomingPush(s); // its sync re-fetches every pending record and every pending UTXO's tx
        c.backend.fault = (_, __) => false;
        final afterOtherTx = batch.state(s);
        final confirmed = await pass(c, s, batch, height: 103);
        final (s2, _) = await c.reconnect();
        _report('r2-pending-batch-refetch-fails', '-', {
          'faults_hit': c.backend.faultsHit,
          'mempool': mempool,
          'after_other_tx': afterOtherTx,
          'confirmed': confirmed,
          'after_reconnect': batch.state(s2),
        });
        expect(afterOtherTx['record_height'], 0, reason: 'a timeout is not evidence that the tx left the mempool');
        expect(confirmed['utxos'], ['unspent'], reason: 'the received coin must be spendable after it confirms');
      },
    );

    for (final persistent in [false, true]) {
      final variant = persistent ? 'r2-prev-fails-persistently' : 'r2-prev-fails-once';
      test('[$variant] one previous-tx fetch fails (after a 1 s hang) during the mempool pass', () async {
        final (c, s, batch) = await batchCase();
        final victim = batch.parents[77].transactionHash;
        var hits = 0;
        c.backend
          ..fault = ((m, k) => m == 'getTransaction' && k == victim && (persistent || hits++ == 0))
          ..faultDelay = const Duration(seconds: 1);
        final mempool = await pass(c, s, batch, height: 0);
        final confirmed = await pass(c, s, batch, height: 103);
        _report(variant, '-', {'faults_hit': c.backend.faultsHit, 'mempool': mempool, 'confirmed': confirmed});
        expect(mempool['node_sync'], 'completed', reason: 'the pass completes');
        expect(confirmed['record_inputs'], 150, reason: 'the record must not keep a partial input list');
      });
    }

    for (final persistent in [false, true]) {
      final variant = persistent ? 'r2-raw-fails-persistently' : 'r2-raw-fails-once';
      test('[$variant] the batch tx itself cannot be fetched during the mempool pass', () async {
        final (c, s, batch) = await batchCase();
        var hits = 0;
        c.backend.fault = (m, k) => m == 'getTransaction' && k == batch.hash && (persistent || hits++ == 0);
        final mempool = await pass(c, s, batch, height: 0);
        // Later pushes that resubscribe and retry the failed script: unrelated incoming payments.
        final retries = <Map<String, Object?>>[];
        for (var i = 0; i < 2; i++) {
          final before = c.backend.calls.length;
          await c.nextIncomingPush(s);
          retries.add({'requests': batch.count(c.backend.calls.sublist(before)), ...batch.state(s)});
        }
        final confirmed = await pass(c, s, batch, height: 103);
        _report(variant, '-', {'mempool': mempool, 'retries': retries, 'confirmed': confirmed});
        expect(confirmed['record_height'], 103);
        expect(confirmed['tx_list_updating'], isFalse, reason: '"업데이트 중" must clear once the sync completes');
      });
    }

    test('[r2-header-missing-at-confirmation] the confirmation pass keeps failing on a missing header', () async {
      final (c, s, batch) = await batchCase();
      final mempool = await pass(c, s, batch, height: 0);
      c.backend.missingHeaders.add(103);
      final confirmed = await pass(c, s, batch, height: 103);
      final retries = <Map<String, Object?>>[];
      for (var i = 0; i < 2; i++) {
        final before = c.backend.calls.length;
        await c.nextIncomingPush(s);
        retries.add({'requests': batch.count(c.backend.calls.sublist(before)), ...batch.state(s)});
      }
      _report('r2-header-missing-at-confirmation', '-', {
        'mempool': mempool,
        'confirmed': confirmed,
        'retries': retries,
      });
      expect(confirmed['record_height'], 103);
    });
  });
}
