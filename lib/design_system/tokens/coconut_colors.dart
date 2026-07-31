import 'package:coconut_design_system/coconut_design_system.dart' as ds;
import 'package:flutter/widgets.dart';

/// 코코넛 메인넷 로고에서 공통으로 사용하는 브랜드 그라디언트입니다.
///
/// 브랜드 일관성을 위해 가능하면 유지하는 것을 권장합니다.
const Gradient kCoconutMainnetLogoGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF54C8F0), Color(0xFF8A61FF)],
);

@immutable
class CoconutColors {
  /// 코코넛 고유 메인넷 로고 그라디언트
  ///
  /// 브랜드 일관성을 위해 가능하면 [kCoconutMainnetLogoGradient]를 유지합니다.
  final Gradient mainnetLogoGradient;
  final Color regtestLogo;

  /// 1. 범용
  ///
  /// 배경 / 표면
  /// 기본 화면 배경색
  final Color background;

  /// 화면 배경 위에 얹히는 박스/버튼 등의 기본 바탕
  final Color surface;

  /// 주로 카드/버튼 눌림 상태의 overlay 색상
  final Color surfacePressOverlay;

  /// surface 위 interactive 요소가 눌렸을 때 기본으로 사용할 overlay 강도
  final double surfacePressOverlayOpacity;
  final Color surfaceDisabled;

  /// surfaceMuted: surface 보조색
  /// 예: 복사 버튼의 기본 바탕색, 덜 중요한 정보 영역의 바탕색, chip 색
  final Color surfaceMuted;

  /// `surface` 안쪽에 한 단계 더 들어간 작은 영역의 배경
  /// 예: 카드 안의 index 배지
  final Color surfaceInset;

  /// 정보성 chip/pill의 표면색
  /// 예: 상태 chip, receiving chip, 강조된 정보 배지
  final Color surfaceInfoChip;

  /// 브랜드 / 강조색
  /// 테마의 대표 강조색
  final Color primary;

  /// 텍스트 색상
  /// primaryText: 기본 본문/제목 텍스트
  /// secondaryText: 보조 정보, 설명, 메타 텍스트
  /// tertiaryText: secondary보다 한 단계 더 약한 보조 정보 텍스트
  /// mutedText: 선택되지 않음, 입력 전, 비활성, 약한 상태 표현에 쓰는 subdued foreground
  final Color primaryText;
  final Color secondaryText;
  final Color tertiaryText;
  final Color mutedText;

  /// 연결됨, 사용 중, 강조된 상태를 나타내는 포그라운드 색상
  /// 텍스트와 아이콘 모두에 사용
  final Color accentForeground;

  /// 테두리
  final Color border;
  final Color borderStrong;

  /// 그림자
  final Color shadowDefault;
  final Color shadowSubtle;

  /// 아이콘
  /// iconBackground: 기본 아이콘 컨테이너 배경
  /// iconBackgroundSubtle: 더 약한 아이콘 컨테이너 배경
  final Color iconBackground;
  final Color iconBackgroundSubtle;

  /// iconPrimary: 기본 아이콘 전경색
  /// iconSecondary: 보조/메타 아이콘 전경색
  final Color iconPrimary;
  final Color iconSecondary;

  /// iconDisabled: 비활성 아이콘 전경색
  /// iconOnDanger: danger 배경 위에 올라가는 아이콘 전경색
  final Color iconDisabled;
  final Color iconOnDanger;

  /// 아이콘 버튼의 터치/하이라이트 배경색
  final Color iconButtonHighlight;

  /// 상태
  final Color warning;
  final Color danger;
  final Color success;

  /// 구분선
  final Color divider;

  /// 2. 공통 위젯별 정의
  ///
  /// 브랜드 강조 요소
  /// CTA, 배지, 강조 아이콘 tint, 강조 섹션 배경에 사용하는 브랜드 강조색 쌍
  /// 공통 버튼 스킨의 기본색이라기보다, 제품 전반의 브랜드 강조 표현에 가까움
  final Color brandAccentBackground;
  final Color brandAccentForeground;

  /// surface 위에 올라가는 Button의 기본 바탕
  final Color surfaceButton;
  final Color surfaceButtonText;

  /// 주요 CTA 버튼의 배경/전경/눌림 overlay 색상
  /// FixedBottomButton 등 공통 primary 버튼 컴포넌트의 기본 스킨에 사용한다
  final Color buttonPrimaryBackground;
  final Color buttonPrimaryForeground;
  final Color buttonPrimaryDisabledBackground;
  final Color buttonPrimaryDisabledForeground;
  final Color buttonPrimaryPressOverlay;

