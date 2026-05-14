import 'package:coconut_design_system/coconut_design_system.dart' as ds;
import 'package:coconut_wallet/design_system/tokens/coconut_colors.dart';
import 'package:flutter/widgets.dart';

enum CustomFonts { number, text }

extension FontsExtension on CustomFonts {
  String get getFontFamily {
    switch (this) {
      case CustomFonts.number:
        return 'SpaceGrotesk';
      case CustomFonts.text:
        return 'Pretendard';
    }
  }
}

abstract class Styles {
  static const _fontNumber = 'SpaceGrotesk';
  static const _fontText = 'Pretendard';

  static const TextStyle h1Number = TextStyle(
    fontFamily: _fontNumber,
    color: MyColors.white,
    fontSize: 32,
    fontStyle: FontStyle.normal,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle h2Number = TextStyle(
    fontFamily: _fontNumber,
    color: MyColors.white,
    fontSize: 18,
    fontStyle: FontStyle.normal,
    fontWeight: FontWeight.w700,
    height: 1,
  );

  static const TextStyle h1 = TextStyle(
    fontFamily: _fontText,
    color: MyColors.white,
    fontSize: 32,
    fontStyle: FontStyle.normal,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle h2 = TextStyle(
    fontFamily: _fontNumber,
    color: MyColors.black,
    fontSize: 28,
    fontStyle: FontStyle.normal,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle h3 = TextStyle(
    fontFamily: _fontText,
    color: MyColors.white,
    fontSize: 18,
    fontStyle: FontStyle.normal,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
  );

  static const TextStyle appbarTitle = TextStyle(
    fontFamily: _fontText,
    color: MyColors.white,
    fontSize: 18,
    fontStyle: FontStyle.normal,
  );

  static const TextStyle h3Number = TextStyle(
    fontFamily: _fontNumber,
    color: MyColors.white,
    fontSize: 22,
    fontStyle: FontStyle.normal,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
  );

  static const TextStyle label = TextStyle(
    fontFamily: _fontText,
    color: MyColors.transparentWhite_70,
    fontSize: 14,
    fontStyle: FontStyle.normal,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle label2 = TextStyle(
    fontFamily: _fontText,
    color: MyColors.transparentWhite_70,
    fontSize: 11,
    fontStyle: FontStyle.normal,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle subLabel = TextStyle(
    fontFamily: _fontText,
    color: MyColors.transparentBlack,
    fontSize: 16,
    fontStyle: FontStyle.normal,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle body1 = TextStyle(
    fontFamily: _fontText,
    color: MyColors.white,
    fontSize: 16,
    fontStyle: FontStyle.normal,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle body1Number = TextStyle(
    fontFamily: _fontNumber,
    color: MyColors.white,
    fontSize: 16,
    fontStyle: FontStyle.normal,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle body1Bold = TextStyle(
    fontFamily: _fontText,
    color: MyColors.white,
    fontSize: 16,
    fontStyle: FontStyle.normal,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle body2 = TextStyle(
    fontFamily: _fontText,
    color: MyColors.white,
    fontSize: 14,
    fontStyle: FontStyle.normal,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle body2Number = TextStyle(
    fontFamily: _fontNumber,
    color: MyColors.white,
    fontSize: 14,
    fontStyle: FontStyle.normal,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle body2Bold = TextStyle(
    fontFamily: _fontText,
    color: MyColors.white,
    fontSize: 14,
    fontStyle: FontStyle.normal,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle body2Grey = TextStyle(
    fontFamily: _fontText,
    color: MyColors.transparentWhite_40,
    fontSize: 14,
    fontStyle: FontStyle.normal,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle body3 = TextStyle(
    fontFamily: _fontText,
    color: MyColors.white,
    fontSize: 12,
    height: 18 / 12,
    letterSpacing: -0.02,
    fontStyle: FontStyle.normal,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle unit1 = TextStyle(
    fontFamily: _fontNumber,
    color: MyColors.transparentBlack,
    fontSize: 24,
    fontStyle: FontStyle.normal,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle unit2 = TextStyle(
    fontFamily: _fontNumber,
    color: MyColors.transparentBlack,
    fontSize: 20,
    fontStyle: FontStyle.normal,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle navHeader = TextStyle(
    fontFamily: _fontText,
    color: MyColors.white,
    fontSize: 16,
    fontStyle: FontStyle.normal,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle whiteButtonTitle = TextStyle(
    fontFamily: _fontText,
    color: MyColors.black,
    fontSize: 16,
    fontStyle: FontStyle.normal,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle whiteButtonTitle_small = TextStyle(
    fontFamily: _fontText,
    color: MyColors.black,
    fontSize: 14,
    fontStyle: FontStyle.normal,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle CTAButtonTitle = TextStyle(
    fontFamily: _fontText,
    color: MyColors.black,
    fontSize: 16,
    fontStyle: FontStyle.normal,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: _fontNumber,
    color: MyColors.transparentWhite_70,
    fontSize: 12,
    fontStyle: FontStyle.normal,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle caption2 = TextStyle(
    fontFamily: _fontText,
    color: MyColors.transparentWhite_70,
    fontSize: 10,
    fontStyle: FontStyle.normal,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle warning = TextStyle(
    fontFamily: _fontText,
    color: MyColors.red,
    fontSize: 12,
    fontStyle: FontStyle.normal,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle title5 = TextStyle(
    fontFamily: _fontText,
    color: MyColors.white,
    fontSize: 20,
    fontStyle: FontStyle.normal,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle balance1 = TextStyle(
    fontFamily: _fontNumber,
    color: MyColors.white,
    fontSize: 36,
    fontStyle: FontStyle.normal,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle balance2 = TextStyle(
    fontFamily: _fontNumber,
    color: MyColors.transparentWhite_60,
    fontSize: 14,
    fontStyle: FontStyle.normal,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle fee = TextStyle(
    fontFamily: _fontNumber,
    color: MyColors.white,
    fontSize: 22,
    fontStyle: FontStyle.normal,
    fontWeight: FontWeight.w600,
  );

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
    fontWeight: FontWeight.w400,
  );
}

@immutable
class CoconutTypography {
  final TextStyle title;
  final TextStyle body;
  final TextStyle bodyBold;
  final TextStyle bodyNumber;
  final TextStyle caption;
  final TextStyle action;

  const CoconutTypography({
    required this.title,
    required this.body,
    required this.bodyBold,
    required this.bodyNumber,
    required this.caption,
    required this.action,
  });

  factory CoconutTypography.dark() {
    return const CoconutTypography(
      title: TextStyle(
        fontFamily: 'Pretendard',
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: Color(0xffffffff),
      ),
      body: TextStyle(
        fontFamily: 'Pretendard',
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: Color(0xffffffff),
      ),
      bodyBold: TextStyle(
        fontFamily: 'Pretendard',
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Color(0xffffffff),
      ),
      bodyNumber: TextStyle(
        fontFamily: 'SpaceGrotesk',
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: Color(0xffffffff),
      ),
      caption: TextStyle(
        fontFamily: 'Pretendard',
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: ds.CoconutColors.gray400,
      ),
      action: TextStyle(
        fontFamily: 'Pretendard',
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Color(0xffffffff),
      ),
    );
  }
}
