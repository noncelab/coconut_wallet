import 'package:coconut_design_system/coconut_design_system.dart' show CoconutLayout, CoconutTypography;
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/home/home_widget_data.dart';
import 'package:coconut_wallet/providers/wallet_appearance_provider.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/home_widget_parts.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/wallet_widget_views.dart';
import 'package:flutter/material.dart';

/// 목표 수량 막대: 목표가 있는 지갑마다 잔액만큼 지갑 색으로 채우고, 조각 사이를 조금 띄운다.
/// 지갑 색이 같아도 조각을 구분할 수 있다.
class GoalSegmentsBar extends StatelessWidget {
  static const segmentGap = 2.0;

  /// 목표가 있는 지갑들
  final List<HomeGoalShare> shares;
  final int target;

  /// 차오른 정도(0~1). 화면을 열 때 막대가 차오르게 한다.
  final double reveal;
  final double height;

  /// 지정하면 지갑별로 나누지 않고 이 색 하나로 채운다(모든 지갑 합산).
  final Color? singleColor;

  const GoalSegmentsBar({
    super.key,
    required this.shares,
    required this.target,
    this.reveal = 1,
    this.height = 10,
    this.singleColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final appearances = context.watchWalletAppearance();
    final filled = [
      for (final share in shares)
        if (share.balance > 0) share,
    ];
    final balance = filled.fold<int>(0, (sum, share) => sum + share.balance);
    // 초과 달성이면 잔액 합을 막대 전체로 본다.
    final whole = balance > target ? balance : target;
    final fill = whole <= 0 ? 0.0 : (balance / whole * reveal).clamp(0.0, 1.0);
    // 부모가 폭을 느슨하게 줘도(Column start 정렬) 막대는 항상 가로를 꽉 채운다.
    return SizedBox(
      width: double.infinity,
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(height / 2),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final fillWidth = constraints.maxWidth * fill;
            final gaps = singleColor != null ? 0.0 : segmentGap * (filled.length - 1).clamp(0, filled.length);
            final usable = (fillWidth - gaps).clamp(0.0, double.infinity);
            return Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(color: colors.surfaceMuted),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: SizedBox(
                    key: const Key('goal-progress-fill'),
                    width: fillWidth,
                    height: height,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (singleColor != null)
                          Expanded(key: const ValueKey('goal-segment-combined'), child: ColoredBox(color: singleColor!))
                        else
                          for (var i = 0; i < filled.length; i++) ...[
                            if (i > 0) const SizedBox(width: segmentGap),
                            SizedBox(
                              key: ValueKey('goal-segment-${filled[i].walletId}'),
                              width: balance <= 0 ? 0 : usable * filled[i].balance / balance,
                              child: ColoredBox(
                                color: BalanceByWalletView.colorOf(
                                  context,
                                  filled[i].asBalanceShare,
                                  appearances: appearances,
                                ),
                              ),
                            ),
                          ],
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class GoalAmountSummary extends StatelessWidget {
  final HomeSavingsGoal goal;

  /// 범위 안 지갑들. 목표가 없는 지갑은 막대와 범례에서 뺀다.
  final List<HomeGoalShare> shares;

  /// 화면을 열 때 차오르는 비율(0~1)
  final double reveal;
  final String Function(int sats) amountNumber;
  final String Function(int sats) amountText;

  const GoalAmountSummary({
    super.key,
    required this.goal,
    required this.shares,
    required this.amountNumber,
    required this.amountText,
    this.reveal = 1,
  });

  /// 목표 수량을 정한 지갑들
  static List<HomeGoalShare> targetedOf(List<HomeGoalShare> shares) => [
    for (final share in shares)
      if (share.hasTarget) share,
  ];

  /// 오른쪽 위 문구. 목표가 한 지갑에만 있으면 그 지갑 이름, 여러 지갑이면 '지갑 N개 합산'
  static String scopeLabelOf(List<HomeGoalShare> targeted) =>
      targeted.length == 1 ? targeted.single.name : t.hodl_insights.goal_wallet_count(count: targeted.length);

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final targeted = targetedOf(shares);
    // 목표가 여러 지갑에 걸쳐 있으면 지갑별 색으로 나누고, 한 지갑뿐이면 예전 목표 막대 색 하나로 채운다.
    final multiple = targeted.length > 1;
    final numberStyle = CoconutTypography.body2_14_Number.copyWith(
      color: colors.secondaryTextStrong,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final animatedBalance = (goal.balance * reveal).round();
    final remaining = goal.target - goal.balance;
    final appearances = context.watchWalletAppearance();
    return Column(
      key: const Key('hodl-insights-goal'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: HomeWidgetHeader(
                iconPath: FeatureWidgetIconPath.bullseyeArrow,
                title: t.hodl_insights.goal_amount,
                style: CoconutTypography.body1_16_Bold,
              ),
            ),
            CoconutLayout.spacing_200w,
            Expanded(
              child: Text(
                scopeLabelOf(targeted),
                key: const Key('goal-scope-label'),
                textAlign: TextAlign.end,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: CoconutTypography.body3_12.copyWith(color: colors.secondaryTextStrong),
              ),
            ),
          ],
        ),
        CoconutLayout.spacing_200h,
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            amountText(goal.target),
            key: const Key('goal-target-amount'),
            style: CoconutTypography.heading3_21_NumberBold.copyWith(color: colors.primaryText),
          ),
        ),
        CoconutLayout.spacing_400h,
        GoalSegmentsBar(
          shares: targeted,
          target: goal.target,
          reveal: reveal,
          singleColor: multiple ? null : colors.success,
        ),
        CoconutLayout.spacing_200h,
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(amountText(animatedBalance), key: const Key('goal-progress-amount'), style: numberStyle),
              ),
            ),
            CoconutLayout.spacing_300w,
            Text(
              formatGoalPercent(goal.ratio * reveal),
              key: const Key('goal-progress-percent'),
              style: CoconutTypography.body2_14_NumberBold.copyWith(
                color: colors.primaryText,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Divider(height: 1, thickness: 0.5, color: colors.border),
        ),
        Row(
          children: [
            Expanded(
              child: Text(
                t.hodl_insights.goal_remaining,
                style: CoconutTypography.body3_12.copyWith(color: colors.secondaryTextStrong),
              ),
            ),
            Text(
              remaining > 0 ? amountText(remaining) : t.hodl_insights.goal_reached,
              key: const Key('goal-remaining-amount'),
              // 다 채우면 한글 문구라 숫자 글꼴을 쓰지 않는다.
              style: (remaining > 0 ? CoconutTypography.body2_14_NumberBold : CoconutTypography.body2_14_Bold).copyWith(
                color: colors.primaryText,
              ),
            ),
          ],
        ),
        if (multiple) ...[
          CoconutLayout.spacing_300h,
          Wrap(
            key: const Key('goal-legend'),
            spacing: 12,
            runSpacing: 6,
            children: [
              for (final share in targeted)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: BalanceByWalletView.colorOf(context, share.asBalanceShare, appearances: appearances),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${share.name} ${formatGoalPercent(goal.balance <= 0 ? 0 : share.balance / goal.balance)}',
                      style: CoconutTypography.caption_10_Number.copyWith(color: colors.secondaryTextStrong),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ],
    );
  }
}
