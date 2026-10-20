import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/safety/safety_check.dart';
import 'package:coconut_wallet/model/safety/safety_incident.dart';
import 'package:coconut_wallet/model/safety/safety_state.dart';
import 'package:coconut_wallet/model/safety/wallet_health_report.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/providers/auth_provider.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/rescue_ready_provider.dart';
import 'package:coconut_wallet/providers/safety_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/services/premium/entitlement_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

/// Wallet Health 위젯 테스트 공용 보고서·하네스(엔진을 거치지 않고 화면 상태를 고정한다)

const reusedAddresses = ['bc1qreuse0000000000000000000000000000000001', 'bc1qreuse0000000000000000000000000000000002'];

Map<SafetyCategory, CategoryScore> categories({
  int? app = 100,
  int? recovery = 80,
  int? activity = 90,
  int? privacy = 70,
  int recoveryIssues = 1,
  int privacyIssues = 1,
  NotApplicableReason waiting = NotApplicableReason.noFunds,
}) => {
  SafetyCategory.app: CategoryScore(category: SafetyCategory.app, score: app, weightPercent: app == null ? 0 : 15),
  SafetyCategory.recovery: CategoryScore(
    category: SafetyCategory.recovery,
    score: recovery,
    weightPercent: recovery == null ? 0 : 45,
    issueCount: recovery == null ? 0 : recoveryIssues,
    waitingReason: recovery == null ? waiting : null,
  ),
  SafetyCategory.activity: CategoryScore(
    category: SafetyCategory.activity,
    score: activity,
    weightPercent: activity == null ? 0 : 25,
    waitingReason: activity == null ? NotApplicableReason.noHistory : null,
  ),
  SafetyCategory.privacy: CategoryScore(
    category: SafetyCategory.privacy,
    score: privacy,
    weightPercent: privacy == null ? 0 : 15,
    issueCount: privacy == null ? 0 : privacyIssues,
    waitingReason: privacy == null ? NotApplicableReason.noReceiveHistory : null,
  ),
};

const _allGood = [
  SafetyCheckResult(SafetyCheckId.appLock, SafetyOutcome.passed),
  SafetyCheckResult(SafetyCheckId.appUpdate, SafetyOutcome.passed),
];

/// WH-S1(issues) / WH-S2(issues: false)
WalletHealthReport scoredReport({int score = 86, bool issues = true, bool connected = true}) => WalletHealthReport(
  status: WalletHealthStatus.scored,
  score: score,
  label: WalletHealthLabel.of(score),
  profile: WeightProfile.mixed,
  categories: categories(recoveryIssues: issues ? 1 : 0, privacyIssues: issues ? 1 : 0),
  recovery: const [
    WalletRecoveryContribution(
      walletId: 1,
      kind: SafetyWalletKind.watchOnly,
      balanceSats: 5000000,
      score: 0,
      weight: 2.2,
      failing: [SafetyCheckId.watchOnlyVerify],
    ),
  ],
  reviewItems:
      issues
          ? const [
            SafetyCheckResult(
              SafetyCheckId.watchOnlyVerify,
              SafetyOutcome.failed,
              walletId: 1,
              severity: SafetySeverity.actionNeeded,
            ),
            SafetyCheckResult(
              SafetyCheckId.addressReuse,
              SafetyOutcome.failed,
              walletId: 1,
              severity: SafetySeverity.warning,
              subjects: reusedAddresses,
            ),
          ]
          : const [],
  allGoodItems: const [
    ..._allGood,
    SafetyCheckResult(SafetyCheckId.unrecognizedOutgoing, SafetyOutcome.passed),
    SafetyCheckResult(SafetyCheckId.possibleDusting, SafetyOutcome.passed, evidence: SafetyEvidence.heuristic),
  ],
  notIncluded: const [
    SafetyCheckResult(SafetyCheckId.metadataBackup, SafetyOutcome.notApplicable, reason: NotApplicableReason.noLabels),
  ],
  recommended: const [RecommendedItem(id: RecommendedCheckId.hotPhysicalBackup)],
  walletCount: 2,
  fundedWalletCount: 1,
  evaluatedAt: DateTime.now().subtract(const Duration(minutes: 8)),
  isConnected: connected,
);

