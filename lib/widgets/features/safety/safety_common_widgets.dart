import 'package:coconut_design_system/coconut_design_system.dart' hide CoconutUnderlinedButton;
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/ui/coconut/coconut_underlined_button.dart';
import 'package:coconut_wallet/utils/custom_wallet_icons.dart';
import 'package:coconut_wallet/utils/text_utils.dart';
import 'package:coconut_wallet/utils/vibration_util.dart';
import 'package:coconut_wallet/widgets/common/buttons/shrink_animation_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// POLISH R1: 한국어는 단어 중간에서 줄을 바꾸지 않는다(앱 방식 `TextUtils.preventLineBreakInsideWords`).
/// 줄바꿈될 수 있는 제목·배너·카드 글에만 쓴다. 주소·금액·숫자에는 쓰지 않는다(글자 사이 이음 문자가 복사·비교를 바꾼다).
/// 두 번 감싸도 한 번과 같다(이미 든 이음 문자를 걷고 다시 넣는다): 스스로 감싸는 공용 행·배너에 감싼 글을 넘겨도 된다.
/// 한글이 든 글만 감싼다: 영문만 있는 글·주소만 있는 줄은 그대로 지나간다(읽기 라벨·검색에도 그대로)
String safetyKoText(String text) =>
    LocaleSettings.currentLocale == AppLocale.ko && _hangul.hasMatch(text)
        ? TextUtils.preventLineBreakInsideWords(text.replaceAll('\u2060', ''))
        : text;

/// 한글이 없는 글(영문 고유명사만 있는 줄 등)에는 넣지 않는다: 읽기 라벨·검색에 그대로 남는다
final _hangul = RegExp('[\uAC00-\uD7A3]');

/// 동작 줄이기(앱 공통 기준)
bool safetyReduceMotion(BuildContext context) =>
    MediaQuery.disableAnimationsOf(context) || MediaQuery.accessibleNavigationOf(context);

/// FixedBottomButton 위 페이드를 비켜 가는 스크롤 아래 여백(R4: 160, 부가 줄이 있으면 184).
/// 버튼과 부가 줄은 본문 글처럼 커지므로 본문 크기(14)의 배율만큼 늘린다. 160을 글자 크기로 키우면 큰 글자를 덜 키우는
/// 비선형 배율(Android 14+)에서 모자란다(선택 시트 common_bottom_sheets.dart와 같은 계산)
double safetyFooterClearance(BuildContext context, {bool hasSubWidget = false}) =>
    (hasSubWidget ? 184 : 160) * (MediaQuery.textScalerOf(context).scale(14) / 14).clamp(1.0, double.infinity);

/// 이 경로의 들어오는 전환이 끝나면 [onSettled]를 한 번 부른다(경로가 이미 떠 있으면 첫 프레임 뒤).
/// 새 경로의 첫 프레임은 Hero 측정용 offstage라 그때의 animation은 '끝남'으로 보이므로 프레임 뒤에 판단한다.
/// 돌려준 함수를 dispose에서 부르면 기다림을 취소한다
VoidCallback whenRouteSettled(BuildContext context, VoidCallback onSettled) {
  final animation = ModalRoute.of(context)?.animation;
  var cancelled = false;
  void onStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    animation!.removeStatusListener(onStatus);
    if (!cancelled) onSettled();
  }

  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (cancelled) return;
    if (animation == null || animation.isCompleted) {
      onSettled();
    } else {
      animation.addStatusListener(onStatus);
    }
  });
  return () {
    cancelled = true;
    animation?.removeStatusListener(onStatus);
  };
}

/// 대시보드 바탕(homeBackground) 위 목록 카드. ButtonGroup과 같은 구분선 규칙을 homeSurface r20 카드에 쓴다
class SafetyListCard extends StatelessWidget {
  const SafetyListCard({super.key, required this.rows, this.backgroundColor});

