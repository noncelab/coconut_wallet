import 'dart:async';
import 'dart:typed_data';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/app/router/app_route_names.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/safety/safety_incident.dart';
import 'package:coconut_wallet/model/safety/safety_state.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/wallet/singlesig_wallet_item.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/model/wallet/wallet_address.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/rescue_ready_provider.dart';
import 'package:coconut_wallet/providers/safety_provider.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/providers/transaction_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/repository/realm/transaction_repository.dart';
import 'package:coconut_wallet/screens/safety/assist/safety_assist_screen.dart';
import 'package:coconut_wallet/services/analytics_service.dart';
import 'package:coconut_wallet/services/model/response/recommended_fee.dart';
import 'package:coconut_wallet/services/premium/entitlement_service.dart';
import 'package:coconut_wallet/services/safety/conflict_analyzer.dart';
import 'package:coconut_wallet/services/safety/sweep_builder.dart';
import 'package:coconut_wallet/utils/result.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../../services/safety/safety_fakes.dart';

const _attackTxid = 'a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1';

SinglesigWalletItem _single(int id, int seed) => SinglesigWalletItem(
  id: id,
  name: 'w$id',
  colorIndex: 0,
  iconIndex: 0,
  descriptor: SingleSignatureVault.fromEntropy(Uint8List.fromList(List.filled(16, seed))).descriptor,
);

class _Wallets extends SafetyWalletsFake {
  _Wallets(super.wallets);

  @override
  WalletAddress getReceiveAddress(int walletId) => throw StateError('no generated address');

  @override
  bool containsAddress(int walletId, String address, {bool? isChange}) => false;

  @override
  int? findWalletIdContainingAddress(String address) => null;
}

/// 전송이 불리면 테스트가 실패한다
class _Node extends SafetyNodeFake {
  @override
  Future<Result<String>> broadcast(Transaction signedTx) => throw StateError('never broadcast');
}

class _NoConflicts extends Fake implements ConflictAnalyzer {
  @override
  Future<List<SweepConflict>> analyze(int walletId, List<String> incidentTxids) async => const [];
}

class _Preferences extends Fake implements PreferenceProvider {
  @override
  BitcoinUnit get currentUnit => BitcoinUnit.btc;

  @override
  bool get isBalanceHidden => true;
}

class _TxRepo extends Fake implements TransactionRepository {
  @override
  TransactionRecord? getTransactionRecord(int walletId, String transactionHash) => null;
}

class _Analytics extends AnalyticsService {
  _Analytics() : super(null, true);

  @override
  Future<void> logEvent({required String eventName, Map<String, Object>? parameters}) async {}
}

/// 흐름 도중에 안전 상태가 바뀌는 SafetyProvider(사건 감지·사용 주의 표시가 그사이 들어온 경우)
class _LiveSafety extends SafetyProvider {
  _LiveSafety(this.current) : super.fixed(null);

  SafetyState current;

  @override
  SafetyState get state => current;
}