  /// primary CTA 버튼이 눌렸을 때 기본으로 사용할 overlay 강도
  final double buttonPrimaryPressOverlayOpacity;

  /// 보조 CTA 버튼의 배경/전경색
  final Color buttonSecondaryBackground;
  final Color buttonSecondaryForeground;

  /// 칩 상태별 배경/전경색
  final Color chipUnselectedBackground;
  final Color chipUnselectedText;
  final Color chipSelectedBackground;
  final Color chipSelectedText;
  final Color chipOutlinedUnselectedBackground;
  final Color chipOutlinedUnselectedText;

  /// 입력 필드 배경/placeholder/보더색
  final Color inputSurface;
  final Color inputPlaceholder;
  final Color inputBorder;

  /// 세그멘티드 컨트롤
  final Color segmentedControlSelected;
  final Color segmentedControlBackground;
  final Color segmentedControlSelectedText;
  final Color segmentedControlUnselectedText;

  /// 바텀시트
  /// 바텀시트 컨테이너의 기본 표면색
  final Color surfaceBottomSheet;

  /// 바텀시트 상단 드래그 핸들 바
  final Color bottomSheetHandle;
  final Color bottomSheetKeyboardToolbar;
  final Color bottomSheetExtensionFieldBackground;

  /// 하단 액션 바 배경색
  final Color bottomActionBarBackground;

  /// 풀다운 메뉴
  final Color pulldownMenuBackground;
  final Color pulldownMenuPressedColor;
  final Color pulldownMenuDividerColor;
  final Color pulldownMenuTextColor;

  /// 스위치
  final Color switchActiveTrack;
  final Color switchInactiveTrack;
  final Color switchActiveThumb;
  final Color switchInactiveThumb;
  final Color switchTrackDisabled;
  final Color switchThumbDisabled;

  /// 툴팁 / 팝업 / 오버레이
  /// 툴팁 배경색
  final Color tooltipBackground;

  /// 팝업 배경
  final Color popupBackground;
  final Color dimOverlay;

  /// 아이콘 탭 시 말풍선 형태로 표시되는 Popover 툴팁
  final Color popoverBackground;
  final Color popoverText;

  /// 로딩 / 스켈레톤
  /// skeleton/shimmer 로딩의 기본 바탕색 및 강조색
  final Color surfaceSkeletonBase;
  final Color surfaceSkeletonHighlight;
  final Color loadingIndicatorColor;
  final Color loadingOverlay;

  /// 페이지 인디케이터
  final Color pageIndicatorActive;
  final Color pageIndicatorInactive;

  /// 체크 아이콘 배경/아이콘 색상 쌍
  /// [checkIconBackground] / [checkIconForeground]: 활성화(isEnabled=true) 상태
  /// [checkIconBackgroundDisabled] / [checkIconForegroundDisabled]: 비활성화(isEnabled=false) 상태
  final Color checkIconBackground;
  final Color checkIconForeground;
  final Color checkIconBackgroundDisabled;
  final Color checkIconForegroundDisabled;

  /// 링크 텍스트
  final Color linkText;

  /// 3. feature별
  ///
  /// Home

  /// homeBackground: 홈 화면 배경색
  /// homeSurface: 홈 화면 배경 위에 얹히는 요소의 기본 바탕
  /// homeSurfacePressOverlay: 홈 화면 요소의 눌림 overlay 색상
  final Color homeBackground;
  final Color homeSurface;
  final Color homeSurfacePressOverlay;

  /// 홈 화면 요소가 눌렸을 때 기본으로 사용할 overlay 강도
  final double homeSurfacePressOverlayOpacity;

  /// 노드 연결 상태
  final Color nodeConnected;
  final Color nodeFailed;

  /// utxo 오버뷰 화면 요소
  final Color utxoOverviewChartSurface;
  final double utxoOverviewChartUnselectedOverlayOpacity;
  final Color utxoOverviewCoinSurface;
  final Color utxoOverviewSelectedCoinBorder;
  final Color utxoOverviewBillSurface;
  final Color utxoOverviewUnselectedOverlay;
  final double utxoOverviewCoinTintStrength;
  final double utxoOverviewCoinIconOpacity;
  final double utxoOverviewCoinInnerStrokeOpacity;

  /// 탭루트 지갑 정보
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

  /// 트랜잭션
  ///
  /// 트랜잭션 흐름선
  final Color txFlowLine;