  final List<Widget> rows;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: backgroundColor ?? colors.homeSurface,
        borderRadius: BorderRadius.circular(CoconutStyles.radius_300),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Sizes.size20),
                child: Divider(color: colors.border.withValues(alpha: 0.21), height: 1),
              ),
            rows[i],
          ],
        ],
      ),
    );
  }
}

/// 선택지 행. SingleButton과 같은 겉모습이지만 긴 문구를 글자 크기를 줄이지 않고 줄바꿈한다
class SafetyChoiceRow extends StatelessWidget {
  const SafetyChoiceRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    required this.onTap,
    this.backgroundColor,
    this.subtitleColor,
    this.below,
    this.keepWords = true,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final VoidCallback onTap;
  final Color? backgroundColor;

  /// 부제 색(기본 secondaryText). 갱신 실패처럼 주의가 필요한 부제는 warningText
  final Color? subtitleColor;

  /// 부제 아래 한 줄 더(예: 이 기기 핫월렛 경고, 같은 시드인지 확인할 수 없음)
  final Widget? below;

  /// 한국어 단어 가운데 줄바꿈 막기(R1). 주소·금액 같은 값이 든 줄이면 false(제목·부제를 주어진 그대로)
  final bool keepWords;

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    return ShrinkAnimationButton(
      onPressed: () {
        vibrateExtraLight();
        onTap();
      },
      defaultColor: backgroundColor ?? colors.surface,
      pressedOverlayColor: colors.surfacePressOverlay,
      borderRadius: CoconutStyles.radius_400,
      animationEndValue: 0.95,
      child: Padding(
        padding: const EdgeInsets.all(Sizes.size20),
        child: Row(
          children: [
            if (leading != null) ...[leading!, CoconutLayout.spacing_400w],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    keepWords ? safetyKoText(title) : title,
                    style: CoconutTypography.body2_14_Bold.setColor(colors.primaryText),
                  ),
                  if (subtitle != null) ...[
                    CoconutLayout.spacing_50h,
                    Text(
                      keepWords ? safetyKoText(subtitle!) : subtitle!,
                      style: CoconutTypography.body3_12.setColor(subtitleColor ?? colors.secondaryText),
                    ),
                  ],
                  if (below != null) ...[CoconutLayout.spacing_100h, below!],
                ],
              ),
            ),
            CoconutLayout.spacing_200w,
            Icon(Icons.keyboard_arrow_right_rounded, color: colors.iconSecondary),
          ],
        ),
      ),
    );
  }
}

/// 검토 필요 행 끝의 연노랑 알약. 따로 누르지 않고 행 전체가 같은 동작을 한다
class SafetyActionPill extends StatelessWidget {
  const SafetyActionPill({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Sizes.size12, vertical: Sizes.size6),
      decoration: BoxDecoration(
        color: colors.warningSurface,
        borderRadius: BorderRadius.circular(CoconutStyles.radius_200),
      ),
      child: Text(text, style: CoconutTypography.body3_12_Bold.setColor(colors.warningText)),
    );
  }
}

/// Premium 브랜드 표시(POLISH §2.3): 다이아를 로고 그라데이션으로 칠한다(`CoconutLogoIcon`과 같은 ShaderMask).
/// 크기는 12·20·32뿐. [muted]는 구독 없음·만료 카드에만 쓰는 단색 `iconSecondary`
class PremiumMark extends StatelessWidget {
  const PremiumMark({super.key, required this.size, this.muted = false})
    : assert(size == 12 || size == 20 || size == 32);

  final double size;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final diamond = SvgPicture.asset(
      CustomWalletIcons.diamond,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(muted ? colors.iconSecondary : Colors.white, BlendMode.srcIn),
    );
    if (muted) return diamond;
    return ShaderMask(
      shaderCallback: colors.mainnetLogoGradient.createShader,
      blendMode: BlendMode.srcIn,
      child: diamond,
    );
  }
}

/// Premium 바탕(POLISH §2.3): 바깥 로고 그라데이션 링 [ringWidth] + 안쪽 `premiumSurfaceGradient`(토스트와 같은 2겹).
/// [onPressed]가 있으면 카드 전체가 버튼 하나(의미 라벨도 하나)
class PremiumSurface extends StatelessWidget {
  const PremiumSurface({
    super.key,
    required this.child,
    required this.radius,
    required this.ringWidth,
    this.padding = EdgeInsets.zero,
    this.onPressed,
  });

