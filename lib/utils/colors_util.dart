import 'dart:ui';

import 'package:coconut_wallet/model/app/wallet/multisig_signer.dart';

import '../styles.dart';

class CustomColorHelper {
  static Color getColorByEnum(CustomColor color) {
    switch (color) {
      case CustomColor.purple:
        return ColorPalette[0];
      case CustomColor.apricot:
        return ColorPalette[1];
      case CustomColor.yellow:
        return ColorPalette[2];
      case CustomColor.green:
        return ColorPalette[3];
      case CustomColor.blue:
        return ColorPalette[4];
      case CustomColor.pink:
        return ColorPalette[5];
      case CustomColor.red:
        return ColorPalette[6];
      case CustomColor.orange:
        return ColorPalette[7];
      case CustomColor.lightgrey:
        return ColorPalette[8];
      case CustomColor.mint:
        return ColorPalette[9];
      default:
        return MyColors.defaultIcon;
    }
  }

  static Color getBackgroundColorByEnum(CustomColor color) {
    switch (color) {
      case CustomColor.purple:
        return BackgroundColorPalette[0];
      case CustomColor.apricot:
        return BackgroundColorPalette[1];
      case CustomColor.yellow:
        return BackgroundColorPalette[2];
      case CustomColor.green:
        return BackgroundColorPalette[3];
      case CustomColor.blue:
        return BackgroundColorPalette[4];
      case CustomColor.pink:
        return BackgroundColorPalette[5];
      case CustomColor.red:
        return BackgroundColorPalette[6];
      case CustomColor.orange:
        return BackgroundColorPalette[7];
      case CustomColor.lightgrey:
        return BackgroundColorPalette[8];
      case CustomColor.mint:
        return BackgroundColorPalette[9];
      default:
        return MyColors.defaultBackground;
    }
  }

  static int getIntFromColor(CustomColor color) {
    switch (color) {
      case CustomColor.purple:
        return 0;
      case CustomColor.apricot:
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
      return MyColors.defaultIcon;
    }

    return ColorPalette[index % ColorPalette.length];
  }

  static Color getBackgroundColorByIndex(int index) {
    if (index < 0 || index > 9) {
      return MyColors.defaultBackground;
    }

    return BackgroundColorPalette[index % ColorPalette.length];
  }

  static List<Color> getGradientColors(List<MultisigSigner> list) {
    if (list.isEmpty) {
      return [MyColors.borderLightgrey];
    }

    Color getColor(MultisigSigner item) {
      return item.innerVaultId != null
          ? CustomColorHelper.getColorByIndex(item.colorIndex ?? 0)
          : MyColors.borderLightgrey;
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

enum CustomColor {
  purple,
  apricot,
  yellow,
  green,
  blue,
  pink,
  red,
  orange,
  lightgrey,
  mint,
}
