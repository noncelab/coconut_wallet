import 'package:coconut_design_system/coconut_design_system.dart' hide CoconutUnderlinedButton;
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/ui/coconut/coconut_underlined_button.dart';
import 'package:coconut_wallet/utils/custom_wallet_icons.dart';
import 'package:coconut_wallet/utils/vibration_util.dart';
import 'package:coconut_wallet/widgets/common/buttons/shrink_animation_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// 동작 줄이기(앱 공통 기준)
bool safetyReduceMotion(BuildContext context) =>
    MediaQuery.disableAnimationsOf(context) || MediaQuery.accessibleNavigationOf(context);

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
                  Text(title, style: CoconutTypography.body2_14_Bold.setColor(colors.primaryText)),
                  if (subtitle != null) ...[
                    CoconutLayout.spacing_50h,
                    Text(subtitle!, style: CoconutTypography.body3_12.setColor(subtitleColor ?? colors.secondaryText)),
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

class PremiumChip extends StatelessWidget {
  const PremiumChip({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Sizes.size8, vertical: 3),
      decoration: BoxDecoration(
        gradient: colors.premiumSurfaceGradient,
        borderRadius: BorderRadius.circular(CoconutStyles.radius_300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(
            CustomWalletIcons.diamond,
            width: 10,
            height: 10,
            colorFilter: ColorFilter.mode(colors.premiumText, BlendMode.srcIn),
          ),
          CoconutLayout.spacing_50w,
          Text(t.premium.badge, style: CoconutTypography.caption_10_Bold.setColor(colors.premiumText)),
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
                Text(title, style: titleStyle.setColor(colors.primaryText)),
                if (description != null) ...[
                  CoconutLayout.spacing_50h,
                  Text(description!, style: CoconutTypography.body3_12.setColor(colors.secondaryText)),
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
      padding: EdgeInsets.fromLTRB(16, 16, 16, hasLink ? 12 : 16),
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
              Expanded(child: Text(title, style: CoconutTypography.body2_14_Bold.setColor(colors.primaryText))),
            ],
          ),
          CoconutLayout.spacing_150h,
          Padding(
            padding: const EdgeInsets.only(left: 28),
            child: Text(body, style: CoconutTypography.body3_12.setColor(colors.primaryText)),
          ),
          if (hasLink) ...[
            CoconutLayout.spacing_200h,
            Align(
              alignment: Alignment.centerRight,
              child: CoconutUnderlinedButton(
                text: linkText!,
                onTap: onLink!,
                textStyle: CoconutTypography.body3_12_Bold,
                defaultColor: colors.primaryText,
              ),
            ),
          ],
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
        child: Text(text, style: CoconutTypography.heading4_18_Bold.setColor(context.coconutColors.primaryText)),
      ),
    );
  }
}