  /// Fee bumping
  final Color rbfAccent;
  final Color cpfpAccent;
  final Color feeBumpingHistoryLine;

  /// 상태별 아이콘/로티 색상
  final Color sendingColor;
  final Color receivingColor;

  /// 추천 수수료 애니메이션
  final Color recommendFeeAnimStart;
  final Color recommendFeeAnimHighlight;

  /// 용어집
  final Color glossaryKeywordBackground;
  final Color glossaryKeywordText;

  /// QR 스캐너 (카메라 오버레이)
  /// qrScannerOverlay: 카메라 오버레이
  /// qrScannerProgressBar*: 프로그레스 바
  final Color qrScannerOverlay;
  final Color qrScannerProgressBarTrack;
  final Color qrScannerProgressBarFill;

  /// Regtest 전용 - Faucet Popover 툴팁
  final Color faucetPopoverBackground;
  final Color faucetPopoverText;

  const CoconutColors({
    required this.mainnetLogoGradient,
    required this.regtestLogo,
    required this.background,
    required this.surface,
    required this.surfacePressOverlay,
    required this.surfacePressOverlayOpacity,
    required this.surfaceDisabled,
    required this.surfaceMuted,
    required this.surfaceInset,
    required this.surfaceInfoChip,
    required this.primary,
    required this.primaryText,
    required this.secondaryText,
    required this.tertiaryText,
    required this.mutedText,
    required this.accentForeground,
    required this.border,
    required this.borderStrong,
    required this.shadowDefault,
    required this.shadowSubtle,
    required this.iconBackground,
    required this.iconBackgroundSubtle,
    required this.iconPrimary,
    required this.iconSecondary,
    required this.iconDisabled,
    required this.iconOnDanger,
    required this.iconButtonHighlight,
    required this.warning,
    required this.danger,
    required this.success,
    required this.divider,
    required this.brandAccentBackground,
    required this.brandAccentForeground,
    required this.surfaceButton,
    required this.surfaceButtonText,
    required this.buttonPrimaryBackground,
    required this.buttonPrimaryForeground,
    required this.buttonPrimaryDisabledBackground,
    required this.buttonPrimaryDisabledForeground,
    required this.buttonPrimaryPressOverlay,
    required this.buttonPrimaryPressOverlayOpacity,
    required this.buttonSecondaryBackground,
    required this.buttonSecondaryForeground,
    required this.chipUnselectedBackground,
    required this.chipUnselectedText,
    required this.chipSelectedBackground,
    required this.chipSelectedText,
    required this.chipOutlinedUnselectedBackground,
    required this.chipOutlinedUnselectedText,
    required this.inputSurface,
    required this.inputPlaceholder,
    required this.inputBorder,
    required this.segmentedControlSelected,
    required this.segmentedControlBackground,
    required this.segmentedControlSelectedText,
    required this.segmentedControlUnselectedText,
    required this.surfaceBottomSheet,
    required this.bottomSheetHandle,
    required this.bottomSheetKeyboardToolbar,
    required this.bottomSheetExtensionFieldBackground,
    required this.bottomActionBarBackground,
    required this.pulldownMenuBackground,
    required this.pulldownMenuPressedColor,
    required this.pulldownMenuDividerColor,
    required this.pulldownMenuTextColor,
    required this.switchActiveTrack,
    required this.switchInactiveTrack,
    required this.switchActiveThumb,
    required this.switchInactiveThumb,
    required this.switchTrackDisabled,
    required this.switchThumbDisabled,
    required this.tooltipBackground,
    required this.popupBackground,
    required this.dimOverlay,
    required this.popoverBackground,
    required this.popoverText,
    required this.surfaceSkeletonBase,
    required this.surfaceSkeletonHighlight,
    required this.loadingIndicatorColor,
    required this.loadingOverlay,
    required this.pageIndicatorActive,
    required this.pageIndicatorInactive,
    required this.checkIconBackground,
    required this.checkIconForeground,
    required this.checkIconBackgroundDisabled,
    required this.checkIconForegroundDisabled,
    required this.linkText,
    required this.homeBackground,
    required this.homeSurface,
    required this.homeSurfacePressOverlay,
    required this.homeSurfacePressOverlayOpacity,
    required this.nodeConnected,
    required this.nodeFailed,
    required this.utxoOverviewChartSurface,
    required this.utxoOverviewChartUnselectedOverlayOpacity,
    required this.utxoOverviewCoinSurface,
    required this.utxoOverviewSelectedCoinBorder,
    required this.utxoOverviewBillSurface,
    required this.utxoOverviewUnselectedOverlay,
    required this.utxoOverviewCoinTintStrength,
    required this.utxoOverviewCoinIconOpacity,
    required this.utxoOverviewCoinInnerStrokeOpacity,
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
    required this.txFlowLine,
    required this.rbfAccent,
    required this.cpfpAccent,
    required this.feeBumpingHistoryLine,
    required this.sendingColor,
    required this.receivingColor,
    required this.recommendFeeAnimStart,
    required this.recommendFeeAnimHighlight,
    required this.glossaryKeywordBackground,
    required this.glossaryKeywordText,
    required this.qrScannerOverlay,
    required this.qrScannerProgressBarTrack,
    required this.qrScannerProgressBarFill,
    required this.faucetPopoverBackground,
    required this.faucetPopoverText,
  });

