import 'package:flutter/material.dart';
import 'dart:math' as math;

abstract class MyColors {
  static const black = Color.fromRGBO(20, 19, 24, 1);
  static const nero = Color.fromRGBO(26, 26, 26, 1);
  static const shadowGray = Color.fromRGBO(34, 33, 38, 1);
  static const transparentBlack = Color.fromRGBO(0, 0, 0, 0.7);
  static const transparentBlack_03 = Color.fromRGBO(0, 0, 0, 0.03);
  static const grey = Color.fromRGBO(48, 47, 52, 1);
  static const gray200 = Color(0xFFEFEFEF);
  static const white = Color.fromRGBO(255, 255, 255, 1);
  static const transparentWhite = Color.fromRGBO(255, 255, 255, 0.2);
  static const transparentWhite_06 = Color.fromRGBO(255, 255, 255, 0.06);
  static const transparentWhite_10 = Color.fromRGBO(255, 255, 255, 0.10);
  static const transparentWhite_12 = Color.fromRGBO(255, 255, 255, 0.12);
  static const transparentWhite_15 = Color.fromRGBO(255, 255, 255, 0.15);
  static const transparentWhite_20 = Color.fromRGBO(255, 255, 255, 0.2);
  static const transparentWhite_30 = Color.fromRGBO(255, 255, 255, 0.3);
  static const transparentWhite_40 = Color.fromRGBO(255, 255, 255, 0.4);
  static const transparentWhite_50 = Color.fromRGBO(255, 255, 255, 0.5);
  static const transparentWhite_60 = Color.fromRGBO(255, 255, 255, 0.6);
  static const transparentWhite_70 = Color.fromRGBO(255, 255, 255, 0.7);
  static const transparentWhite_90 = Color.fromRGBO(255, 255, 255, 0.9);
  static const transparentBlack_06 = Color.fromRGBO(0, 0, 0, 0.06);
  static const transparentBlack_30 = Color.fromRGBO(0, 0, 0, 0.3);
  static const transparentBlack_50 = Color.fromRGBO(0, 0, 0, 0.5);

  static const darkgrey = Color.fromRGBO(48, 47, 52, 1);
  static const transparentGrey = Color.fromRGBO(20, 19, 24, 0.15);
  static const lightgrey = Color.fromRGBO(244, 244, 245, 1);
  static const red = Color.fromRGBO(255, 0, 0, 1);
  static const transparentRed = Color.fromRGBO(242, 147, 146, 0.15);
  // tesnet tag
  static const cyanblue = Color.fromRGBO(69, 204, 238, 1);
  static const skybule = Color.fromRGBO(179, 240, 255, 1);
  static const lightblue = Color.fromRGBO(235, 246, 255, 1);

  static const oceanBlue = Color.fromRGBO(88, 135, 249, 1);

  static const borderGrey = Color.fromRGBO(81, 81, 96, 1);
  static const borderLightgrey = Color.fromRGBO(235, 231, 228, 0.2);
  static const defaultIcon = Color.fromRGBO(221, 219, 230, 1);
  static const defaultBackground = Color.fromRGBO(255, 255, 255, 0.1);
  static const defaultText = Color.fromRGBO(221, 219, 230, 1);

  static const warningRed = Color.fromRGBO(218, 65, 92, 1.0); // color6Red
  static const transparentWarningRed = Color.fromRGBO(218, 65, 92, 0.7);
  static const backgroundActive =
      Color.fromRGBO(145, 179, 242, 0.67); // color4Blue

  static const primary = Color.fromRGBO(222, 255, 88, 1);
  static const secondary = Color.fromRGBO(0, 196, 255, 1.0);

  static const warningYellow = Color.fromRGBO(255, 175, 3, 1.0);
  static const warningYellowBackground = Color.fromRGBO(255, 243, 190, 1.0);

  static const failedYellow = Color.fromRGBO(218, 152, 65, 1);

  static const Color bottomSheetBackground = Color(0xFF232222);
  static const Color selectBackground = Color(0xFF393939);
  static const Color gray800 = Color(0xFF303030);
}

const List<Color> ColorPalette = [
  Color.fromRGBO(163, 100, 217, 1.0), // color0Purple
  Color.fromRGBO(250, 156, 90, 1.0), // color1Apricot
  Color.fromRGBO(254, 204, 47, 1.0), // color2Yellow
  Color.fromRGBO(136, 193, 37, 1.0), // color3Green
  Color.fromRGBO(65, 164, 216, 1.0), // color4Blue
  Color.fromRGBO(238, 101, 121, 1.0), // color5Pink
  Color.fromRGBO(219, 57, 55, 1.0), // color6Red
  Color.fromRGBO(245, 99, 33, 1.0), // color7Orange
  Color.fromRGBO(154, 154, 154, 1.0), // color8Lightgrey
  Color.fromRGBO(51, 191, 184, 1.0), // color9Mint
];

