import 'dart:convert';
import 'dart:isolate';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/constants/shared_pref_keys.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/model/node/script_status.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/wallet/transaction_address.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/model/wallet/watch_only_wallet.dart';
import 'package:coconut_wallet/providers/node_provider/balance_sync_service.dart';
import 'package:coconut_wallet/providers/node_provider/isolate/isolate_enum.dart';
import 'package:coconut_wallet/providers/node_provider/resync/wallet_resync_service.dart';
import 'package:coconut_wallet/providers/node_provider/state/isolate_state_manager.dart';
import 'package:coconut_wallet/providers/node_provider/subscription/script_callback_service.dart';
import 'package:coconut_wallet/providers/node_provider/subscription/script_sync_service.dart';
import 'package:coconut_wallet/providers/node_provider/subscription/subscription_service.dart';
import 'package:coconut_wallet/providers/node_provider/transaction/transaction_record_service.dart';
import 'package:coconut_wallet/providers/node_provider/transaction/transaction_sync_service.dart';
import 'package:coconut_wallet/providers/node_provider/utxo_sync_service.dart';
import 'package:coconut_wallet/repository/realm/address_repository.dart';
import 'package:coconut_wallet/repository/realm/model/coconut_wallet_model.dart'
    show RealmTransaction, RealmWalletAddress, RealmWalletBalance, RealmWalletBase;
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

  /// 거래 없이 이력만 정해 둔 주소(RPC 횟수 테스트용). 지갑 기록에도 같은 거래를 넣어 둔다
  final fixedHistories = <String, List<GetTxHistoryRes>>{};

  /// get_history를 실패시킬 주소
  final failedHistories = <String>{};

  /// get_balance를 실패시킬 주소
  final failedBalances = <String>{};

  /// 구독 요청을 실패시킬 주소
  final failedSubscribes = <String>{};

  /// 받은 요청(종류, 주소나 거래 해시)
  final requests = <(String, String)>[];

  Map<String, int> get counts => {
    for (final (kind, _) in requests) kind: requests.where((request) => request.$1 == kind).length,
  };

  List<String> requestsFor(String target) => [
    for (final (kind, value) in requests)
      if (value == target) kind,
  ];

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
    requests.add(('subscribe', address));
    if (failedSubscribes.contains(address)) throw StateError('injected subscribe failure');
    (callbacks[address] ??= {})[walletId] = onUpdate;
    await Future<void>.delayed(const Duration(milliseconds: 1));
    return _status(address);
  }

  @override
  Future<bool> unsubscribeScriptForWallet(AddressType addressType, String address, {required int walletId}) async {
    requests.add(('unsubscribe', address));
    callbacks[address]?.remove(walletId);
    if (callbacks[address]?.isEmpty ?? false) callbacks.remove(address);
    return true;
  }

  @override
  Future<bool> unsubscribeScript(AddressType addressType, String address) async {
    requests.add(('unsubscribe', address));
    callbacks.remove(address);
    return true;
  }

  @override
  Future<GetBalanceRes> getBalance(AddressType addressType, String address) async {
    requests.add(('get_balance', address));
    await Future<void>.delayed(const Duration(milliseconds: 1));
    if (failedBalances.contains(address)) throw StateError('injected get_balance failure');
    final unconfirmed = [
      for (final o in _outputsTo(address))
        if (o.$4 <= 0 && !_spent(o.$1, o.$2)) o.$3,
    ].fold(0, (sum, value) => sum + value);
    return GetBalanceRes(confirmed: balanceOf(address) - unconfirmed, unconfirmed: unconfirmed);
  }

  @override
  Future<List<GetTxHistoryRes>> getHistory(AddressType addressType, String address) async {
    requests.add(('get_history', address));
    await Future<void>.delayed(const Duration(milliseconds: 1));
    if (failedHistories.contains(address)) throw StateError('injected get_history failure');
    return fixedHistories[address] ?? _history(address);
  }

  @override
  Future<List<ListUnspentRes>> getUnspentList(AddressType addressType, String address) async {
    requests.add(('listunspent', address));
    await Future<void>.delayed(const Duration(milliseconds: 1));
    return [
      for (final (hash, index, value, height) in _outputsTo(address))
        if (!_spent(hash, index)) ListUnspentRes(height: height, txHash: hash, txPos: index, value: value),
    ];
  }

  @override
  Future<String> getTransaction(String txHash, {bool? verbose, Duration timeout = const Duration(seconds: 5)}) async {
    requests.add(('get_transaction', txHash));
    return txs[txHash]!.serialize();
  }

  @override
  Future<List<Transaction>> getPreviousTransactions(
    Transaction transaction, {
    List<Transaction>? existingTxList,
  }) async {
    final existing = {for (final tx in existingTxList ?? const <Transaction>[]) tx.transactionHash};
    for (final hash in {for (final input in transaction.inputs) input.transactionHash}.difference(existing)) {
      requests.add(('get_transaction', hash));
    }
    return [
      for (final input in transaction.inputs)
        if (txs[input.transactionHash] case final previous?) previous,
    ];
  }

  @override
  Future<Map<int, BlockTimestamp>> fetchBlocksByHeight(Set<int> heights) async {
    requests.addAll([for (final height in heights) ('block_header', '$height')]);
    return {
      for (final height in heights) height: BlockTimestamp(height, DateTime.utc(2026).add(Duration(hours: height))),
    };
  }

  @override
  Future<BlockTimestamp> getBlockTimestamp(int height) async {
    requests.add(('block_header', '$height'));
    return BlockTimestamp(height, DateTime.utc(2026).add(Duration(hours: height)));
  }

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
  late ScriptSyncService scripts;
  late ScriptCallbackService callbacks;
  late BalanceSyncService balances;
  final base = SingleSignatureWallet.fromDescriptor(_descriptor);
  final external = WalletMock.createMultiSigWalletItem().walletBase.getAddress(0);
  late int walletId;
  var _funding = 0;

  /// 지갑 동기화 큐가 끝날 때마다 알린 잔액. null이면 화면에 동기화 실패로 보인다
  final queueEnds = <int?>[];

  Future<void> setUp() async {
    port.listen((message) {
      if (message case [_, [IsolateStateMethod.setWalletSyncQueueState, _, false, final int? balance]]) {
        queueEnds.add(balance);
      }
    });
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
    callbacks = ScriptCallbackService();
    scripts = ScriptSyncService(
      state,
      balances = BalanceSyncService(electrum, state, addresses, wallets),
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
    subscriptions = SubscriptionService(electrum, state, addresses, SubscriptionRepository(realmManager), scripts);
    state.initWalletUpdateStatus(walletId);
    await subscriptions.subscribeWallet(await copy());
    await drain();
  }

  Future<void> resync({bool succeeds = true}) async {
    final result = await WalletResyncService(
      wallets,
      utxos,
      addresses,
      subscriptions,
      state,
      callbacks,
    ).resyncWallet(await copy());
    await drain();
    expect(result.isSuccess, succeeds);
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

  /// 외부에서 [address]로 [amount] 입금(확정). 입금 거래를 돌려준다
  Transaction pay(String address, int amount) {
    final funding = _tx([('${++_funding}'.padLeft(64, 'f'), 0)], [(amount + 10000, external)]);
    put(funding, 100);
    final payment = _tx([(funding.transactionHash, 0)], [(amount, address), (9000, external)]);
    put(payment, 100 + _funding);
    electrum.notify(address);
    return payment;
  }

  /// [address]의 코인을 모두 외부로 보냄(확정). 같은 시드의 다른 기기에서 쓴 것과 같다
  Transaction spendAll(String address) => send(address, external, 0);

  /// [from]의 코인을 모두 써서 [to]에 [amount]를 보내고 나머지는 외부로 보냄(확정)
  Transaction send(String from, String to, int amount) {
    final coins = [
      for (final coin in electrum._outputsTo(from))
        if (!electrum._spent(coin.$1, coin.$2)) coin,
    ];
    final total = coins.fold(0, (sum, coin) => sum + coin.$3);
    final tx = _tx(
      [for (final coin in coins) (coin.$1, coin.$2)],
      [if (amount > 0) (amount, to), (total - amount - 1000, external)],
    );
    put(tx, 150 + ++_funding);
    electrum.notify(from);
    if (to != external) electrum.notify(to);
    return tx;
  }

  void put(Transaction tx, int height) => electrum.put(tx, height);

  /// [transactions] 중 지갑 내역에 있는 거래 수
  int recorded(Iterable<Transaction> txs) =>
      transactions.getRealmTransactionListByHashes(walletId, {for (final tx in txs) tx.transactionHash}).length;

  /// 주소 목록 화면이 [cursor] 다음 번호부터 [count]개를 불러와 확인한다.
  Future<void> view(int cursor, int count) async {
    await subscriptions.syncViewedAddresses(
      await copy(),
      await addresses.getWalletAddressList(await copy(), cursor, count, false, false),
    );
    await drain();
  }

  /// 이 주소에 남은 동기화·확인 실패 표시가 있는지
  bool failed(String address) => scripts.hasSyncFailure(walletId, address);

  /// 저장된 주소 잔액을 바꾼다(다른 경로로는 만들기 어려운 상태를 만들 때만)
  void setStoredBalance(String address, int amount) {
    final realm = realmManager.realm;
    final row = realm.query<RealmWalletAddress>(r'walletId == $0 AND address == $1', [walletId, address]).single;
    realm.write(() {
      row.confirmed = amount;
      row.total = amount;
    });
  }

  bool isUsed(String address) =>
      realmManager.realm
          .query<RealmWalletAddress>(r'walletId == $0 AND address == $1', [walletId, address])
          .single
          .isUsed;

  int get chain => [
    for (final isChange in [false, true])
      for (var i = 0; i < 60; i++) electrum.balanceOf(base.getAddress(i, isChange: isChange)),
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

  /// 구멍 #2만 비워 두고 #0·#3에 입금한 뒤 두 번 켠다(두 번째 실행부터 #2는 듣지 않는다)
  Future<(_App, List<String>)> holeApp() async {
    final app = _App();
    addTearDown(app.dispose);
    await app.setUp();
    final r = [for (var i = 0; i < 4; i++) app.base.getAddress(i)];
    app.pay(r[0], 300000);
    app.pay(r[3], 150000);
    await app.launch();
    await app.launch();
    expect(app.electrum.isListening(r[2], app.walletId), isFalse);
    return (app, r);
  }

  /// #0·#1에 입금하고 켠 뒤 #1을 모두 써서 빈 사용 주소로 만들고 다시 켠다
  Future<(_App, List<String>)> emptiedApp() async {
    final app = _App();
    addTearDown(app.dispose);
    await app.setUp();
    final r = [for (var i = 0; i < 2; i++) app.base.getAddress(i)];
    app.pay(r[0], 300000);
    app.pay(r[1], 200000);
    await app.launch();
    app.spendAll(r[1]);
    await app.drain();
    await app.launch();
    expect(app.isUsed(r[1]), isTrue);
    expect(app.electrum.isListening(r[1], app.walletId), isFalse, reason: '잔액이 0이 된 사용 주소는 구독하지 않음');
    return (app, r);
  }

  test('받고 다 쓴 구멍의 거래도 휴면 재확인에서 찾는다', () async {
    final (app, r) = await holeApp();

    // 앱이 듣지 않는 사이 구멍 #2에 들어온 돈을 같은 시드를 쓰는 다른 기기가 모두 썼다. 잔액은 0이다.
    final received = app.pay(r[2], 120000);
    final spent = app.spendAll(r[2]);
    await app.drain();
    expect(app.electrum.balanceOf(r[2]), 0);
    expect(app.recorded([received, spent]), 0);

    app.electrum.requests.clear();
    await app.recheck();
    // ignore: avoid_print
    print('RPC spent hole found: ${app.electrum.counts}');
    expect(app.recorded([received, spent]), 2, reason: '서버 이력 2건이 지갑 내역에도 있어야 함');
    expect(app.isUsed(r[2]), isTrue);
    expect(app.balance, app.chain);
    expect(app.electrum.isListening(r[2], app.walletId), isFalse, reason: '잔액도 미확정 거래도 없으니 구독에 남기지 않음');

    await app.launch();
    await app.recheck();
    expect(app.recorded([received, spent]), 2);
    expect(app.balance, app.chain);
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('빈 사용 주소에 다시 들어왔다가 모두 나간 거래도 찾는다', () async {
    final (app, r) = await emptiedApp();

    // 그 주소를 다시 알려 줘서 돈이 들어왔고, 다른 기기가 바로 모두 썼다.
    final again = app.pay(r[1], 50000);
    final out = app.spendAll(r[1]);
    await app.drain();
    expect(app.recorded([again, out]), 0);

    await app.recheck();
    expect(app.recorded([again, out]), 2);
    expect(app.balance, app.chain);
    expect(app.electrum.isListening(r[1], app.walletId), isFalse);
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('다른 내 주소의 거래로 먼저 기록된 입금도 빈 사용 주소에서 찾는다', () async {
    final (app, r) = await emptiedApp();

    // #0의 코인으로 빈 사용 주소 #1에 70,000을 보냈다. 거래는 #0 알림으로 기록되지만, #1은 듣지 않아 그 돈은 아직 안 센다.
    final self = app.send(r[0], r[1], 70000);
    await app.drain();
    expect(app.recorded([self]), 1);
    expect(app.balance, app.chain - 70000);

    await app.recheck();
    expect(app.balance, app.chain);
    expect(app.electrum.isListening(r[1], app.walletId), isTrue, reason: '잔액이 남았으니 구독');
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('다른 내 주소의 거래로만 기록된 구멍도 사용됨으로 표시한다', () async {
    final (app, r) = await holeApp();

    // 한 거래가 #0과 구멍 #2에 함께 보냈고, 다른 거래가 그 두 코인을 함께 썼다. 둘 다 #0 알림으로 기록된다.
    final both = _tx([('99'.padLeft(64, 'e'), 0)], [(40000, r[2]), (60000, r[0])]);
    app.put(both, 160);
    app.electrum.notify(r[0]);
    await app.drain();
    final spend = _tx([(both.transactionHash, 0), (both.transactionHash, 1)], [(99000, app.external)]);
    app.put(spend, 161);
    app.electrum.notify(r[0]);
    await app.drain();
    expect(app.recorded([both, spend]), 2);
    expect(app.isUsed(r[2]), isFalse);

    await app.recheck();
    expect(app.isUsed(r[2]), isTrue, reason: '이력이 있는 주소는 사용된 주소');
    expect(app.balance, app.chain);
    expect(app.electrum.isListening(r[2], app.walletId), isFalse);
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('빈 구멍은 이력만 한 번 조회하고 사용 표시·구독·동기화를 하지 않는다', () async {
    final app = _App();
    addTearDown(app.dispose);
    await app.setUp();
    final r = [for (var i = 0; i < 6; i++) app.base.getAddress(i)];
    app.pay(r[0], 300000);
    app.pay(r[5], 100000);
    await app.launch();
    await app.launch();

    app.electrum.requests.clear();
    await app.recheck();
    for (final hole in r.sublist(1, 5)) {
      expect(app.electrum.requestsFor(hole), ['get_history']);
      expect(app.isUsed(hole), isFalse);
      expect(app.electrum.isListening(hole, app.walletId), isFalse);
    }
    expect(app.balance, app.chain);
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('이력 조회가 실패한 주소는 사용 표시하지 않고 동기화 실패로 알린 뒤, 다음 재확인에서 찾는다', () async {
    final (app, r) = await holeApp();
    final received = app.pay(r[2], 120000);
    final spent = app.spendAll(r[2]);
    await app.drain();

    app.electrum.failedHistories.add(r[2]);
    await app.recheck();
    expect(app.isUsed(r[2]), isFalse);
    expect(app.recorded([received, spent]), 0);
    expect(app.queueEnds.last, isNull, reason: '조회 실패는 동기화 실패로 보여야 함');

    // 30초가 지난 재확인이나 다음 실행에서 다시 조회한다.
    app.electrum.failedHistories.clear();
    await app.launch();
    await app.recheck();
    expect(app.recorded([received, spent]), 2);
    expect(app.isUsed(r[2]), isTrue);
    expect(app.balance, app.chain);
    expect(app.queueEnds.last, app.balance);
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('입력 없이 기록된 옛 출금이 있어도 실행할 때마다 다시 동기화하지 않는다', () async {
    final app = _App();
    addTearDown(app.dispose);
    await app.setUp();
    final r = [for (var i = 0; i <= 3; i++) app.base.getAddress(i)];
    app.pay(r[0], 300000);
    for (var i = 1; i <= 3; i++) {
      app.pay(r[i], 100000);
    }
    await app.launch();

    // #1~#3의 코인을 한 거래로 합쳐 외부로 보냈다. 거래는 세 주소의 알림으로 기록된다.
    final merge = _tx(
      [
        for (var i = 1; i <= 3; i++)
          for (final coin in app.electrum._outputsTo(r[i])) (coin.$1, coin.$2),
      ],
      [(299000, app.external)],
    );
    app.put(merge, 170);
    for (var i = 1; i <= 3; i++) {
      app.electrum.notify(r[i]);
    }
    await app.drain();
    expect(app.recorded([merge]), 1);

    // 이전 거래를 받지 못하면 입력 없이 기록한다(v1.0.x 기록, 지금도 이전 거래가 빠지면 이렇게 남긴다).
    final realm = app.realmManager.realm;
    realm.write(() {
      realm
          .query<RealmTransaction>(r'walletId == $0 AND transactionHash == $1', [app.walletId, merge.transactionHash])
          .single
          .inputAddressList
          .clear();
    });

    for (var launch = 0; launch < 2; launch++) {
      await app.launch();
      app.electrum.requests.clear();
      await app.recheck();
      expect(app.electrum.counts, {
        'get_history': 3,
        'get_balance': 3,
      }, reason: '기록으로 잔액을 셀 수 없는 주소는 서버 잔액만 한 번 더 묻고, 같으면 다시 동기화하지 않음');
      expect(app.balance, app.chain);
    }
  }, timeout: const Timeout(Duration(seconds: 90)));

  test('입력 없이 기록된 옛 출금이 있는 빈 사용 주소도 내 다른 주소에서 보낸 돈을 찾는다', () async {
    final (app, r) = await emptiedApp();
    // #1을 비운 옛 출금을 입력 없이 기록된 모양으로 만든다.
    final oldSpend = app.electrum._all
        .map((item) => item.$1)
        .firstWhere(
          (tx) => tx.inputs.any(
            (input) => app.electrum
                ._outputsTo(r[1])
                .any((output) => output.$1 == input.transactionHash && output.$2 == input.index),
          ),
        );
    final realm = app.realmManager.realm;
    final row =
        realm.query<RealmTransaction>(r'walletId == $0 AND transactionHash == $1', [
          app.walletId,
          oldSpend.transactionHash,
        ]).single;
    expect(row.inputAddressList, isNotEmpty);
    realm.write(() => row.inputAddressList.clear());

    // #0에서 #1로 70,000을 보냈다. 거래는 #0 알림으로 기록되지만 #1은 듣지 않는다.
    final self = app.send(r[0], r[1], 70000);
    await app.drain();
    expect(app.recorded([self]), 1);
    expect(app.balance, app.chain - 70000);

    app.electrum.requests.clear();
    await app.recheck();
    expect(app.electrum.requestsFor(r[1]), containsAll(['get_history', 'get_balance']));
    expect(app.balance, app.chain);
    expect(app.electrum.isListening(r[1], app.walletId), isTrue);
    expect(app.queueEnds.last, app.balance);
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('입력 없이 기록된 주소의 추가 잔액 조회가 실패하면 실패로 남고, 다음 재확인에서 맞춘 뒤로는 다시 묻지 않는다', () async {
    final (app, r) = await emptiedApp();
    final oldSpend = app.electrum._all
        .map((item) => item.$1)
        .firstWhere(
          (tx) => tx.inputs.any(
            (input) => app.electrum
                ._outputsTo(r[1])
                .any((output) => output.$1 == input.transactionHash && output.$2 == input.index),
          ),
        );
    final realm = app.realmManager.realm;
    final row =
        realm.query<RealmTransaction>(r'walletId == $0 AND transactionHash == $1', [
          app.walletId,
          oldSpend.transactionHash,
        ]).single;
    realm.write(() => row.inputAddressList.clear());
    final self = app.send(r[0], r[1], 70000);
    await app.drain();
    expect(app.recorded([self]), 1);

    // 기록으로 잔액을 셀 수 없는 #1의 추가 잔액 조회가 실패했다.
    app.electrum.failedBalances.add(r[1]);
    app.electrum.requests.clear();
    await app.recheck();
    expect(app.electrum.requestsFor(r[1]), ['get_history', 'get_balance']);
    expect(app.queueEnds.last, isNull, reason: '잔액 조회 실패는 실패로 남아야 함');
    expect(app.balance, app.chain - 70000);

    // 30초가 지난 다음 재확인에서 다시 묻고 맞춘다.
    app.electrum.failedBalances.clear();
    await Future<void>.delayed(const Duration(seconds: 31));
    await app.recheck();
    expect(app.balance, app.chain);
    expect(app.queueEnds.last, app.balance);

    // 그다음 재확인: 잔액이 생겨 쉬는 주소가 아니므로 #1에는 더 묻지 않는다.
    await Future<void>.delayed(const Duration(seconds: 31));
    app.electrum.requests.clear();
    await app.recheck();
    expect(app.electrum.requestsFor(r[1]), isEmpty);
  }, timeout: const Timeout(Duration(seconds: 150)));

  test('주소 목록에서 본 gap 밖 주소도 받고 다 쓴 거래를 찾는다', () async {
    final app = _App();
    addTearDown(app.dispose);
    await app.setUp();
    await app.addresses.ensureAddressesExist(walletItemBase: await app.copy(), cursor: 0, count: 60, isChange: false);
    final r = [for (var i = 0; i < 50; i++) app.base.getAddress(i)];
    app.pay(r[0], 300000);
    await app.launch();
    await app.launch();

    // gap 밖 #40에 들어온 돈을 다른 기기가 모두 썼고, #41에는 돈이 남았다. 앱은 둘 다 듣지 않는다.
    final received = app.pay(r[40], 70000);
    final spent = app.spendAll(r[40]);
    final kept = app.pay(r[41], 60000);
    await app.drain();

    app.electrum.requests.clear();
    // 주소 목록은 마지막으로 불러온 번호 다음부터 보여 준다(#40~#42).
    final viewed = await app.addresses.getWalletAddressList(await app.copy(), 39, 3, false, false);
    final discovered = await app.subscriptions.syncViewedAddresses(await app.copy(), viewed);
    await app.drain();
    expect(discovered.value.map((address) => address.index), [40, 41]);
    expect(app.isUsed(r[40]), isTrue);
    expect(app.recorded([received, spent]), 2);
    expect(app.electrum.isListening(r[40], app.walletId), isFalse, reason: '잔액도 미확정 거래도 없으니 구독에 남기지 않음');
    expect(app.recorded([kept]), 1);
    expect(app.electrum.isListening(r[41], app.walletId), isTrue);
    expect(app.isUsed(r[42]), isFalse);
    expect(app.electrum.requestsFor(r[42]), ['get_history'], reason: '빈 주소는 이력만 한 번');
    expect(app.balance, app.chain);
    expect(app.addresses.getUsedIndexes(app.walletId).$1, 0, reason: '주소 목록에서 찾은 주소는 사용 인덱스를 옮기지 않음');
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('주소 목록에서 본 주소의 이력 조회가 실패하면 사용 표시하지 않고 실패로 알린 뒤, 다시 볼 때 찾는다', () async {
    final app = _App();
    addTearDown(app.dispose);
    await app.setUp();
    await app.addresses.ensureAddressesExist(walletItemBase: await app.copy(), cursor: 0, count: 60, isChange: false);
    final r = [for (var i = 0; i < 50; i++) app.base.getAddress(i)];
    app.pay(r[0], 300000);
    await app.launch();
    await app.launch();
    final received = app.pay(r[40], 70000);
    final spent = app.spendAll(r[40]);
    await app.drain();

    app.electrum.failedHistories.add(r[40]);
    await app.subscriptions.syncViewedAddresses(
      await app.copy(),
      await app.addresses.getWalletAddressList(await app.copy(), 39, 3, false, false),
    );
    await app.drain();
    expect(app.isUsed(r[40]), isFalse);
    expect(app.recorded([received, spent]), 0);
    expect(app.queueEnds.last, isNull, reason: '조회 실패는 동기화 실패로 보여야 함');

    // 휴면 재확인은 이 주소를 다시 확인하지 않으므로 실패 표시를 지우지 않는다.
    await app.recheck();
    expect(app.queueEnds.last, isNull);

    // 1분이 지나 다시 보거나 다음 실행에서 보면 다시 묻는다.
    app.electrum.failedHistories.clear();
    await app.launch();
    await app.subscriptions.syncViewedAddresses(
      await app.copy(),
      await app.addresses.getWalletAddressList(await app.copy(), 39, 3, false, false),
    );
    await app.drain();
    expect(app.isUsed(r[40]), isTrue);
    expect(app.recorded([received, spent]), 2);
    expect(app.queueEnds.last, app.balance);
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('주소 목록에서 실패한 주소가 다른 경로로 사용 주소가 되면, 다시 볼 때 실패 표시가 지워진다', () async {
    final app = _App();
    addTearDown(app.dispose);
    await app.setUp();
    await app.addresses.ensureAddressesExist(walletItemBase: await app.copy(), cursor: 0, count: 60, isChange: false);
    final r = [for (var i = 0; i < 50; i++) app.base.getAddress(i)];
    app.pay(r[0], 300000);
    await app.launch();
    await app.launch();
    app.pay(r[40], 70000);
    app.spendAll(r[40]);
    await app.drain();

    app.electrum.failedHistories.add(r[40]);
    await app.subscriptions.syncViewedAddresses(
      await app.copy(),
      await app.addresses.getWalletAddressList(await app.copy(), 39, 3, false, false),
    );
    await app.drain();
    expect(app.queueEnds.last, isNull);

    // 그사이 다른 경로(예: 다시 연결할 때의 지갑 구독)로 #40이 사용 주소가 됐다. 잔액은 0이라 다시 볼 때는 잔액만 묻는다.
    app.electrum.failedHistories.clear();
    await app.addresses.setWalletAddressUsed(await app.copy(), 40, false);
    await Future<void>.delayed(const Duration(seconds: 61));
    app.electrum.requests.clear();
    await app.subscriptions.syncViewedAddresses(
      await app.copy(),
      await app.addresses.getWalletAddressList(await app.copy(), 39, 3, false, false),
    );
    await app.drain();
    expect(app.electrum.requestsFor(r[40]), ['get_balance']);
    expect(app.queueEnds.last, app.balance, reason: '다시 확인한 주소의 실패 표시는 지워져야 함');
  }, timeout: const Timeout(Duration(seconds: 150)));

  test('주소 목록에서 실패한 주소를 실시간 알림으로 맞추면 실패 표시가 지워진다', () async {
    final app = _App();
    addTearDown(app.dispose);
    await app.setUp();
    final r = [for (var i = 0; i < 8; i++) app.base.getAddress(i)];
    app.pay(r[0], 300000);
    await app.launch();
    await app.launch();
    expect(app.electrum.isListening(r[5], app.walletId), isTrue, reason: 'gap 안의 빈 주소는 구독 중');

    app.electrum.failedHistories.add(r[5]);
    await app.subscriptions.syncViewedAddresses(
      await app.copy(),
      await app.addresses.getWalletAddressList(await app.copy(), 4, 3, false, false),
    );
    await app.drain();
    expect(app.queueEnds.last, isNull);

    // #5에 입금 알림이 와서 그 주소를 서버 기준으로 다시 맞췄다.
    app.electrum.failedHistories.clear();
    app.pay(r[5], 40000);
    await app.drain();
    expect(app.isUsed(r[5]), isTrue);
    expect(app.balance, app.chain);
    expect(app.queueEnds.last, app.balance, reason: '그 주소를 다시 맞췄으니 실패 표시는 지워져야 함');
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('주소 목록에서 실패한 구멍을 휴면 재확인이 확인하면 실패 표시가 지워진다', () async {
    final app = _App();
    addTearDown(app.dispose);
    await app.setUp();
    final r = [for (var i = 0; i < 4; i++) app.base.getAddress(i)];
    app.pay(r[0], 300000);
    app.pay(r[3], 150000);
    await app.launch();
    await app.launch();

    // 빈 구멍 #2를 주소 목록에서 볼 때 이력 조회가 실패했다.
    app.electrum.failedHistories.add(r[2]);
    await app.subscriptions.syncViewedAddresses(
      await app.copy(),
      await app.addresses.getWalletAddressList(await app.copy(), 1, 2, false, false),
    );
    await app.drain();
    expect(app.queueEnds.last, isNull);

    // 휴면 재확인이 #2의 이력을 받았다(비어 있어 동기화는 하지 않는다).
    app.electrum.failedHistories.clear();
    app.electrum.requests.clear();
    await app.recheck();
    expect(app.electrum.requestsFor(r[2]), ['get_history']);
    expect(app.queueEnds.last, app.balance, reason: '같은 주소를 확인했으니 실패 표시는 지워져야 함');
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('주소 목록에서 본 빈 사용 주소에 다시 들어온 돈은 거래까지 받고 구독한다', () async {
    final (app, r) = await emptiedApp();
    final again = app.pay(r[1], 50000);
    await app.drain();

    final viewed = await app.addresses.getWalletAddressList(await app.copy(), 0, 3, false, false);
    await app.subscriptions.syncViewedAddresses(await app.copy(), viewed);
    await app.drain();
    expect(app.recorded([again]), 1);
    expect(app.electrum.isListening(r[1], app.walletId), isTrue);
    expect(app.balance, app.chain);
  }, timeout: const Timeout(Duration(seconds: 60)));

  group('실패 표시 풀기: 그 주소를 확인하거나 맞추면 그 주소의 실패만 풀린다', () {
    /// #1·#2를 받고 다 써서 빈 사용 주소로, #0·#3은 잔액이 남은 주소로 두고 다시 켠다.
    Future<(_App, List<String>)> twoEmptied() async {
      final app = _App();
      addTearDown(app.dispose);
      await app.setUp();
      final r = [for (var i = 0; i < 4; i++) app.base.getAddress(i)];
      app.pay(r[0], 300000);
      app.pay(r[1], 100000);
      app.pay(r[2], 100000);
      app.pay(r[3], 150000);
      await app.launch();
      app.spendAll(r[1]);
      app.spendAll(r[2]);
      await app.drain();
      await app.launch();
      return (app, r);
    }

    /// #0·#3에 잔액이 남고 #1·#2는 빈 구멍인 지갑
    Future<(_App, List<String>)> twoHoles() async {
      final app = _App();
      addTearDown(app.dispose);
      await app.setUp();
      final r = [for (var i = 0; i < 4; i++) app.base.getAddress(i)];
      app.pay(r[0], 300000);
      app.pay(r[3], 150000);
      await app.launch();
      await app.launch();
      return (app, r);
    }

    test('R2 P2 재동기화로 빈 구멍을 실제로 확인하면 휴면 실패가 풀린다', () async {
      final (app, r) = await twoHoles();
      app.electrum.failedHistories.addAll([r[1], r[2]]);
      await app.recheck();
      expect([app.failed(r[1]), app.failed(r[2])], [true, true]);
      app.electrum.failedHistories.clear();

      // 일반 재구독은 사용 인덱스 앞의 구멍을 확인하지 않으므로 그대로 남긴다.
      app.electrum.requests.clear();
      expect((await app.subscriptions.subscribeWallet(await app.copy())).isSuccess, isTrue);
      await app.drain();
      expect(app.electrum.requestsFor(r[1]), isEmpty);
      expect([app.failed(r[1]), app.failed(r[2])], [true, true]);
      expect(app.queueEnds.last, isNull);

      app.electrum.requests.clear();
      await app.resync();
      expect(app.electrum.requestsFor(r[1]), ['subscribe']);
      expect(app.electrum.requestsFor(r[2]), ['subscribe']);
      expect([app.failed(r[1]), app.failed(r[2])], [false, false]);
      expect(app.balance, 450000);
      expect(app.balance, app.chain);
      expect(app.queueEnds.last, app.balance);
    }, timeout: const Timeout(Duration(seconds: 60)));

    Future<(_App, List<String>)> failedOutsideGap() async {
      final app = _App();
      addTearDown(app.dispose);
      await app.setUp();
      await app.addresses.ensureAddressesExist(walletItemBase: await app.copy(), cursor: 0, count: 60, isChange: false);
      final r = [for (var i = 0; i < 42; i++) app.base.getAddress(i)];
      app.pay(r[0], 300000);
      await app.launch();
      app.electrum.failedHistories.addAll([r[40], r[41]]);
      await app.view(39, 2);
      expect([app.failed(r[40]), app.failed(r[41])], [true, true]);
      expect(app.queueEnds.last, isNull);
      return (app, r);
    }

    for (final resync in [false, true]) {
      test('R2 P3 ${resync ? '재동기화는' : '다시 구독은'} gap 밖 주소도 다시 확인하고 실패한 주소만 남긴다', () async {
        final (app, r) = await failedOutsideGap();
        app.electrum.failedHistories.remove(r[40]);
        app.electrum.requests.clear();
        if (resync) {
          // 주소 목록 실패 직후 재동기화해야 DB에서 그 주소 행이 지워지는 순서를 검증한다.
          await app.resync();
        } else {
          expect((await app.subscriptions.subscribeWallet(await app.copy())).isSuccess, isTrue);
          await app.drain();
        }
        expect(app.electrum.requestsFor(r[40]), ['get_history']);
        expect(app.electrum.requestsFor(r[41]), ['get_history']);
        expect([app.failed(r[40]), app.failed(r[41])], [false, true]);
        expect(app.queueEnds.last, isNull, reason: '확인 못 한 #41의 실패는 남겨야 한다');
        expect(app.balance, app.chain);

        app.electrum.failedHistories.clear();
        app.electrum.requests.clear();
        expect((await app.subscriptions.subscribeWallet(await app.copy())).isSuccess, isTrue);
        await app.drain();
        expect(app.electrum.requestsFor(r[40]), isEmpty, reason: '이미 성공한 주소는 다시 묻지 않는다');
        expect(app.electrum.requestsFor(r[41]), ['get_history']);
        expect(app.failed(r[41]), isFalse);
        expect(app.queueEnds.last, app.balance);
      }, timeout: const Timeout(Duration(seconds: 60)));
    }

    test('R2 P3 입금된 gap 밖 주소의 행을 재동기화 뒤 복원하고 거래와 잔액을 맞춘다', () async {
      final (app, r) = await failedOutsideGap();
      final received = app.pay(r[40], 70000);
      final spent = app.spendAll(r[40]);
      final kept = app.pay(r[41], 60000);
      app.electrum.failedHistories.clear();
      await app.resync();
      expect([app.failed(r[40]), app.failed(r[41])], [false, false]);
      expect([app.isUsed(r[40]), app.isUsed(r[41])], [true, true]);
      expect(app.recorded([received, spent, kept]), 3);
      expect(app.balance, 360000);
      expect(app.balance, app.chain);
      expect(app.addresses.getUsedIndexes(app.walletId).$1, 0);
      expect(app.queueEnds.last, app.balance);
      expect(app.electrum.isListening(r[40], app.walletId), isFalse);
      expect(app.electrum.isListening(r[41], app.walletId), isTrue);
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('R2C 주소 목록 실패 재확인은 모든 주소 행을 복원한 뒤 같은 확정 거래의 입금액을 합산한다', () async {
      final (app, r) = await failedOutsideGap();
      final funding = _tx([('1'.padLeft(64, 'e'), 0)], [(160000, app.external)]);
      app.put(funding, 200);
      final payment = _tx([(funding.transactionHash, 0)], [(70000, r[40]), (80000, r[41]), (9000, app.external)]);
      app.put(payment, 201);
      app.electrum.failedHistories.clear();

      await app.resync();

      final record = app.transactions.getRealmTransactionListByHashes(app.walletId, {payment.transactionHash}).single;
      expect(record.amount, 150000, reason: '같은 확정 거래의 #40·#41 출력을 모두 내 입금으로 세어야 한다');
      expect([app.failed(r[40]), app.failed(r[41])], [false, false]);
      expect([app.isUsed(r[40]), app.isUsed(r[41])], [true, true]);
      expect(app.balance, 450000);
      expect(app.balance, app.chain);
      expect(app.queueEnds.last, app.balance);
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('R2B Q1 주소 목록 실패 재확인의 구독 오류는 재동기화 성공과 UTXO 잠금을 보존하고 그 주소의 실패만 남긴다', () async {
      final (app, r) = await failedOutsideGap();
      final coin = app.utxos.getUtxosByStatus(app.walletId, UtxoStatus.unspent).single;
      await app.utxos.toggleUtxoLockStatus(app.walletId, coin.utxoId);
      expect(app.utxos.snapshotLockedUtxoIds(app.walletId), {coin.utxoId});

      app.pay(r[40], 70000);
      app.electrum.failedHistories.clear();
      app.electrum.failedSubscribes.add(r[40]);
      await app.resync();

      expect(app.utxos.snapshotLockedUtxoIds(app.walletId), {coin.utxoId});
      expect([app.failed(r[40]), app.failed(r[41]), app.failed(r[0])], [true, false, false]);
      expect(app.queueEnds.last, isNull);
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('R2 P3b gap 안 빈 주소의 구독 캐시는 성공으로 보지 않고 이력으로 다시 확인한다', () async {
      final app = _App();
      addTearDown(app.dispose);
      await app.setUp();
      app.pay(app.base.getAddress(0), 300000);
      await app.launch();
      final address = app.base.getAddress(5);
      final wallet = await app.copy();
      expect((await app.subscriptions.subscribeWallet(wallet)).isSuccess, isTrue);
      app.electrum.failedHistories.add(address);
      await app.view(4, 1);
      expect(app.failed(address), isTrue);

      app.electrum.requests.clear();
      expect((await app.subscriptions.subscribeWallet(wallet)).isSuccess, isTrue);
      await app.drain();
      expect(app.electrum.requestsFor(address), ['get_history'], reason: '캐시 재사용은 새 서버 확인이 아니다');
      expect(app.failed(address), isTrue);
      expect(app.queueEnds.last, isNull);

      app.electrum.failedHistories.clear();
      app.electrum.requests.clear();
      expect((await app.subscriptions.subscribeWallet(wallet)).isSuccess, isTrue);
      await app.drain();
      expect(app.electrum.requestsFor(address), ['get_history']);
      expect(app.failed(address), isFalse);
      expect(app.queueEnds.last, app.balance);
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('R2 F2 같은 키 두 지갑의 첫 확인은 독립적이고 각 지갑의 1분 제한은 유지된다', () async {
      final (app, r) = await twoHoles();
      final other = await app.wallets.addSinglesigWallet(
        WatchOnlyWallet('same key', 1, 1, _descriptor, null, null, 'coconutVault'),
      );
      await app.addresses.ensureAddressesInit(walletItemBase: other);
      app.state.initWalletUpdateStatus(other.id);
      expect((await app.subscriptions.subscribeWallet(other)).isSuccess, isTrue);
      await app.drain();
      app.electrum.failedHistories.add(r[1]);
      await app.recheck();
      expect(app.failed(r[1]), isTrue);
      app.electrum.failedHistories.clear();
      final otherAddresses = await app.addresses.getWalletAddressList(other, 0, 1, false, false);
      app.electrum.requests.clear();
      await app.subscriptions.syncViewedAddresses(other, otherAddresses);
      expect(app.electrum.requestsFor(r[1]), ['get_history']);
      expect(app.scripts.hasSyncFailure(other.id, r[1]), isFalse);
      expect(app.failed(r[1]), isTrue, reason: '다른 지갑의 확인으로 이 지갑의 실패를 지우지 않는다');

      app.electrum.requests.clear();
      await app.view(0, 1);
      expect(app.electrum.requestsFor(r[1]), ['get_history']);
      expect(app.failed(r[1]), isFalse);
      expect(app.queueEnds.last, app.balance);
      app.electrum.requests.clear();
      await app.view(0, 1);
      await app.subscriptions.syncViewedAddresses(other, otherAddresses);
      expect(app.electrum.requestsFor(r[1]), isEmpty, reason: '각 지갑에서 1분 내 다시 보는 것은 제한한다');
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('R2 F3 재동기화 전 이력 기억으로 현재 잔액 실패를 풀지 않는다', () async {
      final (app, r) = await twoHoles();
      final received = app.pay(r[1], 50000);
      await app.recheck();
      expect(app.balance, 500000);
      expect(app.failed(r[1]), isFalse);

      app.electrum.failedBalances.add(r[1]);
      await app.resync(succeeds: false);
      expect(app.balances.hasBalanceFetchFailure(app.walletId, r[1]), isTrue);
      final before = (await app.addresses.getWalletAddressList(await app.copy(), 0, 1, false, false)).single;
      expect(before.total, 0);
      app.electrum.failedBalances.clear();
      await Future<void>.delayed(const Duration(seconds: 31));
      app.electrum.requests.clear();
      await app.recheck();
      final after = (await app.addresses.getWalletAddressList(await app.copy(), 0, 1, false, false)).single;
      expect(after.total, 50000, reason: 'DB를 지우기 전 이력 기억은 현재 잔액을 증명하지 못한다');
      expect(app.balances.hasBalanceFetchFailure(app.walletId, r[1]), isFalse);
      expect(app.electrum.requestsFor(r[1]), contains('get_balance'));
      expect(app.recorded([received]), 1);
      expect(app.balance, app.chain);
    }, timeout: const Timeout(Duration(seconds: 90)));

    test('주소 목록에서 잔액 조회가 실패한 빈 사용 주소는 휴면 재확인이 기록과 맞는 것을 확인하면 실패가 풀린다', () async {
      final (app, r) = await emptiedApp();
      app.electrum.failedBalances.add(r[1]);
      await app.view(0, 1);
      expect(app.queueEnds.last, isNull);

      app.electrum.failedBalances.clear();
      await app.recheck();
      expect(app.balance, app.chain);
      expect(app.queueEnds.last, app.balance, reason: '같은 주소를 이력으로 확인했으니 잔액 조회 실패도 풀려야 함');
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('휴면 재확인이 확인하지 않은 다른 주소의 잔액 조회 실패는 남는다', () async {
      final (app, r) = await emptiedApp();
      // #0(잔액이 남은 주소, 휴면 재확인 대상 아님)과 #1(빈 사용 주소)의 잔액 조회가 실패했다.
      app.electrum.failedBalances.addAll([r[0], r[1]]);
      await app.view(-1, 2);
      expect(app.queueEnds.last, isNull);

      app.electrum.failedBalances.clear();
      await app.recheck();
      expect(app.queueEnds.last, isNull, reason: '#1만 확인했으니 #0의 실패는 남아야 함');
      expect(app.failed(r[0]), isTrue);
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('휴면 재확인에서 실패한 주소를 주소 목록이 다시 맞추면 실패가 풀린다', () async {
      final (app, r) = await emptiedApp();
      final again = app.pay(r[1], 50000);
      await app.drain();
      app.electrum.failedHistories.add(r[1]);
      await app.recheck();
      expect(app.queueEnds.last, isNull);

      app.electrum.failedHistories.clear();
      await app.view(0, 1);
      expect(app.recorded([again]), 1);
      expect(app.balance, app.chain);
      expect(app.queueEnds.last, app.balance, reason: '같은 주소를 다시 맞췄으니 휴면 재확인 실패도 풀려야 함');
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('다시 맞춘 주소가 아닌 다른 주소의 휴면 재확인 실패는 남는다', () async {
      final app = _App();
      addTearDown(app.dispose);
      await app.setUp();
      final r = [for (var i = 0; i < 3; i++) app.base.getAddress(i)];
      app.pay(r[0], 300000);
      app.pay(r[1], 100000);
      app.pay(r[2], 100000);
      await app.launch();
      app.spendAll(r[1]);
      app.spendAll(r[2]);
      await app.drain();
      await app.launch();
      // 빈 사용 주소 #1에만 다시 입금됐고, #1·#2 모두 휴면 재확인의 이력 조회가 실패했다.
      app.pay(r[1], 40000);
      app.electrum.failedHistories.addAll([r[1], r[2]]);
      await app.recheck();
      expect(app.queueEnds.last, isNull);

      app.electrum.failedHistories.clear();
      await app.view(0, 1);
      expect(app.balance, app.chain);
      expect(app.queueEnds.last, isNull, reason: '#1만 다시 맞췄으니 #2의 실패는 남아야 함');
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('입금 알림으로 맞춘 주소는 그 주소의 휴면 재확인 실패가 풀린다', () async {
      final app = _App();
      addTearDown(app.dispose);
      await app.setUp();
      final r = [for (var i = 0; i < 4; i++) app.base.getAddress(i)];
      app.pay(r[0], 300000);
      await app.launch();
      // 같은 실행에서 #3에 먼저 입금돼 #1·#2가 구멍이 됐다. 이 실행의 gap 구독은 아직 #1을 듣는다.
      app.pay(r[3], 50000);
      await app.drain();
      expect(app.electrum.isListening(r[1], app.walletId), isTrue);
      app.electrum.failedHistories.add(r[1]);
      await app.recheck();
      expect(app.failed(r[1]), isTrue);
      app.electrum.failedHistories.clear();
      app.pay(r[1], 20000);
      await app.drain();
      expect(app.failed(r[1]), isFalse);
      expect(app.balance, app.chain);
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('배치 동기화로 다시 맞춘 주소는 휴면 재확인 실패가 풀리고, 배치에 없던 주소의 실패는 남는다', () async {
      final (app, r) = await twoEmptied();
      app.electrum.failedHistories.addAll([r[1], r[2]]);
      await app.recheck();
      expect([app.failed(r[1]), app.failed(r[2])], [true, true]);
      app.electrum.failedHistories.clear();
      // 지갑 구독·재동기화가 쓰는 배치 동기화로 #1만 다시 맞춘다.
      final row = (await app.addresses.getWalletAddressList(await app.copy(), 0, 1, false, false)).single;
      expect(row.address, r[1]);
      await app.subscriptions.runExclusive(
        app.walletId,
        () async => app.scripts.syncBatchScriptStatusList(
          walletItem: await app.copy(),
          scriptStatuses: [
            ScriptStatus(
              derivationPath: row.derivationPath,
              address: row.address,
              index: row.index,
              isChange: row.isChange,
              scriptPubKey: '',
              status: null,
              timestamp: DateTime.now(),
            ),
          ],
        ),
      );
      expect([app.failed(r[1]), app.failed(r[2])], [false, true]);
      expect(app.balance, app.chain);
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('R2 P1 주소 목록의 잔액 성공만으로 놓친 거래의 휴면 이력 실패를 풀지 않는다', () async {
      final (app, r) = await emptiedApp();
      final received = app.pay(r[1], 50000);
      final spent = app.spendAll(r[1]);
      await app.drain();
      expect(app.recorded([received, spent]), 0);
      app.electrum.failedHistories.add(r[1]);
      await app.recheck();
      expect(app.failed(r[1]), isTrue);
      expect(app.queueEnds.last, isNull);

      app.electrum.failedHistories.clear();
      app.electrum.requests.clear();
      await app.view(0, 1);
      expect(app.electrum.requestsFor(r[1]), ['get_balance']);
      expect(app.balance, app.chain);
      expect(app.recorded([received, spent]), 0);
      expect(app.failed(r[1]), isTrue, reason: '잔액이 맞아도 거래 이력은 확인하지 못했다');
      expect(app.queueEnds.last, isNull);
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('주소 목록에서 본 사용 주소가 아닌 다른 주소의 휴면 재확인 실패는 남는다', () async {
      final (app, r) = await twoEmptied();
      app.electrum.failedHistories.addAll([r[1], r[2]]);
      await app.recheck();
      app.electrum.failedHistories.clear();
      await app.view(0, 1);
      expect(app.failed(r[2]), isTrue);
    }, timeout: const Timeout(Duration(seconds: 60)));

    /// #0·#1에 잔액이 남은 지갑에서 [flagged] 주소들에 휴면 재확인 실패를 남긴다.
    /// 잔액이 남은 주소는 휴면 재확인 대상이 아니라, 잠깐 저장 잔액을 0으로 바꿔 실패를 남긴 뒤 되돌린다.
    Future<(_App, List<String>)> coSpentWallet(List<int> flagged) async {
      final app = _App();
      addTearDown(app.dispose);
      await app.setUp();
      final r = [for (var i = 0; i < 3; i++) app.base.getAddress(i)];
      app.pay(r[0], 300000);
      app.pay(r[1], 100000);
      app.pay(r[2], 80000);
      await app.launch();
      await app.launch();
      final kept = {for (final i in flagged) i: app.electrum.balanceOf(r[i])};
      for (final i in flagged) {
        app.setStoredBalance(r[i], 0);
        app.electrum.failedHistories.add(r[i]);
      }
      await app.recheck();
      app.electrum.failedHistories.clear();
      for (final i in flagged) {
        app.setStoredBalance(r[i], kept[i]!);
        expect(app.failed(r[i]), isTrue);
      }
      return (app, r);
    }

    /// #0의 알림으로만 기록되는 거래가 #0과 #1의 코인을 함께 쓴다(#1 자신의 알림은 오지 않음).
    Future<void> coSpend(_App app, List<String> r) async {
      final coins = [
        for (final i in [0, 1])
          for (final coin in app.electrum._outputsTo(r[i]))
            if (!app.electrum._spent(coin.$1, coin.$2)) (coin.$1, coin.$2),
      ];
      final total = app.electrum.balanceOf(r[0]) + app.electrum.balanceOf(r[1]);
      app.put(_tx(coins, [(total - 1000, app.external)]), 190);
      app.electrum.notify(r[0]);
      await app.drain();
    }

    test('R2 G2 함께 소비된 주소의 잔액 성공만으로 휴면 이력 실패를 풀지 않는다', () async {
      final (app, r) = await coSpentWallet([1]);
      await coSpend(app, r);
      expect(app.electrum.balanceOf(r[1]), 0);
      expect(app.failed(r[1]), isTrue);
      expect(app.balance, app.chain);
      expect(app.queueEnds.last, isNull);
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('함께 소비되지 않은 다른 주소의 휴면 재확인 실패는 남는다', () async {
      final (app, r) = await coSpentWallet([1, 2]);
      await coSpend(app, r);
      expect(app.failed(r[2]), isTrue);
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('주소 목록에서 빈 미사용 주소의 이력을 확인하면 그 주소의 휴면 재확인 실패가 풀린다', () async {
      final (app, r) = await twoHoles();
      app.electrum.failedHistories.add(r[1]);
      await app.recheck();
      expect(app.failed(r[1]), isTrue);
      app.electrum.failedHistories.clear();
      await app.view(0, 1);
      expect(app.failed(r[1]), isFalse);
      expect(app.queueEnds.last, app.balance);
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('주소 목록에서 본 미사용 주소가 아닌 다른 구멍의 휴면 재확인 실패는 남는다', () async {
      final (app, r) = await twoHoles();
      app.electrum.failedHistories.addAll([r[1], r[2]]);
      await app.recheck();
      app.electrum.failedHistories.clear();
      await app.view(0, 1);
      expect(app.failed(r[2]), isTrue);
    }, timeout: const Timeout(Duration(seconds: 60)));

    /// 빈 사용 주소 #1의 옛 출금 기록에서 #1이 낸 금액을 틀리게 바꾼다(기록이 서버와 어긋난 채 남은 모양).
    /// 그러면 #1은 재확인마다 다시 동기화 대상으로 골라지고, 첫 동기화 뒤로는 같은 이력이라 건너뛴다.
    Future<(_App, List<String>)> skippedApp() async {
      final (app, r) = await emptiedApp();
      final spend = app.electrum._all
          .map((item) => item.$1)
          .firstWhere(
            (tx) => tx.inputs.any(
              (input) => app.electrum
                  ._outputsTo(r[1])
                  .any((output) => output.$1 == input.transactionHash && output.$2 == input.index),
            ),
          );
      final realm = app.realmManager.realm;
      final row =
          realm.query<RealmTransaction>(r'walletId == $0 AND transactionHash == $1', [
            app.walletId,
            spend.transactionHash,
          ]).single;
      realm.write(() {
        row.inputAddressList
          ..clear()
          ..add(jsonEncode({'address': r[1], 'amount': 90000}));
      });
      await app.recheck();
      expect(app.failed(r[1]), isFalse);
      return (app, r);
    }

    test('같은 이력으로 이미 맞춰 건너뛴 주소는 그사이 생긴 잔액 조회 실패가 풀린다', () async {
      final (app, r) = await skippedApp();
      app.electrum.failedBalances.add(r[1]);
      await app.view(0, 1);
      expect(app.failed(r[1]), isTrue);
      app.electrum.failedBalances.clear();
      await Future<void>.delayed(const Duration(seconds: 31));
      app.electrum.requests.clear();
      await app.recheck();
      expect(app.electrum.requestsFor(r[1]), ['get_history'], reason: '같은 이력이라 다시 동기화하지 않음');
      expect(app.failed(r[1]), isFalse);
    }, timeout: const Timeout(Duration(seconds: 90)));

    test('건너뛴 주소가 아닌 다른 주소의 잔액 조회 실패는 남는다', () async {
      final (app, r) = await skippedApp();
      app.electrum.failedBalances.addAll([r[0], r[1]]);
      await app.view(-1, 2);
      expect([app.failed(r[0]), app.failed(r[1])], [true, true]);
      app.electrum.failedBalances.clear();
      await Future<void>.delayed(const Duration(seconds: 31));
      await app.recheck();
      expect(app.failed(r[0]), isTrue);
    }, timeout: const Timeout(Duration(seconds: 90)));

    test('휴면 재확인은 이번에 확인하지 않은 주소의 실패를 지우지 않는다', () async {
      final (app, r) = await twoEmptied();
      app.electrum.failedHistories.addAll([r[1], r[2]]);
      await app.recheck();
      expect([app.failed(r[1]), app.failed(r[2])], [true, true]);
      // #2가 다른 경로에서 잔액이 생겨 휴면 대상이 아니게 됐지만, 그 경로는 #2를 끝까지 맞추지 못했다.
      app.setStoredBalance(r[2], 1000);
      app.electrum.failedHistories.clear();
      await Future<void>.delayed(const Duration(seconds: 31));
      await app.recheck();
      expect([app.failed(r[1]), app.failed(r[2])], [false, true]);
    }, timeout: const Timeout(Duration(seconds: 90)));

    test('휴면 재확인은 이번에 다시 확인한 주소의 실패만 갈아끼운다', () async {
      final (app, r) = await twoEmptied();
      app.electrum.failedHistories.addAll([r[1], r[2]]);
      await app.recheck();
      app.electrum.failedHistories.remove(r[1]);
      await Future<void>.delayed(const Duration(seconds: 31));
      await app.recheck();
      expect([app.failed(r[1]), app.failed(r[2])], [false, true]);
    }, timeout: const Timeout(Duration(seconds: 90)));
  });

  group('휴면 재확인 조회 수', () {
    test('보통 지갑: 쉬고 있는 주소 26개를 이력 조회 26번으로 확인하고 그 밖의 요청은 없다', () async {
      final app = _App();
      addTearDown(app.dispose);
      await app.setUp();
      final receive = [for (var i = 0; i < 20; i++) app.base.getAddress(i)];
      final change = [for (var i = 0; i < 10; i++) app.base.getAddress(i, isChange: true)];
      const holes = {3, 8, 13};
      const kept = {0, 5, 10, 15};
      for (var i = 0; i < 20; i++) {
        if (!holes.contains(i)) app.pay(receive[i], 100000 + i);
      }
      for (final address in change) {
        app.pay(address, 50000);
      }
      for (var i = 0; i < 20; i++) {
        if (!holes.contains(i) && !kept.contains(i)) app.spendAll(receive[i]);
      }
      for (final address in change) {
        app.spendAll(address);
      }
      await app.launch();
      await app.launch();
      expect(app.balance, app.chain);

      app.electrum.requests.clear();
      await app.recheck();
      // ignore: avoid_print
      print(
        'RPC typical wallet (receive 20: 4 funded, 13 emptied, 3 holes; change 10 emptied): ${app.electrum.counts}',
      );
      expect(app.balance, app.chain);
      expect(app.electrum.counts, {'get_history': 26});
    }, timeout: const Timeout(Duration(seconds: 90)));

    /// 받는 주소 0~999를 만든 뒤 [holes]는 미사용, 100개마다 하나는 잔액이 남은 사용 주소, 나머지는 받고 모두 쓴 빈 사용 주소로 둔다.
    /// 빈 사용 주소는 서버 이력(입금·출금 2건)과 같은 거래를 지갑 기록에도 넣어 둔다.
    Future<Map<String, int>> runLarge({required Set<int> holes}) async {
      final app = _App();
      addTearDown(app.dispose);
      await app.setUp();
      final wallet = await app.copy();
      await app.addresses.ensureAddressesExist(walletItemBase: wallet, cursor: 0, count: 1000, isChange: false);
      final realm = app.realmManager.realm;
      final rows = realm.query<RealmWalletAddress>(r'walletId == $0 AND isChange == false', [app.walletId]);
      final records = <TransactionRecord>[];
      var total = 0;
      realm.write(() {
        for (final row in rows) {
          final funded = row.index % 100 == 0;
          row.isUsed = !holes.contains(row.index);
          row.confirmed = funded ? 10000 : 0;
          row.total = row.confirmed;
          total += row.confirmed;
          app.electrum.fixedBalances[row.address] = row.confirmed;
          if (row.isUsed && !funded) {
            final received = 'a${'${row.index}'.padLeft(63, '0')}';
            final spent = 'b${'${row.index}'.padLeft(63, '0')}';
            app.electrum.fixedHistories[row.address] = [
              GetTxHistoryRes(height: 100, txHash: received),
              GetTxHistoryRes(height: 101, txHash: spent),
            ];
            records
              ..add(
                _record(
                  received,
                  100,
                  [TransactionAddress(app.external, 20000)],
                  [TransactionAddress(row.address, 10000), TransactionAddress(app.external, 9000)],
                ),
              )
              ..add(
                _record(spent, 101, [TransactionAddress(row.address, 10000)], [TransactionAddress(app.external, 9000)]),
              );
          }
        }
        realm.find<RealmWalletBase>(app.walletId)!.usedReceiveIndex = 999;
      });
      await app.transactions.addAllTransactions(app.walletId, records);
      app.wallets.getWalletBalance(app.walletId);
      realm.write(() {
        final balance = realm.query<RealmWalletBalance>(r'walletId == $0', [app.walletId]).single;
        balance.confirmed = total;
        balance.total = total;
      });
      await app.launch();
      expect(app.addresses.getDormantUsedAddresses(app.walletId).length, 990 - holes.length);

      app.electrum.requests.clear();
      await app.recheck();
      expect(app.balance, total, reason: '서버와 같은 상태에서는 잔액이 그대로');
      return app.electrum.counts;
    }

    test('주소 1,000개 지갑, 구멍 없음: 빈 사용 주소 990개를 이력 조회 990번으로 확인한다', () async {
      final counts = await runLarge(holes: {});
      // ignore: avoid_print
      print('RPC 1000 addresses, no holes: $counts');
      expect(counts, {'get_history': 990});
    }, timeout: const Timeout(Duration(seconds: 90)));

    test('주소 1,000개 지갑, 구멍 10개: 이력 조회 990번(빈 사용 주소 980 + 구멍 10)이고 그 밖의 요청은 없다', () async {
      final counts = await runLarge(holes: {for (var i = 1; i <= 10; i++) i * 37});
      // ignore: avoid_print
      print('RPC 1000 addresses, 10 holes: $counts');
      expect(counts, {'get_history': 990});
    }, timeout: const Timeout(Duration(seconds: 90)));
  });
}

TransactionRecord _record(String hash, int height, List<TransactionAddress> inputs, List<TransactionAddress> outputs) =>
    TransactionRecord.fromTransactions(
      transactionHash: hash,
      timestamp: DateTime.utc(2026),
      blockHeight: height,
      transactionType: TransactionType.unknown,
      amount: 0,
      fee: 1000,
      inputAddressList: inputs,
      outputAddressList: outputs,
      vSize: 141,
    );
