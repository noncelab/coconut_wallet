import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/app.dart';
import 'package:coconut_wallet/core/exceptions/cpfp_creation/cpfp_creation_exception.dart';
import 'package:coconut_wallet/core/transaction/fee_bumping/cpfp_preparer.dart';
import 'package:coconut_wallet/core/transaction/fee_bumping/rbf_builder.dart';
import 'package:coconut_wallet/core/transaction/fee_bumping/rbf_preparer.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/enums/utxo_enums.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/node/isolate_state_message.dart';
import 'package:coconut_wallet/model/node/node_provider_state.dart';
import 'package:coconut_wallet/model/node/resync_progress.dart';
import 'package:coconut_wallet/model/node/script_status.dart';
import 'package:coconut_wallet/model/node/wallet_fetch_progress.dart';
import 'package:coconut_wallet/model/node/wallet_update_info.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/wallet/balance.dart';
import 'package:coconut_wallet/model/wallet/singlesig_wallet_item.dart';
import 'package:coconut_wallet/model/wallet/transaction_draft.dart';
import 'package:coconut_wallet/model/wallet/wallet_address.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:coconut_wallet/providers/node_provider/balance_sync_service.dart';
import 'package:coconut_wallet/providers/node_provider/isolate/isolate_enum.dart';
import 'package:coconut_wallet/providers/node_provider/network_service.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/node_provider/state/isolate_state_manager.dart';
import 'package:coconut_wallet/providers/node_provider/state/node_state_manager.dart';
import 'package:coconut_wallet/providers/node_provider/subscription/script_callback_service.dart';
import 'package:coconut_wallet/providers/node_provider/subscription/script_sync_service.dart';
import 'package:coconut_wallet/providers/node_provider/subscription/subscription_service.dart';
import 'package:coconut_wallet/providers/node_provider/transaction/transaction_record_service.dart';
import 'package:coconut_wallet/providers/node_provider/transaction/transaction_sync_service.dart';
import 'package:coconut_wallet/providers/node_provider/utxo_sync_service.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/preferences/block_explorer_provider.dart';
import 'package:coconut_wallet/providers/price_provider.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/providers/transaction_provider.dart';
import 'package:coconut_wallet/providers/utxo_tag_provider.dart';
import 'package:coconut_wallet/providers/view_model/send/broadcasting_view_model.dart';
import 'package:coconut_wallet/providers/view_model/send/send_view_model.dart';
import 'package:coconut_wallet/providers/view_model/send/utxo_selection_view_model.dart';
import 'package:coconut_wallet/providers/view_model/wallet_detail/fee_bumping_view_model.dart';
import 'package:coconut_wallet/providers/view_model/wallet_detail/utxo_merge/utxo_merge_view_model.dart';
import 'package:coconut_wallet/providers/view_model/wallet_detail/utxo_overview_view_model.dart';
import 'package:coconut_wallet/providers/view_model/wallet_detail/utxo_detail_view_model.dart';
import 'package:coconut_wallet/providers/view_model/wallet_detail/utxo_split/utxo_split_view_model.dart';
import 'package:coconut_wallet/providers/view_model/wallet_detail/wallet_detail_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/repository/realm/address_repository.dart';
import 'package:coconut_wallet/repository/realm/model/coconut_wallet_model.dart';
import 'package:coconut_wallet/repository/realm/service/realm_id_service.dart';
import 'package:coconut_wallet/repository/realm/subscription_repository.dart';
import 'package:coconut_wallet/repository/realm/transaction_draft_repository.dart';
import 'package:coconut_wallet/repository/realm/transaction_repository.dart';
import 'package:coconut_wallet/repository/realm/utxo_repository.dart';
import 'package:coconut_wallet/repository/realm/wallet_preferences_repository.dart';
import 'package:coconut_wallet/repository/realm/wallet_repository.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:coconut_wallet/screens/wallet_detail/transaction_fee_bumping_screen.dart';
import 'package:coconut_wallet/services/transaction_fetch_pass.dart';
import 'package:coconut_wallet/services/model/response/block_timestamp.dart';
import 'package:coconut_wallet/services/model/response/electrum_response_types.dart';
import 'package:coconut_wallet/utils/electrum_utils.dart';
import 'package:coconut_wallet/utils/result.dart';
import 'package:flutter/foundation.dart' show ChangeNotifier;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../mock/electrum_transaction_transport.dart';
import '../../../mock/manual_timers.dart';
import '../../../mock/script_sync_service_mock.dart';
import '../../../mock/wallet_mock.dart';
import '../transaction/rbf_service_test.mocks.dart';

// Real sync services and UI repositories share Realm, but only the UI repository reserves inputs.
// The fake Electrum backend controls subscription pushes, eviction and in-flight responses.

const _walletId = 1;
final _external = WalletMock.createMultiSigWalletItem().walletBase.getAddress(0);
final _ports = <ReceivePort>[];

