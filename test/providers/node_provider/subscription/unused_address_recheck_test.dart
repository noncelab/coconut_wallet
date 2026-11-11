import 'dart:isolate';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/constants/shared_pref_keys.dart';
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
import 'package:coconut_wallet/repository/realm/model/coconut_wallet_model.dart'
    show RealmWalletAddress, RealmWalletBalance, RealmWalletBase;
import 'package:coconut_wallet/repository/realm/subscription_repository.dart';
import 'package:coconut_wallet/repository/realm/transaction_draft_repository.dart';
import 'package:coconut_wallet/repository/realm/transaction_repository.dart';
import 'package:coconut_wallet/repository/realm/utxo_repository.dart';
import 'package:coconut_wallet/repository/realm/wallet_repository.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:coconut_wallet/services/electrum_service.dart';
import 'package:coconut_wallet/services/model/response/block_timestamp.dart';
import 'package:coconut_wallet/services/model/response/electrum_response_types.dart';
import 'package:coconut_wallet/utils/electrum_utils.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../mock/wallet_mock.dart';
import '../../../repository/realm/test_realm_manager.dart';

/// 공개 regtest 테스트 키(test/mock/wallet_mock.dart와 같은 값)
const _descriptor =
    "wpkh([D45AA182/84'/1'/0']vpub5YtEovN9MqeUZxWqdpUKngsiaLCPFY34KpWGQVk9Tjq8G5SYcRFj9s5aCKeAQYGunG7LrFkA5obtH8kPJiv92JtWHfRvnir6PDvhd4p93Pp/<0;1>/*)#rcn2hj6y";

/// 작은 일렉트럼 서버. 구독 콜백은 SocketManager처럼 스크립트 해시 → 지갑 id 맵으로 두고, 조회 횟수를 센다.
class _FakeElectrum extends Fake implements ElectrumService {
  final txs = <String, Transaction>{};
  final heights = <String, int>{};
  final callbacks = <String, Map<int, Function(String, String?)>>{};

  /// 거래 없이 잔액만 정해 둔 주소(RPC 횟수 테스트용)
  final fixedBalances = <String, int>{};
  int balanceCalls = 0;
  int historyCalls = 0;

  void put(Transaction tx, int height) {
    txs[tx.transactionHash] = tx;
    heights[tx.transactionHash] = height;
  }

  Iterable<(Transaction, int)> get _all => txs.values.map((tx) => (tx, heights[tx.transactionHash]!));

  bool _spent(String hash, int index) =>
      _all.any((e) => e.$1.inputs.any((i) => i.transactionHash == hash && i.index == index));

  List<(String, int, int, int)> _outputsTo(String address) => [
    for (final (tx, height) in _all)
      for (var i = 0; i < tx.outputs.length; i++)
        if (tx.outputs[i].getAddress() == address) (tx.transactionHash, i, tx.outputs[i].amount, height),
  ];

  List<GetTxHistoryRes> _history(String address) {
    final own = _outputsTo(address).map((o) => (o.$1, o.$2)).toSet();
    return [
      for (final (tx, height) in _all)
        if (tx.outputs.any((o) => o.getAddress() == address) ||
            tx.inputs.any((i) => own.contains((i.transactionHash, i.index))))
          GetTxHistoryRes(height: height, txHash: tx.transactionHash),
    ]..sort((a, b) => a.height.compareTo(b.height));
  }

  String? _status(String address) {
    final history = _history(address);
    return history.isEmpty ? null : Hash.sha256(history.map((h) => '${h.txHash}:${h.height}:').join()).toString();
  }

  int balanceOf(String address) =>
      fixedBalances[address] ?? _outputsTo(address).where((o) => !_spent(o.$1, o.$2)).fold(0, (sum, o) => sum + o.$3);

  void notify(String address) {
    final script = ElectrumUtil.addressToReversedScriptHash(AddressType.p2wpkh, address);
    for (final callback in [...?callbacks[address]?.values]) {
      callback(script, _status(address));
    }
  }

  bool isListening(String address, int walletId) => callbacks[address]?.containsKey(walletId) ?? false;

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

  @override
  Future<bool> unsubscribeScript(AddressType addressType, String address) async {
    callbacks.remove(address);
    return true;
  }