const List<Color> BackgroundColorPalette = [
  Color.fromRGBO(167, 122, 254, 0.18), // color0Purple
  Color.fromRGBO(242, 147, 146, 0.18), // color1Apricot
  Color.fromRGBO(246, 215, 118, 0.18), // color2Yellow
  Color.fromRGBO(146, 199, 154, 0.18), // color3Green
  Color.fromRGBO(145, 179, 242, 0.18), // color4Blue
  Color.fromRGBO(235, 140, 215, 0.18), // color5Pink
  Color.fromRGBO(206, 91, 111, 0.18), // color6Red
  Color.fromRGBO(229, 164, 103, 0.18), // color7Orange
  Color.fromRGBO(230, 230, 230, 0.18), // color8Lightgrey
  Color.fromRGBO(158, 226, 230, 0.18), // color9Mint
];

enum CustomFonts { number, text }

extension FontsExtension on CustomFonts {
  String get getFontFamily {
    switch (this) {
      case CustomFonts.number:
        return 'SpaceGrotesk';
      case CustomFonts.text:
        return 'Pretendard';
      default:
        return 'Pretendard';
    }
  }
}

abstract class Styles {
  static const _fontNumber = 'SpaceGrotesk';
  static const _fontText = 'Pretendard';

  // 지갑 상세 화면의 잔액 표기
  static const TextStyle h1Number = TextStyle(
      fontFamily: _fontNumber,
      color: MyColors.white,
      fontSize: 32,
      fontStyle: FontStyle.normal,
      fontWeight: FontWeight.w700);

  static const TextStyle h2Number = TextStyle(
      fontFamily: _fontNumber,
      color: MyColors.white,
      fontSize: 18,
      fontStyle: FontStyle.normal,
      fontWeight: FontWeight.w700,
      height: 1);

  static const TextStyle h1 = TextStyle(
      fontFamily: _fontText,
      color: MyColors.white,
      fontSize: 32,
      fontStyle: FontStyle.normal,
      fontWeight: FontWeight.w700);

// wallet_list 화면의 잔액 표기
  static const TextStyle h2 = TextStyle(
    fontFamily: _fontNumber,
    color: MyColors.black,
    fontSize: 28,
    fontStyle: FontStyle.normal,
    fontWeight: FontWeight.w700,
  );

// 거래내역, '수수료를 입력하세요',
  static const TextStyle h3 = TextStyle(
      fontFamily: _fontText,
      color: Colors.white,
      fontSize: 18,
      fontStyle: FontStyle.normal,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.2);

  static const TextStyle appbarTitle = TextStyle(
      fontFamily: _fontText,
      color: MyColors.white,
      fontSize: 18,
      fontStyle: FontStyle.normal);

  static const TextStyle h3Number = TextStyle(
      fontFamily: _fontNumber,
      color: Colors.white,
      fontSize: 22,
      fontStyle: FontStyle.normal,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.2);

  static const TextStyle label = TextStyle(
      fontFamily: _fontText,
      color: MyColors.transparentWhite_70,
      fontSize: 14,
      fontStyle: FontStyle.normal,
      fontWeight: FontWeight.w500);

  static const TextStyle label2 = TextStyle(
      fontFamily: _fontText,
      color: MyColors.transparentWhite_70,
      fontSize: 11,
      fontStyle: FontStyle.normal,
      fontWeight: FontWeight.w500);

  static const TextStyle subLabel = TextStyle(
      fontFamily: _fontText,
      color: MyColors.transparentBlack,
      fontSize: 16,
      fontStyle: FontStyle.normal,
      fontWeight: FontWeight.w400);

  static const TextStyle body1 = TextStyle(
      fontFamily: _fontText,
      color: MyColors.white,
      fontSize: 16,
      fontStyle: FontStyle.normal,
      fontWeight: FontWeight.w400);

  static const TextStyle body1Number = TextStyle(
      fontFamily: _fontNumber,
      color: MyColors.white,
      fontSize: 16,
      fontStyle: FontStyle.normal,
      fontWeight: FontWeight.w400);

  static const TextStyle body1Bold = TextStyle(
      fontFamily: _fontText,
      color: MyColors.white,
      fontSize: 16,
      fontStyle: FontStyle.normal,
      fontWeight: FontWeight.bold);

  static const TextStyle body2 = TextStyle(
      fontFamily: _fontText,
      color: MyColors.white,
      fontSize: 14,
      fontStyle: FontStyle.normal,
      fontWeight: FontWeight.w400);

  static const TextStyle body2Number = TextStyle(
      fontFamily: _fontNumber,
      color: MyColors.white,
      fontSize: 14,
      fontStyle: FontStyle.normal,
      fontWeight: FontWeight.w400);

  static const TextStyle body2Bold = TextStyle(
      fontFamily: _fontText,
      color: MyColors.white,
      fontSize: 14,
      fontStyle: FontStyle.normal,
      fontWeight: FontWeight.w600);

  static const TextStyle body2Grey = TextStyle(
      fontFamily: _fontText,
      color: MyColors.transparentWhite_40,
      fontSize: 14,
      fontStyle: FontStyle.normal,
      fontWeight: FontWeight.w400);