/// One Fulcrum backend as seen through the app's current socket.
class _Backend {
  final txs = <String, Transaction>{};
  final heights = <String, int>{}; // tx in this backend's chain (>0) or mempool (0)
  final _outputs = <String, List<(String, int)>>{}; // hash -> (address, amount) per output
  final listeners = <String, Function(String, String?)>{}; // scripthash subscriptions of the current socket
  final calls = <String>[]; // '$method:$key' of every request

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
      return body();
    }

    String arg(Invocation call, int i) => call.positionalArguments[i] as String;
    when(electrum.connectionStatus).thenReturn(SocketConnectionStatus.connected);
    when(electrum.getBalance(any, any)).thenAnswer((c) => answer('getBalance', arg(c, 1), () => balance(arg(c, 1))));
    when(electrum.getHistory(any, any)).thenAnswer((c) => answer('getHistory', arg(c, 1), () => history(arg(c, 1))));
    when(
      electrum.getUnspentList(any, any),
    ).thenAnswer((c) => answer('listunspent', arg(c, 1), () => unspent(arg(c, 1))));
    when(
      electrum.getTransaction(any, timeout: anyNamed('timeout')),
    ).thenAnswer((c) => answer('getTransaction', arg(c, 0), () => rawTx(arg(c, 0))));
    // Exercise the real all-or-throw parent loader and its per-pass request sharing.
    final parents = ElectrumTransactionTransport((hash) => answer('getTransaction', hash, () => rawTx(hash))).service;
    when(
      electrum.getPreviousTransactions(
        any,
        existingTxList: anyNamed('existingTxList'),
        transactionFetch: anyNamed('transactionFetch'),
      ),
    ).thenAnswer((c) async {
      return parents.getPreviousTransactions(
        c.positionalArguments[0] as Transaction,
        existingTxList: c.namedArguments[#existingTxList] as List<Transaction>?,
        transactionFetch: c.namedArguments[#transactionFetch] as TransactionFetchPass?,
      );
    });
    when(electrum.fetchBlocksByHeight(any)).thenAnswer(
      (c) => answer('headers', '', () {
        final requested = c.positionalArguments[0] as Set<int>;
        return {for (final h in requested) h: BlockTimestamp(h, DateTime.utc(2026, 10, 27).add(Duration(minutes: h)))};
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
    when(electrum.unsubscribeScriptForWallet(any, any, walletId: anyNamed('walletId'))).thenAnswer((c) async {
      listeners.remove(arg(c, 1));
      return true;
    });
    when(electrum.broadcast(any, timeout: anyNamed('timeout'), onRpcError: anyNamed('onRpcError'))).thenAnswer(
      (c) => answer('broadcast', '', () {
        final tx = Transaction.parse(arg(c, 0));
        put(tx, 0);
        return tx.transactionHash;
      }),
    );
    // A failed broadcast asks the server for the txid; these scenarios never lose a broadcast reply.
    when(electrum.lookUpTransaction(any, timeout: anyNamed('timeout'))).thenAnswer((_) async => null);
  }
}

/// One isolate session (IsolateInitializer wiring) plus the main isolate's NodeStateManager fed by its messages.
class _Session {
  final SubscriptionService node;
  final IsolateStateManager isolateState;
  final NodeStateManager main;
  final ManualTimers retryClock; // this isolate's retry timers; dropped with the session like a replaced isolate
  // What the main NodeStateManager publishes (NodeProvider's streams).
  final StreamController<NodeSyncState> nodeEvents;
  final StreamController<Map<int, WalletUpdateInfo>> walletEvents;
  final StreamController<Map<int, WalletFetchProgress>> fetchEvents;
  _Session(
    this.node,
    this.isolateState,
    this.main,
    this.retryClock,
    this.nodeEvents,
    this.walletEvents,
    this.fetchEvents,
  );

  factory _Session.start(MockElectrumService electrum) {
    final nodeEvents = StreamController<NodeSyncState>.broadcast();
    final walletEvents = StreamController<Map<int, WalletUpdateInfo>>.broadcast();
    final fetchEvents = StreamController<Map<int, WalletFetchProgress>>.broadcast();
    final resyncEvents = StreamController<Map<int, ResyncProgress>>.broadcast();
    final main = NodeStateManager(() {}, nodeEvents, walletEvents, resyncEvents, fetchEvents);
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
    final retryClock = ManualTimers();
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
      createTimer: retryClock.create,
      random: () => 0.5, // no jitter: the retry fires at exactly 10 s
    );
    addTearDown(() async {
      sync.cancelRetry(_walletId);
      port.close();
      await nodeEvents.close();
      await walletEvents.close();
      await fetchEvents.close();
      await resyncEvents.close();
    });
    return _Session(
      SubscriptionService(electrum, state, addresses, SubscriptionRepository(realmManager), sync),
      state,
      main,
      retryClock,
      nodeEvents,
      walletEvents,
      fetchEvents,
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
  late final Transaction faucet, funding, spend;

  String get coin => getUtxoId(funding.transactionHash, 0);
  Duration now = Duration.zero;
  late final UtxoRepository utxos = UtxoRepository(ScriptSyncServiceMock.realmManager!, clock: () => now);
  List<String> get spendAddresses => [input, change];

  Future<void> init() async {
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
    input = base.getAddress(0);
    change = base.getAddress(0, isChange: true);

    faucet = _tx([('00' * 32, 0)], List.filled(8, (_external, 5000000)));
    funding = _tx([(faucet.transactionHash, 0)], [(input, 1000000), (_external, 3999000)]);
    spend = _tx([(funding.transactionHash, 0)], [(_external, 300000), (change, 699000)]);
    backend
      ..put(faucet, 10)
      ..put(funding, 100)
      ..put(spend);
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

  String _utxo(String id) => utxos.getUtxoState(_walletId, id)?.status.name ?? 'deleted';
  String coinState() => _utxo(coin);

  /// Pull-to-refresh / resume with a failed state / connectivity change: NodeProvider.reconnect() replaces the isolate
  /// (and the main NodeStateManager) and resubscribes.
  Future<(_Session, bool)> reconnect() async {
    backend.listeners.clear();
    final session = _Session.start(electrum);
    final ok = await session.subscribe(walletCopy());
    return (session, ok);
  }
}

void _report(String variant, String order, Map<String, Object?> observed) {
  // ignore: avoid_print
  print('FIELD_OBS ${jsonEncode({'variant': variant, 'order': order, ...observed})}');
}

class _UiNode extends Fake with ChangeNotifier implements NodeProvider {
  final _Session session;
  _UiNode(this.session);

  @override
  NodeProviderState get state => session.main.state;

  @override
  Stream<NodeSyncState> get syncStateStream => Stream.multi((controller) {
    controller.add(state.nodeSyncState);
    final subscription = session.nodeEvents.stream.listen(controller.add);
    controller.onCancel = subscription.cancel;
  });

  @override
  Stream<WalletUpdateInfo> getWalletStateStream(int walletId) => Stream.multi((controller) {
    final initial = state.registeredWallets[walletId];
    if (initial != null) controller.add(initial);
    final subscription = session.walletEvents.stream
        .where((wallets) => wallets[walletId] != null)
        .map((wallets) => wallets[walletId]!)
        .listen(controller.add);
    controller.onCancel = subscription.cancel;
  });

  @override
  Stream<WalletFetchProgress> getWalletFetchProgressStream(int walletId) => Stream.multi((controller) {
    final initial = session.main.fetchProgressByWallet[walletId];
    if (initial != null) controller.add(initial);
    final subscription = session.fetchEvents.stream
        .where((progress) => progress[walletId] != null)
        .map((progress) => progress[walletId]!)
        .listen(controller.add);
    controller.onCancel = subscription.cancel;
  });
}

class _UiWallets extends Fake with ChangeNotifier implements WalletProvider {
  final WalletItemBase wallet;
  _UiWallets(this.wallet);

  @override
  WalletItemBase getWalletById(int id) => wallet;

  @override
  List<WalletItemBase> get walletItemList => [wallet];

  @override
  Balance getWalletBalance(int id) {
    final balance = ScriptSyncServiceMock.walletRepository.getWalletBalance(id)!;
    return Balance(balance.confirmed, balance.unconfirmed);
  }

  @override
  WalletAddress getReceiveAddress(int id) =>
      ScriptSyncServiceMock.addressRepository.getReceiveAddress(id, wallet: wallet.walletBase);
}

class _UiConnectivity extends Fake with ChangeNotifier implements ConnectivityProvider {
  @override
  bool get isInternetOff => false;
}

class _UiPrice extends Fake with ChangeNotifier implements PriceProvider {
  @override
  int? get bitcoinPriceKrw => null;
}

class _UiPreferences extends Fake with ChangeNotifier implements PreferenceProvider {
  @override
  bool get isManualUtxoSelectionMode => false;
}

// Real sync fixture adapted from the independent PR3 review probes; separate UI/sync repositories.
// All Electrum calls use _Backend; fee RPC is disabled. No device/server access.
class _ProbeNode extends _UiNode {
  final _Case c;
  _ProbeNode(super.session, this.c);
  @override
  Future<Result<BlockTimestamp>> getLatestBlock() async => Result.success(BlockTimestamp(100, DateTime(2026)));
  @override
  Future<Result<String>> broadcast(Transaction tx, {int attempt = 0}) => NetworkService(c.electrum).broadcast(tx);
}

class _ProbeWallets extends _UiWallets {
  _ProbeWallets(super.wallet, this.utxos);
  final UtxoRepository utxos;
  @override
  List<UtxoState> getUtxoList(int id) => utxos.getUtxoStateList(id);
  @override
  UtxoState? getUtxoState(int id, String utxoId) => utxos.getUtxoState(id, utxoId);
  @override
  Future<void> updateUtxoStatus(int id, List<String> ids, UtxoStatus status) => utxos.updateUtxoStatus(id, ids, status);
  @override
  Future<void> toggleUtxoLockStatus(int id, String utxoId) async {
    final result = await utxos.toggleUtxoLockStatus(id, utxoId);
    if (result.isFailure) throw result.error;
  }

  @override
  WalletAddress getChangeAddress(int id) =>
      ScriptSyncServiceMock.addressRepository.getChangeAddress(id, wallet: wallet.walletBase);
  @override
  Map<int, WalletAddress> getReceiveAddressMap() => ScriptSyncServiceMock.addressRepository.getReceiveAddressMap();
  @override
  bool containsAddress(int id, String address, {bool? isChange}) =>
      ScriptSyncServiceMock.addressRepository.containsAddress(id, address);
}

class _ProbePrefs extends _UiPreferences {
  @override
  BitcoinUnit get currentUnit => BitcoinUnit.sats;
  @override
  List<int> get walletOrder => [];
  @override
  UtxoOrder get utxoSortOrder => UtxoOrder.byAmountDesc;
}

class _ProbeSend extends SendViewModel {
  _ProbeSend(_ProbeWallets wallets, _ProbePrefs prefs, {SendInfoProvider? sendInfo, int? walletId = _walletId})
    : super(
        wallets,
        sendInfo ?? SendInfoProvider(),
        prefs,
        TransactionDraftRepository(ScriptSyncServiceMock.realmManager!),
        wallets.utxos,
        true,
        (_) {},
        (_) {},
        (_) {},
        walletId,
        SendEntryPoint.walletDetail,
        null,
        [],
      );
  @override
  Future<bool> fetchRecommendedFees({
    required String currentFeeRateText,
    required void Function(String) onDefaultFeeRateSet,
  }) async => false;
}

class _ProbeMerge extends UtxoMergeViewModel {
  _ProbeMerge(UtxoRepository utxos, UtxoTagProvider tags, WalletProvider wallets)
    : super(_walletId, utxos, tags, SendInfoProvider(), wallets);
  @override
  Future<bool> fetchRecommendedFees({
    required String currentFeeRateText,
    required void Function(String) onDefaultFeeRateSet,
  }) async => false;
}

class _ProbeSplit extends UtxoSplitViewModel {
  _ProbeSplit(PreferenceProvider prefs, WalletProvider wallets, UtxoRepository utxos, UtxoTagProvider tags)
    : super(
        _walletId,
        prefs,
        wallets,
        ScriptSyncServiceMock.addressRepository,
        utxos,
        SendInfoProvider(),
        tags,
        () async => false,
      );
  @override
  Future<bool> fetchRecommendedFees({
    required String currentFeeRateText,
    required void Function(String) onDefaultFeeRateSet,
  }) async => false;
}

ScriptStatus _inputScript(_Case c) => ScriptStatus(
  derivationPath: '${c.wallet.walletBase.derivationPath}/0/0',
  address: c.input,
  index: 0,
  isChange: false,
  scriptPubKey: ElectrumUtil.getScriptForAddress(c.wallet.walletBase.addressType, c.input),
  status: c.backend.status(c.input),
  timestamp: DateTime.now(),
);

Future<BroadcastingViewModel> _broadcastVm(_Case c, _Session s) async {
  final manager = ScriptSyncServiceMock.realmManager!;
  final wallets = _ProbeWallets(c.wallet, c.utxos);
  final tags = UtxoTagProvider(c.utxos);
  final node = _ProbeNode(s, c);
  final txs = TransactionProvider(ScriptSyncServiceMock.transactionRepository);
  c.spend.utxoList.add(c.utxos.getUtxoState(_walletId, c.coin)!);
  c.spend.changeAddressDerivationPath = '${c.wallet.walletBase.derivationPath}/1/0';
  final psbt = Psbt.fromTransaction(c.spend, c.wallet.walletBase);
  final sendInfo =
      SendInfoProvider()
        ..setWalletId(_walletId)
        ..setTxWaitingForSign(psbt.serialize())
        ..setSignedResult(c.spend.serialize());
  final vm = BroadcastingViewModel(
    sendInfo,
    wallets,
    tags,
    true,
    node,
    txs,
    TransactionDraftRepository(manager),
    c.utxos,
    null,
  );
  await vm.setTxInfo();
  addTearDown(() {
    vm.dispose();
    wallets.dispose();
    tags.dispose();
    node.dispose();
    txs.dispose();
  });
  return vm;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    ScriptSyncServiceMock.init();
    CoconutWalletApp.kFaucetHost = 'http://localhost';
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    await SharedPrefsRepository().init();
  });
  tearDown(() {
    for (final port in _ports) {
      port.close();
    }
    _ports.clear();
    ScriptSyncServiceMock.realmManager?.dispose();
    ScriptSyncServiceMock.realmManager = null;
  });
  Future<(_Case, _Session, BroadcastingViewModel)> fixture() async {
    final c = _Case();
    await c.init();
    final s = _Session.start(c.electrum);
    expect(await s.subscribe(c.wallet), isTrue);
    return (c, s, await _broadcastVm(c, s));
  }

  test('new screen models after accepted broadcast', () async {
    final (c, s, vm) = await fixture();
    final wallets = _ProbeWallets(c.wallet, c.utxos);
    final prefs = _ProbePrefs();
    final txs = TransactionProvider(ScriptSyncServiceMock.transactionRepository);
    final node = _ProbeNode(s, c);
    final detail = WalletDetailViewModel(_walletId, wallets, txs, node, initialUnit: BitcoinUnit.sats);
    final tags = UtxoTagProvider(c.utxos);
    final sendBefore = _ProbeSend(wallets, prefs);
    await _settle();
    expect(sendBefore.balance, 1000000);
    expect((await vm.broadcast(inheritedTagIds: [])).isSuccess, isTrue);
    final sendAfter = _ProbeSend(wallets, prefs);
    // Newly opened screens read the overlay; existing snapshots keep their original state.
    final overview = UtxoOverviewViewModel(
      _walletId,
      wallets,
      txs,
      tags,
      _UiConnectivity(),
      _UiPrice(),
      prefs,
      node,
      node.getWalletStateStream(_walletId),
    );
    txs.initTxList(_walletId);
    _report('pr3-ui-before-sync', '-', {
      'coin': c.coinState(),
      'old_send_available': sendBefore.balance,
      'new_send_available': sendAfter.balance,
      'new_send_incoming': sendAfter.incomingBalance,
      'wallet_detail_balance': detail.balance,
      'utxo_header_balance': overview.balance,
      'utxo_chart_total': overview.utxoList.fold<int>(0, (s, u) => s + u.amount),
      'utxo_chart_available': overview.utxoList
          .where((u) => u.status == UtxoStatus.unspent)
          .fold<int>(0, (s, u) => s + u.amount),
      'history_has_spend': detail.transactions.any((t) => t.transactionHash == c.spend.transactionHash),
      'change_exists': c.utxos.getUtxoState(_walletId, getUtxoId(c.spend.transactionHash, 1)) != null,
    });
    addTearDown(() {
      sendBefore.dispose();
      sendAfter.dispose();
      detail.dispose();
      overview.dispose();
      wallets.dispose();
      prefs.dispose();
      txs.dispose();
      tags.dispose();
      node.dispose();
    });
    expect(sendAfter.balance, 0);
    expect(sendBefore.balance, 1000000);
    expect(
      overview.utxoList.where((u) => u.status == UtxoStatus.unspent).fold<int>(0, (sum, u) => sum + u.amount),
      sendAfter.balance,
    );
    expect(overview.utxoList.single.status, UtxoStatus.outgoing);
    expect(detail.balance, 1000000);
    expect(sendAfter.incomingBalance, 0);
    expect(detail.transactions.any((t) => t.transactionHash == c.spend.transactionHash), isFalse);
  });

  test('[codex] unlocking through a fresh overview must preserve the overlay in displayed rows', () async {
    final (c, s, vm) = await fixture();
    expect((await vm.broadcast(inheritedTagIds: [])).isSuccess, isTrue);
    final wallets = _ProbeWallets(c.wallet, c.utxos);
    final prefs = _ProbePrefs();
    final tags = UtxoTagProvider(c.utxos);
    final txs = TransactionProvider(ScriptSyncServiceMock.transactionRepository);
    final node = _ProbeNode(s, c);
    final explorer = BlockExplorerProvider();
    final detail = UtxoDetailViewModel(
      _walletId,
      c.utxos.getUtxoState(_walletId, c.coin)!,
      tags,
      txs,
      wallets,
      ScriptSyncServiceMock.addressRepository,
      const Stream<WalletUpdateInfo>.empty(),
      explorer,
    );
    addTearDown(() {
      detail.dispose();
      explorer.dispose();
    });
    expect(await detail.toggleUtxoLockStatus(), isTrue);
    expect(c.coinState(), 'locked');
    final overview = UtxoOverviewViewModel(
      _walletId,
      wallets,
      txs,
      tags,
      _UiConnectivity(),
      _UiPrice(),
      prefs,
      node,
      node.getWalletStateStream(_walletId),
    );
    expect(overview.utxoList.single.status, UtxoStatus.locked);
    overview.selectedUtxoIds.add(c.coin);
    overview.setSelectedUtxoList(overview.utxoList);
    expect(overview.selectedUtxoAmountSum, 1000000);
    // Actual overview button path, not a direct UTXO mutation in the test.
    expect(await overview.setUtxoLockStatus([c.coin], false), 1);
    expect(overview.utxoList.single.status, UtxoStatus.outgoing);
    expect(overview.selectedUtxoIds, isEmpty);
    await overview.updateSelectedUtxosStatus([c.coin], UtxoStatus.locked);
    overview.selectedUtxoIds.add(c.coin);
    overview.setSelectedUtxoList(overview.utxoList);
    expect(overview.selectedUtxoAmountSum, 1000000);
    await overview.updateSelectedUtxosStatus([c.coin], UtxoStatus.unspent);
    final available = overview.utxoList
        .where((u) => u.status == UtxoStatus.unspent)
        .fold<int>(0, (sum, u) => sum + u.amount);
    final fresh = _ProbeSend(wallets, prefs);
    // Same pending-row guard as the overview's tap/long-press selection handlers.
    final overviewRowSelectable =
        overview.utxoList.single.status != UtxoStatus.outgoing &&
        overview.utxoList.single.status != UtxoStatus.incoming;
    final manuallySelected = overviewRowSelectable ? overview.getUtxosByIds([c.coin]) : <UtxoState>[];
    final info = SendInfoProvider();
    final manual = _ProbeSend(wallets, prefs, sendInfo: info);
    await _settle();
    manual.setSelectedUtxoList(manuallySelected);
    manual.setAddressText(_external, 0);
    manual.setAmountText(50000, 0);
    manual.setFeeRateText('1');
    manual.validateAllFieldsOnFocusLost();
    if (manual.canGoNext) manual.saveSendInfo();
    _report('pr3c-fresh-unlock', '-', {
      'raw_status': ScriptSyncServiceMock.utxoRepository.getUtxoState(_walletId, c.coin)!.status.name,
      'repository_status': c.coinState(),
      'overview_status': overview.utxoList.single.status.name,
      'overview_row_selectable': overviewRowSelectable,
      'overview_available': available,
      'fresh_send_available': fresh.balance,
      'manual_available': manual.balance,
      'manual_can_next': manual.canGoNext,
      'manual_reuses_accepted_input': info.transaction?.inputs.any(
        (i) => getUtxoId(i.transactionHash, i.index) == c.coin,
      ),
    });
    addTearDown(() {
      overview.dispose();
      fresh.dispose();
      manual.dispose();
      wallets.dispose();
      prefs.dispose();
      tags.dispose();
      txs.dispose();
      node.dispose();
    });
    expect(available, fresh.balance, reason: 'a screen opened after acceptance must keep the projection after unlock');
    expect(available, 0);
    expect(overviewRowSelectable, isFalse);
    expect(manual.canGoNext, isFalse);
    expect(overview.selectedUtxoIds, isEmpty);
    expect(overview.selectedUtxoList, isEmpty);
    expect(overview.selectedUtxoAmountSum, 0);
  });

  test('[codex] reopening picker must not carry invisible reserved initial selections', () async {
    final (c, s, vm) = await fixture();
    final extra = _tx([(c.faucet.transactionHash, 1)], [(c.input, 200000), (_external, 4799000)]);
    c.backend.put(extra, 100);
    await ScriptSyncServiceMock.utxoSyncService.fetchScriptUtxo(c.wallet, _inputScript(c));
    final cached = c.utxos.getUtxoState(_walletId, c.coin)!;
    await vm.broadcast(inheritedTagIds: []);
    final wallets = _ProbeWallets(c.wallet, c.utxos);
    final tags = UtxoTagProvider(c.utxos);
    final price = _UiPrice();
    final prefs = _ProbePrefs();
    final picker = UtxoSelectionViewModel(wallets, tags, price, prefs, true, _walletId)..initialize([cached]);
    expect(picker.confirmedUtxoList.map((u) => u.utxoId), [getUtxoId(extra.transactionHash, 0)]);
    picker.toggleUtxoSelection(picker.confirmedUtxoList.single);
    _report('pr3c-picker-initial', '-', {
      'visible_count': picker.confirmedUtxoList.length,
      'selected_count': picker.selectedUtxoList.length,
      'selected_amount': picker.selectedUtxoAmountSum,
      'done_enabled': picker.hasSelectionChanged,
      'reserved_selected': picker.selectedUtxoList.any((u) => u.utxoId == c.coin),
    });
    addTearDown(() {
      picker.dispose();
      wallets.dispose();
      tags.dispose();
      price.dispose();
      prefs.dispose();
    });
    expect(picker.selectedUtxoList.any((u) => u.utxoId == c.coin), isFalse);
    expect(picker.selectedUtxoAmountSum, 200000);
    expect(picker.hasSelectionChanged, isTrue);
    final send = _ProbeSend(wallets, prefs)..setSelectedUtxoList(picker.selectedUtxoList);
    addTearDown(send.dispose);
    expect(send.selectedUtxoAmountSum, 200000);
  });

  test('detail lock and unlock re-read the projection without mutating old snapshots', () async {
    final (c, s, vm) = await fixture();
    expect((await vm.broadcast(inheritedTagIds: [])).isSuccess, isTrue);
    final wallets = _ProbeWallets(c.wallet, c.utxos);
    final tags = UtxoTagProvider(c.utxos);
    final txs = TransactionProvider(ScriptSyncServiceMock.transactionRepository);
    final explorer = BlockExplorerProvider();
    final snapshot = c.utxos.getUtxoState(_walletId, c.coin)!;
    final detail = UtxoDetailViewModel(
      _walletId,
      snapshot,
      tags,
      txs,
      wallets,
      ScriptSyncServiceMock.addressRepository,
      const Stream<WalletUpdateInfo>.empty(),
      explorer,
    );
    addTearDown(() {
      detail.dispose();
      explorer.dispose();
      wallets.dispose();
      tags.dispose();
      txs.dispose();
    });
    expect(await detail.toggleUtxoLockStatus(), isTrue);
    expect(detail.utxoStatus, UtxoStatus.locked);
    expect(snapshot.status, UtxoStatus.outgoing);
    expect(await detail.toggleUtxoLockStatus(), isTrue);
    expect(detail.utxoStatus, UtxoStatus.outgoing);
    expect(c.coinState(), 'outgoing');
    final prefs = _ProbePrefs();
    final send = _ProbeSend(wallets, prefs);
    addTearDown(() {
      send.dispose();
      prefs.dispose();
    });
    expect(send.balance, 0);
    expect(detail.utxoStatus == UtxoStatus.unspent ? snapshot.amount : 0, send.balance);
  });

  test('auto/manual/MAX, merge, split and draft reads exclude reserved inputs', () async {
    final (c, s, vm) = await fixture();
    for (final (index, amount) in [(1, 200000), (2, 100000)]) {
      c.backend.put(_tx([(c.faucet.transactionHash, index)], [(c.input, amount), (_external, 4999000 - amount)]), 100);
    }
    await ScriptSyncServiceMock.utxoSyncService.fetchScriptUtxo(c.wallet, _inputScript(c));
    final wallets = _ProbeWallets(c.wallet, c.utxos);
    final prefs = _ProbePrefs();
    final tags = UtxoTagProvider(c.utxos);
    final price = _UiPrice();
    final merge = _ProbeMerge(c.utxos, tags, wallets)..initialize();
    final split = _ProbeSplit(prefs, wallets, c.utxos, tags);
    split.setSelectedUtxoList([c.utxos.getUtxoState(_walletId, c.coin)!]);
    expect(merge.utxoList, hasLength(3));
    await vm.broadcast(inheritedTagIds: []);
    merge.revalidateAvailableUtxos();
    split.revalidateSelectedUtxo();
    expect(merge.utxoList, hasLength(2));
    expect(merge.utxoList.any((u) => u.utxoId == c.coin), isFalse);
    expect(split.selectedUtxoList, isEmpty);
    final reopenedMerge = _ProbeMerge(c.utxos, tags, wallets)..initialize();
    expect(reopenedMerge.utxoList, hasLength(2));
    final selection = UtxoSelectionViewModel(wallets, tags, price, prefs, true, _walletId)..initialize([]);
    selection.selectAllUtxo();
    expect(selection.selectedUtxoList, hasLength(2));
    expect(selection.selectedUtxoAmountSum, 300000);
    final sendInfo = SendInfoProvider();
    final send = _ProbeSend(wallets, prefs, sendInfo: sendInfo);
    await _settle();
    expect(send.balance, 300000);
    send.setAddressText(_external, 0);
    send.setAmountText(50000, 0);
    send.setFeeRateText('1');
    send.validateAllFieldsOnFocusLost();
    expect(send.canGoNext, isTrue);
    send.saveSendInfo();
    expect(sendInfo.transaction!.inputs.any((i) => getUtxoId(i.transactionHash, i.index) == c.coin), isFalse);
    send.setMaxMode(true);
    send.validateAllFieldsOnFocusLost();
    expect(send.canGoNext, isTrue);
    send.saveSendInfo();
    expect(sendInfo.transaction!.inputs, hasLength(2));
    expect(sendInfo.transaction!.outputs.fold<int>(0, (sum, o) => sum + o.amount) + send.estimatedFeeInSats!, 300000);
    send.setSelectedUtxoList(selection.selectedUtxoList);
    expect(send.selectedUtxoAmountSum, 300000);
    final drafts = TransactionDraftRepository(ScriptSyncServiceMock.realmManager!);
    final draft = await drafts.saveUnsignedDraft(
      walletId: _walletId,
      feeRate: 1,
      isMaxMode: false,
      isFeeSubtractedFromSendAmount: false,
      recipients: [RecipientDraft(address: _external, amount: 50000)],
      bitcoinUnit: BitcoinUnit.sats,
      selectedUtxoIds: [c.coin],
    );
    final fromDraft = _ProbeSend(wallets, prefs, walletId: null);
    expect(fromDraft.loadTransactionDraft(draft.value.id), SelectedUtxoExcludedStatus.used);
    expect(fromDraft.selectedUtxoList, isEmpty);
    addTearDown(() {
      fromDraft.dispose();
      send.dispose();
      selection.dispose();
      reopenedMerge.dispose();
      merge.dispose();
      split.dispose();
      price.dispose();
      tags.dispose();
      prefs.dispose();
      wallets.dispose();
    });
  });

  test('fee bump keeps its original input but excludes reserved extra inputs', () async {
    final (c, s, vm) = await fixture();
    final reservedExtra = _tx([(c.faucet.transactionHash, 1)], [(c.input, 200000), (_external, 4799000)]);
    final availableExtra = _tx([(c.faucet.transactionHash, 2)], [(c.input, 800000), (_external, 4199000)]);
    c.backend
      ..put(reservedExtra, 100)
      ..put(availableExtra, 100);
    await ScriptSyncServiceMock.utxoSyncService.fetchScriptUtxo(c.wallet, _inputScript(c));
    final anotherSend = _tx([(reservedExtra.transactionHash, 0)], [(_external, 199000)]);
    final staleExtra = c.utxos.getUtxoState(_walletId, getUtxoId(reservedExtra.transactionHash, 0))!;
    c.utxos.reserveBroadcastInputs(anotherSend, anotherSend.transactionHash);
    expect((await vm.broadcast(inheritedTagIds: [])).isSuccess, isTrue);
    for (final address in c.spendAddresses) {
      c.backend.notify(address);
    }
    await _drain(s);
    final pending =
        ScriptSyncServiceMock.transactionRepository.getTransactionRecord(_walletId, c.spend.transactionHash)!;
    final wallets = _ProbeWallets(c.wallet, c.utxos);
    final node = _ProbeNode(s, c);
    final prefs = _ProbePrefs();
    final txs = TransactionProvider(ScriptSyncServiceMock.transactionRepository);
    final feeModels = [
      for (final type in FeeBumpingType.values)
        FeeBumpingViewModel(
          type,
          pending,
          _walletId,
          SendInfoProvider(),
          node,
          txs,
          wallets,
          ScriptSyncServiceMock.addressRepository,
          c.utxos,
          prefs,
          WalletPreferencesRepository(ScriptSyncServiceMock.realmManager!),
          true,
        ),
    ];
    addTearDown(() {
      for (final model in feeModels) {
        model.dispose();
      }
      wallets.dispose();
      node.dispose();
      prefs.dispose();
      txs.dispose();
    });
    final availableId = getUtxoId(availableExtra.transactionHash, 0);
    for (final model in feeModels) {
      expect(model.availableUtxos.map((u) => u.utxoId), [availableId]);
    }
    final tags = UtxoTagProvider(c.utxos);
    final price = _UiPrice();
    final picker = UtxoSelectionViewModel(wallets, tags, price, prefs, true, _walletId)
      ..initialize([staleExtra, feeModels.first.availableUtxos.single]);
    addTearDown(() {
      picker.dispose();
      tags.dispose();
      price.dispose();
    });
    expect(picker.hasSelectionChanged, isFalse);
    expect(picker.selectedUtxoList.map((u) => u.utxoId), [availableId]);
    expect(picker.selectedUtxoAmountSum, 800000);
    final preparer = RbfPreparer.fromPendingTx(
      pendingTx: pending,
      rawTx: c.spend.serialize(),
      getUtxos: (id) => c.utxos.getUtxoState(_walletId, id),
      isMyAddress:
          (address, {bool isChange = false}) =>
              ScriptSyncServiceMock.addressRepository.containsAddress(_walletId, address),
      getDerivationPath: (address) => ScriptSyncServiceMock.addressRepository.getDerivationPath(_walletId, address),
    );
    for (final extras in [feeModels.first.availableUtxos, picker.selectedUtxoList]) {
      final replacement = RbfBuilder(
        preparer: preparer,
        walletItemBase: c.wallet,
        nextChangeAddress: wallets.getChangeAddress(_walletId),
        additionalSpendable: extras,
      ).build(newFeeRate: 5000);
      expect(replacement.isSuccess, isTrue, reason: replacement.exception.toString());
      expect(replacement.addedInputs!.map((u) => u.utxoId), [availableId]);
      expect(replacement.transaction!.inputs.map((i) => getUtxoId(i.transactionHash, i.index)), [c.coin, availableId]);
    }
    expect(preparer.inputUtxos.single.spentByTransactionHash, c.spend.transactionHash);
  });

  test('signed draft reports used and CPFP cannot reuse an accepted child input', () async {
    final (c, s, vm) = await fixture();
    final drafts = TransactionDraftRepository(ScriptSyncServiceMock.realmManager!);
    final psbt = Psbt.fromTransaction(c.spend, c.wallet.walletBase).serialize();
    final saved = await drafts.saveSignedDraft(
      walletId: _walletId,
      recipients: [RecipientDraft(address: _external, amount: 300000)],
      feeRate: 1,
      isMaxMode: false,
      txWaitingForSign: psbt,
      signedPsbtBase64Encoded: c.spend.serialize(),
    );
    expect(saved.isSuccess, isTrue);
    await vm.broadcast(inheritedTagIds: []);
    final wallets = _ProbeWallets(c.wallet, c.utxos);
    final tags = UtxoTagProvider(c.utxos);
    final txs = TransactionProvider(ScriptSyncServiceMock.transactionRepository);
    final node = _ProbeNode(s, c);
    final loaded = BroadcastingViewModel(
      SendInfoProvider(),
      wallets,
      tags,
      true,
      node,
      txs,
      drafts,
      c.utxos,
      saved.value.id,
    );
    expect(await loaded.setTxInfo(), SelectedUtxoExcludedStatus.used);
    for (final address in c.spendAddresses) {
      c.backend.notify(address);
    }
    await _drain(s);
    final pending =
        ScriptSyncServiceMock.transactionRepository.getTransactionRecord(_walletId, c.spend.transactionHash)!;
    CpfpPreparer prepare() => CpfpPreparer.fromPendingTx(
      pendingTx: pending,
      incomingUtxos: c.utxos.getUtxosByStatus(_walletId, UtxoStatus.incoming),
      isMyAddress:
          (address, {bool isChange = false}) =>
              ScriptSyncServiceMock.addressRepository.containsAddress(_walletId, address),
    );
    expect(prepare().receivedUtxos, hasLength(1));
    final child = _tx([(c.spend.transactionHash, 1)], [(_external, 698000)]);
    c.utxos.reserveBroadcastInputs(child, child.transactionHash);
    expect(prepare, throwsA(isA<NoCpfpableOutputException>()));
    expect(ScriptSyncServiceMock.utxoRepository.getUtxosByStatus(_walletId, UtxoStatus.incoming), hasLength(1));
    addTearDown(() {
      loaded.dispose();
      wallets.dispose();
      tags.dispose();
      txs.dispose();
      node.dispose();
    });
  });

  test('eviction before first sync leaves Realm available and expires the UI reservation', () async {
    final (c, s, vm) = await fixture();
    expect((await vm.broadcast(inheritedTagIds: [])).isSuccess, isTrue);
    final immediatelyAfter = c.coinState();
    c.backend.heights.remove(c.spend.transactionHash);
    final callsBefore = c.backend.calls.length;
    final (s2, ok) = await c.reconnect();
    final (s3, ok3) = await c.reconnect();
    final after = c.coinState();
    final calls = c.backend.calls.skip(callsBefore).toList();
    _report('pr3-evicted-no-push', '-', {
      'after_accepted': immediatelyAfter,
      'after_two_reconnects': after,
      'backend_unspent': c.backend.unspent(c.input).any((u) => u.txHash == c.funding.transactionHash),
      'reconnects_ok': ok && ok3,
      'listunspent_calls': calls.where((s) => s.startsWith('listunspent:')).length,
      'history_calls': calls.where((s) => s.startsWith('getHistory:')).length,
      'pending_retry_count': s2.retryClock.pendingDelays.length + s3.retryClock.pendingDelays.length,
      'node_state': s3.main.state.nodeSyncState.name,
    });
    expect(immediatelyAfter, 'outgoing');
    expect(after, 'outgoing');
    expect(ScriptSyncServiceMock.utxoRepository.getUtxoState(_walletId, c.coin)!.status, UtxoStatus.unspent);
    expect(
      UtxoRepository(ScriptSyncServiceMock.realmManager!).getUtxoState(_walletId, c.coin)!.status,
      UtxoStatus.unspent,
    );
    c.now += const Duration(minutes: 30);
    expect(c.coinState(), 'unspent');
  });

  test('late prebroadcast listunspent must not revert reservation', () async {
    final (c, s, vm) = await fixture();
    final stale = c.backend.unspent(c.input);
    final reply = Completer<List<ListUnspentRes>>();
    final started = Completer<void>();
    when(c.electrum.getUnspentList(any, c.input)).thenAnswer((_) {
      started.complete();
      return reply.future;
    });
    final pending = ScriptSyncServiceMock.utxoSyncService.fetchScriptUtxo(c.wallet, _inputScript(c));
    await started.future;
    expect((await vm.broadcast(inheritedTagIds: [])).isSuccess, isTrue);
    final reserved = c.coinState();
    reply.complete(stale);
    expect(await pending, isTrue);
    final after = c.coinState();
    _report('pr3-late-listunspent', '-', {
      'after_accepted': reserved,
      'after_old_reply': after,
      'spender_is_accepted_tx':
          c.utxos.getUtxoState(_walletId, c.coin)!.spentByTransactionHash == c.spend.transactionHash,
      'selectable': c.utxos.getValidatedSelectedUtxoList(_walletId, [c.coin]).$1.isNotEmpty,
      'backend_unspent_count': c.backend.unspent(c.input).length,
    });
    expect(after, 'outgoing');
  });

  test('in-flight old history cleanup must not permanently delete a dropped reservation', () async {
    final (c, s, vm) = await fixture();
    final reply = Completer<List<ListUnspentRes>>();
    final started = Completer<void>();
    when(c.electrum.getUnspentList(any, c.input)).thenAnswer((_) {
      started.complete();
      return reply.future;
    });
    // A real batch has completed balance/history from before acceptance, and is now waiting for listunspent.
    final batch = ScriptSyncServiceMock.createMockScriptSyncService().syncBatchScriptStatusList(
      walletItem: c.wallet,
      scriptStatuses: [_inputScript(c)],
    );
    await started.future;
    expect((await vm.broadcast(inheritedTagIds: [])).isSuccess, isTrue);
    final afterAccept = c.coinState();
    expect(c.backend.unspent(c.input), isEmpty);
    reply.complete(c.backend.unspent(c.input)); // current result, not stale: accepted spend consumes input
    await batch;
    final afterCleanup = c.coinState();
    c.backend.heights.remove(c.spend.transactionHash); // evicted while offline
    when(c.electrum.getUnspentList(any, c.input)).thenAnswer((_) async => c.backend.unspent(c.input));
    expect(await ScriptSyncServiceMock.utxoSyncService.fetchScriptUtxo(c.wallet, _inputScript(c)), isTrue);
    final finalState = c.coinState();
    final row = ScriptSyncServiceMock.realmManager!.realm.find<RealmUtxo>('$_walletId:${c.coin}');
    _report('pr3-cleanup-tombstone', '-', {
      'after_acceptance': afterAccept,
      'after_batch_cleanup': afterCleanup,
      'after_current_unspent_fetch': finalState,
      'is_deleted': row?.isDeleted,
      'backend_unspent': c.backend.unspent(c.input).any((u) => u.txHash == c.funding.transactionHash),
      'spend_record_exists':
          ScriptSyncServiceMock.transactionRepository.getTransactionRecord(_walletId, c.spend.transactionHash) != null,
    });
    expect(afterAccept, 'outgoing');
    expect(afterCleanup, 'outgoing');
    expect(finalState, 'outgoing');
    expect(row!.isDeleted, isFalse);
    expect(row.status, 'unspent');
    c.now += const Duration(minutes: 30);
    expect(c.coinState(), 'unspent');
  });

  test('own-address reconciliation keeps the soft reservation until expiry', () async {
    final (c, s, vm) = await fixture();
    expect((await vm.broadcast(inheritedTagIds: [])).isSuccess, isTrue);
    c.backend.heights.remove(c.spend.transactionHash);
    expect(await ScriptSyncServiceMock.utxoSyncService.fetchScriptUtxo(c.wallet, _inputScript(c)), isTrue);
    await ScriptSyncServiceMock.utxoSyncService.cleanupOrphanedUtxos(c.wallet, reconciledAddresses: {c.input});
    _report('pr3-drop-own-reconcile', '-', {'coin': c.coinState()});
    expect(c.coinState(), 'outgoing');
    c.now += const Duration(minutes: 30);
    expect(c.coinState(), 'unspent');
  });

  test('accepted reservation syncs history change and confirmation', () async {
    final (c, s, vm) = await fixture();
    expect((await vm.broadcast(inheritedTagIds: [])).isSuccess, isTrue);
    expect(c.coinState(), 'outgoing');
    for (final address in c.spendAddresses) {
      c.backend.notify(address);
    }
    await _drain(s);
    final pending =
        ScriptSyncServiceMock.transactionRepository.getTransactionRecord(_walletId, c.spend.transactionHash)!;
    final before = c.coinState();
    final preparer = RbfPreparer.fromPendingTx(
      pendingTx: pending,
      rawTx: c.spend.serialize(),
      getUtxos: (id) => c.utxos.getUtxoState(_walletId, id),
      isMyAddress:
          (address, {bool isChange = false}) =>
              ScriptSyncServiceMock.addressRepository.containsAddress(_walletId, address),
      getDerivationPath: (address) => ScriptSyncServiceMock.addressRepository.getDerivationPath(_walletId, address),
    );
    expect(preparer.inputUtxos.map((u) => u.utxoId), [c.coin]);
    expect(preparer.inputUtxos.single.spentByTransactionHash, c.spend.transactionHash);
    final changeBefore = c._utxo(getUtxoId(c.spend.transactionHash, 1));
    c.backend.heights[c.spend.transactionHash] = 102;
    for (final address in c.spendAddresses) {
      c.backend.notify(address);
    }
    await _drain(s);
    final confirmed =
        ScriptSyncServiceMock.transactionRepository.getTransactionRecord(_walletId, c.spend.transactionHash)!;
    _report('pr3-confirmation', '-', {
      'pending_coin': before,
      'pending_change': changeBefore,
      'pending_amount': pending.amount,
      'pending_fee': pending.fee,
      'confirmed_coin': c.coinState(),
      'confirmed_height': confirmed.blockHeight,
      'confirmed_change': c._utxo(getUtxoId(c.spend.transactionHash, 1)),
      'wallet_balance': ScriptSyncServiceMock.walletRepository.getWalletBalance(_walletId)!.total,
    });
    expect(pending.amount, -301000);
    expect(pending.fee, 1000);
    expect(confirmed.amount, pending.amount);
    expect(confirmed.fee, pending.fee);
    expect(before, 'outgoing');
    expect(changeBefore, 'incoming');
    expect(c.coinState(), 'deleted');
    expect(confirmed.blockHeight, 102);
    expect(c._utxo(getUtxoId(c.spend.transactionHash, 1)), 'unspent');
    expect(ScriptSyncServiceMock.walletRepository.getWalletBalance(_walletId)!.total, 699000);
  });
}