  final Widget child;
  final double radius;
  final double ringWidth;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final onPressed = this.onPressed;
    // 누를 수 있으면 ShrinkAnimationButton이 링을 그리고(바깥 반지름 radius + 2, 안쪽 radius), 칠은 안쪽 단색 위에 깐다
    final innerRadius = onPressed == null ? radius - ringWidth : radius;
    final fill = DecoratedBox(
      decoration: BoxDecoration(
        gradient: colors.premiumSurfaceGradient,
        borderRadius: BorderRadius.circular(innerRadius),
      ),
      child: Padding(padding: padding, child: child),
    );
    if (onPressed != null) {
      return MergeSemantics(
        child: ShrinkAnimationButton(
          onPressed: onPressed,
          borderGradient: colors.mainnetLogoGradient,
          borderWidth: ringWidth,
          borderRadius: radius,
          child: fill,
        ),
      );
    }
    return Container(
      padding: EdgeInsets.all(ringWidth),
      decoration: BoxDecoration(gradient: colors.mainnetLogoGradient, borderRadius: BorderRadius.circular(radius)),
      child: fill,
    );
  }
}

/// "Premium" 알약. 보통 바탕(목록 줄·지갑 정보 행·화면 머리말)에만 두고 Premium 바탕 위에는 두지 않는다
class PremiumChip extends StatelessWidget {
  const PremiumChip({super.key});

  @override
  Widget build(BuildContext context) {
    return PremiumSurface(
      radius: 20,
      ringWidth: 1,
      padding: const EdgeInsets.symmetric(horizontal: Sizes.size8, vertical: 3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const PremiumMark(size: 12),
          CoconutLayout.spacing_50w,
          Text(t.premium.badge, style: CoconutTypography.caption_10_Bold.setColor(context.coconutColors.premiumText)),
        ],
      ),
    );
  }
}

