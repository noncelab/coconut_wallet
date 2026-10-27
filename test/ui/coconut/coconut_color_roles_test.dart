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

  test('Coconut preserves its palette and readable pressed CTA', () {
    final colors = CoconutColors.coconutTheme();
    expect(colors.secondaryText, const Color(0xFFB87433));
    expect(colors.inputPlaceholder, const Color(0xFFA0652C));
    expect(colors.buttonPrimaryPressOverlayOpacity, 0.12);
    final pressed = Color.alphaBlend(
      colors.buttonPrimaryPressOverlay.withValues(alpha: colors.buttonPrimaryPressOverlayOpacity),
      colors.buttonPrimaryBackground,
    );
    expect(contrast(colors.buttonPrimaryForeground, pressed), greaterThanOrEqualTo(4.5));
  });
}
