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

/// 경고 / 실패(또는 위험)을 나타내는 공통 시맨틱 색상입니다.
///
/// 특정 배경 위에서 가독성이 떨어지는 경우에만 테마별로 다른 값으로 조정하고,
/// 그 외에는 이 기본값을 그대로 사용합니다.
const Color kCoconutWarning = ds.CoconutColors.warningYellow;
const Color kCoconutDanger = ds.CoconutColors.hotPink;
const Color kCoconutWarningCard = ds.CoconutColors.warningAmber;
const Color kCoconutAppLockWarningForeground = ds.CoconutColors.black;
const Color kCoconutUnbackedWarningForeground = ds.CoconutColors.white;

/// 시세·금액의 상승/하락 색상입니다.
/// 상승은 비트코인을 상징하는 주황, 하락은 그에 대비되는 초록을 사용합니다.
const Color kCoconutPriceUp = Color(0xFFE64A19);
const Color kCoconutPriceDown = Color(0xFF35C759);

/// 가이드 말풍선. 테마와 상관없이 같은 파랑 위에 흰 글자
const Color kCoconutGuideBubbleBackground = Color(0xFF4A77F1);
const Color kCoconutGuideBubblePrimaryText = ds.CoconutColors.white;

/// 탭루트 지갑 정보 화면에서 부모 키/자식 키를 구분하는 고정 색상입니다.
///
/// 사용자가 "부모 = 보라, 자식 = 파랑"으로 역할을 색으로 학습하므로,
/// 테마가 바뀌어도 항상 같은 색이어야 합니다. 다크 테마 기준값으로 고정합니다.
const Color kCoconutTaprootParent = ds.CoconutColors.purple;
const Color kCoconutTaprootChild = ds.CoconutColors.sky;

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
  /// secondaryTextStrong: primary보다 약하고 secondary보다 강한 보조 텍스트
  /// secondaryText: 보조 정보, 설명, 메타 텍스트
  /// tertiaryText: secondary보다 한 단계 더 약한 보조 정보 텍스트
  /// mutedText: 선택되지 않음, 입력 전, 비활성, 약한 상태 표현에 쓰는 subdued foreground
  final Color primaryText;
  final Color secondaryTextStrong;
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

  /// 오류·위험을 설명하는 작은 텍스트 전경색.
  final Color dangerText;
  final Color success;
  final Color appLockWarningBackground;
  final Color appLockWarningForeground;
  final Color unbackedWarningForeground;

  /// 구분선
  final Color divider;
  final Color dividerStrong;

  /// 시세·금액 상승/하락
  final Color priceUp;
  final Color priceDown;
  final Color priceUpText;
  final Color priceDownText;

  /// 목표 진행 그래프의 시작/끝 그라디언트 색상
  final Color targetProgressGradientStart;
  final Color targetProgressGradientEnd;

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
  final Color chipMovingBorder;
  final Color chipMovingBackground;
  final Color chipMovingText;
  final Color chipEditModeBackground;
  final Color chipEditModeText;
  final Color chipDisabledText;
  final Color chipDisabledBackground;

  /// 입력 필드 배경/placeholder/보더색
  final Color inputSurface;
  final Color inputPlaceholder;

  /// 포커스 안 됐을 때(비활성화 상태 아님)의 보더색
  final Color inputBorderUnfocused;

  /// 포커스됐을 때의 보더색
  final Color inputBorderFocused;

  /// 세그멘티드 컨트롤
  final Color segmentedControlSelected;
  final Color segmentedControlBackground;
  final Color segmentedControlSelectedText;
  final Color segmentedControlUnselectedText;

  /// 바텀시트
  /// 바텀시트 컨테이너의 기본 표면색
  final Color surfaceBottomSheet;

  /// 바텀시트 기본 표면보다 한 단계 밝은 강조 영역의 표면색
  final Color surfaceBottomSheetElevated;

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

  /// 홈 위젯의 추이 그래프 선
  final Color homeChartLine;

  /// Edit Home 위젯 미리보기 그림자. 어두운 테마에서는 밝은 번짐으로 카드를 띄운다.
  final Color homeWidgetShadow;

  /// utxo 오버뷰 화면 요소
  final Color utxoOverviewChartSurface;
  final double utxoOverviewChartUnselectedOverlayOpacity;
  final Color utxoOverviewCoinSurface;
  final Color utxoOverviewSelectedCoinBorder;
  final Color utxoOverviewBillSurface;
  final Color utxoOverviewUnselectedOverlay;
  final Color utxoOverviewGroupingTabSelectedText;
  final Color utxoOverviewGroupingTabUnselectedText;
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

  /// 가이드 말풍선(예: 홈 지갑 추가 안내)
  final Color guideBubbleBackground;
  final Color guideBubblePrimaryText;

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
    required this.secondaryTextStrong,
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
    required this.dangerText,
    required this.success,
    required this.appLockWarningBackground,
    required this.appLockWarningForeground,
    required this.unbackedWarningForeground,
    required this.divider,
    required this.dividerStrong,
    required this.priceUp,
    required this.priceDown,
    required this.priceUpText,
    required this.priceDownText,
    required this.targetProgressGradientStart,
    required this.targetProgressGradientEnd,
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
    required this.chipMovingBorder,
    required this.chipMovingBackground,
    required this.chipMovingText,
    required this.chipEditModeBackground,
    required this.chipEditModeText,
    required this.chipDisabledText,
    required this.chipDisabledBackground,
    required this.inputSurface,
    required this.inputPlaceholder,
    required this.inputBorderUnfocused,
    required this.inputBorderFocused,
    required this.segmentedControlSelected,
    required this.segmentedControlBackground,
    required this.segmentedControlSelectedText,
    required this.segmentedControlUnselectedText,
    required this.surfaceBottomSheet,
    required this.surfaceBottomSheetElevated,
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
    required this.homeChartLine,
    required this.homeWidgetShadow,
    required this.utxoOverviewChartSurface,
    required this.utxoOverviewChartUnselectedOverlayOpacity,
    required this.utxoOverviewCoinSurface,
    required this.utxoOverviewSelectedCoinBorder,
    required this.utxoOverviewBillSurface,
    required this.utxoOverviewUnselectedOverlay,
    required this.utxoOverviewGroupingTabSelectedText,
    required this.utxoOverviewGroupingTabUnselectedText,
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
    required this.guideBubbleBackground,
    required this.guideBubblePrimaryText,
  });

  static double _contrast(Color foreground, Color background) {
    final a = Color.alphaBlend(Color(foreground.toARGB32()), Color(background.toARGB32())).computeLuminance();
    final b = Color(background.toARGB32()).computeLuminance();
    return a > b ? (a + 0.05) / (b + 0.05) : (b + 0.05) / (a + 0.05);
  }

  static Color _lerpForeground(Color a, Color b, Color surfaceA, Color surfaceB, double t, [double minimum = 4.5]) {
    final foreground = Color.lerp(a, b, t)!;
    final surface = Color.lerp(surfaceA, surfaceB, t)!;
    final floor = [minimum, _contrast(a, surfaceA), _contrast(b, surfaceB)].reduce((a, b) => a < b ? a : b);
    if (_contrast(foreground, surface) >= floor) return foreground;
    const black = Color(0xFF000000);
    const white = Color(0xFFFFFFFF);
    final target = _contrast(black, surface) > _contrast(white, surface) ? black : white;
    var low = 0.0;
    var high = 1.0;
    // Opposite foregrounds must switch polarity; preserve their tint until contrast requires it.
    for (var i = 0; i < 10; i++) {
      final mid = (low + high) / 2;
      if (_contrast(Color.lerp(foreground, target, mid)!, surface) < floor) {
        low = mid;
      } else {
        high = mid;
      }
    }
    return Color.lerp(foreground, target, high)!;
  }

  /// Interpolates existing roles without changing either palette.
  static CoconutColors lerp(CoconutColors a, CoconutColors b, double t) {
    if (t == 0) return a;
    if (t == 1) return b;
    return CoconutColors(
      mainnetLogoGradient: Gradient.lerp(a.mainnetLogoGradient, b.mainnetLogoGradient, t)!,
      regtestLogo: Color.lerp(a.regtestLogo, b.regtestLogo, t)!,
      background: Color.lerp(a.background, b.background, t)!,
      surface: Color.lerp(a.surface, b.surface, t)!,
      surfacePressOverlay: Color.lerp(a.surfacePressOverlay, b.surfacePressOverlay, t)!,
      surfacePressOverlayOpacity:
          a.surfacePressOverlayOpacity + (b.surfacePressOverlayOpacity - a.surfacePressOverlayOpacity) * t,
      surfaceDisabled: Color.lerp(a.surfaceDisabled, b.surfaceDisabled, t)!,
      surfaceMuted: Color.lerp(a.surfaceMuted, b.surfaceMuted, t)!,
      surfaceInset: Color.lerp(a.surfaceInset, b.surfaceInset, t)!,
      surfaceInfoChip: Color.lerp(a.surfaceInfoChip, b.surfaceInfoChip, t)!,
      primary: Color.lerp(a.primary, b.primary, t)!,
      primaryText: _lerpForeground(a.primaryText, b.primaryText, a.background, b.background, t),
      secondaryTextStrong: _lerpForeground(a.secondaryTextStrong, b.secondaryTextStrong, a.background, b.background, t),
      secondaryText: _lerpForeground(a.secondaryText, b.secondaryText, a.background, b.background, t),
      tertiaryText: _lerpForeground(a.tertiaryText, b.tertiaryText, a.background, b.background, t),
      mutedText: _lerpForeground(a.mutedText, b.mutedText, a.background, b.background, t),
      accentForeground: Color.lerp(a.accentForeground, b.accentForeground, t)!,
      border: Color.lerp(a.border, b.border, t)!,
      borderStrong: Color.lerp(a.borderStrong, b.borderStrong, t)!,
      shadowDefault: Color.lerp(a.shadowDefault, b.shadowDefault, t)!,
      shadowSubtle: Color.lerp(a.shadowSubtle, b.shadowSubtle, t)!,
      iconBackground: Color.lerp(a.iconBackground, b.iconBackground, t)!,
      iconBackgroundSubtle: Color.lerp(a.iconBackgroundSubtle, b.iconBackgroundSubtle, t)!,
      iconPrimary: _lerpForeground(a.iconPrimary, b.iconPrimary, a.background, b.background, t, 3),
      iconSecondary: _lerpForeground(a.iconSecondary, b.iconSecondary, a.background, b.background, t, 3),
      iconDisabled: Color.lerp(a.iconDisabled, b.iconDisabled, t)!,
      iconOnDanger: Color.lerp(a.iconOnDanger, b.iconOnDanger, t)!,
      iconButtonHighlight: Color.lerp(a.iconButtonHighlight, b.iconButtonHighlight, t)!,
      warning: Color.lerp(a.warning, b.warning, t)!,
      danger: Color.lerp(a.danger, b.danger, t)!,
      dangerText: Color.lerp(a.dangerText, b.dangerText, t)!,
      success: Color.lerp(a.success, b.success, t)!,
      appLockWarningBackground: Color.lerp(a.appLockWarningBackground, b.appLockWarningBackground, t)!,
      appLockWarningForeground: Color.lerp(a.appLockWarningForeground, b.appLockWarningForeground, t)!,
      unbackedWarningForeground: Color.lerp(a.unbackedWarningForeground, b.unbackedWarningForeground, t)!,
      divider: Color.lerp(a.divider, b.divider, t)!,
      dividerStrong: Color.lerp(a.dividerStrong, b.dividerStrong, t)!,
      priceUp: Color.lerp(a.priceUp, b.priceUp, t)!,
      priceDown: Color.lerp(a.priceDown, b.priceDown, t)!,
      priceUpText: Color.lerp(a.priceUpText, b.priceUpText, t)!,
      priceDownText: Color.lerp(a.priceDownText, b.priceDownText, t)!,
      targetProgressGradientStart: Color.lerp(a.targetProgressGradientStart, b.targetProgressGradientStart, t)!,
      targetProgressGradientEnd: Color.lerp(a.targetProgressGradientEnd, b.targetProgressGradientEnd, t)!,
      brandAccentBackground: Color.lerp(a.brandAccentBackground, b.brandAccentBackground, t)!,
      brandAccentForeground: Color.lerp(a.brandAccentForeground, b.brandAccentForeground, t)!,
      surfaceButton: Color.lerp(a.surfaceButton, b.surfaceButton, t)!,
      surfaceButtonText: _lerpForeground(a.surfaceButtonText, b.surfaceButtonText, a.surfaceButton, b.surfaceButton, t),
      buttonPrimaryBackground: Color.lerp(a.buttonPrimaryBackground, b.buttonPrimaryBackground, t)!,
      buttonPrimaryForeground: _lerpForeground(
        a.buttonPrimaryForeground,
        b.buttonPrimaryForeground,
        a.buttonPrimaryBackground,
        b.buttonPrimaryBackground,
        t,
      ),
      buttonPrimaryDisabledBackground:
          Color.lerp(a.buttonPrimaryDisabledBackground, b.buttonPrimaryDisabledBackground, t)!,
      buttonPrimaryDisabledForeground:
          Color.lerp(a.buttonPrimaryDisabledForeground, b.buttonPrimaryDisabledForeground, t)!,
      buttonPrimaryPressOverlay: Color.lerp(a.buttonPrimaryPressOverlay, b.buttonPrimaryPressOverlay, t)!,
      buttonPrimaryPressOverlayOpacity:
          a.buttonPrimaryPressOverlayOpacity +
          (b.buttonPrimaryPressOverlayOpacity - a.buttonPrimaryPressOverlayOpacity) * t,
      buttonSecondaryBackground: Color.lerp(a.buttonSecondaryBackground, b.buttonSecondaryBackground, t)!,
      buttonSecondaryForeground: _lerpForeground(
        a.buttonSecondaryForeground,
        b.buttonSecondaryForeground,
        a.buttonSecondaryBackground,
        b.buttonSecondaryBackground,
        t,
      ),
      chipUnselectedBackground: Color.lerp(a.chipUnselectedBackground, b.chipUnselectedBackground, t)!,
      chipUnselectedText: _lerpForeground(
        a.chipUnselectedText,
        b.chipUnselectedText,
        a.chipUnselectedBackground,
        b.chipUnselectedBackground,
        t,
      ),
      chipSelectedBackground: Color.lerp(a.chipSelectedBackground, b.chipSelectedBackground, t)!,
      chipSelectedText: _lerpForeground(
        a.chipSelectedText,
        b.chipSelectedText,
        a.chipSelectedBackground,
        b.chipSelectedBackground,
        t,
      ),
      chipOutlinedUnselectedBackground:
          Color.lerp(a.chipOutlinedUnselectedBackground, b.chipOutlinedUnselectedBackground, t)!,
      chipOutlinedUnselectedText: _lerpForeground(
        a.chipOutlinedUnselectedText,
        b.chipOutlinedUnselectedText,
        a.chipOutlinedUnselectedBackground,
        b.chipOutlinedUnselectedBackground,
        t,
      ),
      chipMovingBorder: Color.lerp(a.chipMovingBorder, b.chipMovingBorder, t)!,
      chipMovingBackground: Color.lerp(a.chipMovingBackground, b.chipMovingBackground, t)!,
      chipMovingText: _lerpForeground(
        a.chipMovingText,
        b.chipMovingText,
        a.chipMovingBackground,
        b.chipMovingBackground,
        t,
      ),
      chipEditModeBackground: Color.lerp(a.chipEditModeBackground, b.chipEditModeBackground, t)!,
      chipEditModeText: _lerpForeground(
        a.chipEditModeText,
        b.chipEditModeText,
        a.chipEditModeBackground,
        b.chipEditModeBackground,
        t,
      ),
      chipDisabledText: Color.lerp(a.chipDisabledText, b.chipDisabledText, t)!,
      chipDisabledBackground: Color.lerp(a.chipDisabledBackground, b.chipDisabledBackground, t)!,
      inputSurface: Color.lerp(a.inputSurface, b.inputSurface, t)!,
      inputPlaceholder: _lerpForeground(a.inputPlaceholder, b.inputPlaceholder, a.inputSurface, b.inputSurface, t),
      inputBorderUnfocused: Color.lerp(a.inputBorderUnfocused, b.inputBorderUnfocused, t)!,
      inputBorderFocused: Color.lerp(a.inputBorderFocused, b.inputBorderFocused, t)!,
      segmentedControlSelected: Color.lerp(a.segmentedControlSelected, b.segmentedControlSelected, t)!,
      segmentedControlBackground: Color.lerp(a.segmentedControlBackground, b.segmentedControlBackground, t)!,
      segmentedControlSelectedText: _lerpForeground(
        a.segmentedControlSelectedText,
        b.segmentedControlSelectedText,
        a.segmentedControlSelected,
        b.segmentedControlSelected,
        t,
      ),
      segmentedControlUnselectedText: _lerpForeground(
        a.segmentedControlUnselectedText,
        b.segmentedControlUnselectedText,
        a.segmentedControlBackground,
        b.segmentedControlBackground,
        t,
      ),
      surfaceBottomSheet: Color.lerp(a.surfaceBottomSheet, b.surfaceBottomSheet, t)!,
      surfaceBottomSheetElevated: Color.lerp(a.surfaceBottomSheetElevated, b.surfaceBottomSheetElevated, t)!,
      bottomSheetHandle: Color.lerp(a.bottomSheetHandle, b.bottomSheetHandle, t)!,
      bottomSheetKeyboardToolbar: Color.lerp(a.bottomSheetKeyboardToolbar, b.bottomSheetKeyboardToolbar, t)!,
      bottomSheetExtensionFieldBackground:
          Color.lerp(a.bottomSheetExtensionFieldBackground, b.bottomSheetExtensionFieldBackground, t)!,
      bottomActionBarBackground: Color.lerp(a.bottomActionBarBackground, b.bottomActionBarBackground, t)!,
      pulldownMenuBackground: Color.lerp(a.pulldownMenuBackground, b.pulldownMenuBackground, t)!,
      pulldownMenuPressedColor: Color.lerp(a.pulldownMenuPressedColor, b.pulldownMenuPressedColor, t)!,
      pulldownMenuDividerColor: Color.lerp(a.pulldownMenuDividerColor, b.pulldownMenuDividerColor, t)!,
      pulldownMenuTextColor: _lerpForeground(
        a.pulldownMenuTextColor,
        b.pulldownMenuTextColor,
        a.pulldownMenuBackground,
        b.pulldownMenuBackground,
        t,
      ),
      switchActiveTrack: Color.lerp(a.switchActiveTrack, b.switchActiveTrack, t)!,
      switchInactiveTrack: Color.lerp(a.switchInactiveTrack, b.switchInactiveTrack, t)!,
      switchActiveThumb: Color.lerp(a.switchActiveThumb, b.switchActiveThumb, t)!,
      switchInactiveThumb: Color.lerp(a.switchInactiveThumb, b.switchInactiveThumb, t)!,
      switchTrackDisabled: Color.lerp(a.switchTrackDisabled, b.switchTrackDisabled, t)!,
      switchThumbDisabled: Color.lerp(a.switchThumbDisabled, b.switchThumbDisabled, t)!,
      tooltipBackground: Color.lerp(a.tooltipBackground, b.tooltipBackground, t)!,
      popupBackground: Color.lerp(a.popupBackground, b.popupBackground, t)!,
      dimOverlay: Color.lerp(a.dimOverlay, b.dimOverlay, t)!,
      popoverBackground: Color.lerp(a.popoverBackground, b.popoverBackground, t)!,
      popoverText: _lerpForeground(a.popoverText, b.popoverText, a.popoverBackground, b.popoverBackground, t),
      surfaceSkeletonBase: Color.lerp(a.surfaceSkeletonBase, b.surfaceSkeletonBase, t)!,
      surfaceSkeletonHighlight: Color.lerp(a.surfaceSkeletonHighlight, b.surfaceSkeletonHighlight, t)!,
      loadingIndicatorColor: Color.lerp(a.loadingIndicatorColor, b.loadingIndicatorColor, t)!,
      loadingOverlay: Color.lerp(a.loadingOverlay, b.loadingOverlay, t)!,
      pageIndicatorActive: Color.lerp(a.pageIndicatorActive, b.pageIndicatorActive, t)!,
      pageIndicatorInactive: Color.lerp(a.pageIndicatorInactive, b.pageIndicatorInactive, t)!,
      checkIconBackground: Color.lerp(a.checkIconBackground, b.checkIconBackground, t)!,
      checkIconForeground: _lerpForeground(
        a.checkIconForeground,
        b.checkIconForeground,
        a.checkIconBackground,
        b.checkIconBackground,
        t,
        3,
      ),
      checkIconBackgroundDisabled: Color.lerp(a.checkIconBackgroundDisabled, b.checkIconBackgroundDisabled, t)!,
      checkIconForegroundDisabled: Color.lerp(a.checkIconForegroundDisabled, b.checkIconForegroundDisabled, t)!,
      linkText: Color.lerp(a.linkText, b.linkText, t)!,
      homeBackground: Color.lerp(a.homeBackground, b.homeBackground, t)!,
      homeSurface: Color.lerp(a.homeSurface, b.homeSurface, t)!,
      homeSurfacePressOverlay: Color.lerp(a.homeSurfacePressOverlay, b.homeSurfacePressOverlay, t)!,
      homeSurfacePressOverlayOpacity:
          a.homeSurfacePressOverlayOpacity + (b.homeSurfacePressOverlayOpacity - a.homeSurfacePressOverlayOpacity) * t,
      homeChartLine: Color.lerp(a.homeChartLine, b.homeChartLine, t)!,
      homeWidgetShadow: Color.lerp(a.homeWidgetShadow, b.homeWidgetShadow, t)!,
      utxoOverviewChartSurface: Color.lerp(a.utxoOverviewChartSurface, b.utxoOverviewChartSurface, t)!,
      utxoOverviewChartUnselectedOverlayOpacity:
          a.utxoOverviewChartUnselectedOverlayOpacity +
          (b.utxoOverviewChartUnselectedOverlayOpacity - a.utxoOverviewChartUnselectedOverlayOpacity) * t,
      utxoOverviewCoinSurface: Color.lerp(a.utxoOverviewCoinSurface, b.utxoOverviewCoinSurface, t)!,
      utxoOverviewSelectedCoinBorder:
          Color.lerp(a.utxoOverviewSelectedCoinBorder, b.utxoOverviewSelectedCoinBorder, t)!,
      utxoOverviewBillSurface: Color.lerp(a.utxoOverviewBillSurface, b.utxoOverviewBillSurface, t)!,
      utxoOverviewUnselectedOverlay: Color.lerp(a.utxoOverviewUnselectedOverlay, b.utxoOverviewUnselectedOverlay, t)!,
      utxoOverviewGroupingTabSelectedText:
          Color.lerp(a.utxoOverviewGroupingTabSelectedText, b.utxoOverviewGroupingTabSelectedText, t)!,
      utxoOverviewGroupingTabUnselectedText:
          Color.lerp(a.utxoOverviewGroupingTabUnselectedText, b.utxoOverviewGroupingTabUnselectedText, t)!,
      utxoOverviewCoinTintStrength:
          a.utxoOverviewCoinTintStrength + (b.utxoOverviewCoinTintStrength - a.utxoOverviewCoinTintStrength) * t,
      utxoOverviewCoinIconOpacity:
          a.utxoOverviewCoinIconOpacity + (b.utxoOverviewCoinIconOpacity - a.utxoOverviewCoinIconOpacity) * t,
      utxoOverviewCoinInnerStrokeOpacity:
          a.utxoOverviewCoinInnerStrokeOpacity +
          (b.utxoOverviewCoinInnerStrokeOpacity - a.utxoOverviewCoinInnerStrokeOpacity) * t,
      taprootParent: Color.lerp(a.taprootParent, b.taprootParent, t)!,
      taprootChild: Color.lerp(a.taprootChild, b.taprootChild, t)!,
      taprootRoleText: Color.lerp(a.taprootRoleText, b.taprootRoleText, t)!,
      taprootParticipantIconBorder: Color.lerp(a.taprootParticipantIconBorder, b.taprootParticipantIconBorder, t)!,
      taprootParticipantIconBackground:
          Color.lerp(a.taprootParticipantIconBackground, b.taprootParticipantIconBackground, t)!,
      taprootParticipantNeutralBackground:
          Color.lerp(a.taprootParticipantNeutralBackground, b.taprootParticipantNeutralBackground, t)!,
      taprootParticipantNeutralBorder:
          Color.lerp(a.taprootParticipantNeutralBorder, b.taprootParticipantNeutralBorder, t)!,
      taprootParticipantNeutralRoleBackground:
          Color.lerp(a.taprootParticipantNeutralRoleBackground, b.taprootParticipantNeutralRoleBackground, t)!,
      taprootParticipantNeutralRoleBorder:
          Color.lerp(a.taprootParticipantNeutralRoleBorder, b.taprootParticipantNeutralRoleBorder, t)!,
      taprootParticipantNeutralRoleText:
          Color.lerp(a.taprootParticipantNeutralRoleText, b.taprootParticipantNeutralRoleText, t)!,
      txFlowLine: Color.lerp(a.txFlowLine, b.txFlowLine, t)!,
      rbfAccent: Color.lerp(a.rbfAccent, b.rbfAccent, t)!,
      cpfpAccent: Color.lerp(a.cpfpAccent, b.cpfpAccent, t)!,
      feeBumpingHistoryLine: Color.lerp(a.feeBumpingHistoryLine, b.feeBumpingHistoryLine, t)!,
      sendingColor: Color.lerp(a.sendingColor, b.sendingColor, t)!,
      receivingColor: Color.lerp(a.receivingColor, b.receivingColor, t)!,
      recommendFeeAnimStart: Color.lerp(a.recommendFeeAnimStart, b.recommendFeeAnimStart, t)!,
      recommendFeeAnimHighlight: Color.lerp(a.recommendFeeAnimHighlight, b.recommendFeeAnimHighlight, t)!,
      glossaryKeywordBackground: Color.lerp(a.glossaryKeywordBackground, b.glossaryKeywordBackground, t)!,
      glossaryKeywordText: Color.lerp(a.glossaryKeywordText, b.glossaryKeywordText, t)!,
      qrScannerOverlay: Color.lerp(a.qrScannerOverlay, b.qrScannerOverlay, t)!,
      qrScannerProgressBarTrack: Color.lerp(a.qrScannerProgressBarTrack, b.qrScannerProgressBarTrack, t)!,
      qrScannerProgressBarFill: Color.lerp(a.qrScannerProgressBarFill, b.qrScannerProgressBarFill, t)!,
      faucetPopoverBackground: Color.lerp(a.faucetPopoverBackground, b.faucetPopoverBackground, t)!,
      faucetPopoverText: Color.lerp(a.faucetPopoverText, b.faucetPopoverText, t)!,
      guideBubbleBackground: Color.lerp(a.guideBubbleBackground, b.guideBubbleBackground, t)!,
      guideBubblePrimaryText: Color.lerp(a.guideBubblePrimaryText, b.guideBubblePrimaryText, t)!,
    );
  }

  factory CoconutColors.dark() {
    return CoconutColors(
      mainnetLogoGradient: kCoconutMainnetLogoGradient,
      regtestLogo: ds.CoconutColors.white,
      background: ds.CoconutColors.black,
      surface: ds.CoconutColors.gray850,
      surfacePressOverlay: ds.CoconutColors.black,
      surfacePressOverlayOpacity: 0.5,
      surfaceDisabled: ds.CoconutColors.black,
      surfaceMuted: ds.CoconutColors.gray800,
      surfaceInset: ds.CoconutColors.black,
      surfaceInfoChip: ds.CoconutColors.gray750,
      primary: ds.CoconutColors.primary,
      primaryText: ds.CoconutColors.white,
      secondaryTextStrong: ds.CoconutColors.gray300,
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
      warning: kCoconutWarning,
      danger: kCoconutDanger,
      dangerText: const Color(0xFFFF7890),
      success: ds.CoconutColors.successOnDark,
      appLockWarningBackground: kCoconutWarningCard,
      appLockWarningForeground: kCoconutAppLockWarningForeground,
      unbackedWarningForeground: kCoconutUnbackedWarningForeground,
      divider: ds.CoconutColors.gray800,
      dividerStrong: ds.CoconutColors.gray700,
      priceUp: kCoconutPriceUp,
      priceDown: kCoconutPriceDown,
      priceUpText: const Color(0xFFF36A35),
      priceDownText: kCoconutPriceDown,
      targetProgressGradientStart: const Color(0xFF8CD5FF),
      targetProgressGradientEnd: const Color(0xFF7775FF),

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
      chipUnselectedText: const Color(0xFFA0A0A0),
      chipSelectedBackground: ds.CoconutColors.white,
      chipSelectedText: ds.CoconutColors.black,
      chipOutlinedUnselectedBackground: ds.CoconutColors.gray800,
      chipOutlinedUnselectedText: const Color(0xFFA0A0A0),
      chipMovingBorder: ds.CoconutColors.gray350,
      chipMovingBackground: ds.CoconutColors.gray750,
      chipMovingText: ds.CoconutColors.white,
      chipEditModeBackground: ds.CoconutColors.gray800,
      chipEditModeText: ds.CoconutColors.gray300,
      chipDisabledText: ds.CoconutColors.gray600,
      chipDisabledBackground: ds.CoconutColors.gray850,
      inputSurface: ds.CoconutColors.gray800,
      inputPlaceholder: const Color(0xFFA0A0A0),
      inputBorderUnfocused: ds.CoconutColors.gray800,
      inputBorderFocused: ds.CoconutColors.white,
      segmentedControlSelected: ds.CoconutColors.gray900,
      segmentedControlBackground: ds.CoconutColors.gray800,
      segmentedControlSelectedText: ds.CoconutColors.white,
      segmentedControlUnselectedText: const Color(0xFFA0A0A0),
      surfaceBottomSheet: ds.CoconutColors.gray900,
      surfaceBottomSheetElevated: ds.CoconutColors.gray850,
      bottomSheetHandle: ds.CoconutColors.gray600,
      bottomSheetKeyboardToolbar: const Color(0xFF2E2E2E),
      bottomSheetExtensionFieldBackground: ds.CoconutColors.black,
      bottomActionBarBackground: ds.CoconutColors.gray900,
      pulldownMenuBackground: ds.CoconutColors.gray900,
      pulldownMenuPressedColor: ds.CoconutColors.gray800,
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
      homeSurfacePressOverlay: ds.CoconutColors.gray800,
      homeSurfacePressOverlayOpacity: 0.5,
      homeChartLine: kCoconutPriceUp,
      homeWidgetShadow: const Color.fromARGB(12, 255, 255, 255),
      utxoOverviewChartSurface: ds.CoconutColors.gray800,
      utxoOverviewChartUnselectedOverlayOpacity: 0.6,
      utxoOverviewCoinSurface: ds.CoconutColors.gray900,
      utxoOverviewSelectedCoinBorder: ds.CoconutColors.gray150,
      utxoOverviewBillSurface: ds.CoconutColors.gray900,
      utxoOverviewUnselectedOverlay: ds.CoconutColors.black,
      utxoOverviewGroupingTabSelectedText: ds.CoconutColors.white,
      utxoOverviewGroupingTabUnselectedText: ds.CoconutColors.gray500,
      utxoOverviewCoinTintStrength: 0.7,
      utxoOverviewCoinIconOpacity: 0.1,
      utxoOverviewCoinInnerStrokeOpacity: 0.1,
      taprootParent: kCoconutTaprootParent,
      taprootChild: kCoconutTaprootChild,
      taprootRoleText: ds.CoconutColors.white,
      taprootParticipantIconBorder: ds.CoconutColors.gray800,
      taprootParticipantIconBackground: ds.CoconutColors.gray800,
      taprootParticipantNeutralBackground: ds.CoconutColors.gray850,
      taprootParticipantNeutralBorder: ds.CoconutColors.gray850,
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
      guideBubbleBackground: kCoconutGuideBubbleBackground,
      guideBubblePrimaryText: kCoconutGuideBubblePrimaryText,
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
      surfacePressOverlayOpacity: 0.12,
      surfaceDisabled: ds.CoconutColors.gray300,
      surfaceMuted: ds.CoconutColors.gray200,
      surfaceInfoChip: ds.CoconutColors.gray300,
      primary: ds.CoconutColors.purple,
      primaryText: ds.CoconutColors.black,
      secondaryTextStrong: ds.CoconutColors.gray800,
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
      warning: kCoconutWarning,
      danger: kCoconutDanger,
      dangerText: const Color(0xFFBF285F),
      success: ds.CoconutColors.successOnLight,
      appLockWarningBackground: kCoconutWarningCard,
      appLockWarningForeground: kCoconutAppLockWarningForeground,
      unbackedWarningForeground: kCoconutUnbackedWarningForeground,
      divider: ds.CoconutColors.gray200,
      dividerStrong: ds.CoconutColors.gray300,
      priceUp: kCoconutPriceUp,
      priceDown: kCoconutPriceDown,
      priceUpText: const Color(0xFFBA3B13),
      priceDownText: const Color(0xFF19752F),
      targetProgressGradientStart: const Color(0xFF329DDA),
      targetProgressGradientEnd: ds.CoconutColors.purple,

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
      chipUnselectedText: const Color(0xFF6E6E6E),
      chipSelectedBackground: ds.CoconutColors.gray800,
      chipSelectedText: ds.CoconutColors.white,
      chipOutlinedUnselectedBackground: ds.CoconutColors.gray150,
      chipOutlinedUnselectedText: const Color(0xFF6E6E6E),
      chipMovingBorder: ds.CoconutColors.gray350,
      chipMovingBackground: ds.CoconutColors.gray200,
      chipMovingText: ds.CoconutColors.gray800,
      chipEditModeBackground: ds.CoconutColors.gray150,
      chipEditModeText: const Color(0xFF6E6E6E),
      chipDisabledText: ds.CoconutColors.gray300,
      chipDisabledBackground: ds.CoconutColors.gray100,
      //inputSurface: const Color(0xFFF1F2F5),
      inputSurface: ds.CoconutColors.white,
      inputPlaceholder: const Color(0xFF6E6E6E),
      inputBorderUnfocused: ds.CoconutColors.gray200,
      inputBorderFocused: ds.CoconutColors.black,
      segmentedControlSelected: ds.CoconutColors.gray800,
      segmentedControlBackground: ds.CoconutColors.gray150,
      segmentedControlSelectedText: ds.CoconutColors.white,
      segmentedControlUnselectedText: const Color(0xFF6E6E6E),
      surfaceBottomSheet: ds.CoconutColors.white,
      surfaceBottomSheetElevated: ds.CoconutColors.gray150,
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
      homeChartLine: kCoconutPriceUp,
      homeWidgetShadow: ds.CoconutColors.gray600.withValues(alpha: 0.3),
      utxoOverviewChartSurface: ds.CoconutColors.white,
      utxoOverviewChartUnselectedOverlayOpacity: 0.6,
      utxoOverviewCoinSurface: ds.CoconutColors.white,
      utxoOverviewSelectedCoinBorder: ds.CoconutColors.black,
      utxoOverviewBillSurface: ds.CoconutColors.white,
      utxoOverviewUnselectedOverlay: ds.CoconutColors.black,
      utxoOverviewGroupingTabSelectedText: ds.CoconutColors.black,
      utxoOverviewGroupingTabUnselectedText: ds.CoconutColors.gray400,
      utxoOverviewCoinTintStrength: 0.7,
      utxoOverviewCoinIconOpacity: 0.1,
      utxoOverviewCoinInnerStrokeOpacity: 0.1,
      taprootParent: kCoconutTaprootParent,
      taprootChild: kCoconutTaprootChild,
      taprootRoleText: ds.CoconutColors.white,
      taprootParticipantIconBorder: ds.CoconutColors.gray200,
      taprootParticipantIconBackground: ds.CoconutColors.gray100,
      taprootParticipantNeutralBackground: ds.CoconutColors.gray150,
      taprootParticipantNeutralBorder: ds.CoconutColors.gray150,
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
      guideBubbleBackground: kCoconutGuideBubbleBackground,
      guideBubblePrimaryText: kCoconutGuideBubblePrimaryText,
    );
  }

  factory CoconutColors.coconutTheme() {
    const pulp = Color(0xFFFAF8F3);
    const cream = Color(0xFFF4E9D3);
    const shell = Color(0xFFFFFDF7);
    const sand = Color(0xFFEAD6B4);
    const caramel = Color(0xFFD89A5B);
    const huskDeep = Color(0xFF6E3D18);
    const husk = Color(0xFFB87433);
    const huskSoft = Color(0xFFDFC09A);
    const toast = Color(0xFFC18C55);
    const lagoon = Color(0xFF72CFEA);
    const lagoonDeep = Color(0xFF4FA8B8);
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
      surfaceInfoChip: sand.withAlpha(90),
      primary: palmGreen,
      primaryText: huskDeep,
      secondaryTextStrong: huskDeep,
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
      iconDisabled: sand,
      iconOnDanger: ds.CoconutColors.white,
      iconButtonHighlight: dim,
      warning: kCoconutWarning,
      danger: kCoconutDanger,
      dangerText: const Color(0xFFBF285F),
      success: ds.CoconutColors.successOnLight,
      appLockWarningBackground: kCoconutWarningCard,
      appLockWarningForeground: kCoconutAppLockWarningForeground,
      unbackedWarningForeground: kCoconutUnbackedWarningForeground,
      divider: lagoon.withAlpha(30),
      dividerStrong: lagoon.withAlpha(60),
      priceUp: kCoconutPriceUp,
      priceDown: kCoconutPriceDown,
      priceUpText: const Color(0xFFBA3B13),
      priceDownText: const Color(0xFF19752F),
      targetProgressGradientStart: lagoonDeep,
      targetProgressGradientEnd: palmGreen,

      brandAccentBackground: lagoon,
      brandAccentForeground: huskDeep,
      surfaceButton: sand,
      surfaceButtonText: huskDeep,
      buttonPrimaryBackground: huskDeep,
      buttonPrimaryForeground: ds.CoconutColors.white,
      buttonPrimaryDisabledBackground: cream,
      buttonPrimaryDisabledForeground: line,
      buttonPrimaryPressOverlay: ds.CoconutColors.white,
      buttonPrimaryPressOverlayOpacity: 0.12,
      buttonSecondaryBackground: sand,
      buttonSecondaryForeground: huskDeep,
      chipUnselectedBackground: cream,
      chipUnselectedText: const Color(0xFF865729),
      chipSelectedBackground: huskDeep,
      chipSelectedText: ds.CoconutColors.white,
      chipOutlinedUnselectedBackground: cream,
      chipOutlinedUnselectedText: const Color(0xFF865729),
      chipMovingBorder: huskSoft,
      chipMovingBackground: sand,
      chipMovingText: huskDeep,
      chipEditModeBackground: cream,
      chipEditModeText: const Color(0xFF865729),
      chipDisabledText: line,
      chipDisabledBackground: shell,
      inputSurface: ds.CoconutColors.white,
      inputPlaceholder: const Color(0xFFA0652C),
      inputBorderUnfocused: line,
      inputBorderFocused: huskDeep,
      segmentedControlSelected: huskDeep,
      segmentedControlBackground: dim,
      segmentedControlSelectedText: ds.CoconutColors.white,
      segmentedControlUnselectedText: const Color(0xFF865729),
      surfaceBottomSheet: shell,
      surfaceBottomSheetElevated: Color.lerp(shell, caramel, 0.15)!,
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
      homeChartLine: kCoconutPriceUp,
      homeWidgetShadow: huskDeep.withValues(alpha: 0.18),
      utxoOverviewChartSurface: shell,
      utxoOverviewChartUnselectedOverlayOpacity: 0.32,
      utxoOverviewCoinSurface: shell,
      utxoOverviewSelectedCoinBorder: huskDeep,
      utxoOverviewBillSurface: shell,
      utxoOverviewUnselectedOverlay: sand,
      utxoOverviewGroupingTabSelectedText: huskDeep,
      utxoOverviewGroupingTabUnselectedText: huskSoft,
      utxoOverviewCoinTintStrength: 1,
      utxoOverviewCoinIconOpacity: 0.06,
      utxoOverviewCoinInnerStrokeOpacity: 0.06,
      taprootParent: kCoconutTaprootParent,
      taprootChild: kCoconutTaprootChild,
      taprootRoleText: ds.CoconutColors.white,
      taprootParticipantIconBorder: sand,
      taprootParticipantIconBackground: cream,
      taprootParticipantNeutralBackground: cream,
      taprootParticipantNeutralBorder: cream,
      taprootParticipantNeutralRoleBackground: dim,
      taprootParticipantNeutralRoleBorder: line,
      taprootParticipantNeutralRoleText: huskDeep,
      txFlowLine: huskSoft,
      rbfAccent: palmGreen,
      cpfpAccent: lagoonDeep,
      feeBumpingHistoryLine: sand,
      sendingColor: palmGreen,
      receivingColor: lagoonDeep,
      recommendFeeAnimStart: huskDeep,
      recommendFeeAnimHighlight: caramel,
      glossaryKeywordBackground: seefoam,
      glossaryKeywordText: huskDeep,
      qrScannerOverlay: huskSoft.withValues(alpha: 0.4),
      qrScannerProgressBarTrack: sand,
      qrScannerProgressBarFill: huskDeep,
      faucetPopoverBackground: seefoam,
      faucetPopoverText: huskDeep,
      guideBubbleBackground: kCoconutGuideBubbleBackground,
      guideBubblePrimaryText: kCoconutGuideBubblePrimaryText,
    );
  }
}