  factory CoconutColors.dark() {
    return CoconutColors(
      mainnetLogoGradient: kCoconutMainnetLogoGradient,
      regtestLogo: ds.CoconutColors.white,
      background: ds.CoconutColors.black,
      surface: ds.CoconutColors.gray850,
      surfacePressOverlay: ds.CoconutColors.black,
      surfacePressOverlayOpacity: 0.5,
      surfaceDisabled: ds.CoconutColors.black,
      surfaceMuted: ds.CoconutColors.gray850,
      surfaceInset: ds.CoconutColors.black,
      surfaceInfoChip: ds.CoconutColors.gray850,
      primary: ds.CoconutColors.primary,
      primaryText: ds.CoconutColors.white,
      secondaryText: ds.CoconutColors.gray400,
      tertiaryText: ds.CoconutColors.gray600,
      mutedText: ds.CoconutColors.gray500,
      accentForeground: ds.CoconutColors.primary,
      border: ds.CoconutColors.gray700,
      borderStrong: ds.CoconutColors.white,
      shadowDefault: ds.CoconutColors.gray700.withValues(alpha: 0.12),
      shadowSubtle: ds.CoconutColors.gray900.withValues(alpha: 0.3),
      iconBackground: ds.CoconutColors.gray800,
      iconBackgroundSubtle: ds.CoconutColors.gray600,
      iconPrimary: ds.CoconutColors.white,
      iconSecondary: ds.CoconutColors.gray400,
      iconDisabled: ds.CoconutColors.gray600,
      iconOnDanger: ds.CoconutColors.white,
      iconButtonHighlight: ds.CoconutColors.gray850,
      warning: ds.CoconutColors.warningYellow,
      danger: ds.CoconutColors.hotPink,
      success: ds.CoconutColors.cyanBlue,
      divider: ds.CoconutColors.gray800,

      brandAccentBackground: ds.CoconutColors.primary,
      brandAccentForeground: ds.CoconutColors.black,
      surfaceButton: ds.CoconutColors.gray850,
      surfaceButtonText: ds.CoconutColors.white,
      buttonPrimaryBackground: ds.CoconutColors.white,
      buttonPrimaryForeground: ds.CoconutColors.black,
      buttonPrimaryDisabledBackground: ds.CoconutColors.gray800,
      buttonPrimaryDisabledForeground: ds.CoconutColors.gray900,
      buttonPrimaryPressOverlay: ds.CoconutColors.black,
      buttonPrimaryPressOverlayOpacity: 0.3,
      buttonSecondaryBackground: ds.CoconutColors.gray350,
      buttonSecondaryForeground: ds.CoconutColors.black,
      chipUnselectedBackground: ds.CoconutColors.gray800,
      chipUnselectedText: ds.CoconutColors.gray600,
      chipSelectedBackground: ds.CoconutColors.white,
      chipSelectedText: ds.CoconutColors.black,
      chipOutlinedUnselectedBackground: ds.CoconutColors.gray800,
      chipOutlinedUnselectedText: ds.CoconutColors.gray700,
      inputSurface: ds.CoconutColors.gray800,
      inputPlaceholder: ds.CoconutColors.gray700,
      inputBorder: ds.CoconutColors.gray600,
      segmentedControlSelected: ds.CoconutColors.gray900,
      segmentedControlBackground: ds.CoconutColors.gray800,
      segmentedControlSelectedText: ds.CoconutColors.white,
      segmentedControlUnselectedText: ds.CoconutColors.gray500,
      surfaceBottomSheet: ds.CoconutColors.gray900,
      bottomSheetHandle: ds.CoconutColors.gray600,
      bottomSheetKeyboardToolbar: const Color(0xFF2E2E2E),
      bottomSheetExtensionFieldBackground: ds.CoconutColors.black,
      bottomActionBarBackground: ds.CoconutColors.gray900,
      pulldownMenuBackground: ds.CoconutColors.gray900,
      pulldownMenuPressedColor: ds.CoconutColors.gray700,
      pulldownMenuDividerColor: ds.CoconutColors.black,
      pulldownMenuTextColor: ds.CoconutColors.white,
      switchActiveTrack: ds.CoconutColors.gray100,
      switchInactiveTrack: ds.CoconutColors.gray800,
      switchActiveThumb: ds.CoconutColors.black,
      switchInactiveThumb: ds.CoconutColors.gray600,
      switchTrackDisabled: ds.CoconutColors.gray700,
      switchThumbDisabled: ds.CoconutColors.gray600,
      tooltipBackground: ds.CoconutColors.gray850,
      popupBackground: ds.CoconutColors.gray900,
      dimOverlay: ds.CoconutColors.black,
      popoverBackground: ds.CoconutColors.white,
      popoverText: ds.CoconutColors.gray900,
      surfaceSkeletonBase: ds.CoconutColors.gray850,
      surfaceSkeletonHighlight: ds.CoconutColors.gray750,
      loadingIndicatorColor: ds.CoconutColors.white,
      loadingOverlay: const Color.fromRGBO(0, 0, 0, 0.2),
      pageIndicatorActive: ds.CoconutColors.gray400,
      pageIndicatorInactive: ds.CoconutColors.gray800,
      checkIconBackground: ds.CoconutColors.white,
      checkIconForeground: ds.CoconutColors.gray800,
      checkIconBackgroundDisabled: ds.CoconutColors.gray800,
      checkIconForegroundDisabled: ds.CoconutColors.gray600,
      linkText: ds.CoconutColors.sky,

      homeBackground: ds.CoconutColors.black,
      homeSurface: ds.CoconutColors.gray850,
      homeSurfacePressOverlay: ds.CoconutColors.black,
      homeSurfacePressOverlayOpacity: 0.5,
      nodeConnected: ds.CoconutColors.primary,
      nodeFailed: ds.CoconutColors.red,
      utxoOverviewChartSurface: ds.CoconutColors.gray800,
      utxoOverviewChartUnselectedOverlayOpacity: 0.6,
      utxoOverviewCoinSurface: ds.CoconutColors.gray900,
      utxoOverviewSelectedCoinBorder: ds.CoconutColors.gray150,
      utxoOverviewBillSurface: ds.CoconutColors.gray900,
      utxoOverviewUnselectedOverlay: ds.CoconutColors.black,
      utxoOverviewCoinTintStrength: 0.7,
      utxoOverviewCoinIconOpacity: 0.1,
      utxoOverviewCoinInnerStrokeOpacity: 0.1,
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
      txFlowLine: ds.CoconutColors.gray600,
      rbfAccent: ds.CoconutColors.primary,
      cpfpAccent: ds.CoconutColors.cyan,
      feeBumpingHistoryLine: ds.CoconutColors.gray700,
      sendingColor: ds.CoconutColors.primary,
      receivingColor: ds.CoconutColors.cyanBlue,
      recommendFeeAnimStart: ds.CoconutColors.whiteLilac,
      recommendFeeAnimHighlight: ds.CoconutColors.gray700,
      glossaryKeywordBackground: const Color(0xFFA6E1E7),
      glossaryKeywordText: ds.CoconutColors.black,
      qrScannerOverlay: ds.CoconutColors.gray350,
      qrScannerProgressBarTrack: ds.CoconutColors.gray350,
      qrScannerProgressBarFill: ds.CoconutColors.black,
      faucetPopoverBackground: const Color.fromRGBO(179, 240, 255, 1),
      faucetPopoverText: ds.CoconutColors.gray900,
    );
  }

