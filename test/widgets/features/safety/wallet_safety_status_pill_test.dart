import 'package:coconut_wallet/app/router/app_route_names.dart';
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/safety/safety_check.dart';
import 'package:coconut_wallet/model/safety/safety_incident.dart';
import 'package:coconut_wallet/model/safety/safety_state.dart';
import 'package:coconut_wallet/model/safety/wallet_health_report.dart';
import 'package:coconut_wallet/providers/safety_provider.dart';
import 'package:coconut_wallet/screens/safety/wallet_health_screen.dart';
import 'package:coconut_wallet/widgets/common/buttons/shrink_animation_button.dart';
import 'package:coconut_wallet/widgets/features/safety/wallet_safety_status_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

const _pill = Key('wallet-safety-status-pill');

WalletHealthReport _report({
  List<SafetyCheckResult> issues = const [],
  List<SafetyIncident> incidents = const [],
  bool checked = true,
}) => WalletHealthReport(
  status: incidents.isNotEmpty ? WalletHealthStatus.criticalOverride : WalletHealthStatus.scored,
  profile: WeightProfile.watchOnlyOnly,
  evaluatedAt: DateTime(2026),
  reviewItems: issues,
  criticalIncidents: incidents,
  allGoodItems:
      checked ? [const SafetyCheckResult(SafetyCheckId.watchOnlyVerify, SafetyOutcome.passed, walletId: 1)] : [],
);

const _attention = SafetyCheckResult(
  SafetyCheckId.addressReuse,
  SafetyOutcome.failed,
  walletId: 1,
  severity: SafetySeverity.actionNeeded,
);
const _criticalCheck = SafetyCheckResult(
  SafetyCheckId.watchOnlyVerify,
  SafetyOutcome.failed,
  walletId: 1,
  severity: SafetySeverity.critical,
);

Finder _svg(String asset) => find.byWidgetPredicate(
  (w) => w is SvgPicture && w.bytesLoader is SvgAssetLoader && (w.bytesLoader as SvgAssetLoader).assetName == asset,
);

