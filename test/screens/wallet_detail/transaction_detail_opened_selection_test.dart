// 거래 상세는 연 거래를 고른 채로 연다(N1). 수수료 대체 묶음은 수수료율 높은 순(0번 = 가장 최근 대체, 수수료 올리기가 쓰는
// 거래)이라, 대체된 거래 T로 열면(알림·Wallet Health의 사건 거래) T가 0번이 아니다. 전에는 0번(T2)을 골라 T의 배너와
// "이 거래 검토"가 보이지 않았고, "기존 수수료"를 눌러도 화면이 갱신될 때 0번으로 돌아갔다
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/error/app_error.dart';
import 'package:coconut_wallet/model/node/cpfp_history.dart';
import 'package:coconut_wallet/model/node/node_provider_state.dart';
import 'package:coconut_wallet/model/node/rbf_history.dart';
import 'package:coconut_wallet/model/node/wallet_update_info.dart';
import 'package:coconut_wallet/model/safety/safety_incident.dart';
import 'package:coconut_wallet/model/safety/safety_state.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/wallet/singlesig_wallet_item.dart';
import 'package:coconut_wallet/model/wallet/transaction_address.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/preferences/block_explorer_provider.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/price_provider.dart';
import 'package:coconut_wallet/providers/safety_provider.dart';
import 'package:coconut_wallet/providers/transaction_provider.dart';
import 'package:coconut_wallet/providers/utxo_tag_provider.dart';
import 'package:coconut_wallet/providers/view_model/wallet_detail/transaction_detail_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/repository/realm/address_repository.dart';
import 'package:coconut_wallet/repository/realm/utxo_repository.dart';
import 'package:coconut_wallet/app/router/app_route_names.dart';
import 'package:coconut_wallet/app/router/route_args.dart';
import 'package:coconut_wallet/routes/route_observer.dart';
import 'package:coconut_wallet/screens/wallet_detail/transaction_detail_screen.dart';
import 'package:coconut_wallet/screens/wallet_detail/transaction_fee_bumping_screen.dart'
    show FeeBumpingType, RbfSentHandoff;
import 'package:coconut_wallet/analytics/analytics_screen_names.dart' show TransactionDetailPurpose;
import 'package:coconut_wallet/constants/lottie_path.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/repository/realm/transaction_draft_repository.dart';
import 'package:coconut_wallet/screens/send/broadcasting_complete_screen.dart';
import 'package:coconut_wallet/screens/send/broadcasting_screen.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:lottie/lottie.dart';
import 'package:coconut_wallet/services/model/response/block_timestamp.dart';
import 'package:coconut_wallet/utils/result.dart';
import 'package:coconut_wallet/widgets/features/safety/transaction_safety_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../mock/utxo_mock.dart';
import '../../repository/realm/test_realm_manager.dart';
import '../safety/safety_test_harness.dart' show findText;

final _t = 'a' * 64; // T: 처음 보낸 거래(다른 앱에서 수수료를 올려 대체됨)
final _t2 = 'b' * 64; // T2: T의 수수료 올림(대기 중)
final _t3 = 'c' * 64; // T3: 한 번 더 올림
final _parent = 'd' * 64; // CPFP 부모(받은 거래)
final _child = 'e' * 64; // CPFP 자식

final _inputs = [TransactionAddress('bc1qknowninput0000000000000000000000000000', 100000)];
final _outputs = [TransactionAddress('bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq', 50000)];

/// 대기 중인 대체 거래의 기록은 원거래 묶음 전체를 이력으로 읽는다(transaction_repository getRbfHistoryList)
TransactionRecord _sent(String hash, int fee, {List<String> chain = const [], int blockHeight = 0, String? memo}) =>
    TransactionRecord(
      hash,
      DateTime(2026, 11, 3),
      blockHeight,
      TransactionType.sent,
      memo,
      -50000 - fee,
      fee,
      _inputs.toList(),
      _outputs.toList(),
      141,
      DateTime(2026, 11, 3),
      rbfHistoryList:
          chain.isEmpty
              ? null
              : [
                for (final h in chain)
                  RbfHistory(
                    walletId: 1,
                    originalTransactionHash: _t,
                    transactionHash: h,
                    feeRate: 0,
                    timestamp: DateTime(2026, 11, 3),
                  ),
              ],
    );

TransactionRecord _copyWithMemo(TransactionRecord r, String memo) => TransactionRecord(
  r.transactionHash,
  r.timestamp,
  r.blockHeight,
  r.transactionType,
  memo,
  r.amount,
  r.fee,
  r.inputAddressList,
  r.outputAddressList,
  r.vSize,
  r.createdAt,
  rbfHistoryList: r.rbfHistoryList,
  cpfpHistory: r.cpfpHistory,
);

late WalletItemBase _wallet;

