import 'package:coconut_design_system/coconut_design_system.dart' as ds;
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/design_system/tokens/coconut_colors.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

double contrast(Color foreground, Color background) {
  final a = Color.alphaBlend(foreground, background).computeLuminance();
  final b = background.computeLuminance();
  return (a > b ? a + 0.05 : b + 0.05) / (a > b ? b + 0.05 : a + 0.05);
}

void main() {
  for (final variant in CoconutThemeVariant.values) {
    test('$variant active form, selection, error and market foregrounds remain readable', () {
      final colors = resolveCoconutThemeExtension(variant: variant).colors;
      for (final background in [colors.inputSurface, colors.background, colors.surfaceBottomSheet]) {
        expect(contrast(colors.inputPlaceholder, background), greaterThanOrEqualTo(4.5));
        expect(contrast(colors.iconSecondary, background), greaterThanOrEqualTo(3));
      }
      expect(contrast(colors.chipUnselectedText, colors.chipUnselectedBackground), greaterThanOrEqualTo(4.5));
      expect(
        contrast(colors.chipOutlinedUnselectedText, colors.chipOutlinedUnselectedBackground),
        greaterThanOrEqualTo(4.5),
      );
      expect(contrast(colors.chipEditModeText, colors.chipEditModeBackground), greaterThanOrEqualTo(4.5));
      expect(
        contrast(colors.segmentedControlUnselectedText, colors.segmentedControlBackground),
        greaterThanOrEqualTo(4.5),
      );
      for (final background in [colors.background, colors.surface, colors.homeSurface, colors.surfaceBottomSheet]) {
        expect(contrast(colors.dangerText, background), greaterThanOrEqualTo(4.5));
        expect(contrast(colors.priceUpText, background), greaterThanOrEqualTo(4.5));
        expect(contrast(colors.priceDownText, background), greaterThanOrEqualTo(4.5));
      }
      expect(colors.chipUnselectedText, isNot(colors.chipDisabledText));
      expect(colors.danger, kCoconutDanger);
      expect(colors.priceUp, kCoconutPriceUp);
      expect(colors.priceDown, kCoconutPriceDown);
    });
  }

  test(
    'Coconut secondary text reads at 4.5:1 on cream and pulp while iconSecondary stays husk and other themes keep theirs',
    () {
      final coconut = CoconutColors.coconutTheme();
      // 크림(surface F4E9D3) 4.70:1, 밝은 바탕(background FAF8F3) 5.33:1
      expect(contrast(coconut.secondaryText, coconut.surface), greaterThanOrEqualTo(4.5));
      expect(contrast(coconut.secondaryText, coconut.background), greaterThanOrEqualTo(4.5));
      expect(coconut.iconSecondary, const Color(0xFFB87433));
      expect(coconut.pageIndicatorActive, const Color(0xFFB87433));
      expect(coconut.tertiaryText, const Color(0xFFC18C55));
      expect(CoconutColors.light().secondaryText, ds.CoconutColors.gray700);
      expect(CoconutColors.dark().secondaryText, ds.CoconutColors.gray400);
    },
  );

  test('Coconut preserves its palette and readable pressed CTA', () {
    final colors = CoconutColors.coconutTheme();
    expect(colors.secondaryText, const Color(0xFF905B28));
    expect(colors.inputPlaceholder, const Color(0xFFA0652C));
    expect(colors.buttonPrimaryPressOverlayOpacity, 0.12);
    final pressed = Color.alphaBlend(
      colors.buttonPrimaryPressOverlay.withValues(alpha: colors.buttonPrimaryPressOverlayOpacity),
      colors.buttonPrimaryBackground,
    );
    expect(contrast(colors.buttonPrimaryForeground, pressed), greaterThanOrEqualTo(4.5));
  });
}