void main() {
  late List<String?> pushed;

  Future<void> mount(
    WidgetTester tester,
    SafetyProvider? safety, {
    CoconutThemeVariant theme = CoconutThemeVariant.light,
    double width = 390,
    double textScale = 1.0,
    VoidCallback? onPressed,
  }) async {
    LocaleSettings.setLocaleSync(AppLocale.ko);
    pushed = [];
    tester.view.physicalSize = Size(width, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    if (safety != null) addTearDown(safety.dispose);
    Widget app = MaterialApp(
      theme: buildCoconutThemeData(variant: theme),
      builder:
          (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
      // 사건 상세는 이름 있는 경로로 연다: 이름만 기록하고 빈 화면을 띄운다
      onGenerateRoute: (settings) {
        pushed.add(settings.name);
        return MaterialPageRoute<void>(settings: settings, builder: (_) => const Scaffold());
      },
      home: Scaffold(body: Column(children: [WalletSafetyStatusPill(walletId: 1, onPressed: onPressed)])),
    );
    if (safety != null) app = ChangeNotifierProvider<SafetyProvider>.value(value: safety, child: app);
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
  }

  testWidgets('without SafetyProvider the pill and its top spacing are not drawn', (tester) async {
    await mount(tester, null);
    expect(find.byKey(_pill), findsNothing);
    expect(tester.getSize(find.byType(WalletSafetyStatusPill)).height, 0);
  });

  for (final theme in CoconutThemeVariant.values) {
    final colors = resolveCoconutThemeExtension(variant: theme).colors;
    final cases = <String, (SafetyProvider Function(), String, String, Color, Color, Color)>{
      'waiting': (
        () => SafetyProvider.fixed(null),
        t.wallet_health.wallet_info.waiting,
        CommonStateIconPath.shieldCheck,
        colors.iconSecondary,
        colors.surfaceInfoChip,
        colors.secondaryTextStrong,
      ),
      'no issues': (
        () => SafetyProvider.fixed(_report()),
        t.wallet_health.wallet_info.no_issues,
        CommonStateIconPath.shieldCheck,
        colors.secondaryTextStrong,
        colors.surfaceInfoChip,
        colors.secondaryTextStrong,
      ),
      'needs attention': (
        () => SafetyProvider.fixed(_report(issues: [_attention])),
        t.wallet_health.wallet_info.needs_attention(n: 1),
        CommonStateIconPath.triangleWarning,
        colors.warningText,
        colors.warningSurface,
        colors.warningText,
      ),
      'caution': (
        () => SafetyProvider.fixed(_report(), state: SafetyState.initial().copyWith(cautionWalletIds: {1})),
        t.wallet_health.wallet_info.caution,
        CommonStateIconPath.triangleWarning,
        colors.danger,
        colors.dangerSurface,
        colors.dangerText,
      ),
      'critical': (
        () => SafetyProvider.fixed(_report(issues: [_criticalCheck])),
        t.wallet_health.wallet_info.critical,
        CommonStateIconPath.siren,
        colors.danger,
        colors.dangerSurface,
        colors.dangerText,
      ),
    };
    for (final MapEntry(key: name, value: (safety, text, icon, iconColor, background, textColor)) in cases.entries) {
      testWidgets('${theme.name} $name: same judgement as the wallet info row, chip colour pairs on a tinted fill', (
        tester,
      ) async {
        await mount(tester, safety(), theme: theme);
        final pill = find.byKey(_pill);
        expect(pill, findsOneWidget);
        expect(tester.widget<ShrinkAnimationButton>(pill).defaultColor, background);
        final state = tester.widget<Text>(find.text(text));
        expect(state.style!.color, textColor);
        expect(state.maxLines, 2); // 길면 두 줄, 말줄임 없음
        expect(state.overflow, isNot(TextOverflow.ellipsis));
        expect(
          tester.widget<Text>(find.text('${t.wallet_health.wallet_info.safety_status} · ')).style!.color,
          textColor,
        );
        final svg = tester.widget<SvgPicture>(find.descendant(of: pill, matching: _svg(icon)));
        expect(svg.colorFilter, ColorFilter.mode(iconColor, BlendMode.srcIn));
        // 누르는 영역(알약 + 위아래 6)은 44 이상
        final hitArea = find.ancestor(of: pill, matching: find.byType(GestureDetector)).first;
        expect(tester.getSize(hitArea).height, greaterThanOrEqualTo(44));
      });
    }
  }

  testWidgets('one button for screen readers with the chip label', (tester) async {
    final semantics = tester.ensureSemantics();
    await mount(tester, SafetyProvider.fixed(_report(issues: [_attention])));
    expect(
      find.bySemanticsLabel(
        t.wallet_health.status_chip.a11y(status: t.wallet_health.wallet_info.needs_attention(n: 1)),
      ),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('at 320 dp and 1.3x a long state wraps instead of overflowing', (tester) async {
    await mount(tester, SafetyProvider.fixed(_report(issues: [_attention])), width: 320, textScale: 1.3);
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byKey(_pill)).width, lessThanOrEqualTo(320));
  });

  testWidgets('tap: this wallet sheet (logged once), never the whole Health screen', (tester) async {
    var logged = 0;
    await mount(tester, SafetyProvider.fixed(_report(issues: [_attention])), onPressed: () => logged++);
    await tester.tap(find.byKey(_pill));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('wallet-health-wallet-sheet')), findsOneWidget);
    expect(find.byType(WalletHealthScreen), findsNothing);
    expect(logged, 1);
  });

  testWidgets('a tap just above the pill still opens it (44 touch height)', (tester) async {
    var logged = 0;
    await mount(tester, SafetyProvider.fixed(_report()), onPressed: () => logged++);
    await tester.tapAt(tester.getRect(find.byKey(_pill)).topCenter - const Offset(0, 4));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('wallet-health-wallet-sheet')), findsOneWidget);
    expect(logged, 1);
  });

  testWidgets('tap on a critical check (no incident) opens Wallet Health', (tester) async {
    await mount(tester, SafetyProvider.fixed(_report(issues: [_criticalCheck])));
    await tester.tap(find.byKey(_pill));
    await tester.pumpAndSettle();
    expect(find.byType(WalletHealthScreen), findsOneWidget);
    expect(find.byKey(const Key('wallet-health-wallet-sheet')), findsNothing);
  });

  testWidgets('tap on a critical incident opens its transaction detail', (tester) async {
    final incident = SafetyIncident(walletId: 1, txid: 'tx-1', detectedAt: DateTime(2026));
    await mount(tester, SafetyProvider.fixed(_report(incidents: [incident])));
    expect(find.text(t.wallet_health.wallet_info.critical), findsOneWidget);
    await tester.tap(find.byKey(_pill));
    await tester.pumpAndSettle();
    expect(pushed, [AppRouteNames.transactionDetail]);
    expect(find.byKey(const Key('wallet-health-wallet-sheet')), findsNothing);
  });
}
