import 'dart:isolate';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/constants/shared_pref_keys.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/wallet/hot_wallet_metadata.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/model/wallet/watch_only_wallet.dart';
import 'package:coconut_wallet/providers/node_provider/balance_sync_service.dart';
import 'package:coconut_wallet/providers/node_provider/state/isolate_state_manager.dart';
import 'package:coconut_wallet/providers/node_provider/subscription/script_callback_service.dart';
import 'package:coconut_wallet/providers/node_provider/subscription/script_sync_service.dart';
import 'package:coconut_wallet/providers/node_provider/subscription/subscription_service.dart';
import 'package:coconut_wallet/providers/node_provider/transaction/transaction_record_service.dart';
import 'package:coconut_wallet/providers/node_provider/transaction/transaction_sync_service.dart';
import 'package:coconut_wallet/providers/node_provider/utxo_sync_service.dart';
import 'package:coconut_wallet/repository/realm/address_repository.dart';
import 'package:coconut_wallet/repository/realm/subscription_repository.dart';
import 'package:coconut_wallet/repository/realm/transaction_draft_repository.dart';
import 'package:coconut_wallet/repository/realm/transaction_repository.dart';
import 'package:coconut_wallet/repository/realm/utxo_repository.dart';
import 'package:coconut_wallet/repository/realm/wallet_repository.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:coconut_wallet/services/electrum_service.dart';
import 'package:coconut_wallet/services/model/response/block_timestamp.dart';
import 'package:coconut_wallet/services/model/response/electrum_response_types.dart';
import 'package:coconut_wallet/services/wallet_add_service.dart';
import 'package:coconut_wallet/utils/electrum_utils.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../mock/wallet_mock.dart';
import '../../../repository/realm/test_realm_manager.dart';

/// 공개 regtest 테스트 키(test/mock/wallet_mock.dart와 같은 값)
const _descriptor =
    "wpkh([D45AA182/84'/1'/0']vpub5YtEovN9MqeUZxWqdpUKngsiaLCPFY34KpWGQVk9Tjq8G5SYcRFj9s5aCKeAQYGunG7LrFkA5obtH8kPJiv92JtWHfRvnir6PDvhd4p93Pp/<0;1>/*)#rcn2hj6y";

/// 작은 일렉트럼 서버. 상태 알림은 바로 보내고, [held] 거래는 잔액·내역 조회에 아직 반영하지 않는다.
/// 구독 콜백은 SocketManager처럼 스크립트 해시 → 지갑 id 맵으로 둔다.
class _FakeElectrum extends Fake implements ElectrumService {
  final txs = <String, Transaction>{};
  final heights = <String, int>{};
  final held = <String>{};
  final callbacks = <String, Map<int, Function(String, String?)>>{};
  bool _queryView = false;

  void put(Transaction tx, int height, {bool hold = false}) {
    txs[tx.transactionHash] = tx;
    heights[tx.transactionHash] = height;
    if (hold) held.add(tx.transactionHash);
  }

  Iterable<(Transaction, int)> get _visible => txs.values
      .where((tx) => !_queryView || !held.contains(tx.transactionHash))
      .map((tx) => (tx, heights[tx.transactionHash]!));

  T _query<T>(T Function() read) {
    _queryView = true;
    try {
      return read();
    } finally {
      _queryView = false;
    }
  }

  bool _spent(String hash, int index, {bool confirmedOnly = false}) => _visible.any(
    (e) => (!confirmedOnly || e.$2 > 0) && e.$1.inputs.any((i) => i.transactionHash == hash && i.index == index),
  );

  List<(String, int, int, int)> outputsTo(String address) => [
    for (final (tx, height) in _visible)
      for (var i = 0; i < tx.outputs.length; i++)
        if (tx.outputs[i].getAddress() == address) (tx.transactionHash, i, tx.outputs[i].amount, height),
  ];

  List<GetTxHistoryRes> _history(String address) {
    final own = outputsTo(address).map((o) => (o.$1, o.$2)).toSet();
    return [
      for (final (tx, height) in _visible)
        if (tx.outputs.any((o) => o.getAddress() == address) ||
            tx.inputs.any((i) => own.contains((i.transactionHash, i.index))))
          GetTxHistoryRes(height: height, txHash: tx.transactionHash),
    ]..sort((a, b) => a.height.compareTo(b.height));
  }

