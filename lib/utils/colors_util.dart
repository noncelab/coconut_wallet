import 'dart:ui';

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/model/wallet/multisig_signer.dart';

const defaultIconColor = Color.fromRGBO(218, 216, 228, 1);
const defaultBackgroundColor = Color.fromRGBO(255, 255, 255, 0.1);

enum CustomColor {
  purple,
  tangerine,
  yellow,
  green,
  blue,
  pink,
  red,
  orange,
  lightgrey,
  mint,
}

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
  CoconutColors.purple.withOpacity(0.18),
  CoconutColors.tangerine.withOpacity(0.18),
  CoconutColors.yellow.withOpacity(0.18),
  CoconutColors.green.withOpacity(0.18),
  CoconutColors.sky.withOpacity(0.18),
  CoconutColors.pink.withOpacity(0.18),
  CoconutColors.red.withOpacity(0.18),
  CoconutColors.orange.withOpacity(0.18),
  CoconutColors.gray600.withOpacity(0.18),
  CoconutColors.mint.withOpacity(0.18),
];

class ColorUtil {
  static Color getColor(int index) =>
      index < 0 || index > 9 ? defaultIconColor : colorPalette[index % colorPalette.length];
  static Color getBackgroundColor(int index) => index < 0 || index > 9
      ? defaultBackgroundColor
      : backgroundColorPalette[index % colorPalette.length];

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
      return item.innerVaultId != null
          ? ColorUtil.getColorByIndex(item.colorIndex ?? 0)
          : CoconutColors.gray300;
    }

    // 2개인 경우
    if (list.length == 2) {
      return [
        getColor(list[0]),
        getColor(list[1]),
      ];
    }

    return [
      getColor(list[0]),
      getColor(list[1]),
      getColor(list[2]),
    ];
  }
}