  factory CoconutColors.light() {
    return CoconutColors(
      mainnetLogoGradient: kCoconutMainnetLogoGradient,
      regtestLogo: ds.CoconutColors.black,
      background: ds.CoconutColors.white,
      surface: ds.CoconutColors.gray150,
      surfaceInset: ds.CoconutColors.white,
      surfacePressOverlay: ds.CoconutColors.black,
      surfacePressOverlayOpacity: 0.6,
      surfaceDisabled: ds.CoconutColors.gray300,
      surfaceMuted: ds.CoconutColors.gray200,
      surfaceInfoChip: ds.CoconutColors.gray300,
      primary: ds.CoconutColors.purple,
      primaryText: ds.CoconutColors.black,
      secondaryText: ds.CoconutColors.gray700,
      tertiaryText: ds.CoconutColors.gray600,
      mutedText: ds.CoconutColors.gray500,
      accentForeground: ds.CoconutColors.purple,
      border: ds.CoconutColors.gray400,
      borderStrong: ds.CoconutColors.black,
      shadowDefault: ds.CoconutColors.gray600.withValues(alpha: 0.3),
      shadowSubtle: ds.CoconutColors.gray600.withValues(alpha: 0.15),
      iconBackground: ds.CoconutColors.gray300,
      iconBackgroundSubtle: ds.CoconutColors.gray200,
      iconPrimary: ds.CoconutColors.black,
      iconSecondary: ds.CoconutColors.gray600,
      iconDisabled: ds.CoconutColors.gray350,
      iconOnDanger: ds.CoconutColors.white,
      iconButtonHighlight: ds.CoconutColors.gray400,
      warning: ds.CoconutColors.warningYellow,
      danger: ds.CoconutColors.hotPink,
      success: ds.CoconutColors.cyanBlue,
      divider: ds.CoconutColors.gray200,

      brandAccentBackground: ds.CoconutColors.purple,
      brandAccentForeground: ds.CoconutColors.black,
      surfaceButton: ds.CoconutColors.gray300,
      surfaceButtonText: ds.CoconutColors.black,
      buttonPrimaryBackground: ds.CoconutColors.black,
      buttonPrimaryForeground: ds.CoconutColors.white,
      buttonPrimaryDisabledBackground: ds.CoconutColors.gray150,
      buttonPrimaryDisabledForeground: ds.CoconutColors.gray350,
      buttonPrimaryPressOverlay: ds.CoconutColors.black,
      buttonPrimaryPressOverlayOpacity: 0.5,
      buttonSecondaryBackground: ds.CoconutColors.gray200,
      buttonSecondaryForeground: ds.CoconutColors.black,
      chipUnselectedBackground: ds.CoconutColors.gray150,
      chipUnselectedText: ds.CoconutColors.gray350,
      chipSelectedBackground: ds.CoconutColors.gray800,
      chipSelectedText: ds.CoconutColors.white,
      chipOutlinedUnselectedBackground: ds.CoconutColors.gray150,
      chipOutlinedUnselectedText: ds.CoconutColors.gray350,
      //inputSurface: const Color(0xFFF1F2F5),
      inputSurface: ds.CoconutColors.white,
      inputPlaceholder: ds.CoconutColors.gray300,
      inputBorder: ds.CoconutColors.gray350,
      segmentedControlSelected: ds.CoconutColors.gray800,
      segmentedControlBackground: ds.CoconutColors.gray150,
      segmentedControlSelectedText: ds.CoconutColors.white,
      segmentedControlUnselectedText: ds.CoconutColors.gray400,
      surfaceBottomSheet: ds.CoconutColors.white,
      bottomSheetHandle: ds.CoconutColors.gray600,
      bottomSheetKeyboardToolbar: ds.CoconutColors.gray150,
      bottomSheetExtensionFieldBackground: const Color(0xFFF1F2F5),
      bottomActionBarBackground: ds.CoconutColors.white,
      pulldownMenuBackground: ds.CoconutColors.white,
      pulldownMenuPressedColor: ds.CoconutColors.gray200,
      pulldownMenuDividerColor: ds.CoconutColors.gray200,
      pulldownMenuTextColor: ds.CoconutColors.black,
      switchActiveTrack: ds.CoconutColors.black,
      switchInactiveTrack: ds.CoconutColors.gray300,
      switchActiveThumb: ds.CoconutColors.white,
      switchInactiveThumb: ds.CoconutColors.gray200,
      switchTrackDisabled: ds.CoconutColors.gray200,
      switchThumbDisabled: ds.CoconutColors.gray350,
      tooltipBackground: ds.CoconutColors.gray150,
      popupBackground: ds.CoconutColors.white,
      dimOverlay: const Color(0xFFEEEEEE),
      popoverBackground: ds.CoconutColors.gray850,
      popoverText: ds.CoconutColors.white,
      surfaceSkeletonBase: ds.CoconutColors.gray200,
      surfaceSkeletonHighlight: ds.CoconutColors.gray100,
      loadingIndicatorColor: ds.CoconutColors.black,
      loadingOverlay: const Color.fromRGBO(0, 0, 0, 0.2),
      pageIndicatorActive: ds.CoconutColors.gray700,
      pageIndicatorInactive: ds.CoconutColors.gray300,
      checkIconBackground: ds.CoconutColors.black,
      checkIconForeground: ds.CoconutColors.white,
      checkIconBackgroundDisabled: ds.CoconutColors.gray200,
      checkIconForegroundDisabled: ds.CoconutColors.gray400,
      linkText: ds.CoconutColors.sky,

      homeBackground: ds.CoconutColors.gray150,
      homeSurface: ds.CoconutColors.white,
      homeSurfacePressOverlay: ds.CoconutColors.gray700,
      homeSurfacePressOverlayOpacity: 0.2,
      nodeConnected: ds.CoconutColors.purple,
      nodeFailed: ds.CoconutColors.red,
      utxoOverviewChartSurface: ds.CoconutColors.white,
      utxoOverviewChartUnselectedOverlayOpacity: 0.6,
      utxoOverviewCoinSurface: ds.CoconutColors.white,
      utxoOverviewSelectedCoinBorder: ds.CoconutColors.black,
      utxoOverviewBillSurface: ds.CoconutColors.white,
      utxoOverviewUnselectedOverlay: ds.CoconutColors.black,
      utxoOverviewCoinTintStrength: 0.7,
      utxoOverviewCoinIconOpacity: 0.1,
      utxoOverviewCoinInnerStrokeOpacity: 0.1,
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
      txFlowLine: ds.CoconutColors.gray350,
      rbfAccent: ds.CoconutColors.purple,
      cpfpAccent: ds.CoconutColors.cyan,
      feeBumpingHistoryLine: ds.CoconutColors.gray300,
      sendingColor: ds.CoconutColors.purple,
      receivingColor: const Color.fromARGB(255, 50, 148, 173),
      recommendFeeAnimStart: ds.CoconutColors.gray800,
      recommendFeeAnimHighlight: ds.CoconutColors.gray400,
      glossaryKeywordBackground: ds.CoconutColors.lightSky,
      glossaryKeywordText: ds.CoconutColors.black,
      qrScannerOverlay: ds.CoconutColors.gray350,
      qrScannerProgressBarTrack: ds.CoconutColors.gray350,
      qrScannerProgressBarFill: ds.CoconutColors.black,
      faucetPopoverBackground: const Color.fromRGBO(179, 240, 255, 1),
      faucetPopoverText: ds.CoconutColors.gray900,
    );
  }

