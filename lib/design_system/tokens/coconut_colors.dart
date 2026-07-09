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
  final Color homeBackground;
  final Color homeSurfaceCard;
  final Color homeSurfaceCardPressed;
  final Color background;
  final Color backgroundSubtle;
  final Color backgroundHighlight;
  final Color backgroundHighlightText;
  final Color blurButtonBackground;
  final Color surface;
  final Color surfaceDeep;
  final Color surfaceCard;
  final Color surfaceButton;
  final Color surfaceButtonText;
  final Color surfaceButtonSecondary;
  final Color surfaceButtonSecondaryText;
  final Color surfaceMuted;
  final Color surfaceRaised;
  final Color surfaceDisabled;
  final Color surfaceBottomSheet;
  final Color surfaceSectionBreak;
  final Color surfaceFilterChip;
  final Color surfaceFilterChipPressed;
  final Color surfaceFilterChipSelected;
  final Color surfaceSkeletonBase;
  final Color surfaceSkeletonHighlight;
  final Color chartSurface;
  final Color coinSurface;
  final Color selectedCoinBorder;
  final Color billSurface;
  final Color selectionOverlay;
  final Color surfaceSelected;
  final Color surfacePressed;
  final Color inputSurface;
  final Color inputPlaceholder;
  final Color primary;
  final Color primaryText;
  final Color primaryButtonBackground;
  final Color primaryButtonPressed;
  final Color primaryButtonText;
  final Color secondaryText;
  final Color secondaryTextStrong;
  final Color secondaryButtonBackground;
  final Color secondaryButtonText;
  final Color segmentedControlSelected;
  final Color segmentedControlBackground;
  final Color segmentedControlSelectedText;
  final Color segmentedControlUnselectedText;
  final Color tertiaryText;
  final Color tooltipBackground;
  final Color mutedText;
  final Color textFilterChip;
  final Color textFilterChipSelected;
  final Color textHighlight;
  final Color border;
  final Color borderStrong;
  final Color iconBackground;
  final Color iconBackgroundSubtle;
  final Color iconDefault;
  final Color iconSubDefault;
  final Color iconHighlight;
  final Color iconDisabled;
  final Color warning;
  final Color danger;
  final Color success;
  final Color rbfAccent;
  final Color cpfpAccent;
  final Color recommendFeeAnimStart;
  final Color recommendFeeAnimHighlight;
  final Color taprootParent;
  final Color taprootChild;
  final Color taprootRoleText;
  final Color taprootParticipantIconBorder;
  final Color taprootParticipantIconBackground;
  final Color taprootParticipantNeutralBackground;
  final Color taprootParticipantNeutralBorder;
  final Color taprootParticipantNeutralRoleBackground;
  final Color taprootParticipantNeutralRoleBorder;
  final Color taprootParticipantNeutralRoleText;
  final Color pulldownMenuBackground;
  final Color pulldownMenuPressedColor;
  final Color pulldownMenuDividerColor;
  final Color pulldownMenuTextColor;
  final Color shadowDefault;
  final Color shadowSubtle;
  final Color popupBackground;
  final Color dimOverlay;
  final Color pageIndicatorActive;
  final Color pageIndicatorInactive;

  /// 보내는 중 아이콘/로티 색상
  final Color sendingColor;

  /// 받는 중 아이콘/로티 색상
  final Color receivingColor;

  final Color bottomActionBarBackground;
  final Color bottomSheetKeyboardToolbar;
  final Color bottomSheetExtensionFieldBackground;
  final Color loadingIndicatorColor;
  final Color loadingOverlay;
  final Color glossaryKeywordBackground;
  final Color glossaryKeywordText;
  final Color divider;
  final Color txFlowLine;
  final Color feeBumpingHistoryLine;
  final Color switchActiveTrack;
  final Color switchInactiveTrack;
  final Color switchThumb;
  final Color switchTrackDisabled;
  final Color switchThumbDisabled;
  final Color linkText;
  final Color nodeConnected;
  final Color nodeFailed;

  /// 아이콘 탭 시 말풍선 형태로 표시되는 Popover 툴팁
  final Color popoverBackground;
  final Color popoverText;

  /// Faucet 전용 Popover 툴팁 (하늘색 강조 배경) (only Regtest)
  final Color faucetPopoverBackground;
  final Color faucetPopoverText;

  /// 바텀시트 상단 드래그 핸들 바
  final Color bottomSheetHandle;

  /// QR 스캐너 (카메라 오버레이)
  final Color qrScannerOverlay;

  /// QR 스캐너 프로그레스 바
  final Color qrScannerProgressBarTrack;
  final Color qrScannerProgressBarFill;

  /// 체크 아이콘 배경/아이콘 색상 쌍
  /// [checkIconBackground] / [checkIconForeground]: 활성화(isEnabled=true) 상태
  /// [checkIconBackgroundDisabled] / [checkIconForegroundDisabled]: 비활성화(isEnabled=false) 상태
  final Color checkIconBackground;
  final Color checkIconForeground;
  final Color checkIconBackgroundDisabled;
  final Color checkIconForegroundDisabled;

  const CoconutColors({
    required this.homeBackground,
    required this.homeSurfaceCard,
    required this.homeSurfaceCardPressed,
    required this.background,
    required this.backgroundSubtle,
    required this.backgroundHighlight,
    required this.backgroundHighlightText,
    required this.blurButtonBackground,
    required this.surface,
    required this.surfaceDeep,
    required this.surfaceCard,
    required this.surfaceButton,
    required this.surfaceButtonText,
    required this.surfaceButtonSecondary,
    required this.surfaceButtonSecondaryText,
    required this.surfaceMuted,
    required this.surfaceRaised,
    required this.surfaceDisabled,
    required this.surfaceBottomSheet,
    required this.surfaceSectionBreak,
    required this.surfaceFilterChip,
    required this.surfaceFilterChipPressed,
    required this.surfaceFilterChipSelected,
    required this.surfaceSkeletonBase,
    required this.surfaceSkeletonHighlight,
    required this.chartSurface,
    required this.coinSurface,
    required this.selectedCoinBorder,
    required this.billSurface,
    required this.selectionOverlay,
    required this.surfaceSelected,
    required this.surfacePressed,
    required this.inputSurface,
    required this.inputPlaceholder,
    required this.primary,
    required this.primaryText,
    required this.primaryButtonBackground,
    required this.primaryButtonPressed,
    required this.primaryButtonText,
    required this.secondaryText,
    required this.secondaryTextStrong,
    required this.secondaryButtonBackground,
    required this.secondaryButtonText,
    required this.segmentedControlSelected,
    required this.segmentedControlBackground,
    required this.segmentedControlSelectedText,
    required this.segmentedControlUnselectedText,
    required this.tertiaryText,
    required this.tooltipBackground,
    required this.mutedText,
    required this.textFilterChip,
    required this.textFilterChipSelected,
    required this.textHighlight,
    required this.border,
    required this.borderStrong,
    required this.iconBackground,
    required this.iconBackgroundSubtle,
    required this.iconDefault,
    required this.iconSubDefault,
    required this.iconHighlight,
    required this.iconDisabled,
    required this.warning,
    required this.danger,
    required this.success,
    required this.rbfAccent,
    required this.cpfpAccent,
    required this.recommendFeeAnimStart,
    required this.recommendFeeAnimHighlight,
    required this.taprootParent,
    required this.taprootChild,
    required this.taprootRoleText,
    required this.taprootParticipantIconBorder,
    required this.taprootParticipantIconBackground,
    required this.taprootParticipantNeutralBackground,
    required this.taprootParticipantNeutralBorder,
    required this.taprootParticipantNeutralRoleBackground,
    required this.taprootParticipantNeutralRoleBorder,
    required this.taprootParticipantNeutralRoleText,
    required this.pulldownMenuBackground,
    required this.pulldownMenuPressedColor,
    required this.pulldownMenuDividerColor,
    required this.pulldownMenuTextColor,
    required this.shadowDefault,
    required this.shadowSubtle,
    required this.popupBackground,
    required this.dimOverlay,
    required this.pageIndicatorActive,
    required this.pageIndicatorInactive,
    required this.sendingColor,
    required this.receivingColor,
    required this.bottomActionBarBackground,
    required this.bottomSheetKeyboardToolbar,
    required this.bottomSheetExtensionFieldBackground,
    required this.loadingIndicatorColor,
    required this.loadingOverlay,
    required this.glossaryKeywordBackground,
    required this.glossaryKeywordText,
    required this.divider,
    required this.txFlowLine,
    required this.feeBumpingHistoryLine,
    required this.switchActiveTrack,
    required this.switchInactiveTrack,
    required this.switchThumb,
    required this.switchTrackDisabled,
    required this.switchThumbDisabled,
    required this.linkText,
    required this.nodeConnected,
    required this.nodeFailed,
    required this.popoverBackground,
    required this.popoverText,
    required this.faucetPopoverBackground,
    required this.faucetPopoverText,
    required this.bottomSheetHandle,
    required this.qrScannerOverlay,
    required this.qrScannerProgressBarTrack,
    required this.qrScannerProgressBarFill,
    required this.checkIconBackground,
    required this.checkIconForeground,
    required this.checkIconBackgroundDisabled,
    required this.checkIconForegroundDisabled,
  });

  factory CoconutColors.dark() {
    return const CoconutColors(
      homeBackground: ds.CoconutColors.black,
      homeSurfaceCard: ds.CoconutColors.gray850,
      homeSurfaceCardPressed: ds.CoconutColors.gray900,
      background: ds.CoconutColors.black,
      backgroundSubtle: ds.CoconutColors.gray850,
      backgroundHighlight: ds.CoconutColors.primary,
      backgroundHighlightText: ds.CoconutColors.black,
      blurButtonBackground: ds.CoconutColors.gray600,
      surface: ds.CoconutColors.gray850,
      surfaceDeep: ds.CoconutColors.black,
      surfaceCard: ds.CoconutColors.gray850,
      surfaceButton: ds.CoconutColors.gray850,
      surfaceButtonText: ds.CoconutColors.white,
      surfaceButtonSecondary: ds.CoconutColors.gray850,
      surfaceButtonSecondaryText: ds.CoconutColors.white,
      surfaceMuted: ds.CoconutColors.gray850,
      surfaceRaised: ds.CoconutColors.gray900,
      surfaceDisabled: ds.CoconutColors.gray850,
      surfaceBottomSheet: ds.CoconutColors.gray900,
      surfaceSectionBreak: ds.CoconutColors.gray900,
      surfaceFilterChip: ds.CoconutColors.gray800,
      surfaceFilterChipPressed: ds.CoconutColors.gray700,
      surfaceFilterChipSelected: ds.CoconutColors.white,
      surfaceSkeletonBase: ds.CoconutColors.gray850,
      surfaceSkeletonHighlight: ds.CoconutColors.gray750,
      chartSurface: ds.CoconutColors.gray800,
      coinSurface: ds.CoconutColors.gray900,
      selectedCoinBorder: ds.CoconutColors.gray150,
      billSurface: ds.CoconutColors.gray900,
      selectionOverlay: ds.CoconutColors.black,
      surfaceSelected: ds.CoconutColors.gray800,
      surfacePressed: ds.CoconutColors.gray750,
      inputSurface: ds.CoconutColors.gray800,
      inputPlaceholder: ds.CoconutColors.gray700,
      primary: ds.CoconutColors.primary,
      primaryButtonText: ds.CoconutColors.black,
      primaryButtonBackground: ds.CoconutColors.white,
      primaryButtonPressed: ds.CoconutColors.gray300,
      primaryText: ds.CoconutColors.white,
      secondaryText: ds.CoconutColors.gray400,
      secondaryTextStrong: ds.CoconutColors.gray300,
      secondaryButtonBackground: ds.CoconutColors.gray350,
      secondaryButtonText: ds.CoconutColors.black,
      segmentedControlSelected: ds.CoconutColors.gray900,
      segmentedControlBackground: ds.CoconutColors.gray800,
      segmentedControlSelectedText: ds.CoconutColors.white,
      segmentedControlUnselectedText: ds.CoconutColors.gray500,
      tertiaryText: ds.CoconutColors.gray600,
      tooltipBackground: ds.CoconutColors.gray850,
      mutedText: ds.CoconutColors.gray500,
      textFilterChip: ds.CoconutColors.white,
      textFilterChipSelected: ds.CoconutColors.gray800,
      textHighlight: ds.CoconutColors.primary,
      border: ds.CoconutColors.gray700,
      borderStrong: ds.CoconutColors.white,
      iconBackground: ds.CoconutColors.gray800,
      iconBackgroundSubtle: ds.CoconutColors.gray600,
      iconDefault: ds.CoconutColors.white,
      iconSubDefault: ds.CoconutColors.gray400,
      iconHighlight: ds.CoconutColors.gray850,
      iconDisabled: ds.CoconutColors.gray600,
      warning: ds.CoconutColors.warningYellow,
      danger: ds.CoconutColors.hotPink,
      success: ds.CoconutColors.cyanBlue,
      rbfAccent: ds.CoconutColors.primary,
      cpfpAccent: ds.CoconutColors.cyan,
      recommendFeeAnimStart: ds.CoconutColors.whiteLilac,
      recommendFeeAnimHighlight: ds.CoconutColors.gray700,
      taprootParent: ds.CoconutColors.purple,
      taprootChild: ds.CoconutColors.sky,
      taprootRoleText: ds.CoconutColors.white,
      taprootParticipantIconBorder: ds.CoconutColors.gray800,
      taprootParticipantIconBackground: ds.CoconutColors.gray800,
      taprootParticipantNeutralBackground: ds.CoconutColors.gray900,
      taprootParticipantNeutralBorder: ds.CoconutColors.gray800,
      taprootParticipantNeutralRoleBackground: ds.CoconutColors.gray700,
      taprootParticipantNeutralRoleBorder: ds.CoconutColors.gray600,
      taprootParticipantNeutralRoleText: ds.CoconutColors.white,
      pulldownMenuBackground: ds.CoconutColors.gray900,
      pulldownMenuPressedColor: ds.CoconutColors.gray700,
      pulldownMenuDividerColor: ds.CoconutColors.black,
      pulldownMenuTextColor: ds.CoconutColors.white,
      shadowDefault: ds.CoconutColors.black,
      shadowSubtle: ds.CoconutColors.gray900,
      popupBackground: ds.CoconutColors.gray900,
      dimOverlay: ds.CoconutColors.black,
      pageIndicatorActive: ds.CoconutColors.gray400,
      pageIndicatorInactive: ds.CoconutColors.gray800,
      sendingColor: ds.CoconutColors.primary,
      receivingColor: ds.CoconutColors.cyanBlue,
      bottomActionBarBackground: ds.CoconutColors.gray900,
      bottomSheetKeyboardToolbar: Color(0xFF2E2E2E),
      bottomSheetExtensionFieldBackground: ds.CoconutColors.black,
      loadingIndicatorColor: ds.CoconutColors.white,
      loadingOverlay: Color.fromRGBO(0, 0, 0, 0.2),
      glossaryKeywordBackground: Color(0xFFA6E1E7),
      glossaryKeywordText: ds.CoconutColors.black,
      divider: ds.CoconutColors.gray800,
      txFlowLine: ds.CoconutColors.gray600,
      feeBumpingHistoryLine: ds.CoconutColors.gray700,
      switchActiveTrack: ds.CoconutColors.gray100,
      switchInactiveTrack: ds.CoconutColors.gray600,
      switchThumb: ds.CoconutColors.gray800,
      switchTrackDisabled: ds.CoconutColors.gray700,
      switchThumbDisabled: ds.CoconutColors.gray600,
      linkText: ds.CoconutColors.sky,
      nodeConnected: ds.CoconutColors.green,
      nodeFailed: ds.CoconutColors.red,
      popoverBackground: ds.CoconutColors.white,
      popoverText: ds.CoconutColors.gray900,
      faucetPopoverBackground: Color.fromRGBO(179, 240, 255, 1),
      faucetPopoverText: ds.CoconutColors.gray900,
      bottomSheetHandle: ds.CoconutColors.gray600,
      qrScannerOverlay: ds.CoconutColors.gray350,
      qrScannerProgressBarTrack: ds.CoconutColors.gray350,
      qrScannerProgressBarFill: ds.CoconutColors.black,
      checkIconBackground: ds.CoconutColors.white,
      checkIconForeground: ds.CoconutColors.gray800,
      checkIconBackgroundDisabled: ds.CoconutColors.gray800,
      checkIconForegroundDisabled: ds.CoconutColors.gray600,
    );
  }

  factory CoconutColors.light() {
    return CoconutColors(
      homeBackground: ds.CoconutColors.gray150,
      homeSurfaceCard: ds.CoconutColors.white,
      homeSurfaceCardPressed: ds.CoconutColors.gray200,
      background: ds.CoconutColors.white,
      backgroundSubtle: ds.CoconutColors.gray150,
      backgroundHighlight: ds.CoconutColors.purple,
      backgroundHighlightText: ds.CoconutColors.black,
      blurButtonBackground: ds.CoconutColors.gray400,
      surface: ds.CoconutColors.gray150,
      surfaceDeep: ds.CoconutColors.white,
      surfaceCard: ds.CoconutColors.gray150,
      surfaceButton: ds.CoconutColors.white,
      surfaceButtonText: ds.CoconutColors.black,
      surfaceButtonSecondary: ds.CoconutColors.black,
      surfaceButtonSecondaryText: ds.CoconutColors.white,
      surfaceMuted: ds.CoconutColors.gray200,
      surfaceRaised: ds.CoconutColors.white,
      surfaceDisabled: ds.CoconutColors.gray300,
      surfaceBottomSheet: ds.CoconutColors.white,
      surfaceSectionBreak: ds.CoconutColors.gray200,
      surfaceFilterChip: ds.CoconutColors.gray300,
      surfaceFilterChipPressed: ds.CoconutColors.gray350,
      surfaceFilterChipSelected: ds.CoconutColors.black,
      surfaceSkeletonBase: ds.CoconutColors.gray200,
      surfaceSkeletonHighlight: ds.CoconutColors.gray100,
      chartSurface: ds.CoconutColors.white,
      coinSurface: ds.CoconutColors.white,
      selectedCoinBorder: ds.CoconutColors.black,
      billSurface: ds.CoconutColors.white,
      selectionOverlay: ds.CoconutColors.black,
      surfaceSelected: ds.CoconutColors.gray200,
      surfacePressed: ds.CoconutColors.gray150,
      inputSurface: const Color(0xFFF1F2F5),
      inputPlaceholder: ds.CoconutColors.gray400,
      primary: ds.CoconutColors.black,
      primaryButtonText: ds.CoconutColors.white,
      primaryButtonBackground: ds.CoconutColors.black,
      primaryButtonPressed: ds.CoconutColors.gray800,
      primaryText: ds.CoconutColors.black,
      secondaryText: ds.CoconutColors.gray700,
      secondaryTextStrong: ds.CoconutColors.gray800,
      secondaryButtonBackground: ds.CoconutColors.gray200,
      secondaryButtonText: ds.CoconutColors.black,
      segmentedControlSelected: ds.CoconutColors.gray800,
      segmentedControlBackground: ds.CoconutColors.gray150,
      segmentedControlSelectedText: ds.CoconutColors.white,
      segmentedControlUnselectedText: ds.CoconutColors.gray400,
      tertiaryText: ds.CoconutColors.gray600,
      tooltipBackground: ds.CoconutColors.gray150,
      mutedText: ds.CoconutColors.gray500,
      textFilterChip: ds.CoconutColors.gray900,
      textFilterChipSelected: ds.CoconutColors.white,
      textHighlight: ds.CoconutColors.purple,
      border: ds.CoconutColors.gray400,
      borderStrong: ds.CoconutColors.black,
      iconBackground: ds.CoconutColors.gray300,
      iconBackgroundSubtle: ds.CoconutColors.gray200,
      iconDefault: ds.CoconutColors.black,
      iconSubDefault: ds.CoconutColors.gray600,
      iconHighlight: ds.CoconutColors.gray600,
      iconDisabled: ds.CoconutColors.gray350,
      warning: ds.CoconutColors.warningYellow,
      danger: ds.CoconutColors.hotPink,
      success: ds.CoconutColors.cyanBlue,
      rbfAccent: ds.CoconutColors.purple,
      cpfpAccent: ds.CoconutColors.cyan,
      recommendFeeAnimStart: ds.CoconutColors.gray800,
      recommendFeeAnimHighlight: ds.CoconutColors.gray400,
      taprootParent: ds.CoconutColors.purple,
      taprootChild: ds.CoconutColors.sky,
      taprootRoleText: ds.CoconutColors.white,
      taprootParticipantIconBorder: ds.CoconutColors.gray200,
      taprootParticipantIconBackground: ds.CoconutColors.gray100,
      taprootParticipantNeutralBackground: ds.CoconutColors.white,
      taprootParticipantNeutralBorder: ds.CoconutColors.gray200,
      taprootParticipantNeutralRoleBackground: ds.CoconutColors.gray100,
      taprootParticipantNeutralRoleBorder: ds.CoconutColors.gray200,
      taprootParticipantNeutralRoleText: ds.CoconutColors.gray800,
      pulldownMenuBackground: ds.CoconutColors.white,
      pulldownMenuPressedColor: ds.CoconutColors.gray200,
      pulldownMenuDividerColor: ds.CoconutColors.gray200,
      pulldownMenuTextColor: ds.CoconutColors.black,
      shadowDefault: ds.CoconutColors.black,
      shadowSubtle: ds.CoconutColors.black.withValues(alpha: 0.12),
      popupBackground: ds.CoconutColors.white,
      dimOverlay: const Color(0xFFEEEEEE),
      pageIndicatorActive: ds.CoconutColors.gray700,
      pageIndicatorInactive: ds.CoconutColors.gray300,
      sendingColor: const Color.fromARGB(255, 128, 148, 50),
      receivingColor: const Color.fromARGB(255, 50, 148, 173),
      bottomActionBarBackground: ds.CoconutColors.white,
      bottomSheetKeyboardToolbar: ds.CoconutColors.gray150,
      bottomSheetExtensionFieldBackground: const Color(0xFFF1F2F5),
      loadingIndicatorColor: ds.CoconutColors.black,
      loadingOverlay: const Color.fromRGBO(0, 0, 0, 0.2),
      glossaryKeywordBackground: ds.CoconutColors.lightSky,
      glossaryKeywordText: ds.CoconutColors.black,
      divider: ds.CoconutColors.gray200,
      txFlowLine: ds.CoconutColors.gray350,
      feeBumpingHistoryLine: ds.CoconutColors.gray300,
      switchActiveTrack: ds.CoconutColors.purple,
      switchInactiveTrack: ds.CoconutColors.gray300,
      switchThumb: ds.CoconutColors.white,
      switchTrackDisabled: ds.CoconutColors.gray200,
      switchThumbDisabled: ds.CoconutColors.gray350,
      linkText: ds.CoconutColors.sky,
      nodeConnected: ds.CoconutColors.purple,
      nodeFailed: ds.CoconutColors.red,
      popoverBackground: ds.CoconutColors.gray850,
      popoverText: ds.CoconutColors.white,
      faucetPopoverBackground: const Color.fromRGBO(179, 240, 255, 1),
      faucetPopoverText: ds.CoconutColors.gray900,
      bottomSheetHandle: ds.CoconutColors.gray600,
      qrScannerOverlay: ds.CoconutColors.gray350,
      qrScannerProgressBarTrack: ds.CoconutColors.gray350,
      qrScannerProgressBarFill: ds.CoconutColors.black,
      checkIconBackground: ds.CoconutColors.black,
      checkIconForeground: ds.CoconutColors.white,
      checkIconBackgroundDisabled: ds.CoconutColors.gray200,
      checkIconForegroundDisabled: ds.CoconutColors.gray400,
    );
  }
}