  static const TextStyle body3 = TextStyle(
      fontFamily: _fontText,
      color: MyColors.white,
      fontSize: 12,
      height: 18 / 12,
      letterSpacing: -0.02,
      fontStyle: FontStyle.normal,
      fontWeight: FontWeight.w400);

  static const TextStyle unit1 = TextStyle(
      fontFamily: _fontNumber,
      color: MyColors.transparentBlack,
      fontSize: 24,
      fontStyle: FontStyle.normal,
      fontWeight: FontWeight.w400);

  static const TextStyle unit2 = TextStyle(
      fontFamily: _fontNumber,
      color: MyColors.transparentBlack,
      fontSize: 20,
      fontStyle: FontStyle.normal,
      fontWeight: FontWeight.w400);

  static const TextStyle navHeader = TextStyle(
      fontFamily: _fontText,
      color: Color.fromRGBO(255, 255, 255, 1),
      fontSize: 16,
      fontStyle: FontStyle.normal,
      fontWeight: FontWeight.w500);

  static const TextStyle whiteButtonTitle = TextStyle(
      fontFamily: _fontText,
      color: MyColors.black,
      fontSize: 16,
      fontStyle: FontStyle.normal,
      fontWeight: FontWeight.w400);

  static const TextStyle whiteButtonTitle_small = TextStyle(
      fontFamily: _fontText,
      color: MyColors.black,
      fontSize: 14,
      fontStyle: FontStyle.normal,
      fontWeight: FontWeight.w400);

  static const TextStyle CTAButtonTitle = TextStyle(
      fontFamily: _fontText,
      color: MyColors.black,
      fontSize: 16,
      fontStyle: FontStyle.normal,
      fontWeight: FontWeight.bold);

  static const TextStyle caption = TextStyle(
      fontFamily: _fontNumber,
      color: MyColors.transparentWhite_70,
      fontSize: 12,
      fontStyle: FontStyle.normal,
      fontWeight: FontWeight.w400);

  static const TextStyle caption2 = TextStyle(
      fontFamily: _fontText,
      color: MyColors.transparentWhite_70,
      fontSize: 10,
      fontStyle: FontStyle.normal,
      fontWeight: FontWeight.w400);

  static const TextStyle warning = TextStyle(
      fontFamily: _fontText,
      color: MyColors.red,
      fontSize: 12,
      fontStyle: FontStyle.normal,
      fontWeight: FontWeight.w400);

  static const TextStyle title5 = TextStyle(
      fontFamily: _fontText,
      color: MyColors.white,
      fontSize: 20,
      fontStyle: FontStyle.normal,
      fontWeight: FontWeight.w600);

  static const TextStyle balance1 = TextStyle(
      fontFamily: _fontNumber,
      color: MyColors.white,
      fontSize: 36,
      fontStyle: FontStyle.normal,
      fontWeight: FontWeight.w600);

  static const TextStyle balance2 = TextStyle(
      fontFamily: _fontNumber,
      color: MyColors.transparentWhite_60,
      fontSize: 14,
      fontStyle: FontStyle.normal,
      fontWeight: FontWeight.w400);

  static const TextStyle fee = TextStyle(
      fontFamily: _fontNumber,
      color: MyColors.white,
      fontSize: 22,
      fontStyle: FontStyle.normal,
      fontWeight: FontWeight.w600);

  static const TextStyle unit = TextStyle(
    fontFamily: _fontNumber,
    color: MyColors.white,
    fontSize: 18,
    fontStyle: FontStyle.normal,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle unitSmall = TextStyle(
    fontFamily: _fontNumber,
    fontSize: 13.0,
    color: MyColors.transparentWhite_70,
    fontStyle: FontStyle.normal,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle mfpH3 = TextStyle(
      fontFamily: _fontNumber,
      color: MyColors.white,
      fontSize: 16,
      fontStyle: FontStyle.normal,
      fontWeight: FontWeight.w400);
}

abstract class MyBorder {
  static const double defaultRadiusValue = 24.0;
  static final BorderRadius defaultRadius =
      BorderRadius.circular(defaultRadiusValue);
  static final BorderRadius boxDecorationRadius = BorderRadius.circular(28);
}

class Paddings {
  static const EdgeInsets container =
      EdgeInsets.symmetric(horizontal: 10, vertical: 20);
  static const EdgeInsets widgetContainer =
      EdgeInsets.symmetric(horizontal: 20, vertical: 15);
}

class BoxDecorations {
  static BorderRadius boxDecorationRadius = BorderRadius.circular(8);

  static BoxDecoration boxDecoration = BoxDecoration(
    borderRadius: MyBorder.boxDecorationRadius,
    color: MyColors.transparentWhite_06,
  );

  static LinearGradient getMultisigLinearGradient(List<Color> colors) {
    return LinearGradient(
        colors: colors,
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        transform: const GradientRotation(math.pi / 10));
  }
}