class _Wallets extends Fake with ChangeNotifier implements WalletProvider {
  @override
  WalletItemBase getWalletById(int id) => _wallet;
  @override
  bool isTransactionSuspicious(TransactionRecord transaction) => false;
  @override
  bool containsAddressInAnyWallet(String address) => false;
  @override
  List<WalletItemBase> get walletItemList => [_wallet];
  @override
  bool containsAddress(int walletId, String address, {bool? isChange}) => false;
  @override
  int? findWalletIdContainingAddress(String address) => null;
  @override
  UtxoState? getUtxoState(int walletId, String utxoId) => null;

  /// 지갑 갱신 알림(화면의 ProxyProvider가 updateProvider를 부른다)
  void ping() => notifyListeners();
}

/// 저장된 기록(테스트가 직접 바꾼다)
class _Transactions extends Fake with ChangeNotifier implements TransactionProvider {
  _Transactions(this.records);
  final Map<String, TransactionRecord> records;
  TransactionRecord? _current;

  @override
  bool hasTransactionConfirmed(int walletId, String txHash) => false;

  @override
  TransactionRecord? getTransaction(int walletId, String txHash, {String? utxoTo}) => records[txHash];
  @override
  TransactionRecord? getTransactionRecord(int walletId, String txHash) => records[txHash];
  @override
  TransactionRecord? get transaction => _current;
  @override
  void initTransaction(int walletId, String txHash, {String? utxoTo}) => _current = records[txHash];
  @override
  Future<void> updateTransaction(int walletId, String txHash, TransactionRecord updatedTx) async =>
      records[txHash] = updatedTx;
  @override
  bool updateTransactionMemo(int walletId, String txHash, String memo) {
    records[txHash] = _copyWithMemo(records[txHash]!, memo);
    return true;
  }
}

class _Preferences extends Fake with ChangeNotifier implements PreferenceProvider {
  @override
  BitcoinUnit get currentUnit => BitcoinUnit.btc;
  @override
  String get language => 'ko';
  @override
  bool get isFakeBalanceActive => false;
  @override
  bool get isBalanceHidden => false;
}

class _Connectivity extends Fake with ChangeNotifier implements ConnectivityProvider {
  @override
  bool get isInternetOn => true;
}

class _Prices extends Fake with ChangeNotifier implements PriceProvider {
  @override
  String getFiatPrice(int satoshiAmount, {FiatCode? fiatCode, bool showCurrencySymbol = true}) => '';
}

class _Explorer extends Fake with ChangeNotifier implements BlockExplorerProvider {}

/// 멤풀 응답을 해석할 때 "내 주소"로 볼 주소(보낸 거래로 읽히게)
final _myAddresses = <String>{};

class _Addresses extends Fake implements AddressRepository {
  @override
  bool containsAddress(int walletId, String address, {bool? isChange}) => _myAddresses.contains(address);
  @override
  String getDerivationPath(int walletId, String address) => "m/84'/0'/0'/0/0";
}

class _Node extends Fake with ChangeNotifier implements NodeProvider {
  final _walletStates = StreamController<Map<int, WalletUpdateInfo>>.broadcast();

  /// 당겨서 새로고침이 받을 결과
  Result<TransactionRecord> refreshed = Result.failure(ErrorCodes.nodeUnknown);

  /// 실제 보내기 화면(BroadcastingScreen)이 쓰는 노드: 연결돼 있고, 전송은 [sent]가 끝날 때 끝난다
  final sent = Completer<Result<String>>();
  int broadcasts = 0;
  @override
  String get host => 'localhost';
  @override
  Future<bool> reconnectWithoutWaitingForSync() async => true;
  @override
  Future<Result<String>> getTransaction(String txHash) async => Result.failure(ErrorCodes.nodeUnknown);
  @override
  Future<Result<String>> broadcast(Transaction transaction) {
    broadcasts++;
    return sent.future;
  }

  @override
  Future<Result<TransactionRecord>> getTransactionRecord(
    WalletItemBase walletItem,
    String txHash, {
    Duration? timeout,
  }) async => refreshed;
  @override
  NodeProviderState get state => NodeProviderState(
    nodeSyncState: NodeSyncState.completed,
    registeredWallets: {
      1: WalletUpdateInfo(
        1,
        subscription: WalletSyncState.completed,
        balance: WalletSyncState.completed,
        transaction: WalletSyncState.completed,
        utxo: WalletSyncState.completed,
        balanceSnapshot: 0,
      ),
    },
  );
  @override
  Stream<NodeSyncState> get syncStateStream => const Stream.empty();
  @override
  Future<Result<BlockTimestamp>> getLatestBlock() async =>
      Result.success(BlockTimestamp(974400, DateTime(2026, 11, 3)));
  @override
  Stream<WalletUpdateInfo> getWalletStateStream(int walletId) =>
      _walletStates.stream.map((wallets) => wallets[walletId]).where((state) => state != null).cast<WalletUpdateInfo>();
}

/// 멤풀 API(GET /api/tx/<txid>)만 흉내 내는 HttpClient: [body]를 200으로 돌려준다
class _Mempool extends Fake implements HttpClient {
  _Mempool(this.body);
  final String body;
  int requests = 0;
  @override
  Duration? connectionTimeout;
  @override
  Duration idleTimeout = Duration.zero;
  @override
  bool autoUncompress = true;
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    requests++;
    return _MempoolRequest(body);
  }

  @override
  void close({bool force = false}) {}
}

