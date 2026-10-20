import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/home/home_item.dart';
import 'package:coconut_wallet/model/home/home_item_definition.dart';
import 'package:coconut_wallet/model/home/home_item_ids.dart';
import 'package:coconut_wallet/model/safety/safety_check.dart';
import 'package:coconut_wallet/model/safety/safety_incident.dart';
import 'package:coconut_wallet/model/safety/wallet_health_report.dart';
import 'package:coconut_wallet/providers/safety_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/services/feature/safety_features.dart';
import 'package:coconut_wallet/services/home/builtin_home_widgets.dart';
import 'package:coconut_wallet/services/home/safety_widget_definitions.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/home_widget_parts.dart';
import 'package:coconut_wallet/widgets/features/safety/safety_common_widgets.dart' show safetyKoText;
import 'package:coconut_wallet/widgets/features/safety/safety_score_gauge.dart';
import 'package:coconut_wallet/widgets/features/safety/safety_status_widget_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import '../../../services/safety/safety_fakes.dart';

/// 무한 애니메이션 등으로 멈추면 공유 레인을 오래 잡지 않게
const _timeout = Timeout(Duration(seconds: 60));

WalletHealthReport _report(
  WalletHealthStatus status, {
  int? score,
  List<SafetyIncident> incidents = const [],
  List<SafetyCheckResult> review = const [],
  DateTime? evaluatedAt,
}) => WalletHealthReport(
  status: status,
  score: score,
  profile: WeightProfile.hotFunded,
  criticalIncidents: incidents,
  reviewItems: review,
  allGoodItems: const [SafetyCheckResult(SafetyCheckId.appLock, SafetyOutcome.passed)],
  evaluatedAt: evaluatedAt ?? DateTime.now(),
);

final _scored = _report(WalletHealthStatus.scored, score: 92);
final _attention = _report(
  WalletHealthStatus.scored,
  score: 70,
  review: const [
    SafetyCheckResult(SafetyCheckId.addressReuse, SafetyOutcome.failed, severity: SafetySeverity.warning),
    SafetyCheckResult(SafetyCheckId.mnemonicBackup, SafetyOutcome.failed, severity: SafetySeverity.actionNeeded),
  ],
);
final _critical = _report(
  WalletHealthStatus.criticalOverride,
  score: 80,
  incidents: [SafetyIncident(walletId: 1, txid: 'a', detectedAt: DateTime(2026, 10, 20))],
);

/// 사건 밖 위급(서버 신원)
final _cert = _report(
  WalletHealthStatus.criticalOverride,
  score: 80,
  review: const [SafetyCheckResult(SafetyCheckId.serverCert, SafetyOutcome.failed, severity: SafetySeverity.critical)],
);
final _several = _report(
  WalletHealthStatus.criticalOverride,
  score: 80,
  incidents: [
    SafetyIncident(walletId: 1, txid: 'a', detectedAt: DateTime(2026, 10, 20)),
    SafetyIncident(walletId: 1, txid: 'b', detectedAt: DateTime(2026, 10, 20)),
  ],
);

/// 홈 그리드 칸(320dp: 63, 344dp: 69, 412dp: 86) 기준 2×2·4×2 크기
Size _tileSize(HomeSpan span, double cell) => Size(span.width * cell + (span.width - 1) * 12, span.height * cell + 12);