void main() {
  setUpAll(() => NetworkType.setNetworkType(NetworkType.regtest));
  tearDown(() {
    SafetyAssistFlow.analyzerOverride = null;
    SafetyAssistFlow.fastFeeRateOverride = null;
    SafetyAssistFlow.nodeFeeRateOverride = null;
  });

  testWidgets('구독이 끝나도 지금 이동 → Safety Assist 검토 화면, 사용자가 누르기 전엔 보내기 확인도 전송도 없다', (tester) async {
    final source = _single(1, 1), vault = _single(2, 2);
    final wallets = _Wallets([source, vault]);
    wallets.utxos[1] = [
      UtxoState(
        transactionHash: '1'.padLeft(64, '0'),
        index: 0,
        amount: 50000,
        derivationPath: '${source.walletBase.derivationPath}/0/0',
        blockHeight: 100,
        to: '',
        timestamp: DateTime(2026, 10, 1),
      ),
    ];
    final rescueState = SafetyState(
      rescue: {1: (destination: RescueDestination(walletId: 2, setAt: DateTime(2026, 10, 1)), draft: null)},
      incidents: [SafetyIncident(walletId: 1, txid: _attackTxid, detectedAt: DateTime(2026, 10, 20))],
    );
    final store = SafetyStoreFake()..state = rescueState;
    final node = _Node();
    final premium = FakeEntitlementService(initial: const PremiumState(PremiumStatus.expired));
    final rescue = RescueReadyProvider(
      walletProvider: wallets,
      nodeProvider: node,
      entitlement: premium,
      store: store,
      fetchFees: () async => RecommendedFee(5, 5, 5, 5, 1),
    );
    addTearDown(() {
      rescue.dispose();
      wallets.dispose();
      node.dispose();
    });
    SafetyAssistFlow.analyzerOverride = (_) => _NoConflicts();
    SafetyAssistFlow.fastFeeRateOverride = () async => 5;
    final sendInfo = SendInfoProvider();
    final pushed = <String>[];
    late BuildContext host;

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<WalletProvider>.value(value: wallets),
          ChangeNotifierProvider<NodeProvider>.value(value: node),
          InheritedProvider<PreferenceProvider>.value(value: _Preferences()),
          Provider<AnalyticsService>.value(value: _Analytics()),
          ChangeNotifierProvider<TransactionProvider>.value(value: TransactionProvider(_TxRepo())),
          ChangeNotifierProvider<SafetyProvider>.value(value: SafetyProvider.fixed(null, state: rescueState)),
          Provider<SendInfoProvider>.value(value: sendInfo),
          Provider<EntitlementService>.value(value: premium),
          ChangeNotifierProvider<RescueReadyProvider>.value(value: rescue),
        ],
        child: MaterialApp(
          theme: buildCoconutThemeData(),
          home: Builder(
            builder: (context) {
              host = context;
              return const Scaffold(body: Text('home'));
            },
          ),
          onGenerateRoute: (settings) {
            pushed.add(settings.name!);
            return MaterialPageRoute(builder: (_) => const Text('send confirm'), settings: settings);
          },
        ),
      ),
    );

    expect(rescue.isPremiumActive, isFalse);
    final moving = rescue.moveNow(host, 1);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('safety-assist-review')), findsOneWidget, reason: '만료돼도 검토까지 간다');
    expect(pushed, isNot(contains(AppRouteNames.sendConfirm)), reason: '사용자가 누르기 전');
    expect(sendInfo.transaction, isNull);

    // 사용자가 검토에서 누르면 기존 보내기 확인으로만 간다(서명·전송은 그 화면 몫)
    await tester.tap(find.byKey(const Key('safety-guide-button')));
    await tester.pumpAndSettle();
    expect(pushed.last, AppRouteNames.sendConfirm);
    expect(sendInfo.sendEntryPoint, SendEntryPoint.home);
    expect(sendInfo.transaction!.outputs.single.getAddress(), vault.walletBase.getAddress(0));
    expect(store.state.appTxidPrefixes, isEmpty);

    // 사용자처럼 보내기 확인 → 검토에서 뒤로 가면 흐름이 닫힌다
    Navigator.of(host).pop();
    await tester.pumpAndSettle();
    Navigator.of(host).pop();
    await tester.pumpAndSettle();
    await moving;
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('수수료를 못 받으면 마지막 초안의 수수료로 검토까지 가고, 다시 계산했다고 하지 않는다', (tester) async {
    final source = _single(1, 1), vault = _single(2, 2);
    final wallets = _Wallets([source, vault]);
    wallets.utxos[1] = [
      UtxoState(
        transactionHash: '1'.padLeft(64, '0'),
        index: 0,
        amount: 50000,
        derivationPath: '${source.walletBase.derivationPath}/0/0',
        blockHeight: 100,
        to: '',
        timestamp: DateTime(2026, 10, 1),
      ),
    ];
    final state = SafetyState(
      rescue: {
        1: (
          destination: RescueDestination(walletId: 2, setAt: DateTime(2026, 10, 1)),
          draft: RescueDraftSummary(
            destinationAddress: vault.walletBase.getAddress(0),
            amount: 48590,
            fee: 1410,
            inputCount: 1,
            feeRate: 7,
            preparedAt: DateTime(2026, 10, 20),
          ),
        ),
      },
    );
    final node = _Node();
    final rescue = RescueReadyProvider(
      walletProvider: wallets,
      nodeProvider: node,
      entitlement: FakeEntitlementService(initial: const PremiumState(PremiumStatus.expired)),
      store: SafetyStoreFake()..state = state,
    );
    addTearDown(() {
      rescue.dispose();
      wallets.dispose();
      node.dispose();
    });
    SafetyAssistFlow.analyzerOverride = (_) => _NoConflicts();
    SafetyAssistFlow.fastFeeRateOverride = () async => null; // 오프라인
    late BuildContext host;
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<WalletProvider>.value(value: wallets),
          ChangeNotifierProvider<NodeProvider>.value(value: node),
          InheritedProvider<PreferenceProvider>.value(value: _Preferences()),
          Provider<AnalyticsService>.value(value: _Analytics()),
          ChangeNotifierProvider<TransactionProvider>.value(value: TransactionProvider(_TxRepo())),
          ChangeNotifierProvider<SafetyProvider>.value(value: SafetyProvider.fixed(null, state: state)),
          Provider<SendInfoProvider>.value(value: SendInfoProvider()),
        ],
        child: MaterialApp(
          theme: buildCoconutThemeData(),
          home: Builder(
            builder: (context) {
              host = context;
              return const Scaffold(body: Text('home'));
            },
          ),
        ),
      ),
    );
    final moving = rescue.moveNow(host, 1);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('safety-assist-review')), findsOneWidget);
    expect(find.text(t.premium.rescue.recalc_note), findsNothing);
    expect(find.text(t.premium.rescue.recalculated), findsNothing);
    Navigator.of(host).pop(); // 검토에서 뒤로 → 흐름이 닫힌다
    await tester.pumpAndSettle();
    await moving;
    expect(find.text('home'), findsOneWidget);
  });

  /// 실제 흐름(Track H)까지 띄우는 공통 준비. [safety]를 바꾸면 흐름이 그 상태를 다시 읽는다
  Future<({BuildContext Function() host, List<String> pushed, SendInfoProvider sendInfo, _LiveSafety safety})> pumpFlow(
    WidgetTester tester, {
    required RescueReadyProvider Function(_Wallets, _Node, SafetyStoreFake) rescueOf,
    required SafetyState state,
  }) async {
    final source = _single(1, 1), vault = _single(2, 2);
    final wallets = _Wallets([source, vault]);
    wallets.utxos[1] = [
      UtxoState(
        transactionHash: '1'.padLeft(64, '0'),
        index: 0,
        amount: 50000,
        derivationPath: '${source.walletBase.derivationPath}/0/0',
        blockHeight: 100,
        to: '',
        timestamp: DateTime(2026, 10, 1),
      ),
    ];
    final node = _Node();
    final store = SafetyStoreFake()..state = state;
    final rescue = rescueOf(wallets, node, store);
    final safety = _LiveSafety(state);
    final sendInfo = SendInfoProvider();
    final pushed = <String>[];
    late BuildContext host;
    addTearDown(() {
      rescue.dispose();
      wallets.dispose();
      node.dispose();
    });
    SafetyAssistFlow.analyzerOverride = (_) => _NoConflicts();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<WalletProvider>.value(value: wallets),
          ChangeNotifierProvider<NodeProvider>.value(value: node),
          InheritedProvider<PreferenceProvider>.value(value: _Preferences()),
          Provider<AnalyticsService>.value(value: _Analytics()),
          ChangeNotifierProvider<TransactionProvider>.value(value: TransactionProvider(_TxRepo())),
          ChangeNotifierProvider<SafetyProvider>.value(value: safety),
          Provider<SendInfoProvider>.value(value: sendInfo),
          ChangeNotifierProvider<RescueReadyProvider>.value(value: rescue),
        ],
        child: MaterialApp(
          theme: buildCoconutThemeData(),
          home: Builder(
            builder: (context) {
              host = context;
              return const Scaffold(body: Text('home'));
            },
          ),
          onGenerateRoute: (settings) {
            pushed.add(settings.name!);
            return MaterialPageRoute(builder: (_) => const Text('send confirm'), settings: settings);
          },
        ),
      ),
    );
    return (host: () => host, pushed: pushed, sendInfo: sendInfo, safety: safety);
  }

  final toVault = SafetyState(
    rescue: {1: (destination: RescueDestination(walletId: 2, setAt: DateTime(2026, 10, 1)), draft: null)},
  );
  RescueReadyProvider Function(_Wallets, _Node, SafetyStoreFake) rescueWith(PremiumStatus status) =>
      (wallets, node, store) => RescueReadyProvider(
        walletProvider: wallets,
        nodeProvider: node,
        entitlement: FakeEntitlementService(initial: PremiumState(status)),
        store: store,
        fetchFees: () async => RecommendedFee(5, 5, 5, 5, 1),
      );

  testWidgets('분석하는 동안 목적지가 제외되면 검토로 가지 않는다(리뷰 I-1)', (tester) async {
    final feeGate = Completer<double?>();
    SafetyAssistFlow.fastFeeRateOverride = () => feeGate.future;
    final env = await pumpFlow(tester, rescueOf: rescueWith(PremiumStatus.active), state: toVault);
    final rescue = env.host().read<RescueReadyProvider>();
    final moving = rescue.moveNow(env.host(), 1);
    await tester.pump();

    env.safety.current = env.safety.current.copyWith(cautionWalletIds: {2}); // 그사이 사용 주의
    feeGate.complete(5);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('safety-assist-review')), findsNothing);
    expect(env.pushed, isNot(contains(AppRouteNames.sendConfirm)));
    expect(env.sendInfo.transaction, isNull);
    Navigator.of(env.host()).popUntil((route) => route.isFirst);
    await tester.pumpAndSettle();
    await moving;
    await tester.pump(const Duration(seconds: 6)); // 안내 토스트 타이머
  });

  testWidgets('검토를 연 뒤 목적지가 제외되면 눌러도 보내기 확인으로 넘기지 않는다(리뷰 I-1)', (tester) async {
    SafetyAssistFlow.fastFeeRateOverride = () async => 5;
    final env = await pumpFlow(tester, rescueOf: rescueWith(PremiumStatus.active), state: toVault);
    final moving = env.host().read<RescueReadyProvider>().moveNow(env.host(), 1);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('safety-assist-review')), findsOneWidget);

    env.safety.current = env.safety.current.copyWith(
      incidents: [SafetyIncident(walletId: 2, txid: _attackTxid, detectedAt: DateTime(2026, 10, 20))],
    );
    await tester.tap(find.byKey(const Key('safety-guide-button')));
    await tester.pumpAndSettle();
    expect(env.pushed, isNot(contains(AppRouteNames.sendConfirm)));
    expect(env.sendInfo.transaction, isNull);
    Navigator.of(env.host()).pop();
    await tester.pumpAndSettle();
    await moving;
    await tester.pump(const Duration(seconds: 6)); // 안내 토스트 타이머
  });

  testWidgets('목적지가 그사이 사용 주의가 되면 옮기지 않고 알린다', (tester) async {
    final wallets = _Wallets([_single(1, 1), _single(2, 2)]);
    final store =
        SafetyStoreFake()
          ..state = SafetyState(
            cautionWalletIds: const {2},
            rescue: {1: (destination: RescueDestination(walletId: 2, setAt: DateTime(2026, 10, 1)), draft: null)},
          );
    final node = _Node();
    final rescue = RescueReadyProvider(
      walletProvider: wallets,
      nodeProvider: node,
      entitlement: FakeEntitlementService(initial: const PremiumState(PremiumStatus.active)),
      store: store,
    );
    addTearDown(() {
      rescue.dispose();
      wallets.dispose();
      node.dispose();
    });
    late BuildContext host;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildCoconutThemeData(),
        home: Builder(
          builder: (context) {
            host = context;
            return const Scaffold(body: Text('home'));
          },
        ),
      ),
    );
    await rescue.moveNow(host, 1);
    await tester.pump();
    expect(find.text(t.premium.rescue.destination_invalid), findsOneWidget);
    expect(find.byKey(const Key('safety-assist-review')), findsNothing);
    await tester.pump(const Duration(seconds: 4));
  });
}