  String? _status(String address) {
    final history = _history(address);
    return history.isEmpty ? null : Hash.sha256(history.map((h) => '${h.txHash}:${h.height}:').join()).toString();
  }

  int balanceOf(String address) {
    var total = 0;
    for (final (hash, index, value, _) in outputsTo(address)) {
      if (!_spent(hash, index)) total += value;
    }
    return total;
  }

  void notify(String address) {
    final script = ElectrumUtil.addressToReversedScriptHash(AddressType.p2wpkh, address);
    for (final callback in [...?callbacks[address]?.values]) {
      callback(script, _status(address));
    }
  }

  @override
  Future<String?> subscribeScriptForWallet(
    AddressType addressType,
    String address, {
    required int walletId,
    required Function(String, String?) onUpdate,
  }) async {
    (callbacks[address] ??= {})[walletId] = onUpdate;
    await Future<void>.delayed(const Duration(milliseconds: 1));
    return _status(address);
  }

  @override
  Future<bool> unsubscribeScriptForWallet(AddressType addressType, String address, {required int walletId}) async {
    callbacks[address]?.remove(walletId);
    if (callbacks[address]?.isEmpty ?? false) callbacks.remove(address);
    return true;
  }

  /// SocketManager.removeSubscriptionCallback처럼 그 스크립트의 모든 지갑 콜백을 지운다.
  @override
  Future<bool> unsubscribeScript(AddressType addressType, String address) async {
    callbacks.remove(address);
    return true;
  }

  @override
  Future<GetBalanceRes> getBalance(AddressType addressType, String address) async {
    await Future<void>.delayed(const Duration(milliseconds: 1));
    return _query(() {
      var confirmed = 0;
      var unconfirmed = 0;
      for (final (hash, index, value, height) in outputsTo(address)) {
        if (height > 0) {
          if (!_spent(hash, index, confirmedOnly: true)) confirmed += value;
          if (_spent(hash, index) && !_spent(hash, index, confirmedOnly: true)) unconfirmed -= value;
        } else if (!_spent(hash, index)) {
          unconfirmed += value;
        }
      }
      return GetBalanceRes(confirmed: confirmed, unconfirmed: unconfirmed);
    });
  }

  @override
  Future<List<GetTxHistoryRes>> getHistory(AddressType addressType, String address) async {
    await Future<void>.delayed(const Duration(milliseconds: 1));
    return _query(() => _history(address));
  }

  @override
  Future<List<ListUnspentRes>> getUnspentList(AddressType addressType, String address) async {
    await Future<void>.delayed(const Duration(milliseconds: 1));
    return _query(
      () => [
        for (final (hash, index, value, height) in outputsTo(address))
          if (!_spent(hash, index)) ListUnspentRes(height: height, txHash: hash, txPos: index, value: value),
      ],
    );
  }

  @override
  Future<String> getTransaction(String txHash, {bool? verbose, Duration timeout = const Duration(seconds: 5)}) async =>
      txs[txHash]!.serialize();

  @override
  Future<List<Transaction>> getPreviousTransactions(
    Transaction transaction, {
    List<Transaction>? existingTxList,
  }) async => [
    for (final input in transaction.inputs)
      if (txs[input.transactionHash] case final previous?) previous,
  ];

  @override
  Future<Map<int, BlockTimestamp>> fetchBlocksByHeight(Set<int> heights) async => {
    for (final height in heights) height: BlockTimestamp(height, DateTime.utc(2026).add(Duration(hours: height))),
  };

  @override
  Future<BlockTimestamp> getBlockTimestamp(int height) async =>
      BlockTimestamp(height, DateTime.utc(2026).add(Duration(hours: height)));

  @override
  Future<BlockHeaderSubscribe> getCurrentBlock() async => BlockHeaderSubscribe(height: 200, hex: '');
}

Transaction _tx(List<(String, int)> inputs, List<(int, String)> outputs) => Transaction.withInputsAndOutputs(
  [for (final (hash, index) in inputs) TransactionInput.forPayment(hash, index)],
  [for (final (amount, address) in outputs) TransactionOutput.forPayment(amount, address)],
  AddressType.p2wpkh,
);

