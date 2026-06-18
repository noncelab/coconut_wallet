import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/wallet/multisig_signer.dart';
import 'package:coconut_wallet/model/wallet/taproot_wallet_list_item.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;

const defaultIconColor = Color.fromRGBO(218, 216, 228, 1);
const defaultBackgroundColor = Color.fromRGBO(255, 255, 255, 0.1);

const defaultBoxDecoration = BoxDecoration(
  color: CoconutColors.gray800,
  borderRadius: BorderRadius.all(Radius.circular(24)),
);

const defaultCardColor = Color.fromRGBO(255, 255, 255, 0.06);

class ColorSet {
  final Color color;
  final Color backgroundColor;

  const ColorSet({required this.color, required this.backgroundColor});

  ColorSet withOpacity(double opacity) {
    return ColorSet(color: color, backgroundColor: backgroundColor.withValues(alpha: opacity));
  }
}

enum CustomColor { purple, tangerine, yellow, green, blue, pink, red, orange, lightgrey, mint }

const List<Color> colorPalette = [
  CoconutColors.purple,
  CoconutColors.tangerine,
  CoconutColors.yellow,
  CoconutColors.green,
  CoconutColors.sky,
  CoconutColors.pink,
  CoconutColors.red,
  CoconutColors.orange,
  CoconutColors.gray600,
  CoconutColors.mint,
];

final List<Color> backgroundColorPalette = [
  CoconutColors.purple.withValues(alpha: 0.18),
  CoconutColors.tangerine.withValues(alpha: 0.18),
  CoconutColors.yellow.withValues(alpha: 0.18),
  CoconutColors.green.withValues(alpha: 0.18),
  CoconutColors.sky.withValues(alpha: 0.18),
  CoconutColors.pink.withValues(alpha: 0.18),
  CoconutColors.red.withValues(alpha: 0.18),
  CoconutColors.orange.withValues(alpha: 0.18),
  CoconutColors.gray600.withValues(alpha: 0.18),
  CoconutColors.mint.withValues(alpha: 0.18),
];

const List<Color> tagColorPalette = [
  CoconutColors.purple,
  CoconutColors.tangerine,
  CoconutColors.yellow,
  CoconutColors.green,
  CoconutColors.sky,
  CoconutColors.pink,
  CoconutColors.red,
  CoconutColors.orange,
  CoconutColors.gray400,
  CoconutColors.mint,
];

class TaprootCardStyle {
  final Gradient borderGradient;
  final Gradient backgroundGradient;
  final List<Color> iconGradientColors;

  const TaprootCardStyle({
    required this.borderGradient,
    required this.backgroundGradient,
    required this.iconGradientColors,
  });

  static TaprootCardStyle? from(WalletListItemBase wallet) {
    if (wallet is! TaprootWalletListItem) return null;
    return TaprootCardStyle.fromKeyPath(wallet.canSpendViaKeyPath);
  }

  static TaprootCardStyle fromKeyPath(bool canSpendViaKeyPath) {
    final colors =
        canSpendViaKeyPath
            ? [CoconutColors.periwinkle, CoconutColors.lightSky]
            : [CoconutColors.lightSky, CoconutColors.periwinkle];

    const begin = Alignment(0.97, -0.25);
    const end = Alignment(-0.97, 0.25);
    const stops = [0.18, 0.89];

    return TaprootCardStyle(
      borderGradient: LinearGradient(begin: begin, end: end, colors: colors, stops: stops),
      backgroundGradient: LinearGradient(
        begin: begin,
        end: end,
        stops: stops,
        colors: [colors[0].withValues(alpha: 0.2), colors[1].withValues(alpha: 0.2)],
      ),
      iconGradientColors: colors,
    );
  }
}

class ColorUtil {
  static ColorSet getColor(int index) {
    if (index < 0 || index >= colorPalette.length) {
      return const ColorSet(color: defaultIconColor, backgroundColor: defaultBackgroundColor);
    }

    return ColorSet(color: colorPalette[index], backgroundColor: backgroundColorPalette[index]);
  }

  static int getIntFromColor(CustomColor color) {
    switch (color) {
      case CustomColor.purple:
        return 0;
      case CustomColor.tangerine:
        return 1;
      case CustomColor.yellow:
        return 2;
      case CustomColor.green:
        return 3;
      case CustomColor.blue:
        return 4;
      case CustomColor.pink:
        return 5;
      case CustomColor.red:
        return 6;
      case CustomColor.orange:
        return 7;
      case CustomColor.lightgrey:
        return 8;
      case CustomColor.mint:
        return 9;
      default:
        throw Exception('Invalid color enum: $color');
    }
  }

  static Color getColorByIndex(int index) {
    if (index < 0 || index > 9) {
      return defaultIconColor;
    }

    return colorPalette[index % colorPalette.length];
  }

  static Color getBackgroundColorByIndex(int index) {
    if (index < 0 || index > 9) {
      return defaultBackgroundColor;
    }

    return backgroundColorPalette[index % colorPalette.length];
  }

  static List<Color> getGradientColors(List<MultisigSigner> list) {
    if (list.isEmpty) {
      return [CoconutColors.gray300];
    }

    Color getColor(MultisigSigner item) {
      return item.innerVaultId != null ? ColorUtil.getColorByIndex(item.colorIndex ?? 0) : CoconutColors.gray300;
    }

    // 2개인 경우
    if (list.length == 2) {
      return [getColor(list[0]), getColor(list[1])];
    }

    return [getColor(list[0]), getColor(list[1]), getColor(list[2])];
  }

  static LinearGradient getMultisigLinearGradient(List<Color> colors) {
    return LinearGradient(
      colors: colors,
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      transform: const GradientRotation(math.pi / 10),
    );
  }
}