class _MempoolRequest extends Fake implements HttpClientRequest {
  _MempoolRequest(this.body);
  final String body;
  @override
  final HttpHeaders headers = _Headers();
  @override
  bool followRedirects = true;
  @override
  int maxRedirects = 5;
  @override
  int contentLength = -1;
  @override
  bool persistentConnection = true;
  @override
  Future<void> addStream(Stream<List<int>> stream) => stream.drain<void>();
  @override
  Future<HttpClientResponse> close() async => _MempoolResponse(body);
}

class _Headers extends Fake implements HttpHeaders {
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}
  @override
  void forEach(void Function(String name, List<String> values) action) => action('content-type', ['application/json']);
}

class _MempoolResponse extends Stream<List<int>> implements HttpClientResponse {
  _MempoolResponse(this.body);
  final String body;
  @override
  final HttpHeaders headers = _Headers();
  @override
  int get statusCode => 200;
  @override
  int get contentLength => -1;
  @override
  bool get isRedirect => false;
  @override
  List<RedirectInfo> get redirects => const [];
  @override
  bool get persistentConnection => false;
  @override
  String get reasonPhrase => 'OK';
  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => Stream.value(utf8.encode(body)).listen(onData, onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late TestRealmManager manager;

  setUpAll(() {
    NetworkType.setNetworkType(NetworkType.mainnet);
    LocaleSettings.setLocaleSync(AppLocale.ko);
  });
  tearDownAll(() => NetworkType.setNetworkType(NetworkType.regtest));
  setUp(() {
    manager = TestRealmManager();
    _myAddresses.clear();
    RbfSentHandoff.take();
  });
  tearDown(() {
    manager.dispose();
    TransactionDetailScreen.now = DateTime.now;
  });

  /// T는 확인 전에 대체됐고(감지 + 대체됨 = 정보 배너), T2는 이미 "내 거래예요"로 인지함
  final incidents = [
    SafetyIncident(walletId: 1, txid: _t, detectedAt: DateTime(2026, 11, 3, 9), txState: IncidentTxState.replaced),
    SafetyIncident(walletId: 1, txid: _t2, detectedAt: DateTime(2026, 11, 3, 10), state: IncidentState.recognized),
  ];
  final pendingChain = [_t2, _t];
  Map<String, TransactionRecord> pending() => {
    _t: _sent(_t, 300, chain: pendingChain),
    _t2: _sent(_t2, 1000, chain: pendingChain),
  };

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<
    ({
      _Wallets wallets,
      _Transactions txs,
      _Node node,
      GlobalKey<NavigatorState> navigator,
      List<TransactionFeeBumpingRouteArgs> feeBumps,
      SendInfoProvider sendInfo,
    })
  >
  open(
    WidgetTester tester, {
    required String hash,
    required Map<String, TransactionRecord> records,
    List<SafetyIncident> safetyIncidents = const [],
    TransactionDetailPurpose? purpose,
  }) async {
    _wallet = SinglesigWalletItem(
      id: 1,
      name: 'QA',
      colorIndex: 0,
      iconIndex: 0,
      descriptor: SingleSignatureVault.fromEntropy(Uint8List(16)).descriptor,
    );
    final env = (
      wallets: _Wallets(),
      txs: _Transactions(records),
      node: _Node(),
      navigator: GlobalKey<NavigatorState>(),
      feeBumps: <TransactionFeeBumpingRouteArgs>[],
      sendInfo: SendInfoProvider(),
    );
    final tags = UtxoTagProvider(UtxoRepository(manager));
    addTearDown(tags.dispose);
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = const Size(1179, 2556);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<WalletProvider>.value(value: env.wallets),
          ChangeNotifierProvider<TransactionProvider>.value(value: env.txs),
          ChangeNotifierProvider<PreferenceProvider>(create: (_) => _Preferences()),
          ChangeNotifierProvider<ConnectivityProvider>(create: (_) => _Connectivity()),
          ChangeNotifierProvider<PriceProvider>(create: (_) => _Prices()),
          ChangeNotifierProvider<BlockExplorerProvider>(create: (_) => _Explorer()),
          ChangeNotifierProvider<NodeProvider>.value(value: env.node),
          ChangeNotifierProvider<UtxoTagProvider>.value(value: tags),
          Provider<AddressRepository>.value(value: _Addresses()),
          Provider<SendInfoProvider>.value(value: env.sendInfo),
          Provider<UtxoRepository>.value(value: UtxoRepository(manager)),
          Provider<TransactionDraftRepository>.value(value: TransactionDraftRepository(manager)),
          ChangeNotifierProvider<SafetyProvider>.value(
            value: SafetyProvider.fixed(null, state: SafetyState(incidents: safetyIncidents)),
          ),
        ],
        child: MaterialApp(
          theme: buildCoconutThemeData(variant: CoconutThemeVariant.light),
          navigatorKey: env.navigator,
          navigatorObservers: [routeObserver],
          // purpose가 있으면 앱처럼 이름 있는 경로(인자 포함)로 연다
          home: purpose == null ? TransactionDetailScreen(id: 1, txHash: hash) : const SizedBox(),
          // 앱의 거래 상세 경로처럼 인자로 상세를 만든다. 수수료 올리기는 넘긴 인자만 남기는 자리표시 화면
          onGenerateRoute: (settings) {
            final args = settings.arguments;
            if (args is TransactionFeeBumpingRouteArgs) env.feeBumps.add(args);
            return MaterialPageRoute<void>(
              settings: settings,
              builder:
                  (_) => switch (args) {
                    final TransactionDetailRouteArgs args => TransactionDetailScreen(id: args.id, txHash: args.txHash),
                    TransactionFeeBumpingRouteArgs() => const Scaffold(body: Text('수수료 올리기')),
                    _ => const SizedBox(),
                  },
            );
          },
        ),
      ),
    );
    if (purpose != null) {
      unawaited(
        env.navigator.currentState!.pushNamed(
          AppRouteNames.transactionDetail,
          arguments: TransactionDetailRouteArgs(id: 1, txHash: hash, purpose: purpose),
        ),
      );
    }
    await settle(tester);
    return env;
  }

  TransactionDetailViewModel model(WidgetTester tester) =>
      tester.element(find.byType(TransactionSafetyBanner)).read<TransactionDetailViewModel>();
  List<String> shown(WidgetTester tester) => model(tester).transactionList!.map((tx) => tx.transactionHash).toList();
  String selected(WidgetTester tester) => shown(tester)[model(tester).selectedTransactionIndex];
  Future<void> tapChip(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await settle(tester); // 칩의 setState가 화면 갱신(updateProvider)도 부른다
  }

  final review = t.safety_guide.tx_banner.review;
  final newFee = t.transaction_fee_bumping_screen.new_fee;
  final existingFee = t.transaction_fee_bumping_screen.existing_fee;

  for (final opened in [_t, _t2]) {
    for (final withIncidents in [true, false]) {
      final name = '${opened == _t ? 'T (replaced)' : 'T2 (latest)'}${withIncidents ? ', with incidents' : ''}';
      testWidgets('opened as $name: the opened transaction is selected and each chip choice stays', (tester) async {
        final env = await open(
          tester,
          hash: opened,
          records: pending(),
          safetyIncidents: withIncidents ? incidents : const [],
        );
        expect(shown(tester), [_t2, _t], reason: '수수료율 순은 그대로(0번 = 수수료 올리기가 쓰는 최근 대체)');
        expect(selected(tester), opened);
        if (withIncidents && opened == _t) {
          expect(find.byKey(const Key('transaction-safety-banner-info')), findsOneWidget);
          expect(findText(review), findsOneWidget, reason: '알림에서 연 T의 "이 거래 검토"가 바로 보인다');
        }

        await tapChip(tester, newFee);
        expect(selected(tester), _t2);
        await tapChip(tester, existingFee);
        expect(selected(tester), _t, reason: '"기존 수수료"가 T2로 돌아가지 않는다');
        env.wallets.ping();
        await settle(tester);
        expect(selected(tester), _t, reason: '바뀐 것이 없으면 갱신돼도 고른 거래 그대로');
        if (withIncidents) expect(findText(review), findsOneWidget);
      });
    }
  }

  for (final opened in [_t, _t2]) {
    testWidgets('a third bump (T3) rebuilds the list and keeps T selected (opened as ${opened == _t ? 'T' : 'T2'})', (
      tester,
    ) async {
      final env = await open(tester, hash: opened, records: pending());
      if (opened == _t2) await tapChip(tester, existingFee);
      expect(selected(tester), _t);

      final chain = [_t3, _t2, _t];
      env.txs.records
        ..[_t] = _sent(_t, 300, chain: chain)
        ..[_t2] = _sent(_t2, 1000, chain: chain)
        ..[_t3] = _sent(_t3, 2000, chain: chain);
      env.wallets.ping();
      await settle(tester);
      expect(shown(tester), [_t3, _t2, _t], reason: '연 거래가 그대로여도 묶음이 바뀌면 다시 만든다');
      expect(selected(tester), _t);
    });
  }

  testWidgets('T2 confirming is noticed while T stays selected, even before the history is deleted', (tester) async {
    final env = await open(tester, hash: _t, records: pending());
    env.txs.records[_t2] = _sent(_t2, 1000, chain: pendingChain, blockHeight: 974401);
    env.wallets.ping();
    await settle(tester);
    expect(model(tester).transactionList!.first.blockHeight, 974401);
    expect(selected(tester), _t);
  });

  testWidgets('T2 confirmed and the history deleted: opened as T, T alone stays with its review link', (tester) async {
    final env = await open(tester, hash: _t, records: pending(), safetyIncidents: incidents);
    env.txs.records
      ..[_t] = _sent(_t, 300)
      ..[_t2] = _sent(_t2, 1000, blockHeight: 974401);
    env.wallets.ping();
    await settle(tester);
    expect(shown(tester), [_t]);
    expect(findText(review), findsOneWidget);
  });

  testWidgets('when the selected T leaves the list, the opened T2 is selected', (tester) async {
    final env = await open(tester, hash: _t2, records: pending());
    await tapChip(tester, existingFee);
    expect(selected(tester), _t);
    env.txs.records[_t2] = _sent(_t2, 1000, blockHeight: 974401); // 확정되며 이력이 지워짐
    env.wallets.ping();
    await settle(tester);
    expect(shown(tester), [_t2]);
    expect(selected(tester), _t2);
  });

  testWidgets('a related record that cannot be read is left out and the opened T stays', (tester) async {
    final env = await open(tester, hash: _t, records: {_t: _sent(_t, 300, chain: pendingChain)});
    expect(shown(tester), [_t]);
    env.wallets.ping();
    await settle(tester);
    expect(selected(tester), _t);
  });

  testWidgets('pull-to-refresh keeps the selected transaction whether the lookup works or fails', (tester) async {
    final env = await open(tester, hash: _t2, records: pending());
    await tapChip(tester, existingFee);

    env.node.refreshed = Result.success(_sent(_t2, 1000, chain: pendingChain));
    unawaited(model(tester).onRefresh());
    await settle(tester);
    expect(selected(tester), _t, reason: '다시 받은 기록으로 다시 만들어도 고른 T 그대로');

    env.node.refreshed = Result.failure(ErrorCodes.nodeUnknown); // 멤풀 대체 조회도 테스트에서는 실패한다
    unawaited(model(tester).onRefresh());
    await settle(tester);
    expect(shown(tester), [_t2, _t]);
    expect(selected(tester), _t, reason: '조회에 실패해도 0번으로 돌리지 않는다');
  });

  testWidgets('CPFP: the received parent stays selected with its child; a missing child leaves the parent', (
    tester,
  ) async {
    final cpfp = CpfpHistory(
      walletId: 1,
      parentTransactionHash: _parent,
      childTransactionHash: _child,
      originalFee: 1,
      newFee: 5,
      timestamp: DateTime(2026, 11, 3),
    );
    final parent = TransactionRecord(
      _parent,
      DateTime(2026, 11, 3),
      0,
      TransactionType.received,
      null,
      50000,
      141,
      _outputs.toList(),
      _inputs.toList(),
      141,
      DateTime(2026, 11, 3),
      cpfpHistory: cpfp,
    );
    final env = await open(tester, hash: _parent, records: {_parent: parent, _child: _sent(_child, 700)});
    expect(shown(tester), [_parent, _child]);
    expect(selected(tester), _parent);
    env.wallets.ping();
    await settle(tester);
    expect(selected(tester), _parent);

    env.txs.records.remove(_child);
    env.wallets.ping();
    await settle(tester);
    expect(shown(tester), [_parent], reason: '자식 기록이 없어도 멈추지 않는다');
  });

  testWidgets('a memo saved on T replaces T only, so T2 stays first and the saved memo shows', (tester) async {
    final records = pending()..[_t2] = _sent(_t2, 1000, chain: pendingChain, memo: 'T2 메모');
    await open(tester, hash: _t, records: records);
    expect(model(tester).fetchTransactionMemo(), 'T2 메모', reason: 'T에 메모가 없으면 묶음의 가장 최근 메모');

    expect(model(tester).updateTransactionMemo('T 메모'), isTrue);
    await settle(tester);
    expect(shown(tester), [_t2, _t], reason: '0번(T2, 수수료 올리기가 쓰는 거래)을 덮지 않는다');
    expect(model(tester).fetchTransactionMemo(), 'T 메모');
    expect(find.text('T 메모'), findsOneWidget);
  });

  // F1(N1 리뷰): 이 상세에서 직접 수수료를 올려 보내고 돌아오면 보낸 새 거래(T2)가 보여야 한다. N1 뒤에는 옛 거래(T)가 고른 채로
  // 남았다. 보내기 화면이 성공했을 때만 남기는 새 거래로 이 상세를 바꾼다(맨 앞을 따라가는 규칙은 쓰지 않는다)
  testWidgets('a fee bump sent from this detail swaps it for the new transaction, whose memo shows and saves', (
    tester,
  ) async {
    final env = await open(tester, hash: _t, records: {_t: _sent(_t, 300)});
    await tester.tap(find.text(t.quick_send));
    await settle(tester);
    expect(env.feeBumps.single.transaction.transactionHash, _t);

    // 보내기 성공(BroadcastingScreen): 새 거래를 남기고, 보내기 완료로 넘어가며 거래 상세까지만 남기고 치운다. 완료 화면은 메모를
    // 새 거래에 쓴다
    env.txs.records
      ..[_t] = _sent(_t, 300, chain: pendingChain)
      ..[_t2] = _sent(_t2, 1000, chain: pendingChain, memo: '완료 화면 메모');
    RbfSentHandoff.note(_t2);
    unawaited(
      env.navigator.currentState!.pushAndRemoveUntil(
        MaterialPageRoute<void>(
          settings: const RouteSettings(name: AppRouteNames.broadcastingComplete),
          builder: (_) => const Scaffold(body: Text('보내기 완료')),
        ),
        (route) => route.settings.name == AppRouteNames.transactionDetail || route.isFirst,
      ),
    );
    await settle(tester);
    env.navigator.currentState!.pop(); // 완료 화면에서 확인
    await settle(tester);

    expect(tester.widget<TransactionDetailScreen>(find.byType(TransactionDetailScreen)).txHash, _t2);
    expect(shown(tester), [_t2, _t]);
    expect(selected(tester), _t2, reason: '보낸 새 거래가 보인다');
    expect(model(tester).fetchTransactionMemo(), '완료 화면 메모');
    expect(model(tester).updateTransactionMemo('고친 메모'), isTrue);
    expect(env.txs.records[_t2]!.memo, '고친 메모', reason: '메모도 새 거래에 저장된다');
  });

  // 보내지 않은 수수료 올리기(취소, 또는 실패하고 돌아옴)는 보내기 화면이 아무것도 남기지 않아 이 상세와 선택이 그대로다.
  // 수수료 올리기 화면이 닫힌 것만으로는 바꾸지 않고, 앞선 다른 흐름이 남긴 값도 버린다
  for (final stale in [false, true]) {
    testWidgets('a fee bump that was not sent keeps this detail and its selection${stale ? ' (stale handoff)' : ''}', (
      tester,
    ) async {
      final env = await open(tester, hash: _t, records: pending());
      expect(selected(tester), _t);
      if (stale) RbfSentHandoff.note(_t3);
      await tester.tap(find.text(t.quick_send));
      await settle(tester);
      expect(env.feeBumps.single.transaction.transactionHash, _t2, reason: '빨리 보내기는 맨 앞(가장 최근 대체) 거래로 간다');
      env.navigator.currentState!.pop(); // 보내지 않고 돌아옴
      await settle(tester);

      expect(tester.widget<TransactionDetailScreen>(find.byType(TransactionDetailScreen)).txHash, _t);
      expect(selected(tester), _t);
    });
  }

  testWidgets('an alert-opened T that was alone stays selected when its fee-bump chain is recovered', (tester) async {
    final env = await open(tester, hash: _t, records: {_t: _sent(_t, 300)}, safetyIncidents: incidents);
    expect(shown(tester), [_t]);
    env.txs.records
      ..[_t] = _sent(_t, 300, chain: pendingChain)
      ..[_t2] = _sent(_t2, 1000, chain: pendingChain);
    env.wallets.ping();
    await settle(tester);
    expect(shown(tester), [_t2, _t]);
    expect(selected(tester), _t, reason: '맨 앞을 따라가지 않는다(사건 거래 T와 "이 거래 검토"를 지킨다)');
    expect(findText(review), findsOneWidget);
  });

  testWidgets('a further external bump (T3) keeps T2 when the user picked it', (tester) async {
    final env = await open(tester, hash: _t, records: pending());
    await tapChip(tester, newFee);
    expect(selected(tester), _t2);
    final chain = [_t3, _t2, _t];
    env.txs.records
      ..[_t] = _sent(_t, 300, chain: chain)
      ..[_t2] = _sent(_t2, 1000, chain: chain)
      ..[_t3] = _sent(_t3, 2000, chain: chain);
    env.wallets.ping();
    await settle(tester);
    expect(shown(tester), [_t3, _t2, _t]);
    expect(selected(tester), _t2);
  });

  testWidgets("deleting T2's memo does not bring back T's", (tester) async {
    await open(
      tester,
      hash: _t2,
      records: {
        _t: _sent(_t, 300, chain: pendingChain, memo: 'T 메모'),
        _t2: _sent(_t2, 1000, chain: pendingChain, memo: 'T2 메모'),
      },
    );
    expect(model(tester).fetchTransactionMemo(), 'T2 메모');
    expect(model(tester).updateTransactionMemo(''), isTrue); // 메모를 지우면 빈 문자열로 저장된다
    await settle(tester);
    expect(model(tester).fetchTransactionMemo(), '', reason: '지운 메모는 지운 채로(옛 T 메모가 다시 나오지 않는다)');
  });

  testWidgets('pull-to-refresh that falls back to the mempool keeps the selected transaction', (tester) async {
    final env = await open(tester, hash: _t2, records: pending());
    await tapChip(tester, existingFee);
    expect(selected(tester), _t);
    _myAddresses.add(_inputs.single.address); // 멤풀 응답의 입력이 내 주소라 보낸 거래로 읽힌다
    final mempool = _Mempool(
      jsonEncode({
        'txid': _t2,
        'fee': 1200,
        'weight': 564,
        'status': {'confirmed': false},
        'vin': [
          {
            'prevout': {'scriptpubkey_address': _inputs.single.address, 'value': _inputs.single.amount},
          },
        ],
        'vout': [
          {'scriptpubkey_address': _outputs.single.address, 'value': _outputs.single.amount},
        ],
      }),
    );
    env.node.refreshed = Result.failure(ErrorCodes.nodeUnknown);
    await HttpOverrides.runZoned(() async {
      unawaited(model(tester).onRefresh());
      await settle(tester);
    }, createHttpClient: (_) => mempool);

    expect(mempool.requests, 1, reason: '노드 조회가 실패해 멤풀에서 받았다');
    expect(model(tester).transactionList!.first.fee, 1200, reason: '멤풀 기록으로 목록을 다시 만들었다');
    expect(selected(tester), _t, reason: '다시 만들어도 고른 T 그대로');
  });

  // 보내기는 성공했지만 새 거래(T2)가 아직 이 기기에 저장되지 않은 채 완료 화면을 닫으면, 지금 상세에 남았다가 기록이 생기는
  // 갱신에서 새 거래의 상세로 바뀐다(보내기 성공과 저장은 따로 일어난다). 전에는 없는 기록으로 상세를 열어 예외가 났다(Astra 재현)
  testWidgets('a fee bump whose new transaction is not saved yet keeps this detail until the record arrives', (
    tester,
  ) async {
    final env = await open(tester, hash: _t, records: {_t: _sent(_t, 300)});
    await tester.tap(find.text(t.quick_send));
    await settle(tester);
    RbfSentHandoff.note(_t2); // 보내기 성공. T2 기록은 아직 없다
    unawaited(
      env.navigator.currentState!.pushAndRemoveUntil(
        MaterialPageRoute<void>(
          settings: const RouteSettings(name: AppRouteNames.broadcastingComplete),
          builder: (_) => const Scaffold(body: Text('보내기 완료')),
        ),
        (route) => route.settings.name == AppRouteNames.transactionDetail || route.isFirst,
      ),
    );
    await settle(tester);
    env.navigator.currentState!.pop(); // 완료 화면에서 확인
    await settle(tester);
    expect(tester.takeException(), isNull);
    expect(
      tester.widget<TransactionDetailScreen>(find.byType(TransactionDetailScreen)).txHash,
      _t,
      reason: '기록이 생길 때까지',
    );

    env.txs.records
      ..[_t] = _sent(_t, 300, chain: pendingChain)
      ..[_t2] = _sent(_t2, 1000, chain: pendingChain); // 동기화가 저장했다
    env.wallets.ping();
    await settle(tester);
    expect(tester.widget<TransactionDetailScreen>(find.byType(TransactionDetailScreen)).txHash, _t2);
    expect(selected(tester), _t2);
  });

  // 실제 보내기 화면으로 이어 본다: 상세(사건 거래로 엶) → 빨리 보내기 → (서명 뒤) 실제 BroadcastingScreen → 전송 성공 → 실제 완료
  // 화면 → 동기화가 새 거래를 저장 → 완료 화면 닫기 → 새 거래의 상세. 연 목적(purpose, 분석 화면 이름)도 그대로다
  testWidgets('a real RBF send from the detail ends on the new transaction detail with the same purpose', (
    tester,
  ) async {
    await tester.runAsync(() => AssetLottie(TransactionLottiePath.checkSpinning).load());
    final env = await open(tester, hash: _t, records: {_t: _sent(_t, 300)}, purpose: TransactionDetailPurpose.incident);
    await tester.tap(find.text(t.quick_send));
    await settle(tester);
    expect(env.feeBumps.single.feeBumpingType, FeeBumpingType.rbf);

    // 수수료 올리기 → 보내기 확인 → 서명을 마친 것처럼 서명된 대체 거래를 채워 실제 보내기 화면을 연다
    final vault = SingleSignatureVault.fromEntropy(Uint8List(16));
    final inputHash = 'f' * 64;
    final tx = Transaction.withInputsAndOutputs(
      [TransactionInput.forPayment(inputHash, 0, sequence: 0xfffffffd)],
      [
        TransactionOutput.forPayment(
          999000,
          vault.getAddress(1, isChange: true),
          derivationPath: '${vault.derivationPath}/1/1',
          isChangeOutput: true,
        ),
      ],
      AddressType.p2wpkh,
    );
    tx.utxoList.add(Utxo(inputHash, 0, 1000000, '${vault.derivationPath}/0/0'));
    tx.changeAddressDerivationPath = '${vault.derivationPath}/1/1';
    final psbt = Psbt.fromTransaction(tx, vault);
    final signed = Psbt.parse(vault.addSignatureToPsbt(psbt.serialize())).getSignedTransaction(AddressType.p2wpkh);
    final sentHash = signed.transactionHash;
    manager.realm.write(
      () => manager.realm.add(
        UtxoMock.createUnspentRealmUtxo(walletId: 1, address: vault.getAddress(0), transactionHash: inputHash),
      ),
    );
    env.sendInfo
      ..setWalletId(1)
      ..setFeeBumpingType(FeeBumpingType.rbf)
      ..setSendEntryPoint(SendEntryPoint.transactionDetail)
      ..setTxWaitingForSign(psbt.serialize())
      ..setSignedResult(signed.serialize());
    unawaited(
      env.navigator.currentState!.push(
        MaterialPageRoute<void>(builder: (_) => const LoaderOverlay(child: BroadcastingScreen())),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.tap(find.text(t.broadcasting_screen.btn_submit));
    for (var frame = 0; frame < 30 && env.node.broadcasts == 0; frame++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(env.node.broadcasts, 1);
    env.node.sent.complete(Result.success(sentHash));
    var completed = false;
    for (var attempt = 0; attempt < 100 && !completed; attempt++) {
      await tester.pump(const Duration(milliseconds: 50));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      completed = find.byType(BroadcastingCompleteScreen).evaluate().isNotEmpty;
    }
    expect(completed, isTrue, reason: '보내기 완료 화면');

    final chain = [sentHash, _t];
    env.txs.records
      ..[_t] = _sent(_t, 300, chain: chain)
      ..[sentHash] = _sent(sentHash, 1000, chain: chain); // 동기화가 새 거래를 저장했다
    env.wallets.ping();
    await settle(tester);
    env.navigator.currentState!.pop(); // 완료 화면에서 확인
    await settle(tester);

    final detail = find.byType(TransactionDetailScreen);
    expect(tester.widget<TransactionDetailScreen>(detail).txHash, sentHash, reason: '보낸 새 거래의 상세');
    final args = ModalRoute.of(tester.element(detail))!.settings.arguments as TransactionDetailRouteArgs;
    expect(args.purpose, TransactionDetailPurpose.incident, reason: '연 목적(분석 화면 이름)은 그대로');
    expect(selected(tester), sentHash);
  });

  /// 보내기 성공(새 거래 기록은 아직 없음) → 보내기 완료 화면이 위에 뜬 상태까지
  Future<void> sendFeeBumpAndShowCompletion(
    WidgetTester tester,
    ({
      _Wallets wallets,
      _Transactions txs,
      _Node node,
      GlobalKey<NavigatorState> navigator,
      List<TransactionFeeBumpingRouteArgs> feeBumps,
      SendInfoProvider sendInfo,
    })
    env,
  ) async {
    await tester.tap(find.text(t.quick_send));
    await settle(tester);
    RbfSentHandoff.note(_t2);
    unawaited(
      env.navigator.currentState!.pushAndRemoveUntil(
        MaterialPageRoute<void>(
          settings: const RouteSettings(name: AppRouteNames.broadcastingComplete),
          builder: (_) => const Scaffold(body: Text('보내기 완료')),
        ),
        (route) => route.settings.name == AppRouteNames.transactionDetail || route.isFirst,
      ),
    );
    await settle(tester);
  }

  // 기록을 기다리는 1분은 이 상세가 다시 보인 때부터 센다. 완료 화면에서 메모·태그를 오래 써도 돌아오면 새 거래로 바뀐다
  // (전에는 보내기 성공부터 세서 완료 화면에 1분 넘게 있으면 기록이 있어도 바뀌지 않았다, Fable P2)
  testWidgets('a long stay on the completion screen still ends on the new transaction detail', (tester) async {
    var now = DateTime(2026, 11, 12, 12);
    TransactionDetailScreen.now = () => now;
    final env = await open(tester, hash: _t, records: {_t: _sent(_t, 300)});
    await sendFeeBumpAndShowCompletion(tester, env);
    env.txs.records
      ..[_t] = _sent(_t, 300, chain: pendingChain)
      ..[_t2] = _sent(_t2, 1000, chain: pendingChain); // 완료 화면에 있는 동안 저장됐다
    env.wallets.ping();
    await settle(tester);
    now = now.add(const Duration(minutes: 3)); // 완료 화면에서 메모·태그를 3분 동안 썼다
    env.navigator.currentState!.pop();
    await settle(tester);

    expect(tester.widget<TransactionDetailScreen>(find.byType(TransactionDetailScreen)).txHash, _t2);
  });

  // 다시 보인 뒤 1분 안에 새 거래 기록이 오지 않으면 그만 기다리고 지금 상세에 남는다(묶음이 갱신되면 칩으로 새 거래를 고른다)
  testWidgets('a new record that arrives more than a minute after the detail is visible again does not swap', (
    tester,
  ) async {
    var now = DateTime(2026, 11, 12, 12);
    TransactionDetailScreen.now = () => now;
    final env = await open(tester, hash: _t, records: {_t: _sent(_t, 300)});
    await sendFeeBumpAndShowCompletion(tester, env);
    env.navigator.currentState!.pop(); // 기록 없이 돌아옴: 이때부터 1분
    await settle(tester);
    now = now.add(const Duration(seconds: 61));
    env.txs.records
      ..[_t] = _sent(_t, 300, chain: pendingChain)
      ..[_t2] = _sent(_t2, 1000, chain: pendingChain);
    env.wallets.ping();
    await settle(tester);

    expect(tester.widget<TransactionDetailScreen>(find.byType(TransactionDetailScreen)).txHash, _t);
    expect(shown(tester), [_t2, _t], reason: '묶음은 갱신돼 칩으로 새 거래를 고를 수 있다');
  });
}