Future<void> _pump(
  WidgetTester tester,
  HomeSpan span, {
  WalletHealthReport? report,
  bool withSafety = true,
  double cell = 69,
  double textScale = 1.2,
}) async {
  final size = _tileSize(span, cell);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        if (withSafety) ChangeNotifierProvider<SafetyProvider>.value(value: SafetyProvider.fixed(report)),
        ChangeNotifierProvider<WalletProvider>.value(value: SafetyWalletsFake([safetyWallet(id: 1)])),
      ],
      child: MaterialApp(
        theme: buildCoconutThemeData(),
        builder:
            (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
              // 홈 타일처럼 글자 배율을 1.2에서 멈춘다
              child: MediaQuery.withClampedTextScaling(maxScaleFactor: kHomeTileMaxTextScale, child: child!),
            ),
        home: Scaffold(body: Center(child: SizedBox.fromSize(size: size, child: SafetyStatusWidgetView(span: span)))),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  for (final span in [HomeSpan.small, HomeSpan.wide]) {
    final name = span == HomeSpan.small ? '2×2' : '4×2';

    testWidgets('$name: skeleton before the first check, nothing without the provider', (tester) async {
      await _pump(tester, span);
      expect(find.byKey(const Key('home-widget-skeleton')), findsOneWidget);
      await _pump(tester, span, report: _scored, withSafety: false);
      expect(find.byType(Text), findsNothing);
      expect(find.byKey(const Key('home-widget-skeleton')), findsNothing);
    }, timeout: _timeout);

    testWidgets('$name: W1 no issues, W2 items to check, W3 critical — without overflow on 344dp and 412dp', (
      tester,
    ) async {
      for (final cell in [69.0, 86.0]) {
        await _pump(tester, span, report: _scored, cell: cell);
        expect(find.text(safetyKoText(t.wallet_health.summary.no_issues_found)), findsOneWidget);
        expect(find.byType(HealthGauge), span == HomeSpan.wide ? findsOneWidget : findsNothing);

        await _pump(tester, span, report: _attention, cell: cell);
        expect(find.text(safetyKoText(t.wallet_health.status_chip.attention(n: 2))), findsOneWidget);
        if (span == HomeSpan.wide) {
          // 가장 급한 항목(조치 필요)이 먼저
          final firstItem = '${t.wallet_health.check.mnemonic_backup.name} ${t.wallet_health.widget.more_items(n: 1)}';
          expect(find.text(firstItem), findsOneWidget);
        }

        await _pump(tester, span, report: _critical, cell: cell);
        expect(find.text(safetyKoText(t.wallet_health.widget.outgoing_short)), findsOneWidget);
        expect(find.text(t.wallet_health.incident.review_now), findsOneWidget);
        if (span == HomeSpan.wide) {
          expect(find.text('Test · ${t.wallet_health.incident.tx_state.unconfirmed}'), findsOneWidget);
        }
        expect(tester.takeException(), isNull, reason: '$name cell $cell');
      }
    }, timeout: _timeout);
  }

  // POLISH §5: 가장 좁은 폰(320dp)과 큰 글자. 시스템 1.3×·2.0×는 타일 안에서 1.2×로 멈춘다
  testWidgets('every state fits 2×2 and 4×2 at 320/344/412dp with 1.3× and 2.0× system text', (tester) async {
    final states = {
      'W1': _scored,
      'S0': _report(WalletHealthStatus.noWallet),
      'W2': _attention,
      'W3': _critical,
      'W3 cause': _cert,
      'W3 several': _several,
    };
    for (final span in [HomeSpan.small, HomeSpan.wide]) {
      for (final cell in [63.0, 69.0, 86.0]) {
        for (final scale in [1.3, 2.0]) {
          for (final MapEntry(key: name, value: report) in states.entries) {
            await _pump(tester, span, report: report, cell: cell, textScale: scale);
            expect(tester.takeException(), isNull, reason: '$name $span cell $cell ×$scale');
          }
        }
      }
    }
  }, timeout: _timeout);

  testWidgets('no wallet: up to date with the add-a-wallet line', (tester) async {
    await _pump(tester, HomeSpan.small, report: _report(WalletHealthStatus.noWallet));
    expect(find.text(safetyKoText(t.wallet_health.status_chip.up_to_date)), findsOneWidget);
    expect(find.text(safetyKoText(t.wallet_health.widget.no_wallet)), findsOneWidget);
  }, timeout: _timeout);

  test('two Safety Status widgets, one size each, in the safety category', () {
    final definitions = safetyHomeWidgets();
    expect(definitions.map((definition) => definition.id), [
      HomeItemIds.safetyStatusSmall,
      HomeItemIds.safetyStatusWide,
    ]);
    expect(definitions.map((definition) => definition.supportedSpans), [
      [HomeSpan.small],
      [HomeSpan.wide],
    ]);
    expect(definitions.every((definition) => definition.category == HomeItemCategory.safety), isTrue);
  });

  test('one always-available Safety Check feature whose keywords never equal the pinned search queries', () {
    final features = safetyFeatures();
    expect(features.map((feature) => feature.id), [SafetyFeatureIds.safetyCheck]);
    expect(features.single.shortcutEligible, isTrue);
    expect(features.single.isAvailable, isNull);
    const pinned = {
      'pin', 'face id', 'electrum', 'explorer', 'sats', 'mfp', 'xpub', //
      '송금', '보내기', '지갑 정보', '주소 검색', 'recovery phrase', 'withdraw',
    };
    for (final locale in AppLocale.values) {
      LocaleSettings.setLocaleSync(locale);
      final keywords = [...features.single.keywords, ...features.single.localizedKeywords!()];
      expect(keywords, isNotEmpty);
      expect(keywords.map((keyword) => keyword.toLowerCase()).where(pinned.contains), isEmpty, reason: '$locale');
    }
    LocaleSettings.setLocaleSync(AppLocale.ko);
  });

  testWidgets('tapping a Safety Status tile opens Wallet Health, or the alert list for several incidents', (
    tester,
  ) async {
    final several = _report(
      WalletHealthStatus.criticalOverride,
      score: 80,
      incidents: [
        SafetyIncident(walletId: 1, txid: 'a', detectedAt: DateTime(2026, 10, 20)),
        SafetyIncident(walletId: 1, txid: 'b', detectedAt: DateTime(2026, 10, 20)),
      ],
    );
    for (final (report, route) in [(_scored, '/wallet-health'), (several, '/wallet-health/alerts')]) {
      final routes = <String?>[];
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<SafetyProvider>.value(value: SafetyProvider.fixed(report)),
            ChangeNotifierProvider<WalletProvider>.value(value: SafetyWalletsFake([safetyWallet(id: 1)])),
          ],
          child: MaterialApp(
            theme: buildCoconutThemeData(),
            navigatorObservers: [_Routes(routes)],
            home: const Scaffold(body: SizedBox()),
          ),
        ),
      );
      for (final definition in safetyHomeWidgets().cast<BuiltinHomeWidget>()) {
        routes.clear();
        definition.onTap!(
          tester.element(find.byType(Scaffold)),
          HomeItem(
            id: 'tile',
            definitionId: definition.id,
            kind: HomeItemKind.widget,
            order: 0,
            span: definition.supportedSpans.single,
          ),
        );
        await tester.pump();
        expect(routes, [route], reason: definition.id);
        Navigator.of(tester.element(find.byType(Scaffold))).popUntil((route) => route.isFirst);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
      }
      await tester.pumpWidget(const SizedBox());
    }
  }, timeout: _timeout);

  testWidgets('a mounted tile refreshes "last checked" when only the check time changes', (tester) async {
    final checkedEarlier = _report(
      WalletHealthStatus.scored,
      score: 92,
      evaluatedAt: DateTime.now().subtract(const Duration(minutes: 10)),
    );
    final checkedNow = _report(WalletHealthStatus.scored, score: 92, evaluatedAt: DateTime.now());
    // 보고서 비교는 evaluatedAt을 뺀다(계약). 그래서 보고서만 고르면 이 변화를 놓친다
    expect(checkedNow, checkedEarlier);

    final safety = _MutableSafety(checkedEarlier);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SafetyProvider>.value(value: safety),
          ChangeNotifierProvider<WalletProvider>.value(value: SafetyWalletsFake([safetyWallet(id: 1)])),
        ],
        child: MaterialApp(
          theme: buildCoconutThemeData(),
          home: Scaffold(
            body: Center(
              child: SizedBox.fromSize(
                size: _tileSize(HomeSpan.small, 86),
                child: const SafetyStatusWidgetView(span: HomeSpan.small),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(t.relative_time.minutes_ago(n: 10)), findsOneWidget);

    // 같은 결과로 다시 검사가 끝났다는 알림
    safety.report = checkedNow;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(t.relative_time.just_now), findsOneWidget);
  }, timeout: _timeout);

  testWidgets('a critical cause that is not an incident reads "보안 경고"; several incidents show their count on 4×2', (
    tester,
  ) async {
    await _pump(tester, HomeSpan.small, report: _cert);
    expect(find.text(safetyKoText(t.wallet_health.status_chip.critical)), findsOneWidget);
    await _pump(tester, HomeSpan.wide, report: _cert, cell: 86);
    expect(find.text(safetyKoText(t.wallet_health.status_chip.critical)), findsOneWidget);
    // 긴 원인 제목은 4×2의 첫 상세 줄로
    expect(find.text(t.wallet_health.incident.server_identity_title), findsOneWidget);

    await _pump(tester, HomeSpan.wide, report: _several, cell: 86);
    expect(find.text(safetyKoText(t.wallet_health.incident.outgoing_multiple_title(n: 2))), findsOneWidget);
    await _pump(tester, HomeSpan.small, report: _several);
    expect(find.text(safetyKoText(t.wallet_health.widget.outgoing_short)), findsOneWidget);
    expect(tester.takeException(), isNull);
  }, timeout: _timeout);

  testWidgets('skeleton bars and the shimmer base use surfaceMuted, so the skeleton shows on the card', (tester) async {
    const variant = CoconutThemeVariant.dark;
    final muted = resolveCoconutThemeExtension(variant: variant).colors.surfaceMuted;
    for (final reduceMotion in [true, false]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildCoconutThemeData(variant: variant),
          home: Builder(
            builder:
                (context) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
                  child: const Scaffold(
                    body: Center(child: SizedBox.square(dimension: 150, child: HomeWidgetSkeleton())),
                  ),
                ),
          ),
        ),
      );
      final bars = tester.widgetList<Container>(
        find.descendant(of: find.byKey(const Key('home-widget-skeleton')), matching: find.byType(Container)),
      );
      expect(bars, isNotEmpty);
      expect(bars.every((bar) => (bar.decoration as BoxDecoration?)?.color == muted), isTrue);
      // 동작 줄이기면 반짝임 없이 막대만, 아니면 반짝임 바탕도 같은 색
      final shimmer = find.byType(Shimmer);
      expect(shimmer, reduceMotion ? findsNothing : findsOneWidget);
      if (!reduceMotion) expect(tester.widget<Shimmer>(shimmer).gradient.colors.first, muted);
    }
  }, timeout: _timeout);
}

/// 마운트된 채로 보고서를 바꿔 끼우고 알린다(검사 완료 알림)
class _MutableSafety extends SafetyProvider {
  _MutableSafety(this._value) : super.fixed(null);
  WalletHealthReport? _value;
  @override
  WalletHealthReport? get report => _value;
  set report(WalletHealthReport? value) {
    _value = value;
    notifyListeners();
  }
}

class _Routes extends NavigatorObserver {
  _Routes(this.names);
  final List<String?> names;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => names.add(route.settings.name);
}
