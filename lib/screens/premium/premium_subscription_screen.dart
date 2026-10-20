import 'package:coconut_design_system/coconut_design_system.dart' hide CoconutAppBar, CoconutToast, CoconutToastLevel;
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/screens/premium/premium_paywall_screen.dart';
import 'package:coconut_wallet/services/premium/entitlement_service.dart';
import 'package:coconut_wallet/ui/coconut/coconut_app_bar.dart';
import 'package:coconut_wallet/ui/coconut/coconut_overlays.dart' show CoconutToast, CoconutToastLevel;
import 'package:coconut_wallet/utils/custom_wallet_icons.dart';
import 'package:coconut_wallet/utils/vibration_util.dart';
import 'package:coconut_wallet/widgets/common/buttons/button_group.dart';
import 'package:coconut_wallet/widgets/common/buttons/fixed_bottom_button.dart';
import 'package:coconut_wallet/widgets/common/buttons/single_button.dart';
import 'package:coconut_wallet/widgets/common/overlays/custom_loading_overlay.dart';
import 'package:coconut_wallet/widgets/features/safety/safety_common_widgets.dart';
import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

/// 앱 설정 > Coconut Premium. 상태·구매 복원·스토어 구독 관리
class PremiumSubscriptionScreen extends StatelessWidget {
  const PremiumSubscriptionScreen({super.key});

  /// 스토어 구독 관리를 못 열면 알린다(해지하려는 사용자가 아무 반응 없이 멈추지 않게)
  static Future<void> _openManage(BuildContext context, EntitlementService premium) async {
    try {
      await premium.openManageSubscriptions();
    } catch (_) {
      if (!context.mounted) return;
      vibrateLightDouble();
      CoconutToast.showToast(
        context: context,
        text: t.premium.toast.manage_failed,
        isVisibleIcon: true,
        iconPath: CommonStateIconPath.triangleWarning,
        level: CoconutToastLevel.warning,
      );
    }
  }

  static Future<void> open(BuildContext context) => Navigator.of(context).push(
    CupertinoPageRoute<void>(
      settings: const RouteSettings(name: '/premium/manage'),
      builder: (_) => const CustomLoadingOverlay(child: PremiumSubscriptionScreen()),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final premium = context.read<EntitlementService>();
    final store = defaultTargetPlatform == TargetPlatform.android ? 'Google Play' : 'App Store';
    return Scaffold(
      key: const Key('premium-subscription'),
      backgroundColor: colors.background,
      appBar: CoconutAppBar.build(context: context, title: t.premium.name, backgroundColor: colors.background),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ValueListenableBuilder<PremiumState>(
              valueListenable: premium.state,
              builder:
                  (context, state, _) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _StatusCard(state: state),
                      // 만료돼도 이미 만든 지갑·초안은 그대로 쓴다(SPEC v2)
                      if (state.status == PremiumStatus.expired) ...[
                        CoconutLayout.spacing_300h,
                        Text(
                          t.premium.subscription.expired_note,
                          style: CoconutTypography.body3_12.setColor(colors.secondaryText),
                        ),
                      ],
                    ],
                  ),
            ),
            CoconutLayout.spacing_500h,
            ButtonGroup(
              buttons: [
                SingleButton(
                  key: const Key('premium-subscription-restore'),
                  enableShrinkAnim: true,
                  animationEndValue: 0.97,
                  title: t.premium.paywall.restore,
                  onPressed: () => restorePremiumPurchases(context, premium),
                ),
                SingleButton(
                  key: const Key('premium-subscription-manage'),
                  enableShrinkAnim: true,
                  animationEndValue: 0.97,
                  title: t.premium.subscription.manage(store: store),
                  rightElement: SvgPicture.asset(
                    CommonActionIconPath.export,
                    width: 16,
                    height: 16,
                    colorFilter: ColorFilter.mode(colors.iconSecondary, BlendMode.srcIn),
                  ),
                  onPressed: () => _openManage(context, premium),
                ),
              ],
            ),
            CoconutLayout.spacing_400h,
            Text(
              t.premium.subscription.manage_note,
              style: CoconutTypography.caption_10.setColor(colors.secondaryText),
            ),
          ],
        ),
      ),
    );
  }
}

/// 앱 설정 줄의 상태 값(사용 중 / 사용 안 함). 확인 중이면 null
String? premiumStatusLabel(PremiumState state) => switch (state.status) {
  PremiumStatus.active => t.premium.subscription.active,
  PremiumStatus.verifying => null,
  _ => t.premium.subscription.not_subscribed,
};

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.state});

  final PremiumState state;

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final subscription = t.premium.subscription;
    final title = CoconutTypography.body1_16_Bold.setColor(colors.primaryText);
    final detail = CoconutTypography.body3_12.setColor(colors.secondaryText);
    final expiresAt = state.expiresAt;
    final plan = switch (state.period) {
      PremiumPeriod.yearly => subscription.yearly_plan,
      PremiumPeriod.monthly => subscription.monthly_plan,
      null => null,
    };
    Widget plans(String text) => InlineActionButton(
      key: const Key('premium-subscription-see-plans'),
      text: text,
      onPressed: () => PremiumPaywallScreen.open(context),
    );
    final children = switch (state.status) {
      // 갱신일은 쓰지 않는다: 자동 갱신을 껐는지 기기에서 알 수 없다
      PremiumStatus.active => [
        Row(
          children: [
            SvgPicture.asset(
              CustomWalletIcons.diamond,
              width: 20,
              height: 20,
              colorFilter: ColorFilter.mode(colors.premiumText, BlendMode.srcIn),
            ),
            CoconutLayout.spacing_200w,
            Expanded(child: Text(subscription.active_title, style: title)),
          ],
        ),
        if (plan != null) ...[CoconutLayout.spacing_200h, Text(plan, style: detail)],
      ],
      PremiumStatus.expired => [
        Text(subscription.expired_title, style: title),
        if (expiresAt != null) ...[
          CoconutLayout.spacing_200h,
          Text(subscription.expired_on(date: DateFormat('yyyy.MM.dd').format(expiresAt)), style: detail),
        ],
        CoconutLayout.spacing_400h,
        plans(subscription.resubscribe),
      ],
      PremiumStatus.none => [
        Text(subscription.none_title, style: title),
        CoconutLayout.spacing_400h,
        plans(t.premium.card.explore),
      ],
      PremiumStatus.pending => [Text(t.premium.purchased.pending_title, style: title)],
      PremiumStatus.verifying => [
        Shimmer.fromColors(
          enabled: !safetyReduceMotion(context),
          baseColor: colors.surfaceSkeletonBase,
          highlightColor: colors.surfaceSkeletonHighlight,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(
              width: 160,
              height: 20,
              decoration: BoxDecoration(color: colors.surfaceSkeletonBase, borderRadius: BorderRadius.circular(4)),
            ),
          ),
        ),
      ],
    };
    return Container(
      key: Key('premium-status-${state.status.name}'),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: state.isActive ? null : colors.surface,
        gradient: state.isActive ? colors.premiumSurfaceGradient : null,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    );
  }
}
