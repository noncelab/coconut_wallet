import 'package:coconut_design_system/coconut_design_system.dart' as ds;
import 'package:flutter/widgets.dart';

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
  static const cyanblue = Color.fromRGBO(69, 204, 238, 1);
  static const skybule = Color.fromRGBO(179, 240, 255, 1);
  static const lightblue = Color.fromRGBO(235, 246, 255, 1);
  static const oceanBlue = Color.fromRGBO(88, 135, 249, 1);
  static const borderGrey = Color.fromRGBO(81, 81, 96, 1);
  static const borderLightgrey = Color.fromRGBO(235, 231, 228, 0.2);
  static const defaultIcon = Color.fromRGBO(221, 219, 230, 1);
  static const defaultBackground = Color.fromRGBO(255, 255, 255, 0.1);
  static const defaultText = Color.fromRGBO(221, 219, 230, 1);
  static const warningRed = Color.fromRGBO(218, 65, 92, 1.0);
  static const transparentWarningRed = Color.fromRGBO(218, 65, 92, 0.7);
  static const backgroundActive = Color.fromRGBO(145, 179, 242, 0.67);
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
  Color.fromRGBO(163, 100, 217, 1.0),
  Color.fromRGBO(250, 156, 90, 1.0),
  Color.fromRGBO(254, 204, 47, 1.0),
  Color.fromRGBO(136, 193, 37, 1.0),
  Color.fromRGBO(65, 164, 216, 1.0),
  Color.fromRGBO(238, 101, 121, 1.0),
  Color.fromRGBO(219, 57, 55, 1.0),
  Color.fromRGBO(245, 99, 33, 1.0),
  Color.fromRGBO(154, 154, 154, 1.0),
  Color.fromRGBO(51, 191, 184, 1.0),
];

const List<Color> BackgroundColorPalette = [
  Color.fromRGBO(167, 122, 254, 0.18),
  Color.fromRGBO(242, 147, 146, 0.18),
  Color.fromRGBO(246, 215, 118, 0.18),
  Color.fromRGBO(146, 199, 154, 0.18),
  Color.fromRGBO(145, 179, 242, 0.18),
  Color.fromRGBO(235, 140, 215, 0.18),
  Color.fromRGBO(206, 91, 111, 0.18),
  Color.fromRGBO(229, 164, 103, 0.18),
  Color.fromRGBO(230, 230, 230, 0.18),
  Color.fromRGBO(158, 226, 230, 0.18),
];

@immutable
class CoconutColors {
  final Color background;
  final Color surface;
  final Color surfaceCard;
  final Color surfaceCardStrong;
  final Color surfaceButton;
  final Color surfaceMuted;
  final Color surfaceDisabled;
  final Color surfaceBottomSheet;
  final Color surfaceSectionBreak;
  final Color surfaceFilterChip;
  final Color surfaceFilterChipSelected;
  final Color surfaceSkeletonBase;
  final Color surfaceSkeletonHighlight;
  final Color surfacePressed;
  final Color inputSurface;
  final Color primary;
  final Color primaryText;
  final Color secondaryText;
  final Color tertiaryText;
  final Color textFilterChip;
  final Color textFilterChipSelected;
  final Color borderSubtle;
  final Color borderStrong;
  final Color iconDefault;
  final Color iconSubDefault;
  final Color iconHighlight;
  final Color iconDisabled;
  final Color danger;
  final Color success;
  final Color pulldownMenuBackground;
  final Color pulldownMenuDividerColor;
  final Color pulldownMenuTextColor;
  final Color shadowDefault;
  final Color popupBackground;
  final Color pageIndicatorActive;
  final Color pageIndicatorInactive;
  final Color sendingColor;
  final Color receivingColor;
  final Color bottomActionBarBackground;

  const CoconutColors({
    required this.background,
    required this.surface,
    required this.surfaceCard,
    required this.surfaceCardStrong,
    required this.surfaceButton,
    required this.surfaceMuted,
    required this.surfaceDisabled,
    required this.surfaceBottomSheet,
    required this.surfaceSectionBreak,
    required this.surfaceFilterChip,
    required this.surfaceFilterChipSelected,
    required this.surfaceSkeletonBase,
    required this.surfaceSkeletonHighlight,
    required this.surfacePressed,
    required this.inputSurface,
    required this.primary,
    required this.primaryText,
    required this.secondaryText,
    required this.tertiaryText,
    required this.textFilterChip,
    required this.textFilterChipSelected,
    required this.borderSubtle,
    required this.borderStrong,
    required this.iconDefault,
    required this.iconSubDefault,
    required this.iconHighlight,
    required this.iconDisabled,
    required this.danger,
    required this.success,
    required this.pulldownMenuBackground,
    required this.pulldownMenuDividerColor,
    required this.pulldownMenuTextColor,
    required this.shadowDefault,
    required this.popupBackground,
    required this.pageIndicatorActive,
    required this.pageIndicatorInactive,
    required this.sendingColor,
    required this.receivingColor,
    required this.bottomActionBarBackground,
  });