/// Premium "순간" 화면 머리(페이월 PA1, Assist 비상 이동 준비): 72 원 + 1.5 링 + PremiumMark 32
class PremiumHero extends StatelessWidget {
  const PremiumHero({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.square(
    dimension: 72,
    child: PremiumSurface(radius: 36, ringWidth: 1.5, child: Center(child: PremiumMark(size: 32))),
  );
}

/// Premium으로 할 수 있는 다음 행동 카드(WH S3 "지금 이동"·"대응 준비", Assist "준비된 이동 있음").
/// 위급 화면의 주 버튼보다 튀지 않게 링 없이 `premiumSurfaceGradient`만 깐다
class PremiumActionCard extends StatelessWidget {
  const PremiumActionCard({
    super.key,
    required this.title,
    required this.body,
    required this.button,
    required this.onPressed,
  });

  final String title;
  final String body;
  final String button;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(gradient: colors.premiumSurfaceGradient, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const PremiumMark(size: 20),
              CoconutLayout.spacing_200w,
              Expanded(child: Text(title, style: CoconutTypography.body1_16_Bold.setColor(colors.primaryText))),
            ],
          ),
          CoconutLayout.spacing_200h,
          Text(body, style: CoconutTypography.body3_12.setColor(colors.secondaryTextStrong)),
          CoconutLayout.spacing_400h,
          // homeSurface는 그라데이션 위에서 1.00~1.07이라 버튼이 사라진다. background는 1.14~1.25
          ShrinkAnimationButton(
            onPressed: onPressed,
            defaultColor: colors.background,
            borderRadius: 12,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
              child: Center(
                child: Text(
                  button,
                  textAlign: TextAlign.center,
                  style: CoconutTypography.body2_14_Bold.setColor(colors.premiumText),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SafetyIconCircle extends StatelessWidget {
  const SafetyIconCircle({super.key, required this.size, required this.background, required this.icon});

  final double size;
  final Color background;
  final Widget icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      child: icon,
    );
  }
}

/// ①②③④ 행. 설명이 있으면 제목을 굵게(지금 할 일·노출 의심), 제목만 있으면 가이드 카드처럼 보통 굵기
class SafetyNumberedRow extends StatelessWidget {
  const SafetyNumberedRow({super.key, required this.number, required this.title, this.description});

  static const _circleSize = 20.0;

  final int number;
  final String title;
  final String? description;

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final titleStyle = description == null ? CoconutTypography.body2_14 : CoconutTypography.body2_14_Bold;
    // 원을 첫 줄 가운데에 맞춘다(핫월렛 백업 가이드 팁 카드와 같은 계산)
    final lineHeight = MediaQuery.textScalerOf(context).scale(titleStyle.fontSize!) * titleStyle.height!;
    final circleTop = ((lineHeight - _circleSize) / 2).clamp(0.0, double.infinity);
    final textTop = ((_circleSize - lineHeight) / 2).clamp(0.0, double.infinity);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(top: circleTop),
          child: SafetyIconCircle(
            size: _circleSize,
            background: colors.iconPrimary,
            icon: Padding(
              padding: const EdgeInsets.all(2),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text('$number', style: CoconutTypography.caption_10_Bold.setColor(colors.background)),
              ),
            ),
          ),
        ),
        CoconutLayout.spacing_300w,
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(top: textTop),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(safetyKoText(title), style: titleStyle.setColor(colors.primaryText)),
                if (description != null) ...[
                  CoconutLayout.spacing_50h,
                  Text(safetyKoText(description!), style: CoconutTypography.body3_12.setColor(colors.secondaryText)),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// 거래 상세·지갑 상세·검증 화면의 상태 상자(수수료 올리기 오류 상자 모양)
class SafetyStatusBanner extends StatelessWidget {
  const SafetyStatusBanner({
    super.key,
    required this.background,
    required this.iconPath,
    required this.iconColor,
    required this.title,
    required this.body,
    this.linkText,
    this.onLink,
  });

  final Color background;
  final String iconPath;
  final Color iconColor;
  final String title;
  final String body;
  final String? linkText;
  final VoidCallback? onLink;

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final hasLink = linkText != null && onLink != null;
    return Container(
      width: double.infinity,
      // 링크는 자체 여백 4가 있어서 아래 여백을 줄인다
      // 링크는 누르는 높이 44를 위해 위아래 14를 품는다(R7). 그만큼 바깥 아래 여백을 줄여 보이는 간격은 그대로
      padding: EdgeInsets.fromLTRB(16, 16, 16, hasLink ? 2 : 16),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(CoconutStyles.radius_200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SvgPicture.asset(
                iconPath,
                width: 20,
                height: 20,
                colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
              ),
              CoconutLayout.spacing_200w,
              Expanded(
                child: Text(safetyKoText(title), style: CoconutTypography.body2_14_Bold.setColor(colors.primaryText)),
              ),
            ],
          ),
          CoconutLayout.spacing_150h,
          Padding(
            padding: const EdgeInsets.only(left: 28),
            child: Text(safetyKoText(body), style: CoconutTypography.body3_12.setColor(colors.primaryText)),
          ),
          if (hasLink)
            Align(
              alignment: Alignment.centerRight,
              child: CoconutUnderlinedButton(
                text: linkText!,
                onTap: onLink!,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
                textStyle: CoconutTypography.body3_12_Bold,
                defaultColor: colors.primaryText,
              ),
            ),
        ],
      ),
    );
  }
}

/// hodl 인사이트 화면 섹션 제목과 같은 값
class SafetySectionTitle extends StatelessWidget {
  const SafetySectionTitle(this.text, {super.key, this.top = 32});

  final String text;
  final double top;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(4, top, 0, 12),
      child: Semantics(
        header: true,
        child: Text(
          safetyKoText(text),
          style: CoconutTypography.heading4_18_Bold.setColor(context.coconutColors.primaryText),
        ),
      ),
    );
  }
}