/// 같은 확장 공개키로 만든 핫월렛과 보기 전용 지갑. 동기화 서비스는 IsolateInitializer와 같은 순서로 묶는다.
class _Pair {
  final electrum = _FakeElectrum();
  final port = ReceivePort();
  final realmManager = TestRealmManager();
  late final addresses = AddressRepository(realmManager);
  late final wallets = WalletRepository(realmManager, TransactionDraftRepository(realmManager));
  late final utxos = UtxoRepository(realmManager);
  late final transactions = TransactionRepository(realmManager);
  late final state = IsolateStateManager(port.sendPort);
  late final SubscriptionService subscriptions;
  final base = SingleSignatureWallet.fromDescriptor(_descriptor);
  final external = WalletMock.createMultiSigWalletItem().walletBase.getAddress(0);
  late final own = [
    for (final isChange in [false, true])
      for (var i = 0; i < 30; i++) base.getAddress(i, isChange: isChange),
  ];
  late int hotId;
  late int watchId;

  Future<void> setUp() async {
    final callbacks = ScriptCallbackService();
    subscriptions = SubscriptionService(
      electrum,
      state,
      addresses,
      SubscriptionRepository(realmManager),
      ScriptSyncService(
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
      ),
    );
    SharedPreferences.setMockInitialValues({SharedPrefKeys.kNextIdField: 1});
    await SharedPrefsRepository().init();
    for (final (i, amount) in [(0, 600000), (1, 100000)]) {
      final funding = _tx([('${i + 1}' * 64, 0)], [(amount + 50000, external)]);
      electrum.put(funding, 100);
      electrum.put(_tx([(funding.transactionHash, 0)], [(amount, base.getAddress(i)), (49000, external)]), 101 + i);
    }
    hotId =
        (await wallets.addHotWallet(
          WatchOnlyWallet('핫월렛', 0, 0, _descriptor, null, null, WalletImportSource.coconutVault.name),
          secureStorageKey: 'hot',
          backupVerified: true,
          enterPassphraseWhenSigning: false,
          createdAt: DateTime.utc(2026),
          lifecycleState: HotWalletLifecycleState.active,
        )).id;
    // 확장 공개키를 붙여 넣어 같은 지갑 팝업에서 핫월렛을 남기고 추가한 보기 전용 지갑과 같은 저장 결과
    final xpub = base.keyStore.extendedPublicKey.serialize();
    watchId =
        (await wallets.addSinglesigWallet(WalletAddService().createExtendedPublicKeyWallet(xpub, '보기 전용', null))).id;
    for (final id in [hotId, watchId]) {
      await addresses.ensureAddressesInit(walletItemBase: await copy(id));
      await subscribe(id);
    }
    await drain();
  }

  /// 동기화 isolate는 메인에서 보낸 지갑 항목의 복사본을 받는다.
  Future<WalletItemBase> copy(int id) async => (await wallets.getWalletItemList()).firstWhere((w) => w.id == id);

  Future<void> subscribe(int id) async {
    state.initWalletUpdateStatus(id);
    await subscriptions.subscribeWallet(await copy(id));
  }

  Future<void> drain() async {
    for (var i = 0; i < 4; i++) {
      await pumpEventQueue();
      for (final wallet in await wallets.getWalletItemList()) {
        await subscriptions.runExclusive(wallet.id, () async {});
      }
    }
  }

  int chain() => own.fold(0, (sum, address) => sum + electrum.balanceOf(address));
  int balance(int id) => wallets.getWalletBalance(id)?.total ?? 0;
  String fundedBy(String address) =>
      electrum.txs.values.firstWhere((tx) => tx.outputs.first.getAddress() == address).transactionHash;

  void notify(Transaction tx) {
    final touched = <String>{
      for (final input in tx.inputs)
        if (electrum.txs[input.transactionHash] case final previous?) previous.outputs[input.index].getAddress(),
      for (final output in tx.outputs) output.getAddress(),
    };
    for (final address in touched.where(own.contains)) {
      electrum.notify(address);
    }
  }