  factory CoconutColors.coconutPulp() {
    const pulp = Color(0xFFFAF8F3);
    const cream = Color(0xFFF4E9D3);
    const shell = Color(0xFFFFFDF7);
    const sand = Color(0xFFEAD6B4);
    const caramel = Color(0xFFD89A5B);
    const huskDeep = Color(0xFF6E3D18);
    const husk = Color(0xFFB87433);
    const huskSoft = Color(0xFFDFC09A);
    const toast = Color(0xFFC18C55);
    const lagoonDeep = Color(0xFF4FA8C8);
    const lagoon = Color(0xFF72CFEA);
    const seefoam = Color(0xFF8FD9C5);
    const palmGreen = Color(0xFF7FB96A);
    const line = Color(0xFFE8D8BF);
    const dim = Color(0xFFF2DFC0);
    const golenSun = Color(0xFFD99B45);

    return CoconutColors(
      mainnetLogoGradient: kCoconutMainnetLogoGradient,
      regtestLogo: palmGreen,
      background: pulp,
      surface: cream,
      surfacePressOverlay: golenSun,
      surfacePressOverlayOpacity: 0.12,
      surfaceDisabled: shell,
      surfaceMuted: sand,
      surfaceInset: shell,
      surfaceInfoChip: seefoam.withAlpha(60),
      primary: palmGreen,
      primaryText: huskDeep,
      secondaryText: husk,
      tertiaryText: toast,
      mutedText: huskSoft,
      accentForeground: palmGreen,
      border: line,
      borderStrong: huskDeep,
      shadowDefault: huskDeep.withValues(alpha: 0.18),
      shadowSubtle: huskSoft.withValues(alpha: 0.12),
      iconBackground: sand,
      iconBackgroundSubtle: dim,
      iconPrimary: huskDeep,
      iconSecondary: husk,
      iconDisabled: caramel,
      iconOnDanger: ds.CoconutColors.white,
      iconButtonHighlight: dim,
      warning: ds.CoconutColors.warningYellow,
      danger: ds.CoconutColors.hotPink,
      success: palmGreen,
      divider: lagoon.withAlpha(30),

      brandAccentBackground: lagoon,
      brandAccentForeground: huskDeep,
      surfaceButton: sand,
      surfaceButtonText: huskDeep,
      buttonPrimaryBackground: huskDeep,
      buttonPrimaryForeground: ds.CoconutColors.white,
      buttonPrimaryDisabledBackground: dim,
      buttonPrimaryDisabledForeground: huskSoft,
      buttonPrimaryPressOverlay: ds.CoconutColors.white,
      buttonPrimaryPressOverlayOpacity: 0.5,
      buttonSecondaryBackground: sand,
      buttonSecondaryForeground: huskDeep,
      chipUnselectedBackground: cream,
      chipUnselectedText: huskSoft,
      chipSelectedBackground: huskDeep,
      chipSelectedText: ds.CoconutColors.white,
      chipOutlinedUnselectedBackground: cream,
      chipOutlinedUnselectedText: huskSoft,
      inputSurface: ds.CoconutColors.white,
      inputPlaceholder: toast.withAlpha(140),
      inputBorder: line,
      segmentedControlSelected: huskDeep,
      segmentedControlBackground: dim,
      segmentedControlSelectedText: ds.CoconutColors.white,
      segmentedControlUnselectedText: huskSoft,
      surfaceBottomSheet: shell,
      bottomSheetHandle: caramel,
      bottomSheetKeyboardToolbar: dim,
      bottomSheetExtensionFieldBackground: shell,
      bottomActionBarBackground: shell,
      pulldownMenuBackground: shell,
      pulldownMenuPressedColor: dim,
      pulldownMenuDividerColor: line,
      pulldownMenuTextColor: huskDeep,
      switchActiveTrack: huskDeep,
      switchInactiveTrack: sand,
      switchActiveThumb: ds.CoconutColors.white,
      switchInactiveThumb: cream,
      switchTrackDisabled: line,
      switchThumbDisabled: caramel,
      tooltipBackground: dim,
      popupBackground: shell,
      dimOverlay: pulp.withValues(alpha: 0.92),
      popoverBackground: huskDeep,
      popoverText: ds.CoconutColors.white,
      surfaceSkeletonBase: cream,
      surfaceSkeletonHighlight: shell,
      loadingIndicatorColor: huskDeep,
      loadingOverlay: huskDeep.withValues(alpha: 0.18),
      pageIndicatorActive: husk,
      pageIndicatorInactive: sand,
      checkIconBackground: huskDeep,
      checkIconForeground: ds.CoconutColors.white,
      checkIconBackgroundDisabled: line,
      checkIconForegroundDisabled: caramel,
      linkText: lagoon,

      homeBackground: pulp,
      homeSurface: cream,
      homeSurfacePressOverlay: golenSun,
      homeSurfacePressOverlayOpacity: 0.2,
      nodeConnected: lagoonDeep,
      nodeFailed: ds.CoconutColors.hotPink,
      utxoOverviewChartSurface: shell,
      utxoOverviewChartUnselectedOverlayOpacity: 0.32,
      utxoOverviewCoinSurface: shell,
      utxoOverviewSelectedCoinBorder: huskDeep,
      utxoOverviewBillSurface: shell,
      utxoOverviewUnselectedOverlay: sand,
      utxoOverviewCoinTintStrength: 1,
      utxoOverviewCoinIconOpacity: 0.06,
      utxoOverviewCoinInnerStrokeOpacity: 0.06,
      taprootParent: husk,
      taprootChild: lagoon,
      taprootRoleText: ds.CoconutColors.white,
      taprootParticipantIconBorder: sand,
      taprootParticipantIconBackground: cream,
      taprootParticipantNeutralBackground: shell,
      taprootParticipantNeutralBorder: line,
      taprootParticipantNeutralRoleBackground: cream,
      taprootParticipantNeutralRoleBorder: line,
      taprootParticipantNeutralRoleText: huskDeep,
      txFlowLine: caramel,
      rbfAccent: palmGreen,
      cpfpAccent: lagoon,
      feeBumpingHistoryLine: sand,
      sendingColor: palmGreen,
      receivingColor: lagoon,
      recommendFeeAnimStart: huskDeep,
      recommendFeeAnimHighlight: caramel,
      glossaryKeywordBackground: seefoam,
      glossaryKeywordText: huskDeep,
      qrScannerOverlay: huskSoft.withValues(alpha: 0.4),
      qrScannerProgressBarTrack: sand,
      qrScannerProgressBarFill: huskDeep,
      faucetPopoverBackground: seefoam,
      faucetPopoverText: huskDeep,
    );
  }
}
