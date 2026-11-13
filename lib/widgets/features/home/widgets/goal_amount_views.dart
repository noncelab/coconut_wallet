import 'package:coconut_design_system/coconut_design_system.dart' show CoconutLayout, CoconutTypography;
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/home/home_widget_data.dart';
import 'package:coconut_wallet/providers/wallet_appearance_provider.dart';
import 'package:coconut_wallet/widgets/common/text/keep_words.dart';
import 'package:coconut_wallet/widgets/common/info/inline_notice.dart';
import 'package:coconut_wallet/widgets/common/text/label_value_row.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/home_widget_parts.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/wallet_widget_views.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

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
            // 채운 폭이 좁으면 간격도 그만큼 줄인다. 간격 합이 채운 폭을 넘으면 넘침이 난다.
            final gapCount = singleColor != null ? 0 : (filled.length - 1).clamp(0, filled.length);
            final gap = gapCount == 0 ? 0.0 : (fillWidth / gapCount).clamp(0.0, segmentGap);
            final usable = (fillWidth - gap * gapCount).clamp(0.0, double.infinity);
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
                            if (i > 0) SizedBox(width: gap),
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

  /// 같은 계정에 서로 다른 목표가 있어 큰 목표로 계산했으면 true. 합계 바로 아래에 이유 한 줄을 둔다.
  final bool hasConflictingGoals;

  /// [목표 정리]를 누르면(목표 설정 시트). 없으면 버튼 없이 한 줄만
  final VoidCallback? onTidyGoals;

  /// 진행률은 목표에 닿았지만 아직 달성이 아니면 true. 남은 수량 줄이 '목표 달성' 대신 '확인 대기'
  final bool awaitingConfirmation;

  /// 같은 계정 지갑끼리 잔액이 다르거나 아직 동기화 중이라 확인 대기면 true. 이유 한 줄을 둔다(B1-a)
  final bool hasUnsettledAccounts;

  /// [hasUnsettledAccounts]의 이유가 실제로 다른 잔액이면 true(작은 잔액으로 보여 준다), 같은데 동기화 중이면 false
  /// (잔액을 확인하는 중이라고만 말한다, Fable C2)
  final bool balancesDiffer;

  const GoalAmountSummary({
    super.key,
    required this.goal,
    required this.shares,
    required this.amountNumber,
    required this.amountText,
    this.reveal = 1,
    this.hasConflictingGoals = false,
    this.onTidyGoals,
    this.awaitingConfirmation = false,
    this.hasUnsettledAccounts = false,
    this.balancesDiffer = false,
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
    final animatedBalance = (goal.balance * reveal).round();
    final remaining = goal.target - goal.balance;
    final appearances = context.watchWalletAppearance();
    final secondaryStyle = CoconutTypography.body3_12.copyWith(color: colors.secondaryTextStrong);
    return Column(
      key: const Key('hodl-insights-goal'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 제목과 범위(지갑 이름·'지갑 N개 합산')가 한 줄에 들어가면 양 끝에, 아니면 범위를 제목 아래 줄로 내린다.
        // 큰 글자·긴 언어에서 둘 다 '…'로 잘리지 않게 한다.
        LayoutBuilder(
          builder: (context, constraints) {
            final scope = scopeLabelOf(targeted);
            // HomeWidgetHeader: 아이콘 16 + 간격 6 + 제목(줄 높이 1)
            final titleStyle = CoconutTypography.body1_16_Bold.copyWith(height: 1);
            final headerWidth = 16 + 6 + LabelValueRow.widthOf(context, t.hodl_insights.goal_amount, titleStyle) + 1;
            // 제목만으로도 한 줄을 넘으면(큰 글자·긴 언어) 홈 위젯 머리(한 줄·'…') 대신 제목이 다음 줄로 이어지는 머리를 쓴다.
            final Widget header =
                headerWidth <= constraints.maxWidth
                    ? HomeWidgetHeader(
                      iconPath: FeatureWidgetIconPath.bullseyeArrow,
                      title: t.hodl_insights.goal_amount,
                      style: CoconutTypography.body1_16_Bold,
                    )
                    : _WrappingHeader(title: t.hodl_insights.goal_amount, style: titleStyle);
            if (headerWidth + 8 + LabelValueRow.widthOf(context, scope, secondaryStyle) <= constraints.maxWidth) {
              return Row(
                children: [
                  SizedBox(width: headerWidth, child: header),
                  CoconutLayout.spacing_200w,
                  Expanded(
                    child: Text(
                      scope,
                      key: const Key('goal-scope-label'),
                      textAlign: TextAlign.end,
                      maxLines: 1,
                      style: secondaryStyle,
                    ),
                  ),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                header,
                CoconutLayout.spacing_100h,
                Text(scope, key: const Key('goal-scope-label'), style: secondaryStyle),
              ],
            );
          },
        ),
        CoconutLayout.spacing_200h,
        // 진행 먼저: 모은 수량 / 목표 → 달성률 → 막대 → 남은 수량. 홈 목표 위젯·지갑별 목표 줄과 같은 순서다.
        _ProgressLine(
          balance: amountNumber(animatedBalance),
          // 배치는 최종 수량·최종 달성률로 정한다(차오르는 동안 줄이 바뀌지 않게).
          layoutBalance: amountNumber(goal.balance),
          target: amountText(goal.target),
          percent: formatGoalPercentOf(animatedBalance, goal.target),
          layoutPercent: formatGoalPercentOf(goal.balance, goal.target),
        ),
        // 같은 계정에 서로 다른 목표가 있으면 합계 바로 아래에 계산 기준과 정리 버튼(결정 ⑦)
        if (hasConflictingGoals) ...[
          CoconutLayout.spacing_200h,
          InlineNotice(
            key: const Key('goal-amount-conflict'),
            icon: CupertinoIcons.info_circle,
            message: t.hodl_insights.goal_conflict_larger,
            actionLabel: onTidyGoals == null ? null : t.hodl_insights.goal_conflict_tidy,
            actionKey: const Key('goal-amount-conflict-tidy'),
            onAction: onTidyGoals,
          ),
        ],
        CoconutLayout.spacing_300h,
        GoalSegmentsBar(
          shares: targeted,
          target: goal.target,
          reveal: reveal,
          singleColor: multiple ? null : colors.success,
        ),
        if (multiple) ...[
          CoconutLayout.spacing_200h,
          // 막대 조각이 어느 지갑인지만 알려 준다. 지갑별 진행은 아래 '지갑별 목표'가 맡는다.
          Wrap(
            key: const Key('goal-legend'),
            spacing: 12,
            runSpacing: 4,
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
                    Flexible(
                      child: Text(share.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: secondaryStyle),
                    ),
                  ],
                ),
            ],
          ),
        ],
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Divider(height: 1, thickness: 0.5, color: colors.border),
        ),
        _RemainingLine(remaining: remaining, pending: awaitingConfirmation, amountText: amountText),
        if (hasUnsettledAccounts) ...[
          CoconutLayout.spacing_200h,
          InlineNotice(
            key: const Key('goal-amount-unsettled'),
            icon: CupertinoIcons.clock,
            message: balancesDiffer ? t.hodl_insights.goal_unsettled_smaller : t.hodl_insights.goal_unsettled_syncing,
          ),
        ],
      ],
    );
  }
}

