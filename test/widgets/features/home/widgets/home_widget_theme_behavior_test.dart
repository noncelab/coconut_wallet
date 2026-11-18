import 'dart:ui' as ui;
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/design_system/tokens/coconut_colors.dart';
import 'package:coconut_wallet/model/home/home_widget_data.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/activity_widget_views.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/home_widget_parts.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/balance_widget_views.dart';
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_design_system/coconut_design_system.dart' show CoconutTypography;
import 'package:flutter_test/flutter_test.dart';
import 'package:shimmer/shimmer.dart';

void main() {
  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    CoconutThemeVariant variant = CoconutThemeVariant.dark,
    bool disableAnimations = false,
    bool accessibleNavigation = false,
  }) => tester.pumpWidget(
    MaterialApp(
      theme: buildCoconutThemeData(variant: variant),
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: disableAnimations, accessibleNavigation: accessibleNavigation),
        child: Center(child: SizedBox(width: 328, height: 156, child: child)),
      ),
    ),
  );

  for (final accessibility in [false, true]) {
    testWidgets(
      'skeleton keeps its geometry and stops scheduling frames with ${accessibility ? 'accessible navigation' : 'reduced motion'}',
      (tester) async {
        await pump(tester, const HomeWidgetSkeleton());
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byType(Shimmer), findsOneWidget);
        final before = tester.getRect(find.byKey(const Key('home-widget-skeleton')));
        await pump(
          tester,
          const HomeWidgetSkeleton(),
          disableAnimations: !accessibility,
          accessibleNavigation: accessibility,
        );
        await tester.pumpAndSettle();
        expect(find.byType(Shimmer), findsNothing);
        expect(tester.getRect(find.byKey(const Key('home-widget-skeleton'))), before);
        expect(tester.binding.hasScheduledFrame, isFalse);
        await pump(tester, const HomeWidgetSkeleton());
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byType(Shimmer), findsOneWidget);
        expect(tester.binding.hasScheduledFrame, isTrue);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets('a scaled home header keeps the complete glyph height', (tester) async {
    await pump(
      tester,
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: Column(
          children: [
            HomeWidgetHeader(
              iconPath: FeatureWidgetIconPath.bullseyeArrow,
              title: 'Goal',
              style: CoconutTypography.body1_16_Bold,
            ),
          ],
        ),
      ),
    );
    final paragraph = tester.renderObject<RenderParagraph>(find.text('Goal'));
    expect(paragraph.size.height, greaterThanOrEqualTo(paragraph.getMaxIntrinsicHeight(paragraph.size.width)));
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced-motion press feedback settles immediately and cancels without activation', (tester) async {
    var taps = 0;
    await pump(
      tester,
      HomeWidgetPressable(onTap: () => taps++, child: const ColoredBox(color: Colors.blue)),
      disableAnimations: true,
    );
    final gesture = await tester.startGesture(tester.getCenter(find.byType(HomeWidgetPressable)));
    await tester.pump(const Duration(milliseconds: 150));
    expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).duration, Duration.zero);
    expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, .97);
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1);
    expect(taps, 0);
    await tester.tap(find.byType(HomeWidgetPressable));
    await tester.pumpAndSettle();
    expect(taps, 1);
  });

  testWidgets('home pressable exposes one enabled button with semantic, pointer and keyboard activation', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var taps = 0;
    await pump(tester, HomeWidgetPressable(onTap: () => taps++, child: const Text('Open insights')));
    final node = tester.getSemantics(find.byType(HomeWidgetPressable));
    expect(node.flagsCollection.isButton, isTrue);
    expect(node.flagsCollection.isEnabled, isNot(ui.Tristate.none));
    expect(node.flagsCollection.isEnabled, ui.Tristate.isTrue);
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    node.owner!.performAction(node.id, SemanticsAction.tap);
    await tester.pump();
    expect(taps, 1);
    await tester.tap(find.byType(HomeWidgetPressable));
    await tester.pumpAndSettle();
    expect(taps, 2);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(taps, 3);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(taps, 4);
    semantics.dispose();
  });

  for (final variant in CoconutThemeVariant.values) {
    for (final (shape, radius, selected) in [
      ('card', 20.0, false),
      ('preset', 24.0, false),
      ('onboarding', 16.0, false),
      ('selected chip', 20.0, true),
    ]) {
      testWidgets('$variant $shape paints visible keyboard focus and restores resting pixels', (tester) async {
        const captureKey = Key('focus-capture');
        var firstTaps = 0;
        var secondTaps = 0;
        late CoconutColors colors;
        await pump(
          tester,
          Builder(
            builder: (context) {
              colors = context.coconutColors;
              Widget card(String id, VoidCallback onTap) => HomeWidgetPressable(
                key: ValueKey(id),
                onTap: onTap,
                borderRadius: radius,
                focusColor: selected ? colors.chipSelectedText : null,
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected ? colors.chipSelectedBackground : colors.homeSurface,
                    borderRadius: BorderRadius.circular(radius),
                  ),
                  child: Text(id),
                ),
              );
              return RepaintBoundary(
                key: captureKey,
                child: Row(
                  children: [
                    Expanded(child: card('first', () => firstTaps++)),
                    const SizedBox(width: 8),
                    Expanded(child: card('second', () => secondTaps++)),
                  ],
                ),
              );
            },
          ),
          variant: variant,
        );
        await tester.pumpAndSettle();
        Future<List<int>> pixels() async {
          final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(captureKey));
          final image = (await tester.runAsync(() => boundary.toImage(pixelRatio: 1)))!;
          final bytes = await tester.runAsync(() => image.toByteData(format: ui.ImageByteFormat.rawRgba));
          final result = bytes!.buffer.asUint8List().toList();
          image.dispose();
          return result;
        }

        Color at(List<int> bytes, int x, int y) {
          final index = (y * 328 + x) * 4;
          return Color.fromARGB(bytes[index + 3], bytes[index], bytes[index + 1], bytes[index + 2]);
        }

        BoxDecoration decoration(String id) =>
            tester
                    .widget<DecoratedBox>(
                      find.descendant(of: find.byKey(ValueKey(id)), matching: find.byType(DecoratedBox)).first,
                    )
                    .decoration
                as BoxDecoration;
        final resting = await pixels();
        final rect = tester.getRect(find.byKey(const ValueKey('first')));
        expect(decoration('first').border, isNull);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        final focus = await pixels();
        final foreground = selected ? colors.chipSelectedText : colors.primaryText;
        final surface = selected ? colors.chipSelectedBackground : colors.homeSurface;
        expect(at(focus, 80, 1), foreground);
        expect(at(resting, 80, 1), surface);
        final a = at(focus, 80, 1).computeLuminance();
        final b = at(resting, 80, 1).computeLuminance();
        expect((a > b ? (a + .05) / (b + .05) : (b + .05) / (a + .05)), greaterThanOrEqualTo(3));
        expect(decoration('first').borderRadius, BorderRadius.circular(radius));
        expect((decoration('first').border! as Border).top.width, 3);
        expect(tester.getRect(find.byKey(const ValueKey('first'))), rect);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        expect(decoration('first').border, isNull);
        expect(decoration('second').border, isNotNull);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        await tester.pumpAndSettle();
        expect(decoration('first').border, isNotNull);
        expect(decoration('second').border, isNull);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        await tester.pumpAndSettle();
        expect(firstTaps, 2);
        expect(secondTaps, 0);
        FocusManager.instance.primaryFocus!.unfocus();
        await tester.pumpAndSettle();
        expect(decoration('first').border, isNull);
        expect(await pixels(), resting);
      });
    }
  }

  for (final variant in CoconutThemeVariant.values) {
    testWidgets('$variant unsigned fiat footer stays neutral for gains and losses', (tester) async {
      for (final rate in [.05, -.05, 0.0]) {
        await pump(
          tester,
          BitcoinBalanceTrendView(
            balance: const HomeAmount('1', 'BTC'),
            fiatText: '₩ 214,892,000',
            rate: rate,
            values: const [1, 2],
          ),
          variant: variant,
        );
        final colors = tester.element(find.byType(BitcoinBalanceTrendView)).coconutColors;
        expect(tester.widget<Text>(find.text('₩ 214,892,000')).style!.color, colors.primaryText);
        expect(colors.homeChartLine, kCoconutPriceUp);
      }
    });

    testWidgets('$variant uses readable market text without changing chart colors or directions', (tester) async {
      for (final rate in [0.1, -0.1, 0.0]) {
        await pump(tester, HomeTrendChange(rate: rate), variant: variant);
        final colors = tester.element(find.byType(HomeTrendChange)).coconutColors;
        final text = tester.widget<Text>(find.text(rate == 0 ? '–' : '10%'));
        expect(
          text.style!.color,
          rate == 0
              ? colors.tertiaryText
              : rate > 0
              ? colors.priceUpText
              : colors.priceDownText,
        );
        expect(
          find.byKey(Key(rate > 0 ? 'home-trend-rate-up' : 'home-trend-rate-down')),
          rate == 0 ? findsNothing : findsOneWidget,
        );
        expect(homePriceColors(tester.element(find.byType(HomeTrendChange))), (
          up: kCoconutPriceUp,
          down: kCoconutPriceDown,
        ));
      }
    });

    testWidgets('$variant renders organized activity as data, not disabled decoration', (tester) async {
      await pump(
        tester,
        TransactionActivityView(
          days: [HomeDailyActivity(day: DateTime(2026, 1, 1), received: 0, sent: 0, organized: 3)],
        ),
        variant: variant,
      );
      final bar = find.byKey(const ValueKey('transaction-activity-bar-0-organized'));
      final colors = tester.element(bar).coconutColors;
      expect((tester.widget<Container>(bar).decoration as BoxDecoration).color, colors.secondaryText);
      expect(tester.getSize(bar).height, greaterThan(0));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('sparkline repaints its selected guide when only the theme changes', (tester) async {
    await pump(tester, const HomeSparkline(values: [1, 3, 2], selectedIndex: 1));
    final oldPainter =
        tester
            .widget<CustomPaint>(find.descendant(of: find.byType(HomeSparkline), matching: find.byType(CustomPaint)))
            .painter!;
    await pump(
      tester,
      const HomeSparkline(values: [1, 3, 2], selectedIndex: 1),
      variant: CoconutThemeVariant.coconutTheme,
    );
    await tester.pump(const Duration(milliseconds: 300));
    final painter =
        tester
            .widget<CustomPaint>(find.descendant(of: find.byType(HomeSparkline), matching: find.byType(CustomPaint)))
            .painter!;
    expect(painter.shouldRepaint(oldPainter), isTrue);
  });
}
