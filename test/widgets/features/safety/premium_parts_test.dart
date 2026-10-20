import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/widgets/common/buttons/shrink_animation_button.dart';
import 'package:coconut_wallet/widgets/features/safety/safety_common_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

/// POLISH §2.3 공용 Premium 부품: 로고 그라데이션 젬·링, premiumSurfaceGradient 바탕
Widget _app(CoconutThemeVariant variant, Widget child) =>
    MaterialApp(theme: buildCoconutThemeData(variant: variant), home: Scaffold(body: Center(child: child)));

double _contrast(Color a, Color b) {
  final x = a.computeLuminance() + .05;
  final y = b.computeLuminance() + .05;
  return x > y ? x / y : y / x;
}

ColorFilter? _svgFilter(WidgetTester tester, Finder within) =>
    tester.widget<SvgPicture>(find.descendant(of: within, matching: find.byType(SvgPicture))).colorFilter;

BoxDecoration _box(WidgetTester tester, Finder finder) =>
    tester.widget<DecoratedBox>(finder).decoration as BoxDecoration;

void main() {
  test('safetyKoText keeps Korean words whole and leaves other locales alone', () {
    addTearDown(() => LocaleSettings.setLocaleSync(AppLocale.ko));
    LocaleSettings.setLocaleSync(AppLocale.ko);
    expect(safetyKoText('다시 계산해 둬요'), '다\u2060시 계\u2060산\u2060해 둬\u2060요');
    // 두 번 감싸도 한 번과 같다(스스로 감싸는 공용 행·배너에 감싼 글을 넘겨도 이음 문자가 겹치지 않는다)
    expect(safetyKoText(safetyKoText('다시 계산해 둬요')), safetyKoText('다시 계산해 둬요'));
    LocaleSettings.setLocaleSync(AppLocale.en);
    expect(safetyKoText('Check again'), 'Check again');
  });

  test('PremiumMark comes in 12, 20 and 32 only', () {
    for (final size in [12.0, 20.0, 32.0]) {
      expect(() => PremiumMark(size: size), returnsNormally);
    }
    expect(() => PremiumMark(size: 10), throwsAssertionError);
  });

  for (final variant in CoconutThemeVariant.values) {
    final colors = resolveCoconutThemeExtension(variant: variant).colors;

    group(variant.name, () {
      testWidgets('PremiumMark paints the diamond with the logo gradient; muted is plain iconSecondary', (
        tester,
      ) async {
        await tester.pumpWidget(_app(variant, const PremiumMark(size: 20)));
        final mask = tester.widget<ShaderMask>(find.byType(ShaderMask));
        expect(mask.blendMode, BlendMode.srcIn);
        expect(_svgFilter(tester, find.byType(PremiumMark)), const ColorFilter.mode(Colors.white, BlendMode.srcIn));
        expect(tester.getSize(find.byType(SvgPicture)), const Size(20, 20));

        await tester.pumpWidget(_app(variant, const PremiumMark(size: 12, muted: true)));
        expect(find.byType(ShaderMask), findsNothing);
        expect(_svgFilter(tester, find.byType(PremiumMark)), ColorFilter.mode(colors.iconSecondary, BlendMode.srcIn));
      });

      testWidgets('PremiumSurface draws the logo-gradient ring around the premium fill', (tester) async {
        await tester.pumpWidget(_app(variant, const PremiumSurface(radius: 24, ringWidth: 1, child: Text('x'))));
        final ring = tester.widget<Container>(
          find.descendant(of: find.byType(PremiumSurface), matching: find.byType(Container)).first,
        );
        final ringBox = ring.decoration! as BoxDecoration;
        expect(ringBox.gradient, colors.mainnetLogoGradient);
        expect(ringBox.borderRadius, BorderRadius.circular(24));
        expect(ring.padding, const EdgeInsets.all(1));
        final fill = _box(
          tester,
          find.descendant(of: find.byType(PremiumSurface), matching: find.byType(DecoratedBox)).last,
        );
        expect(fill.gradient, colors.premiumSurfaceGradient);
        expect(fill.borderRadius, BorderRadius.circular(23));
      });

      testWidgets('a pressable PremiumSurface is one button with the ring width it was given', (tester) async {
        final handle = tester.ensureSemantics();
        var taps = 0;
        await tester.pumpWidget(
          _app(
            variant,
            PremiumSurface(
              radius: 20,
              ringWidth: 1,
              onPressed: () => taps++,
              child: const Column(mainAxisSize: MainAxisSize.min, children: [Text('Title'), Text('Body')]),
            ),
          ),
        );
        final button = tester.widget<ShrinkAnimationButton>(find.byType(ShrinkAnimationButton));
        // ShrinkAnimationButton defaults to a 2.0 border: the ring must be what we asked for
        expect(button.borderWidth, 1);
        expect(button.borderGradient, colors.mainnetLogoGradient);
        expect(button.borderRadius, 20);
        final node = tester.getSemantics(find.text('Title'));
        expect(node.getSemanticsData().flagsCollection.isButton, isTrue);
        expect(node.label, contains('Body'));

        await tester.tap(find.text('Body'));
        await tester.pumpAndSettle();
        expect(taps, 1);
        handle.dispose();
      });

      testWidgets('PremiumChip is a 1px-ring pill with mark 12 and the badge in premiumText', (tester) async {
        await tester.pumpWidget(_app(variant, const PremiumChip()));
        expect(tester.widget<PremiumSurface>(find.byType(PremiumSurface)).ringWidth, 1);
        expect(tester.widget<PremiumSurface>(find.byType(PremiumSurface)).radius, 20);
        expect(tester.widget<PremiumMark>(find.byType(PremiumMark)).size, 12);
        expect(tester.widget<Text>(find.text(t.premium.badge)).style!.color, colors.premiumText);
      });

      testWidgets('PremiumHero is a 72 circle with a 1.5 ring and mark 32', (tester) async {
        await tester.pumpWidget(_app(variant, const PremiumHero()));
        expect(tester.getSize(find.byType(PremiumHero)), const Size(72, 72));
        final surface = tester.widget<PremiumSurface>(find.byType(PremiumSurface));
        expect((surface.radius, surface.ringWidth), (36, 1.5));
        expect(tester.widget<PremiumMark>(find.byType(PremiumMark)).size, 32);
      });

      testWidgets('PremiumActionCard: no ring, primaryText title, readable body and a visible button', (tester) async {
        var taps = 0;
        await tester.pumpWidget(
          _app(variant, PremiumActionCard(title: 'Title', body: 'Body', button: 'Go', onPressed: () => taps++)),
        );
        final gradient = colors.premiumSurfaceGradient as LinearGradient;
        final card = tester.widget<Container>(
          find.descendant(of: find.byType(PremiumActionCard), matching: find.byType(Container)).first,
        );
        final box = card.decoration! as BoxDecoration;
        expect(box.gradient, gradient);
        expect(box.border, isNull);
        expect(
          find.descendant(of: find.byType(PremiumActionCard), matching: find.byType(PremiumSurface)),
          findsNothing,
        );
        expect(tester.widget<PremiumMark>(find.byType(PremiumMark)).size, 20);
        expect(tester.widget<Text>(find.text('Title')).style!.color, colors.primaryText);
        expect(tester.widget<Text>(find.text('Body')).style!.color, colors.secondaryTextStrong);
        expect(tester.widget<Text>(find.text('Go')).style!.color, colors.premiumText);
        final button = tester.widget<ShrinkAnimationButton>(find.byType(ShrinkAnimationButton));
        expect(button.defaultColor, colors.background);
        // The button must stand off the gradient (homeSurface vanished at 1.00–1.07)
        for (final stop in gradient.colors) {
          expect(_contrast(colors.background, stop), greaterThan(1.1), reason: '$stop');
        }
        for (final stop in gradient.colors) {
          expect(_contrast(colors.premiumText, Color.alphaBlend(colors.background, stop)), greaterThanOrEqualTo(4.5));
        }

        await tester.tap(find.text('Go'));
        await tester.pumpAndSettle();
        expect(taps, 1);
      });
    });
  }
}