/// '0.0135 / 0.03 BTC        45.0%'. 한 줄에 안 들어가면 모은 수량을 첫 줄에, '/ 목표'와 달성률을 둘째 줄에 둔다.
/// 배치는 최종 수량·최종 달성률(초과 달성이면 100%보다 넓다)로 잰다. 차오르는 동안의 수량은 끝자리가 길어
/// 최종보다 넓을 수 있어서(0.455 → 0.1234 5678), 한 줄일 때는 최종 폭 안에서 줄여 보인다.
class _ProgressLine extends StatelessWidget {
  final String balance;
  final String layoutBalance;
  final String target;
  final String percent;
  final String layoutPercent;

  const _ProgressLine({
    required this.balance,
    required this.layoutBalance,
    required this.target,
    required this.percent,
    required this.layoutPercent,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    const tabular = [FontFeature.tabularFigures()];
    final balanceStyle = CoconutTypography.heading3_21_NumberBold.copyWith(
      color: colors.primaryText,
      fontFeatures: tabular,
    );
    final targetStyle = CoconutTypography.body2_14_Number.copyWith(
      color: colors.secondaryTextStrong,
      fontFeatures: tabular,
    );
    final percentStyle = CoconutTypography.body2_14_NumberBold.copyWith(
      color: colors.primaryText,
      fontFeatures: tabular,
    );
    final targetLabel = '/ $target';
    final balanceText = Text(balance, key: const Key('goal-progress-amount'), maxLines: 1, style: balanceStyle);
    final targetText = Text(targetLabel, key: const Key('goal-target-amount'), maxLines: 1, style: targetStyle);
    final percentText = Text(percent, key: const Key('goal-progress-percent'), maxLines: 1, style: percentStyle);
    return LayoutBuilder(
      builder: (context, constraints) {
        final balanceWidth = LabelValueRow.widthOf(context, layoutBalance, balanceStyle);
        // 줄여 보일 때도 줄 높이는 그대로 둔다(카드 높이가 차오르는 동안 흔들리면 아래 구역이 움직인다).
        final balanceHeight = LabelValueRow.lineHeightOf(context, balanceStyle);
        final percentWidth = LabelValueRow.widthOf(context, layoutPercent, percentStyle);
        final oneLine =
            balanceWidth + 6 + LabelValueRow.widthOf(context, targetLabel, targetStyle) + 12 + percentWidth <=
            constraints.maxWidth;
        if (oneLine) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              SizedBox(
                width: balanceWidth + 1,
                height: balanceHeight,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: balanceText,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(child: targetText),
              const SizedBox(width: 12),
              percentText,
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: balanceHeight,
              child: FittedBox(fit: BoxFit.scaleDown, alignment: AlignmentDirectional.centerStart, child: balanceText),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: targetText,
                  ),
                ),
                const SizedBox(width: 12),
                percentText,
              ],
            ),
          ],
        );
      },
    );
  }
}

