// Same-device repro for "a pending UTXO still shows as spendable and gets auto-selected after the app's own send".
//
// Drives the real isolate-side sync (SubscriptionService -> ScriptSyncService -> Balance/Transaction/UtxoSyncService,
// wired like IsolateInitializer.entryInitialize) against an in-memory Electrum backend that answers like Fulcrum
// (status/history/listunspent/balance derived from its own chain + mempool; listunspent excludes mempool spends).
// Tests assert the desired behavior, so a failing test is a reproduction. Each test prints one
// `PENDING_UTXO_OBS {json}` line so outcomes can be compared across versions.
import 'dart:convert';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/core/transaction/utxo_selector.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/wallet/balance.dart';
import 'package:coconut_wallet/model/wallet/singlesig_wallet_item.dart';
import 'package:coconut_wallet/model/wallet/wallet_address.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/providers/node_provider/balance_sync_service.dart';
import 'package:coconut_wallet/providers/node_provider/network_service.dart';
import 'package:coconut_wallet/providers/node_provider/subscription/script_callback_service.dart';
import 'package:coconut_wallet/providers/node_provider/subscription/script_sync_service.dart';
import 'package:coconut_wallet/providers/node_provider/subscription/subscription_service.dart';
import 'package:coconut_wallet/providers/node_provider/transaction/transaction_record_service.dart';
import 'package:coconut_wallet/providers/node_provider/transaction/transaction_sync_service.dart';
import 'package:coconut_wallet/providers/node_provider/utxo_sync_service.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/providers/view_model/send/send_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/repository/realm/address_repository.dart';
import 'package:coconut_wallet/repository/realm/model/coconut_wallet_model.dart';
import 'package:coconut_wallet/repository/realm/service/realm_id_service.dart';
import 'package:coconut_wallet/repository/realm/subscription_repository.dart';
import 'package:coconut_wallet/repository/realm/transaction_draft_repository.dart';
import 'package:coconut_wallet/repository/realm/transaction_repository.dart';
import 'package:coconut_wallet/repository/realm/utxo_repository.dart';
import 'package:coconut_wallet/repository/realm/wallet_repository.dart';
import 'package:coconut_wallet/services/transaction_fetch_pass.dart';
import 'package:coconut_wallet/services/model/response/block_timestamp.dart';
import 'package:coconut_wallet/services/model/response/electrum_response_types.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import '../../../mock/electrum_transaction_transport.dart';
import '../../../mock/manual_timers.dart';
import '../../../mock/script_sync_service_mock.dart';
import '../../../mock/wallet_mock.dart';
import '../transaction/rbf_service_test.mocks.dart';

const _walletId = 1;
final _external = WalletMock.createMultiSigWalletItem().walletBase.getAddress(0);

/// Retry timers of the latest isolate session; they fire only when a test advances this clock.
var _retryClock = ManualTimers();

/// One Fulcrum backend as seen through the app's current socket.
class _Backend {
  final txs = <String, Transaction>{};
  final heights = <String, int>{}; // tx in this backend's chain (>0) or mempool (0)
  final listeners = <String, Function(String, String?)>{}; // scripthash subscriptions of the current socket
  final missingHeaders = <int>{};
  bool Function(String method, String key) fault = (_, __) => false;
  int faultsHit = 0; // injected failures that actually fired (guards against vacuous variants)
  final calls = <String>[]; // '$method:$key' of every request
  int get requests => calls.length;
  Duration latency = Duration.zero;

  void put(Transaction tx, [int? height]) {
    txs[tx.transactionHash] = tx;
    if (height != null) heights[tx.transactionHash] = height;
  }

  Iterable<Transaction> get _known => heights.keys.map((hash) => txs[hash]!);
  TransactionOutput? _prevout(TransactionInput input) {
    final parent = txs[input.transactionHash];
    return parent == null || input.index >= parent.outputs.length ? null : parent.outputs[input.index];
  }

  bool _pays(TransactionOutput? output, String address) => output?.scriptPubKey.getAddress() == address;
  bool _spentBy(Transaction spender, String hash, int index) =>
      spender.inputs.any((input) => input.transactionHash == hash && input.index == index);