  void dispose() {
    port.close();
    realmManager.dispose();
  }
}

void main() {
  setUpAll(() => NetworkType.setNetworkType(NetworkType.regtest));

  test('같은 키의 핫월렛이 반영 전 주소를 빈 주소로 보고 구독을 끊어도 보기 전용 지갑은 그 주소에서 나간 돈을 본다', () async {
    final pair = _Pair();
    addTearDown(pair.dispose);
    await pair.setUp();
    final change = pair.addresses.getChangeAddress(pair.hotId).address;

    // 보기 전용 지갑의 큐는 잠시 다른 동기화로 바쁘다.
    final busy = pair.subscriptions.runExclusive(
      pair.watchId,
      () => Future<void>.delayed(const Duration(milliseconds: 1800)),
    );
    // 0초: 핫월렛이 받는 주소 #1을 자기 다음 받는 주소로 보낸다(새 주소라 처리할 때 감시 창을 넓힌다).
    final s0 = _tx(
      [(pair.fundedBy(pair.base.getAddress(1)), 0)],
      [(99000, pair.addresses.getReceiveAddress(pair.hotId).address)],
    );
    pair.electrum.put(s0, 0);
    pair.notify(s0);
    // 0.5초: 받는 주소 #0을 외부 주소와 거스름 주소로 보낸다. 서버는 알림부터 보내고 조회에는 아직 반영하지 않는다.
    await Future<void>.delayed(const Duration(milliseconds: 500));
    final s1 = _tx([(pair.fundedBy(pair.base.getAddress(0)), 0)], [(50000, pair.external), (549000, change)]);
    pair.electrum.put(s1, 0, hold: true);
    pair.notify(s1);
    // 1초: 핫월렛이 S0을 처리하며 일괄 동기화를 돌리고, 아직 반영 전인 거스름 주소를 빈 주소로 보고 구독을 끊는다.
    await Future<void>.delayed(const Duration(milliseconds: 800));
    pair.electrum.held.remove(s1.transactionHash);
    await busy;
    await pair.drain();

    // 핫월렛이 가진 돈을 모두 자기 다음 받는 주소로 모은다.
    final spent = {
      for (final tx in pair.electrum.txs.values)
        for (final input in tx.inputs) (input.transactionHash, input.index),
    };
    final unspent = [
      for (final address in pair.own)
        for (final (hash, index, value, _) in pair.electrum.outputsTo(address))
          if (!spent.contains((hash, index))) (hash, index, value),
    ];
    final total = unspent.fold<int>(0, (sum, u) => sum + u.$3);
    final s2 = _tx(
      [for (final u in unspent) (u.$1, u.$2)],
      [(total - 1000, pair.addresses.getReceiveAddress(pair.hotId).address)],
    );
    pair.electrum.put(s2, 0);
    pair.notify(s2);
    await pair.drain();

    expect(pair.chain(), 647000);
    expect(pair.balance(pair.hotId), 647000);
    expect(pair.balance(pair.watchId), 647000);
    expect(pair.electrum.callbacks[change]?.keys, contains(pair.watchId), reason: '보기 전용 지갑의 구독이 남아 있어야 한다');
  });

  test('같은 키의 지갑 하나를 지워도 남은 지갑은 공유 주소의 거래를 계속 받는다', () async {
    final pair = _Pair();
    addTearDown(pair.dispose);
    await pair.setUp();

    // 지갑 삭제(WalletProvider._deleteWallet → NodeProvider.unsubscribeWallet)
    await pair.subscriptions.unsubscribeWallet(await pair.copy(pair.hotId));
    await pair.wallets.deleteWallet(pair.hotId);

    // 같은 시드로 돈이 다른 곳으로 나가고 거스름이 돌아온다.
    final move = _tx(
      [(pair.fundedBy(pair.base.getAddress(0)), 0), (pair.fundedBy(pair.base.getAddress(1)), 0)],
      [(650000, pair.external), (49000, pair.base.getAddress(0, isChange: true))],
    );
    pair.electrum.put(move, 0);
    pair.notify(move);
    await pair.drain();

    expect(pair.chain(), 49000);
    expect(pair.balance(pair.watchId), 49000);
  });
}