/// 홈 위젯 머리와 같은 모양(아이콘 16 + 간격 6 + 굵은 제목)이지만 제목이 길면 다음 줄로 이어진다. 아이콘은 첫 줄에 맞춘다.
class _WrappingHeader extends StatelessWidget {
  final String title;
  final TextStyle style;

  const _WrappingHeader({required this.title, required this.style});

  @override
  Widget build(BuildContext context) {
    final color = context.coconutColors.primaryText;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: LabelValueRow.lineHeightOf(context, style),
          child: Center(
            child: SvgPicture.asset(
              FeatureWidgetIconPath.bullseyeArrow,
              width: 16,
              height: 16,
              colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(child: Text(keepWords(title), semanticsLabel: title, style: style.copyWith(color: color))),
      ],
    );
  }
}

/// '남은 수량' 줄. 다 채우면 그 자리에 지갑 상세 목표 카드와 같은 문장 한 줄을 둔다.
/// 넘었으면 '목표보다 0.002 BTC 더 모았어요', 딱 맞으면 '축하해요! 목표를 달성했어요'.
class _RemainingLine extends StatelessWidget {
  final int remaining;

  /// 다 채웠지만 아직 달성이 아니면(1차 7판 확인 대기) 문장 대신 '확인 대기'
  final bool pending;
  final String Function(int sats) amountText;

  const _RemainingLine({required this.remaining, required this.pending, required this.amountText});

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final secondaryStyle = CoconutTypography.body3_12.copyWith(color: colors.secondaryTextStrong);
    if (remaining > 0 || pending) {
      return LabelValueRow(
        label: t.hodl_insights.goal_remaining,
        labelStyle: secondaryStyle,
        value: remaining > 0 ? amountText(remaining) : t.hodl_insights.goal_pending,
        valueKey: const Key('goal-remaining-amount'),
        valueStyle: (remaining > 0 ? CoconutTypography.body2_14_NumberBold : CoconutTypography.body2_14_Bold).copyWith(
          color: colors.primaryText,
        ),
      );
    }
    if (remaining == 0) {
      final title = t.wallet_info_screen.target_exceeded_title;
      return Text(
        keepWords(title),
        key: const Key('goal-reached'),
        semanticsLabel: title,
        style: CoconutTypography.body2_14_Bold.copyWith(color: colors.primaryText),
      );
    }
    final excess = amountText(-remaining);
    final message = t.wallet_info_screen.target_exceeded_secondary(amount: excess);
    final at = message.indexOf(excess);
    // 줄바꿈 막기는 보이는 글에만 하고, 화면 읽기에는 원문 문장을 넘긴다.
    return Text.rich(
      key: const Key('goal-reached'),
      semanticsLabel: message,
      TextSpan(
        style: secondaryStyle,
        children: [
          TextSpan(text: keepWords(message.substring(0, at))),
          TextSpan(text: excess, style: CoconutTypography.body2_14_NumberBold.copyWith(color: colors.primaryText)),
          TextSpan(text: keepWords(message.substring(at + excess.length))),
        ],
      ),
    );
  }
}