/// WH-S4
WalletHealthReport notEnoughDataReport() => WalletHealthReport(
  status: WalletHealthStatus.notEnoughData,
  profile: WeightProfile.watchOnlyOnly,
  categories: categories(recovery: null, activity: null, privacy: null),
  allGoodItems: _allGood,
  notIncluded: const [
    SafetyCheckResult(
      SafetyCheckId.mnemonicBackup,
      SafetyOutcome.notApplicable,
      walletId: 1,
      reason: NotApplicableReason.noFunds,
    ),
    SafetyCheckResult(
      SafetyCheckId.unrecognizedOutgoing,
      SafetyOutcome.notApplicable,
      reason: NotApplicableReason.noHistory,
    ),
    SafetyCheckResult(
      SafetyCheckId.addressReuse,
      SafetyOutcome.notApplicable,
      reason: NotApplicableReason.noReceiveHistory,
    ),
    SafetyCheckResult(
      SafetyCheckId.possibleDusting,
      SafetyOutcome.notApplicable,
      reason: NotApplicableReason.noUtxoHistory,
    ),
    SafetyCheckResult(
      SafetyCheckId.passphraseVerify,
      SafetyOutcome.notApplicable,
      reason: NotApplicableReason.noPassphrase,
    ),
  ],
  walletCount: 1,
  evaluatedAt: DateTime.now().subtract(const Duration(minutes: 8)),
);

/// WH-S0
WalletHealthReport noWalletReport() => WalletHealthReport(
  status: WalletHealthStatus.noWallet,
  profile: WeightProfile.watchOnlyOnly,
  categories: categories(recovery: null, activity: null, privacy: null, waiting: NotApplicableReason.noWallet),
  allGoodItems: _allGood,
  notIncluded: const [
    SafetyCheckResult(
      SafetyCheckId.unrecognizedOutgoing,
      SafetyOutcome.notApplicable,
      reason: NotApplicableReason.noWallet,
    ),
    SafetyCheckResult(SafetyCheckId.txConflict, SafetyOutcome.notApplicable, reason: NotApplicableReason.noWallet),
    SafetyCheckResult(SafetyCheckId.addressReuse, SafetyOutcome.notApplicable, reason: NotApplicableReason.noWallet),
    SafetyCheckResult(SafetyCheckId.possibleDusting, SafetyOutcome.notApplicable, reason: NotApplicableReason.noWallet),
    SafetyCheckResult(
      SafetyCheckId.serverCert,
      SafetyOutcome.notApplicable,
      reason: NotApplicableReason.notCustomServer,
    ),
  ],
  evaluatedAt: DateTime.now().subtract(const Duration(minutes: 8)),
);

/// WH-S3(모르는 출금). 점수는 보존된다
WalletHealthReport criticalReport({int incidents = 1}) => WalletHealthReport(
  status: WalletHealthStatus.criticalOverride,
  score: 76,
  label: WalletHealthLabel.good,
  profile: WeightProfile.hotFunded,
  categories: categories(privacyIssues: 0),
  criticalIncidents: [
    for (var i = 0; i < incidents; i++)
      SafetyIncident(walletId: 1, txid: '$i' * 64, detectedAt: DateTime.now().subtract(Duration(minutes: 3 + i))),
  ],
  reviewItems: const [
    SafetyCheckResult(SafetyCheckId.appLock, SafetyOutcome.failed, severity: SafetySeverity.actionNeeded),
  ],
  walletCount: 1,
  fundedWalletCount: 1,
  evaluatedAt: DateTime.now(),
);

/// 다시 검사 횟수를 센다. 실제 fixed provider의 검사(1.2초 이상 검사 중)는 그대로 돈다
class FakeSafetyProvider extends SafetyProvider {
  FakeSafetyProvider(super.report, {super.state}) : super.fixed();

  int checks = 0;
  int refreshes = 0;
  final recommendedDone = <RecommendedCheckId, bool>{};

  @override
  Future<void> checkAgain() {
    checks++;
    return super.checkAgain();
  }

  @override
  Future<void> refresh() {
    refreshes++;
    return super.refresh();
  }

  @override
  Future<void> setRecommendedDone(RecommendedCheckId id, bool done) async => recommendedDone[id] = done;
}

/// 다시 검사가 곧바로 끝나거나 실패하는 provider(화면의 최소 700ms만 따로 본다)
class InstantSafetyProvider extends FakeSafetyProvider {
  InstantSafetyProvider(super.report, {this.error});

  final Object? error;

  @override
  Future<void> checkAgain() async {
    checks++;
    if (error case final error?) throw error;
  }
}