  @override
  Future<GetBalanceRes> getBalance(AddressType addressType, String address) async {
    balanceCalls++;
    await Future<void>.delayed(const Duration(milliseconds: 1));
    final unconfirmed = [
      for (final o in _outputsTo(address))
        if (o.$4 <= 0 && !_spent(o.$1, o.$2)) o.$3,
    ].fold(0, (sum, value) => sum + value);
    return GetBalanceRes(confirmed: balanceOf(address) - unconfirmed, unconfirmed: unconfirmed);
  }

  @override
  Future<List<GetTxHistoryRes>> getHistory(AddressType addressType, String address) async {
    historyCalls++;
    await Future<void>.delayed(const Duration(milliseconds: 1));
    return _history(address);
  }

  @override
  Future<List<ListUnspentRes>> getUnspentList(AddressType addressType, String address) async {
    await Future<void>.delayed(const Duration(milliseconds: 1));
    return [
      for (final (hash, index, value, height) in _outputsTo(address))
        if (!_spent(hash, index)) ListUnspentRes(height: height, txHash: hash, txPos: index, value: value),
    ];
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

/// 지갑 하나와 동기화 서비스. [launch]는 앱 실행(새 isolate)처럼 서비스와 지갑 항목을 새로 만들어 구독한다.
class _App {
  final electrum = _FakeElectrum();
  final port = ReceivePort();
  final realmManager = TestRealmManager();
  late final addresses = AddressRepository(realmManager);
  late final wallets = WalletRepository(realmManager, TransactionDraftRepository(realmManager));
  late final utxos = UtxoRepository(realmManager);
  late final transactions = TransactionRepository(realmManager);
  late IsolateStateManager state;
  late SubscriptionService subscriptions;
  final base = SingleSignatureWallet.fromDescriptor(_descriptor);
  final external = WalletMock.createMultiSigWalletItem().walletBase.getAddress(0);
  late int walletId;
  var _funding = 0;

  Future<void> setUp() async {
    SharedPreferences.setMockInitialValues({SharedPrefKeys.kNextIdField: 1});
    await SharedPrefsRepository().init();
    final wallet = await wallets.addSinglesigWallet(
      WatchOnlyWallet('지갑', 0, 0, _descriptor, null, null, 'coconutVault'),
    );
    walletId = wallet.id;
    await addresses.ensureAddressesInit(walletItemBase: wallet);
  }

  Future<WalletItemBase> copy() async => (await wallets.getWalletItemList()).firstWhere((w) => w.id == walletId);

  Future<void> launch() async {
    electrum.callbacks.clear();
    state = IsolateStateManager(port.sendPort);
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
    state.initWalletUpdateStatus(walletId);
    await subscriptions.subscribeWallet(await copy());
    await drain();
  }

  /// 앱 복귀·홈 새로고침·지갑 상세 새로고침이 부르는 휴면 재확인
  Future<void> recheck() async {
    await subscriptions.syncDormantAddresses(await copy());
    await drain();
  }

  Future<void> drain() async {
    for (var i = 0; i < 4; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 1100)); // 실시간 이벤트의 1초 인덱싱 대기
      await subscriptions.runExclusive(walletId, () async {});
    }
  }

  /// 외부에서 [address]로 [amount] 입금(확정)
  void pay(String address, int amount) {
    final funding = _tx([('${++_funding}'.padLeft(64, 'f'), 0)], [(amount + 10000, external)]);
    put(funding, 100);
    put(_tx([(funding.transactionHash, 0)], [(amount, address), (9000, external)]), 100 + _funding);
    electrum.notify(address);
  }

  void put(Transaction tx, int height) => electrum.put(tx, height);

  int get chain => [
    for (final isChange in [false, true])
      for (var i = 0; i < 30; i++) electrum.balanceOf(base.getAddress(i, isChange: isChange)),
  ].fold(0, (sum, value) => sum + value);

  int get balance => wallets.getWalletBalance(walletId)!.total;

  void dispose() {
    port.close();
    realmManager.dispose();
  }
}