  List<GetTxHistoryRes> history(String address) {
    final result = [
      for (final tx in _known)
        if (tx.outputs.any((o) => _pays(o, address)) || tx.inputs.any((i) => _pays(_prevout(i), address)))
          GetTxHistoryRes(height: heights[tx.transactionHash]!, txHash: tx.transactionHash),
    ];
    int order(GetTxHistoryRes h) => h.height > 0 ? h.height : 1 << 30;
    return result..sort((x, y) => order(x).compareTo(order(y)));
  }

  String? status(String address) {
    final entries = history(address);
    return entries.isEmpty ? null : entries.map((h) => '${h.txHash}:${h.height}').join('|');
  }

  List<ListUnspentRes> unspent(String address) => [
    for (final tx in _known)
      for (var n = 0; n < tx.outputs.length; n++)
        if (_pays(tx.outputs[n], address) && !_known.any((s) => _spentBy(s, tx.transactionHash, n)))
          ListUnspentRes(
            height: heights[tx.transactionHash]!,
            txHash: tx.transactionHash,
            txPos: n,
            value: tx.outputs[n].amount,
          ),
  ];

  GetBalanceRes balance(String address) {
    var confirmed = 0, unconfirmed = 0;
    for (final tx in _known) {
      final inMempool = heights[tx.transactionHash]! <= 0;
      for (var n = 0; n < tx.outputs.length; n++) {
        if (!_pays(tx.outputs[n], address)) continue;
        if (inMempool) {
          unconfirmed += tx.outputs[n].amount;
        } else if (!_known.any((s) => heights[s.transactionHash]! > 0 && _spentBy(s, tx.transactionHash, n))) {
          confirmed += tx.outputs[n].amount;
        }
      }
      if (inMempool) {
        for (final input in tx.inputs) {
          final prevout = _prevout(input);
          if (_pays(prevout, address)) unconfirmed -= prevout!.amount;
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
        throw StateError('injected $method($key) failure');
      }
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
    // ElectrumService.fetchBlocksByHeight swallows per-height failures and returns a partial map.
    when(electrum.fetchBlocksByHeight(any)).thenAnswer(
      (c) => answer('headers', '', () {
        final requested = c.positionalArguments[0] as Set<int>;
        faultsHit += requested.where(missingHeaders.contains).length;
        return {
          for (final h in requested)
            if (!missingHeaders.contains(h)) h: BlockTimestamp(h, DateTime.utc(2026, 10, 27).add(Duration(minutes: h))),
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

/// One isolate session: fresh in-memory sync state on the shared Realm, wired like IsolateInitializer.
SubscriptionService _startIsolate(MockElectrumService electrum) {
  final realmManager = ScriptSyncServiceMock.realmManager!;
  final state = ScriptSyncServiceMock.stateManager;
  final addresses = AddressRepository(realmManager);
  final transactions = TransactionRepository(realmManager);
  final utxos = UtxoRepository(realmManager);
  final callbacks = ScriptCallbackService();
  final wallets = WalletRepository(realmManager, TransactionDraftRepository(realmManager));
  _retryClock = ManualTimers();
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
    createTimer: _retryClock.create,
    random: () => 0.5, // no jitter: the retry fires at exactly 10 s
  );
  return SubscriptionService(electrum, state, addresses, SubscriptionRepository(realmManager), sync);
}

/// Lets the subscription stream enqueue pushed statuses, then waits for the wallet queue to drain.
Future<void> _drain(SubscriptionService node) async {
  await Future<void>.delayed(Duration.zero);
  await node.runExclusive(_walletId, () async {});
}

/// Wallet (receive/change addresses) plus the backend that knows its history.
class _Case {
  final electrum = ScriptSyncServiceMock.electrumService;
  final backend = _Backend();
  final SinglesigWalletItem wallet = WalletMock.createSingleSigWalletItem(id: _walletId);
  late final String input; // address holding the coin the app spends (latest receive address)
  late final String change;
  String? neighbour; // older receive address (index 0) when [withNeighbour]
  late final Transaction faucet, funding, spend;
  Transaction? neighbourIn, neighbourOut, payment;

  String get coin => getUtxoId(funding.transactionHash, 0);
  UtxoRepository get utxos => ScriptSyncServiceMock.utxoRepository;

  static Transaction _tx(List<(String, int)> inputs, List<(String, int)> outputs) => Transaction.withInputsAndOutputs(
    [for (final (hash, index) in inputs) TransactionInput.forPayment(hash, index)],
    [for (final (address, amount) in outputs) TransactionOutput.forPayment(amount, address)],
    AddressType.p2wpkh,
  );

  /// [withNeighbour]: a second receive address; by default it is receive 0 and the coin sits on receive 1 (the max
  /// used index). [neighbourIsNewer] swaps them so the coin is not on the newest used address.
  /// [dormantNeighbour]: the neighbour was funded and emptied (confirmed), so it is dormant.
  Future<void> init({bool withNeighbour = false, bool dormantNeighbour = false, bool neighbourIsNewer = false}) async {
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

    faucet = _tx([('00' * 32, 0)], List.filled(4, (_external, 5000000)));
    funding = _tx([(faucet.transactionHash, 0)], [(input, 1000000), (_external, 3999000)]);
    spend = _tx([(funding.transactionHash, 0)], [(_external, 300000), (change, 699000)]);
    backend
      ..put(faucet, 10)
      ..put(funding, 100)
      ..put(spend);
    if (dormantNeighbour) {
      neighbourIn = _tx([(faucet.transactionHash, 2)], [(neighbour!, 200000), (_external, 4799000)]);
      neighbourOut = _tx([(neighbourIn!.transactionHash, 0)], [(_external, 199000)]);
      backend
        ..put(neighbourIn!, 90)
        ..put(neighbourOut!, 95);
    }
    backend.serve(electrum);
  }

  /// Incoming payment that is first seen unconfirmed and later confirms in block 101.
  Transaction paymentTo(String address) =>
      payment = _tx([(faucet.transactionHash, 1)], [(address, 50000), (_external, 4949000)]);

  /// What the isolate receives from the main isolate: a copy with used indexes as persisted.
  SinglesigWalletItem walletCopy() {
    final copy = WalletMock.createSingleSigWalletItem(id: _walletId);
    final (receive, change) = ScriptSyncServiceMock.addressRepository.getUsedIndexes(_walletId);
    copy.receiveUsedIndex = receive;
    copy.changeUsedIndex = change;
    return copy;
  }

  String coinState() {
    final state = utxos.getUtxoState(_walletId, coin);
    return state == null ? 'deleted' : state.status.name;
  }

  /// Auto-selection exactly as the send screen builds it (send_view_model.dart: unspent only -> UtxoSelector).
  bool autoSelectsCoin() {
    final candidates = utxos.getUtxoStateList(_walletId).where((u) => u.status == UtxoStatus.unspent).toList();
    try {
      final result = UtxoSelector.selectOptimalUtxos(candidates, {_external: 600000}, 1, WalletType.singleSignature);
      return result.selectedUtxos.any((u) => u.utxoId == coin);
    } catch (_) {
      return false; // nothing selectable covers the payment
    }
  }

  /// Pull-to-refresh / app resume / reconnect: NodeProvider.reconnect() restarts the isolate and resubscribes.
  Future<SubscriptionService> reconnect() async {
    backend.listeners.clear();
    final node = _startIsolate(electrum);
    await node.subscribeWallet(walletCopy());
    return node;
  }
}

// Minimal stand-ins for the send screen's collaborators; UTXOs and addresses come from the shared test Realm.
class _Wallets extends Fake implements WalletProvider {
  final WalletItemBase wallet;
  _Wallets(this.wallet);
  @override
  List<WalletItemBase> get walletItemList => [wallet];
  @override
  List<UtxoState> getUtxoList(int walletId) => ScriptSyncServiceMock.utxoRepository.getUtxoStateList(walletId);
  @override
  WalletAddress getChangeAddress(int walletId) =>
      ScriptSyncServiceMock.addressRepository.getChangeAddress(walletId, wallet: wallet.walletBase);
  @override
  WalletAddress getReceiveAddress(int walletId) =>
      ScriptSyncServiceMock.addressRepository.getReceiveAddress(walletId, wallet: wallet.walletBase);
  @override
  Map<int, WalletAddress> getReceiveAddressMap() => ScriptSyncServiceMock.addressRepository.getReceiveAddressMap();
  @override
  bool containsAddress(int walletId, String address, {bool? isChange}) => false;
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _Preferences extends Fake implements PreferenceProvider {
  @override
  BitcoinUnit get currentUnit => BitcoinUnit.sats;
  @override
  List<int> get walletOrder => [];
  @override
  bool get isManualUtxoSelectionMode => false;
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _SendInfo extends Fake implements SendInfoProvider {
  @override
  Transaction? transaction;
  @override
  void setTransaction(Transaction transaction) => this.transaction = transaction;
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _Drafts extends Fake implements TransactionDraftRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void _report(String variant, String order, Map<String, Object?> observed) {
  // ignore: avoid_print
  print('PENDING_UTXO_OBS ${jsonEncode({'variant': variant, 'order': order, ...observed})}');
}

void main() {
  setUp(ScriptSyncServiceMock.init);
  tearDown(() {
    ScriptSyncServiceMock.realmManager?.dispose();
    ScriptSyncServiceMock.realmManager = null;
  });

  /// Wallet with one confirmed coin, synced on a healthy connection; the app then broadcasts its own spend.
  Future<(_Case, SubscriptionService)> sendFromSyncedWallet({
    bool withNeighbour = false,
    bool dormantNeighbour = false,
    bool neighbourIsNewer = false,
  }) async {
    final c = _Case();
    await c.init(withNeighbour: withNeighbour, dormantNeighbour: dormantNeighbour, neighbourIsNewer: neighbourIsNewer);
    final node = _startIsolate(c.electrum);
    expect((await node.subscribeWallet(c.wallet)).isSuccess, isTrue);
    expect(c.coinState(), 'unspent', reason: 'precondition: the confirmed coin is spendable before the send');
    expect(c.autoSelectsCoin(), isTrue, reason: 'precondition: auto-selection picks the coin before the send');
    return (c, node);
  }

  Future<void> broadcast(_Case c) async {
    final sent = await NetworkService(c.electrum).broadcast(c.spend);
    expect(sent.isSuccess, isTrue);
  }

  test(
    '[window-before-notification] the app\'s own broadcast reserves its input before the server pushes',
    () async {
      final (c, _) = await sendFromSyncedWallet();
      await broadcast(c);
      final observed = {'coin_after_broadcast': c.coinState(), 'auto_selects_coin': c.autoSelectsCoin()};
      _report('window-before-notification', '-', observed);
      expect(
        observed,
        {'coin_after_broadcast': 'outgoing', 'auto_selects_coin': false},
        reason: 'Nothing reserves the inputs at broadcast; only the server notification + sync marks them outgoing.',
      );
    },
    skip: 'Out of scope for PR1: reserving the inputs at broadcast is not part of this fix.',
  );

  // Live notification variants. `order` is the order the server pushes the input-address and change-address statuses.
  const liveVariants = [
    'healthy',
    'a-header-same-address', // a confirmed tx in the input address' history needs a header that cannot be fetched
    'a-header-neighbour', // the same, but the confirmed tx belongs to another address synced in the same batch
    'b-balance-once', // the first get_balance after the broadcast times out
    'b-history-once', // the first get_history after the broadcast times out
    'b-tx-once', // the first raw-tx fetch of the app's own tx times out
    'd-tx-not-yet-retrievable', // raw-tx fetch of the app's own tx fails until the network recovers
    'f-other-tx-same-address', // another new tx on the input address cannot be fetched until the network recovers
    'g-dormant-balance-failure', // an earlier dormant-address balance check timed out (app resume)
    'g-dormant-balance-failure-coin-not-newest', // the same, but the spent coin is not on the newest used address
  ];
  for (final variant in liveVariants) {
    for (final changeFirst in [false, true]) {
      final order = changeFirst ? 'change-first' : 'input-first';
      test('[$variant] $order: after sync the spent input is outgoing and not auto-selected', () async {
        final dormant = variant.startsWith('g-dormant');
        final (c, node) = await sendFromSyncedWallet(
          withNeighbour: dormant || variant == 'a-header-neighbour',
          dormantNeighbour: dormant,
          neighbourIsNewer: variant == 'g-dormant-balance-failure-coin-not-newest',
        );
        final b = c.backend;

        if (variant.startsWith('a-header')) {
          // The payment is seen unconfirmed first, then confirms in block 101 just as the app broadcasts.
          final payee = variant == 'a-header-same-address' ? c.input : c.neighbour!;
          b.put(c.paymentTo(payee), 0);
          b.notify(payee);
          await _drain(node);
          final seen = ScriptSyncServiceMock.transactionRepository.getTransactionRecord(
            _walletId,
            c.payment!.transactionHash,
          );
          expect(seen?.blockHeight, 0, reason: 'precondition: the payment is known as unconfirmed');
          b.heights[c.payment!.transactionHash] = 101;
          b.missingHeaders.add(101);
        }
        if (dormant) {
          b.fault = (method, key) => method == 'getBalance' && key == c.neighbour;
          await node.syncDormantAddresses(c.walletCopy());
          b.fault = (_, __) => false;
          expect(b.faultsHit, 1, reason: 'precondition: the dormant-address balance check hit the timeout');
          expect(c.coinState(), 'unspent');
        }
        final faultsBeforeSend = b.faultsHit;

        await broadcast(c);
        final coinAfterBroadcast = c.coinState();

        final once = <String>{};
        bool firstOnly(String id) => once.add(id);
        switch (variant) {
          case 'b-balance-once':
            b.fault = (method, key) => method == 'getBalance' && firstOnly('balance');
          case 'b-history-once':
            b.fault = (method, key) => method == 'getHistory' && firstOnly('history');
          case 'b-tx-once':
            b.fault = (method, key) => method == 'getTransaction' && key == c.spend.transactionHash && firstOnly('tx');
          case 'd-tx-not-yet-retrievable':
            b.fault = (method, key) => method == 'getTransaction' && key == c.spend.transactionHash;
          case 'f-other-tx-same-address':
            b.put(c.paymentTo(c.input), 0); // reaches the same mempool window as the app's tx
            b.fault = (method, key) => method == 'getTransaction' && key == c.payment!.transactionHash;
        }

        final pushes = [
          if (variant == 'a-header-neighbour') c.neighbour!, // block 101 changed the neighbour's status first
          ...(changeFirst ? [c.change, c.input] : [c.input, c.change]),
        ];
        for (final address in pushes) {
          b.notify(address);
        }
        await _drain(node);

        // The network has recovered; nothing else changes on the server. Is the input reserved now?
        b.fault = (_, __) => false;
        b.missingHeaders.clear();
        await _drain(node);
        if (variant == 'd-tx-not-yet-retrievable') {
          // No push comes again: only the bounded retry can reserve the input, after its delay (10 s in the app).
          expect(_retryClock.pendingDelays, [const Duration(seconds: 10)], reason: 'one retry is pending');
          _retryClock.elapse();
          await _drain(node);
        }
        final observed = <String, Object?>{
          'coin_after_broadcast': coinAfterBroadcast,
          'faults_hit_after_send': b.faultsHit - faultsBeforeSend,
          'coin_after_sync': c.coinState(),
          'auto_selects_coin_after_sync': c.autoSelectsCoin(),
          'spend_record_saved':
              ScriptSyncServiceMock.transactionRepository.getTransactionRecord(_walletId, c.spend.transactionHash) !=
              null,
        };
        await c.reconnect();
        observed['coin_after_reconnect'] = c.coinState();
        _report(variant, order, observed);

        final injectedAfterSend = variant != 'healthy' && !dormant;
        expect(
          (observed['faults_hit_after_send'] as int) > 0,
          injectedAfterSend,
          reason: 'the injected fault must fire',
        );
        expect(observed['coin_after_sync'], 'outgoing');
        expect(observed['auto_selects_coin_after_sync'], isFalse);
      });
    }
  }

  test('[c-reconnect-before-notification] the push is lost; the reconnect sync marks the input', () async {
    final (c, _) = await sendFromSyncedWallet();
    await broadcast(c);
    c.backend.listeners.clear(); // socket dropped before the server pushed the new statuses
    await c.reconnect();
    final observed = {'coin_after_sync': c.coinState(), 'auto_selects_coin_after_sync': c.autoSelectsCoin()};
    _report('c-reconnect-before-notification', '-', observed);
    expect(observed, {'coin_after_sync': 'outgoing', 'auto_selects_coin_after_sync': false});
  });

  // [e-lagging-backend]: after the live sync, a reconnect lands on a backend whose mempool lacks the tx (yet).
  // [e-lagging-backend-after-reconnect]: same, but one reconnect to an up-to-date backend happens in between.
  for (final reconnectFirst in [false, true]) {
    final variant = reconnectFirst ? 'e-lagging-backend-after-reconnect' : 'e-lagging-backend';
    test(
      '[$variant] a reconnect to a backend without the tx must not release the input',
      () async {
        final (c, node) = await sendFromSyncedWallet();
        final b = c.backend;
        await broadcast(c);
        b
          ..notify(c.input)
          ..notify(c.change);
        await _drain(node);
        if (reconnectFirst) await c.reconnect();
        // Before bf4eab6d the reconnect saved script statuses without awaiting the write; let it land before probing.
        await Future<void>.delayed(const Duration(milliseconds: 200));
        final stored = SubscriptionRepository(ScriptSyncServiceMock.realmManager!).getAllScriptStatuses(_walletId);
        final observed = <String, Object?>{
          'coin_after_sync': c.coinState(),
          'stored_input_status_is_post_send': stored.value.any((s) => s.status == b.status(c.input)),
        };

        b.heights.remove(c.spend.transactionHash);
        final callsBefore = b.calls.length;
        final lagging = await c.reconnect();
        observed['lagging_reconnect_refetched_input_utxos'] = b.calls
            .skip(callsBefore)
            .contains('listunspent:${c.input}');
        observed['coin_after_lagging_reconnect'] = c.coinState();
        observed['spent_by_kept_after_lagging_reconnect'] =
            c.utxos.getUtxoState(_walletId, c.coin)?.spentByTransactionHash == c.spend.transactionHash;

        // That backend then receives the tx and pushes the statuses.
        b.heights[c.spend.transactionHash] = 0;
        b
          ..notify(c.input)
          ..notify(c.change);
        await _drain(lagging);
        observed['coin_after_lagging_backend_catches_up'] = c.coinState();

        await c.reconnect();
        observed['coin_after_next_reconnect'] = c.coinState();
        observed['auto_selects_coin_at_end'] = c.autoSelectsCoin();
        _report(variant, '-', observed);

        expect(observed['coin_after_sync'], 'outgoing');
        expect(observed['coin_after_lagging_reconnect'], 'outgoing');
        expect(observed['coin_after_next_reconnect'], 'outgoing');
        expect(observed['auto_selects_coin_at_end'], isFalse);
      },
      skip:
          'D1 deferred: keeping a reserved input while a lagging backend\'s listunspent still lists it is not in PR1.',
    );
  }

  test(
    '[h-open-send-screen] a send screen opened before the sync keeps offering the spent input',
    () async {
      final (c, node) = await sendFromSyncedWallet();
      await broadcast(c);
      SendViewModel openSendScreen(_SendInfo info) => SendViewModel(
        _Wallets(c.wallet),
        info,
        _Preferences(),
        _Drafts(),
        c.utxos,
        true,
        (_) {},
        (_) {},
        (_) {},
        _walletId,
        SendEntryPoint.home,
        null,
        null,
      );
      final openInfo = _SendInfo();
      final open = openSendScreen(openInfo); // the user starts the next send right after the first broadcast

      c.backend
        ..notify(c.input)
        ..notify(c.change);
      await _drain(node);
      final reopened = openSendScreen(_SendInfo());
      for (final screen in [open, reopened]) {
        screen
          ..setAddressText(_external, 0)
          ..setAmountText(600000, 0)
          ..validateAllFieldsOnFocusLost()
          ..setFeeRateText('1');
      }
      if (open.canGoNext) open.saveSendInfo(); // what the "next" button does
      final observed = {
        'coin_in_db': c.coinState(),
        'open_screen_balance': open.balance,
        'open_screen_can_go_next': open.canGoNext,
        'open_screen_spends_coin':
            openInfo.transaction?.inputs.any((i) => getUtxoId(i.transactionHash, i.index) == c.coin) ?? false,
        'reopened_screen_balance': reopened.balance,
        'reopened_screen_can_go_next': reopened.canGoNext,
      };
      open.dispose();
      reopened.dispose();
      _report('h-open-send-screen', '-', observed);
      expect(observed['coin_in_db'], 'outgoing', reason: 'precondition: the sync reserved the input');
      expect(observed['open_screen_spends_coin'], isFalse);
    },
    skip: 'PR3: the send screen re-validating its UTXO snapshot at Next/Sign (F) is out of scope for PR1.',
  );

  // How long the healthy window stays open: every Electrum request costs 100 ms (mobile RTT).
  for (final changeFirst in [false, true]) {
    final order = changeFirst ? 'change-first' : 'input-first';
    test('[window-length] $order: time and requests from the push until the input is reserved', () async {
      final (c, node) = await sendFromSyncedWallet();
      final b = c.backend..latency = const Duration(milliseconds: 100);
      await broadcast(c);
      final requestsBefore = b.requests;
      final clock = Stopwatch()..start();
      for (final address in changeFirst ? [c.change, c.input] : [c.input, c.change]) {
        b.notify(address);
      }
      while (c.coinState() != 'outgoing' && clock.elapsed < const Duration(seconds: 60)) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      final reservedAfter = clock.elapsed.inMilliseconds;
      final requestsUntilReserved = b.requests - requestsBefore;
      await _drain(node);
      _report('window-length', order, {
        'ms_until_reserved': reservedAfter,
        'rtt_after_1s_indexing_delay': ((reservedAfter - 1000) / 100).toStringAsFixed(1),
        'requests_until_reserved': requestsUntilReserved,
        'requests_for_both_pushes': b.requests - requestsBefore,
      });
      expect(c.coinState(), 'outgoing');
    });
  }

  // HEAVY_GROW stress (Fold, regtest): a batch pays fresh receive addresses, then single payments reuse them. A single
  // that reaches the mempool after the gap-extension batch read the address' history, but before that batch's
  // listunspent, is listed with no record yet. The batch cleanup took it for an orphan, and the tombstone kept every
  // later listunspent (confirmation, reconnect) from bringing the coin back. 76 coins went missing that way.
  test('[heavy-reuse] a payment landing between a batch\'s history and listunspent stays in the coin list', () async {
    final c = _Case();
    await c.init();
    final node = _startIsolate(c.electrum);
    expect((await node.subscribeWallet(c.wallet)).isSuccess, isTrue);
    final b = c.backend;
    final fresh1 = c.wallet.walletBase.getAddress(1), fresh2 = c.wallet.walletBase.getAddress(2);
    final batch = _Case._tx([(c.faucet.transactionHash, 1)], [(fresh1, 20000), (fresh2, 20000), (_external, 4959000)]);
    final single = _Case._tx([(c.faucet.transactionHash, 2)], [(fresh2, 2780), (_external, 4996220)]);
    String coin() => c.utxos.getUtxoState(_walletId, getUtxoId(single.transactionHash, 0))?.status.name ?? 'deleted';
    b.put(batch, 0);
    String? afterBatch;
    b.fault = (method, key) {
      final arrived = b.heights.containsKey(single.transactionHash);
      if (method == 'listunspent' && key == fresh2 && !arrived) b.put(single, 0); // after the batch read the history
      if (method == 'getBalance' && key == fresh2 && arrived) afterBatch ??= coin(); // fresh2's queued push starts
      return false;
    };
    b
      ..notify(fresh1) // extends the gap window: the batch syncs fresh1 and fresh2
      ..notify(fresh2);
    await _drain(node);
    b.notify(fresh2); // the single's own push
    await _drain(node);
    final observed = <String, Object?>{'after_batch': afterBatch, 'after_own_push': coin()};
    b.heights[batch.transactionHash] = 101;
    b.heights[single.transactionHash] = 101;
    b
      ..notify(fresh1)
      ..notify(fresh2);
    await _drain(node);
    observed['after_block'] = coin();
    await c.reconnect();
    observed['after_reconnect'] = coin();
    _report('heavy-reuse', '-', observed);
    expect(observed, {
      'after_batch': 'incoming',
      'after_own_push': 'incoming',
      'after_block': 'unspent',
      'after_reconnect': 'unspent',
    });
  });

  // HEAVY_SYNC (restart after HEAVY_GROW): the tombstones are persisted and the addresses' statuses match the stored
  // ones, so the startup sync never asks for those coins again. The next subscription must bring them back, once.
  test('[heavy-reuse-heal] a coin removed while incoming comes back on the next subscription', () async {
    final c = _Case();
    await c.init();
    final b = c.backend;
    final single = _Case._tx([(c.faucet.transactionHash, 2)], [(c.input, 2780), (_external, 4996220)]);
    final coin = getUtxoId(single.transactionHash, 0);
    String coinState() => c.utxos.getUtxoState(_walletId, coin)?.status.name ?? 'deleted';
    b.put(single, 101);
    expect((await _startIsolate(c.electrum).subscribeWallet(c.wallet)).isSuccess, isTrue); // stores the statuses
    expect(coinState(), 'unspent', reason: 'precondition: the coin was synced');
    final realm = ScriptSyncServiceMock.realmManager!.realm;
    realm.write(() {
      realm.find<RealmUtxo>('$_walletId:$coin')!
        ..isDeleted = true
        ..status = 'incoming'
        ..blockHeight = 0;
    }); // what the batch cleanup left behind
    var calls = b.calls.length;
    await c.reconnect();
    final healRequests = b.calls.skip(calls).where((call) => !call.startsWith('subscribe:')).toList();
    final observed = <String, Object?>{'after_reconnect': coinState()};
    calls = b.calls.length;
    await c.reconnect();
    observed['requests_after_heal'] = b.calls.skip(calls).where((call) => !call.startsWith('subscribe:')).length;
    _report('heavy-reuse-heal', '-', observed);
    expect(healRequests, contains('listunspent:${c.input}'));
    expect(observed, {'after_reconnect': 'unspent', 'requests_after_heal': 0});
  });

  // Codex review (MUST 1): a coin that the old cleanup removed and another device then spent must stay removed, even
  // when the server's listunspent (and get_balance) still report it. The spend leaves its hash on the tombstone.
  for (final server in ['honest', 'stale-list', 'stale-list-and-balance']) {
    test('[heavy-reuse-spent] a removed coin spent from another device stays removed ($server)', () async {
      final c = _Case();
      await c.init();
      expect((await _startIsolate(c.electrum).subscribeWallet(c.wallet)).isSuccess, isTrue);
      final realm = ScriptSyncServiceMock.realmManager!.realm;
      realm.write(() {
        realm.find<RealmUtxo>('$_walletId:${c.coin}')!
          ..status = 'incoming'
          ..blockHeight = 0
          ..isDeleted = true;
      });
      c.backend.put(c.spend, 101);
      if (server != 'honest') {
        when(c.electrum.getUnspentList(any, any)).thenAnswer((call) async {
          final address = call.positionalArguments[1] as String;
          return address == c.input
              ? [ListUnspentRes(height: 100, txHash: c.funding.transactionHash, txPos: 0, value: 1000000)]
              : c.backend.unspent(address);
        });
      }
      if (server == 'stale-list-and-balance') {
        when(
          c.electrum.getBalance(any, c.input),
        ).thenAnswer((_) async => GetBalanceRes(confirmed: 1000000, unconfirmed: 0));
      }
      await c.reconnect();
      final spend = ScriptSyncServiceMock.transactionRepository.getTransactionRecord(
        _walletId,
        c.spend.transactionHash,
      );
      _report('heavy-reuse-spent', server, {'coin': c.coinState(), 'spend_height': spend?.blockHeight});
      expect(spend?.blockHeight, 101);
      expect(c.coinState(), 'deleted');
    });
  }

  // Claude review (M1): our fee bump loses the race and the original confirms. The original's change coin stays removed
  // (the original stays marked replaced, tracked separately), but that must not re-list its address on every start.
  test(
    '[heavy-reuse-own-bump-loses] an unrestorable removed coin does not re-list its address on every start',
    () async {
      final c = _Case();
      await c.init();
      final node = _startIsolate(c.electrum);
      expect((await node.subscribeWallet(c.wallet)).isSuccess, isTrue);
      final b = c.backend;
      Future<void> push() async {
        b
          ..notify(c.input)
          ..notify(c.change);
        await _drain(node);
      }

      b.heights[c.spend.transactionHash] = 0;
      await push();
      final bump = _Case._tx([(c.funding.transactionHash, 0)], [(_external, 300000), (c.change, 690000)]);
      b.heights.remove(c.spend.transactionHash);
      b.put(bump, 0);
      await push();
      b.heights.remove(bump.transactionHash);
      b.heights[c.spend.transactionHash] = 101; // the original wins
      await push();
      await c.reconnect(); // stores the statuses after the race
      final requests = <int>[];
      for (var i = 0; i < 2; i++) {
        final from = b.calls.length;
        await c.reconnect();
        requests.add(b.calls.skip(from).where((call) => !call.startsWith('subscribe:')).length);
      }
      _report('heavy-reuse-own-bump-loses', '-', {'requests_per_start': requests});
      expect(requests, [0, 0]);
    },
  );
}
