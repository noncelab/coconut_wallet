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
import 'package:coconut_wallet/services/model/response/block_timestamp.dart';
import 'package:coconut_wallet/services/model/response/electrum_response_types.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import '../../../mock/script_sync_service_mock.dart';
import '../../../mock/wallet_mock.dart';
import '../transaction/rbf_service_test.mocks.dart';

const _walletId = 1;
final _external = WalletMock.createMultiSigWalletItem().walletBase.getAddress(0);

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
    when(electrum.getBalance(any, any)).thenAnswer((c) => answer('getBalance', arg(c, 1), () => balance(arg(c, 1))));
    when(electrum.getHistory(any, any)).thenAnswer((c) => answer('getHistory', arg(c, 1), () => history(arg(c, 1))));
    when(
      electrum.getUnspentList(any, any),
    ).thenAnswer((c) => answer('listunspent', arg(c, 1), () => unspent(arg(c, 1))));
    when(electrum.getTransaction(any)).thenAnswer((c) => answer('getTransaction', arg(c, 0), () => rawTx(arg(c, 0))));
    when(electrum.getPreviousTransactions(any, existingTxList: anyNamed('existingTxList'))).thenAnswer((c) async {
      // ElectrumService.getPreviousTransactions returns [] when any parent fetch fails.
      try {
        final tx = c.positionalArguments[0] as Transaction;
        return [
          for (final hash in tx.inputs.map((i) => i.transactionHash).toSet())
            Transaction.parse(await answer('getTransaction', hash, () => rawTx(hash))),
        ];
      } catch (_) {
        return <Transaction>[];
      }
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

/// One isolate session: fresh in-memory sync state on the shared Realm, wired like IsolateInitializer.
SubscriptionService _startIsolate(MockElectrumService electrum) {
  final realmManager = ScriptSyncServiceMock.realmManager!;
  final state = ScriptSyncServiceMock.stateManager;
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

  test('[window-before-notification] the app\'s own broadcast reserves its input before the server pushes', () async {
    final (c, _) = await sendFromSyncedWallet();
    await broadcast(c);
    final observed = {'coin_after_broadcast': c.coinState(), 'auto_selects_coin': c.autoSelectsCoin()};
    _report('window-before-notification', '-', observed);
    expect(
      observed,
      {'coin_after_broadcast': 'outgoing', 'auto_selects_coin': false},
      reason: 'Nothing reserves the inputs at broadcast; only the server notification + sync marks them outgoing.',
    );
  });

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
    test('[$variant] a reconnect to a backend without the tx must not release the input', () async {
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
    });
  }

  test('[h-open-send-screen] a send screen opened before the sync keeps offering the spent input', () async {
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
  });

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
}