  factory CoconutColors.dark() {
    return const CoconutColors(
      background: ds.CoconutColors.black,
      surface: ds.CoconutColors.gray850,
      surfaceCard: ds.CoconutColors.gray850,
      surfaceCardStrong: ds.CoconutColors.gray900,
      surfaceButton: ds.CoconutColors.gray850,
      surfaceMuted: ds.CoconutColors.gray850,
      surfaceDisabled: ds.CoconutColors.gray850,
      surfaceBottomSheet: ds.CoconutColors.gray900,
      surfaceSectionBreak: ds.CoconutColors.gray900,
      surfaceFilterChip: ds.CoconutColors.gray800,
      surfaceFilterChipSelected: ds.CoconutColors.white,
      surfaceSkeletonBase: ds.CoconutColors.gray850,
      surfaceSkeletonHighlight: ds.CoconutColors.gray750,
      surfacePressed: ds.CoconutColors.gray900,
      inputSurface: ds.CoconutColors.gray800,
      primary: ds.CoconutColors.primary,
      primaryText: ds.CoconutColors.white,
      secondaryText: ds.CoconutColors.gray400,
      tertiaryText: ds.CoconutColors.gray600,
      textFilterChip: ds.CoconutColors.white,
      textFilterChipSelected: ds.CoconutColors.gray800,
      borderSubtle: ds.CoconutColors.gray700,
      borderStrong: ds.CoconutColors.white,
      iconDefault: ds.CoconutColors.white,
      iconSubDefault: ds.CoconutColors.gray400,
      iconHighlight: ds.CoconutColors.gray850,
      iconDisabled: ds.CoconutColors.gray600,
      danger: ds.CoconutColors.hotPink,
      success: ds.CoconutColors.cyanBlue,
      pulldownMenuBackground: ds.CoconutColors.gray900,
      pulldownMenuDividerColor: ds.CoconutColors.black,
      pulldownMenuTextColor: ds.CoconutColors.white,
      shadowDefault: ds.CoconutColors.white,
      popupBackground: ds.CoconutColors.gray900,
      pageIndicatorActive: ds.CoconutColors.gray400,
      pageIndicatorInactive: ds.CoconutColors.gray800,
      sendingColor: ds.CoconutColors.primary,
      receivingColor: ds.CoconutColors.cyanBlue,
      bottomActionBarBackground: ds.CoconutColors.gray900,
    );
  }

  factory CoconutColors.ccosPreview() {
    return const CoconutColors(
      background: Color(0xFFF6F3EA),
      surface: Color(0xFFE5EEF7),
      surfaceCard: Color(0xFFD9E8F5),
      surfaceCardStrong: Color(0xFFCDBFD9),
      surfaceButton: Color(0xFFDCEFE3),
      surfaceMuted: Color(0xFFEDE3CF),
      surfaceDisabled: Color(0xFFE2D9DE),
      surfaceBottomSheet: Color(0xFFE8E0F2),
      surfaceSectionBreak: Color(0xFFD8CCE9),
      surfaceFilterChip: Color(0xFFDCEFE3),
      surfaceFilterChipSelected: Color(0xFF181A1F),
      surfaceSkeletonBase: Color(0xFFD7D1E6),
      surfaceSkeletonHighlight: Color(0xFFF0EBFA),
      surfacePressed: Color(0xFFCBB8D8),
      inputSurface: Color(0xFFE6DCCB),
      primary: ds.CoconutColors.primary,
      primaryText: Color(0xFF181A1F),
      secondaryText: Color(0xFF454B57),
      tertiaryText: Color(0xFF727987),
      textFilterChip: Color(0xFF181A1F),
      textFilterChipSelected: Color(0xFFF6F3EA),
      borderSubtle: Color(0xFF98A3B3),
      borderStrong: Color(0xFF181A1F),
      iconDefault: Color(0xFF181A1F),
      iconSubDefault: Color(0xFF727987),
      iconHighlight: Color(0xFFD9E8F5),
      iconDisabled: Color(0xFF727987),
      danger: ds.CoconutColors.hotPink,
      success: ds.CoconutColors.cyanBlue,
      pulldownMenuBackground: Color.fromARGB(255, 85, 61, 115),
      pulldownMenuDividerColor: Color(0xFFD8CCE9),
      shadowDefault: Color(0xFF181A1F),
      pulldownMenuTextColor: Color(0xFF181A1F),
      popupBackground: Color(0xFFE8E0F2),
      pageIndicatorActive: Color(0xFF454B57),
      pageIndicatorInactive: Color(0xFFCBB8D8),
      sendingColor: Color.fromARGB(255, 163, 124, 189),
      receivingColor: Color.fromARGB(255, 102, 136, 136),
      bottomActionBarBackground: Color(0xFFE8E0F2),
    );
  }
}
