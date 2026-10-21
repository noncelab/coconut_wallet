import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/design_system/tokens/wallet_health_colors.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/safety/wallet_health_report.dart';
import 'package:coconut_wallet/widgets/features/safety/safety_score_gauge.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../screens/safety/wallet_health_fixtures.dart';

/// 글자 찾기. 앱은 한국어 단어가 중간에서 끊기지 않게 글자 사이에 U+2060을 넣으므로(safetyKoText) 그 문자를 빼고 비교한다
Finder _text(String text) =>
    find.byWidgetPredicate((w) => w is Text && (w.data ?? w.textSpan?.toPlainText())?.replaceAll('\u2060', '') == text);

/// 글자 일부 찾기(U+2060 이음 문자를 빼고 비교)
Finder _textContaining(Pattern pattern) => find.byWidgetPredicate(
  (w) => w is Text && ((w.data ?? w.textSpan?.toPlainText())?.replaceAll('\u2060', '').contains(pattern) ?? false),
);

/// 게이지 페인터(비공개 타입이라 dynamic으로 읽는다)
dynamic _painter(WidgetTester tester) =>
    tester
        .widget<CustomPaint>(find.descendant(of: find.byType(HealthGauge), matching: find.byType(CustomPaint)).first)
        .painter;

Color _textColor(WidgetTester tester, String text) => tester.widget<Text>(_text(text)).style!.color!;

Future<void> _pump(
  WidgetTester tester,
  WalletHealthReport? report, {
  CoconutThemeVariant variant = CoconutThemeVariant.light,
  bool isChecking = false,
  bool compact = false,
  bool reduceMotion = true,
}) => pumpWalletHealthApp(
  tester,
  Scaffold(
    body: Center(
      child: compact ? HealthGauge.compact(report: report) : HealthGauge(report: report, isChecking: isChecking),
    ),
  ),
  variant: variant,
  reduceMotion: reduceMotion,
  settle: !isChecking || reduceMotion,
);