/// 잔액 숨김·가짜 잔액만 고정한 설정
class FakePreferences extends ChangeNotifier implements PreferenceProvider {
  FakePreferences({this.isBalanceHidden = false, this.isFakeBalanceActive = false});

  @override
  final bool isBalanceHidden;

  @override
  final bool isFakeBalanceActive;

  @override
  BitcoinUnit get currentUnit => BitcoinUnit.btc;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// PIN 설정 시트를 열 수 있을 만큼만 아는 AuthProvider
class FakeAuth extends ChangeNotifier implements AuthProvider {
  @override
  int get pinLength => 4;

  @override
  bool get isSetPin => false;

  @override
  List<String> getShuffledNumberPad({bool isSettings = false}) => [for (var i = 1; i <= 9; i++) '$i', '', '0', '<'];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// 지갑별 비상 이동 상태와 초안만 고정한 Rescue-ready
class FakeRescueReady extends ChangeNotifier implements RescueReadyProvider {
  FakeRescueReady({this.statuses = const {}, this.drafts = const {}});

  final Map<int, RescueStatus> statuses;

  @override
  final Map<int, RescueDraftSummary> drafts;

  @override
  int get readyWalletCount => drafts.values.where((d) => d.blocker == null).length;

  @override
  RescueStatus statusOf(int walletId) => statuses[walletId] ?? RescueStatus.notSet;

  @override
  bool canMoveNow(int walletId) => drafts.containsKey(walletId) && drafts[walletId]!.blocker == null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

RescueDraftSummary readyDraft() => RescueDraftSummary(
  destinationAddress: 'bc1qdestination',
  amount: 100000,
  fee: 300,
  inputCount: 1,
  feeRate: 2,
  preparedAt: DateTime.now().subtract(const Duration(minutes: 3)),
);

/// 지갑 목록과 UTXO만 아는 WalletProvider(거래 기록은 없음)
class FakeWallets extends ChangeNotifier implements WalletProvider {
  FakeWallets(this.walletItemList, {this.utxos = const {}});

  @override
  final List<WalletItemBase> walletItemList;

  /// 지갑별 UTXO
  final Map<int, List<UtxoState>> utxos;

  @override
  TransactionRecord? getTransactionRecord(int walletId, String transactionHash) => null;

  @override
  List<UtxoState> getUtxoList(int walletId) => utxos[walletId] ?? const [];

  @override
  UtxoState? getUtxoState(int walletId, String utxoId) =>
      getUtxoList(walletId).where((u) => u.utxoId == utxoId).firstOrNull;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// [child] 위에 Wallet Health가 읽는 provider를 깐다. 기본은 동작 줄이기(타이머·반짝임 없이 최종 상태)
Future<FakeSafetyProvider> pumpWalletHealthApp(
  WidgetTester tester,
  Widget child, {
  WalletHealthReport? report,
  SafetyState? state,
  CoconutThemeVariant variant = CoconutThemeVariant.light,
  AppLocale locale = AppLocale.ko,
  double width = 390,
  double height = 2400,
  double textScale = 1,
  bool reduceMotion = true,
  PremiumState? premium,
  RescueReadyProvider? rescue,
  List<WalletItemBase>? wallets,
  Map<int, List<UtxoState>> utxos = const {},
  PreferenceProvider? preferences,
  FakeSafetyProvider? safety,
  List<SingleChildWidget> extra = const [],
  bool settle = true,
}) async {
  LocaleSettings.setLocaleSync(locale);
  addTearDown(() => LocaleSettings.setLocaleSync(AppLocale.ko));
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final provider = safety ?? FakeSafetyProvider(report, state: state);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<SafetyProvider>.value(value: provider),
        if (premium != null) Provider<EntitlementService>.value(value: FakeEntitlementService(initial: premium)),
        if (rescue != null) ChangeNotifierProvider<RescueReadyProvider>.value(value: rescue),
        if (wallets != null) ChangeNotifierProvider<WalletProvider>.value(value: FakeWallets(wallets, utxos: utxos)),
        if (preferences != null) ChangeNotifierProvider<PreferenceProvider>.value(value: preferences),
        ...extra,
      ],
      child: MaterialApp(
        theme: buildCoconutThemeData(variant: variant),
        builder:
            (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(disableAnimations: reduceMotion, textScaler: TextScaler.linear(textScale)),
              child: child!,
            ),
        home: child,
      ),
    ),
  );
  if (settle) await tester.pumpAndSettle();
  return provider;
}