void main() {
  setUpAll(() => NetworkType.setNetworkType(NetworkType.regtest));

  test('앱을 다시 켠 뒤 사용 인덱스 앞의 빈 주소에 들어온 돈을 휴면 재확인에서 찾는다', () async {
    final app = _App();
    addTearDown(app.dispose);
    await app.setUp();
    final r = [for (var i = 0; i < 4; i++) app.base.getAddress(i)];
    app.pay(r[0], 300000);
    app.pay(r[1], 200000);
    await app.launch();
    expect(app.balance, 500000);

    // 받는 주소 #2를 누군가에게 알려 줬는데 아직 안 들어온 사이, #3에 먼저 입금돼 사용 인덱스가 #2를 지나간다.
    app.pay(r[3], 150000);
    await app.drain();
    expect(app.balance, 650000);

    // 앱을 다시 켜면 잔액이 남은 사용 주소와 사용 인덱스 뒤 gap만 구독한다. 빈 #2는 듣지 않는다.
    await app.launch();
    expect(app.electrum.isListening(r[2], app.walletId), isFalse);

    // 그 뒤 #2에 입금. 아무도 듣지 않으니 실시간으로는 모른다.
    app.pay(r[2], 120000);
    await app.drain();
    expect(app.balance, 650000);

    await app.recheck();
    expect(app.balance, app.chain, reason: '앱 복귀·새로고침의 휴면 재확인이 #2의 돈을 찾아야 함');
    expect(app.balance, 770000);
    expect(
      app.realmManager.realm
          .query<RealmWalletAddress>(r'walletId == $0 AND isChange == false AND index == 2', [app.walletId])
          .single
          .isUsed,
      isTrue,
      reason: '찾은 주소는 사용됨으로 표시해야 다음 실행부터 구독됨',
    );
    expect(app.electrum.isListening(r[2], app.walletId), isTrue, reason: '찾은 주소는 실시간 구독에 다시 넣음');

    // 다음 실행부터는 잔액이 남은 사용 주소로 구독된다.
    await app.launch();
    expect(app.balance, 770000);
    expect(app.electrum.isListening(r[2], app.walletId), isTrue);
  }, timeout: const Timeout(Duration(seconds: 60)));

  group('주소 1,000개 지갑의 휴면 재확인 조회 수', () {
    /// 받는 주소 0~999를 모두 만든 뒤 [holes]는 미사용, 100개마다 하나는 잔액이 남은 사용 주소, 나머지는 빈 사용 주소로 둔다.
    Future<({int balanceCalls, int historyCalls, int dormantUsed})> run({required Set<int> holes}) async {
      final app = _App();
      addTearDown(app.dispose);
      await app.setUp();
      final wallet = await app.copy();
      await app.addresses.ensureAddressesExist(walletItemBase: wallet, cursor: 0, count: 1000, isChange: false);
      final realm = app.realmManager.realm;
      final rows = realm.query<RealmWalletAddress>(r'walletId == $0 AND isChange == false', [app.walletId]);
      var total = 0;
      realm.write(() {
        for (final row in rows) {
          final funded = row.index % 100 == 0;
          row.isUsed = !holes.contains(row.index);
          row.confirmed = funded ? 10000 : 0;
          row.total = row.confirmed;
          total += row.confirmed;
          app.electrum.fixedBalances[row.address] = row.confirmed;
        }
        realm.find<RealmWalletBase>(app.walletId)!.usedReceiveIndex = 999;
      });
      app.wallets.getWalletBalance(app.walletId);
      realm.write(() {
        final balance = realm.query<RealmWalletBalance>(r'walletId == $0', [app.walletId]).single;
        balance.confirmed = total;
        balance.total = total;
      });
      await app.launch();
      app.electrum.balanceCalls = 0;
      app.electrum.historyCalls = 0;
      await app.recheck();
      expect(app.balance, total, reason: '서버와 같은 상태에서는 잔액이 그대로');
      return (
        balanceCalls: app.electrum.balanceCalls,
        historyCalls: app.electrum.historyCalls,
        dormantUsed: app.addresses.getDormantUsedAddresses(app.walletId).length,
      );
    }

    test('구멍이 없으면 빈 사용 주소만 한 번씩 조회한다', () async {
      final result = await run(holes: {});
      // ignore: avoid_print
      print('RPC 1000 addresses, no holes: get_balance ${result.balanceCalls}, get_history ${result.historyCalls}');
      expect(result.dormantUsed, 990);
      expect(result.balanceCalls, 990);
      expect(result.historyCalls, 0);
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('구멍 10개는 get_balance 10번만 더하고, 빈 구멍은 구독·내역 조회를 하지 않는다', () async {
      final holes = {for (var i = 1; i <= 10; i++) i * 37};
      final result = await run(holes: holes);
      // ignore: avoid_print
      print('RPC 1000 addresses, 10 holes: get_balance ${result.balanceCalls}, get_history ${result.historyCalls}');
      expect(result.dormantUsed, 980);
      expect(result.balanceCalls, 990);
      expect(result.historyCalls, 0);
    }, timeout: const Timeout(Duration(seconds: 60)));
  });
}