void main() {
  for (final variant in CoconutThemeVariant.values) {
    final colors = resolveCoconutThemeExtension(variant: variant).colors;
    final health = resolveCoconutThemeExtension(variant: variant).walletHealth;

    group(variant.name, () {
      testWidgets('scored: number + label, wallet health gradient on its track', (tester) async {
        final semantics = tester.ensureSemantics();
        await _pump(tester, scoredReport(score: 86), variant: variant);
        expect(_text('86'), findsOneWidget);
        expect(_textColor(tester, t.wallet_health.score_label.good), health.good);
        final painter = _painter(tester);
        expect(painter.track, health.gaugeTrack);
        expect(painter.fill, health.gaugeColors);
        expect(painter.stops, health.gaugeStops);
        expect(painter.critical, isNull);
        expect(painter.progress, closeTo(0.86, 1e-9));
        expect(
          find.bySemanticsLabel(t.wallet_health.hero.score_a11y(score: 86, label: t.wallet_health.score_label.good)),
          findsOneWidget,
        );
        semantics.dispose();
      });

      testWidgets('0–49 reads "조치 필요" on the range-colored arc, not the incident arc', (tester) async {
        await _pump(tester, scoredReport(score: 42), variant: variant);
        expect(_text('조치 필요'), findsOneWidget);
        expect(_textContaining('Critical'), findsNothing);
        expect(_textColor(tester, '조치 필요'), health.critical);
        expect(_painter(tester).critical, isNull);
        expect(_painter(tester).fill, health.gaugeColors);
      });

      testWidgets('no wallet and not enough data show the track and a dash, never a number', (tester) async {
        await _pump(tester, noWalletReport(), variant: variant);
        expect(_text(t.wallet_health.hero.no_wallet_title), findsOneWidget);
        expect(_textContaining(RegExp(r'\d')), findsNothing);
        expect(_painter(tester).progress, 0);

        await _pump(tester, notEnoughDataReport(), variant: variant);
        expect(_text(t.wallet_health.hero.not_enough_data_title), findsOneWidget);
        expect(_textContaining(RegExp(r'\d')), findsNothing);
      });

      testWidgets('critical: red arc and siren instead of the preserved score', (tester) async {
        await _pump(tester, criticalReport(), variant: variant);
        expect(_text('76'), findsNothing);
        expect(_painter(tester).critical, colors.danger.withValues(alpha: 0.28));
        final siren = tester.widget<SvgPicture>(find.byType(SvgPicture));
        expect((siren.bytesLoader as SvgAssetLoader).assetName, CommonStateIconPath.siren);
      });
    });
  }

  testWidgets('coconut theme gauge keeps the fixed wallet health colors', (tester) async {
    await _pump(tester, scoredReport(score: 86), variant: CoconutThemeVariant.coconutTheme);
    final painter = _painter(tester);
    expect(painter.fill, WalletHealthColors.base.gaugeColors);
    expect(painter.track, WalletHealthColors.base.gaugeTrack);
  });

  testWidgets('checking dims the previous fill and says "검사 중…"', (tester) async {
    await _pump(tester, scoredReport(score: 86), isChecking: true);
    expect(_text(t.wallet_health.summary.checking), findsOneWidget);
    expect(_painter(tester).fillOpacity, closeTo(0.35, 1e-9));
    expect(_painter(tester).sweep, isNull); // 동작 줄이기: 스윕 없음
  });

  testWidgets('checking sweeps over the track when motion is allowed', (tester) async {
    await _pump(tester, scoredReport(score: 86), isChecking: true, reduceMotion: false);
    await tester.pump(const Duration(milliseconds: 300));
    expect(_painter(tester).sweep, isNotNull);
    await tester.pumpWidget(const SizedBox()); // 반복 애니메이션 정리
  });

  testWidgets('C8: score and checking labels stay on one line and scale down; S0/S4 captions may use two', (
    tester,
  ) async {
    Text label(String text) => tester.widget<Text>(_text(text));
    // de "Handlungsbedarf"가 가장 긴 라벨
    Future<void> pump(WalletHealthReport report, {bool checking = false}) => pumpWalletHealthApp(
      tester,
      Scaffold(body: Center(child: HealthGauge(report: report, isChecking: checking))),
      locale: AppLocale.de,
    );
    await pump(scoredReport(score: 42));
    final scored = walletHealthLabelText(WalletHealthLabel.of(42));
    expect(label(scored).maxLines, 1);
    expect(find.ancestor(of: _text(scored), matching: find.byType(FittedBox)), findsOneWidget);
    // 라벨은 그 높이의 원호 안쪽 폭을 넘지 않는다
    final gauge = tester.getRect(find.byType(HealthGauge));
    final labelRect = tester.getRect(find.ancestor(of: _text(scored), matching: find.byType(FittedBox)));
    expect(labelRect.width, lessThanOrEqualTo(gauge.width * 0.65));
    await pump(scoredReport(score: 86), checking: true);
    expect(label(t.wallet_health.summary.checking).maxLines, 1);
    await pump(noWalletReport());
    expect(label(t.wallet_health.hero.no_wallet_title).maxLines, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact is 72 wide with the number only', (tester) async {
    await _pump(tester, scoredReport(score: 86), compact: true);
    expect(tester.getSize(find.byType(HealthGauge)).width, 72);
    expect(_text('86'), findsOneWidget);
    expect(_text(t.wallet_health.score_label.good), findsNothing);
    expect(_painter(tester).stroke, 10);
  });

  testWidgets('entry: waits for the route + 250 ms, then fills 0 → score over 1600 ms', (tester) async {
    await _pump(tester, scoredReport(score: 80), reduceMotion: false);
    // pumpAndSettle가 전환을 끝냈고 250ms 대기 중
    expect(_painter(tester).progress, 0);
    await tester.pump(const Duration(milliseconds: 260));
    await tester.pump(const Duration(milliseconds: 800));
    final mid = _painter(tester).progress as double;
    expect(mid, greaterThan(0));
    expect(mid, lessThan(0.8));
    // 숫자도 원호와 함께 올라간다
    expect(_text('${(mid * 100).round()}'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(_painter(tester).progress, closeTo(0.8, 1e-9));
  });

  testWidgets('entry waits for the push transition, not the offstage first frame', (tester) async {
    await pumpWalletHealthApp(
      tester,
      Builder(
        builder:
            (context) => TextButton(
              onPressed:
                  () => Navigator.of(context).push(
                    CupertinoPageRoute<void>(
                      builder: (_) => Scaffold(body: Center(child: HealthGauge(report: scoredReport(score: 80)))),
                    ),
                  ),
              child: const Text('open'),
            ),
      ),
      reduceMotion: false,
    );
    await tester.tap(_text('open'));
    await tester.pump(); // 첫 프레임은 Hero 측정용 offstage(전환이 끝난 것처럼 보인다)
    await tester.pump(const Duration(milliseconds: 300)); // 아직 밀려 들어오는 중
    expect(_painter(tester).progress, 0);
    await tester.pumpAndSettle(); // 전환 끝
    await tester.pump(const Duration(milliseconds: 260)); // + 250ms 쉼
    await tester.pumpAndSettle();
    expect(_painter(tester).progress, closeTo(0.8, 1e-9));
  });

  testWidgets('reduced motion shows the final value at once', (tester) async {
    await _pump(tester, scoredReport(score: 80));
    expect(_painter(tester).progress, closeTo(0.8, 1e-9));
  });

  testWidgets('a new score animates from the current value', (tester) async {
    Widget gauge(int score) => Scaffold(body: Center(child: HealthGauge(report: scoredReport(score: score))));
    await pumpWalletHealthApp(tester, gauge(80), reduceMotion: false);
    await tester.pump(const Duration(milliseconds: 260));
    await tester.pumpAndSettle();
    expect(_painter(tester).progress, closeTo(0.8, 1e-9));
    await pumpWalletHealthApp(tester, gauge(60), reduceMotion: false, settle: false);
    await tester.pump(const Duration(milliseconds: 400));
    final mid = _painter(tester).progress as double;
    expect(mid, inExclusiveRange(0.6, 0.8));
    await tester.pumpAndSettle();
    expect(_painter(tester).progress, closeTo(0.6, 1e-9));
    expect(_text('60'), findsOneWidget);
  });
}
