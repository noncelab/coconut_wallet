import 'package:coconut_design_system/coconut_design_system.dart' show CoconutLayout, CoconutTypography;
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/home/home_widget_data.dart';
import 'package:coconut_wallet/providers/view_model/home/hodl_insights_view_model.dart';
import 'package:coconut_wallet/providers/wallet_appearance_provider.dart';
import 'package:coconut_wallet/model/home/home_widget_settings.dart';
import 'package:coconut_wallet/screens/home/widget_configure_sheet.dart';
import 'package:coconut_wallet/screens/home/wallet_balance_history_screen.dart' show walletBalanceHistoryFlight;
import 'package:coconut_wallet/ui/coconut/coconut_app_bar.dart';
import 'package:coconut_wallet/widgets/common/buttons/coconut_icon_button.dart';
import 'package:coconut_wallet/widgets/common/text/label_value_row.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/goal_amount_views.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/goal_plan_card.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/home_widget_parts.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/wallet_widget_views.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// 호들 인사이트에서 목표 수량 카드를 열 때 쓰는 기본 Hero 태그.
/// 인사이트를 홈 목표 위젯에서 열었으면 그 카드의 태그를 그대로 쓴다.
const goalAmountHeroTag = 'hodl-goal-amount';

/// 목표 수량: 범위 안 지갑들의 목표 진행을 자세히 본다.
/// 목표가 한 지갑에만 있으면 합산 카드만, 여러 지갑에 걸쳐 있으면 지갑별 목표도 보여 준다.
/// 범위는 늘 목표를 정한 지갑 전체(합산 기준)다. 모으기 계획은 목표 지갑이 하나여도 보여 준다.
class GoalAmountScreen extends StatefulWidget {
  static const routeName = '/goal-amount';

  final HodlInsightsViewModel viewModel;
  final Object heroTag;

  const GoalAmountScreen({super.key, required this.viewModel, this.heroTag = goalAmountHeroTag});

  /// 잔액 변화 화면과 같은 전환: 배경은 서서히 바뀌고 카드는 제자리에서 이어진다.
  static Future<void> open(
    BuildContext context,
    HodlInsightsViewModel viewModel, {
    Object heroTag = goalAmountHeroTag,
  }) => Navigator.of(context).push<void>(
    PageRouteBuilder<void>(
      settings: const RouteSettings(name: routeName),
      opaque: false,
      transitionDuration: const Duration(milliseconds: 450),
      reverseTransitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (_, __, ___) => GoalAmountScreen(viewModel: viewModel, heroTag: heroTag),
      transitionsBuilder:
          (_, animation, __, child) =>
              FadeTransition(opacity: animation.drive(CurveTween(curve: Curves.easeOutCubic)), child: child),
    ),
  );

  @override
  State<GoalAmountScreen> createState() => _GoalAmountScreenState();
}

class _GoalAmountScreenState extends State<GoalAmountScreen> {
  late final GoalPlanController _plan = GoalPlanController();

  @override
  void dispose() {
    _plan.dispose();
    super.dispose();
  }

  HodlInsightsViewModel get viewModel => widget.viewModel;

  String? _fiat(int sats) {
    final data = viewModel.data;
    final value = data.fiatValueOf(sats, data.fiat);
    return value == null ? null : formatHomeFiat(value, data.fiat);
  }

  Future<void> _openGoalSettings(BuildContext context) async {
    final settings = await WidgetConfigureSheet.openSettings(
      context,
      title: t.hodl_insights.goal_settings_title,
      heading: t.home_edit.wallet_goals,
      showIntro: false,
      spec: const HomeWidgetSettingsSpec(goals: true),
      wallets: viewModel.data.wallets,
      initial: const HomeWidgetSettings(),
    );
    if (settings != null && context.mounted) viewModel.data.refresh();
  }

  String _number(int sats) => viewModel.data.unit.displayBitcoinAmount(sats);
  String _text(int sats) => viewModel.data.unit.displayBitcoinAmount(sats, withUnit: true);

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    return ListenableBuilder(
      listenable: Listenable.merge([viewModel, _plan]),
      builder: (context, _) {
        // 범위는 늘 목표를 정한 지갑 전체(합산 기준). 같은 계정은 한 번, 목표가 다르면 큰 목표(결정 ⑦).
        // 지갑 하나씩은 아래 '지갑별 목표'가 지갑마다 따로 보여 준다.
        final sum = viewModel.goalSum;
        final targeted = GoalAmountSummary.targetedOf(viewModel.goalShares);
        final multiple = targeted.length > 1;
        final goal = sum.goal;
        return Scaffold(
          backgroundColor: colors.homeBackground,
          appBar: CoconutAppBar.build(
            context: context,
            backgroundColor: colors.homeBackground,
            title: t.hodl_insights.goal_amount,
            actionButtonList: [
              CoconutAppBarActionButton(
                key: const Key('goal-amount-edit'),
                onPressed: () => _openGoalSettings(context),
                icon: SvgPicture.asset(
                  CommonActionIconPath.editOutlinedSmall,
                  width: 24,
                  height: 24,
                  colorFilter: ColorFilter.mode(colors.iconPrimary, BlendMode.srcIn),
                ),
              ),
            ],
          ),
          body: SafeArea(
            top: false,
            child: ListView(
              key: const Key('goal-amount-list'),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
              children: [
                Hero(
                  tag: widget.heroTag,
                  flightShuttleBuilder: walletBalanceHistoryFlight,
                  child: Material(
                    key: const Key('goal-amount-card'),
                    color: colors.homeSurface,
                    borderRadius: BorderRadius.circular(20),
                    clipBehavior: Clip.antiAlias,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child:
                          goal == null
                              // 목표를 모두 해제했으면 인사이트의 빈 카드처럼 눌러서 목표를 다시 정한다.
                              ? GestureDetector(
                                key: const Key('goal-amount-empty'),
                                behavior: HitTestBehavior.opaque,
                                onTap: () => _openGoalSettings(context),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    HomeWidgetHeader(
                                      iconPath: FeatureWidgetIconPath.bullseyeArrow,
                                      title: t.hodl_insights.goal_amount,
                                      style: CoconutTypography.body1_16_Bold,
                                    ),
                                    CoconutLayout.spacing_300h,
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            t.hodl_insights.no_goal,
                                            style: CoconutTypography.body3_12.copyWith(
                                              color: colors.secondaryTextStrong,
                                            ),
                                          ),
                                        ),
                                        Icon(CupertinoIcons.chevron_right, size: 14, color: colors.tertiaryText),
                                      ],
                                    ),
                                  ],
                                ),
                              )
                              : GoalAmountSummary(
                                goal: goal,
                                shares: sum.accounts,
                                amountNumber: _number,
                                amountText: _text,
                                hasConflictingGoals: sum.hasConflictingGoals,
                                onTidyGoals: () => _openGoalSettings(context),
                                awaitingConfirmation: sum.awaitingConfirmation,
                                hasUnsettledAccounts: sum.hasUnsettledAccounts,
                                balancesDiffer: sum.hasDifferingBalances,
                              ),
                    ),
                  ),
                ),
                if (multiple) ...[
                  CoconutLayout.spacing_400h,
                  _WalletGoalList(shares: targeted, settled: sum.isSettled, amountNumber: _number, amountText: _text),
                ],
                if (goal != null) ...[
                  CoconutLayout.spacing_400h,
                  GoalPlanCard(
                    controller: _plan,
                    remainingSats: goal.target - goal.balance,
                    clock: () => viewModel.data.now,
                    amountText: _text,
                    fiatText: _fiat,
                    awaitingConfirmation: sum.awaitingConfirmation,
                    amountOnHold: sum.hasUnsettledAccounts,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

/// 목표를 정한 지갑마다 목표 진행과 부족분
class _WalletGoalList extends StatelessWidget {
  final List<HomeGoalShare> shares;

  /// 계정 잔액을 믿을 수 있는지(합계와 같은 규칙, [HomeGoalSum.isSettled]). 아니면 다 채운 지갑도 '확인 대기'(Fable N3)
  final bool Function(String accountKey) settled;

  final String Function(int sats) amountNumber;
  final String Function(int sats) amountText;

  const _WalletGoalList({
    required this.shares,
    required this.settled,
    required this.amountNumber,
    required this.amountText,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final appearances = context.watchWalletAppearance();
    return Container(
      key: const Key('goal-amount-by-wallet'),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      decoration: BoxDecoration(color: colors.homeSurface, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            t.hodl_insights.goal_by_wallet,
            style: CoconutTypography.body1_16_Bold.copyWith(color: colors.primaryText),
          ),
          CoconutLayout.spacing_200h,
          for (var i = 0; i < shares.length; i++) ...[
            if (i > 0) Divider(height: 1, thickness: 0.5, color: colors.border),
            _WalletGoalRow(
              share: shares[i],
              color: BalanceByWalletView.colorOf(context, shares[i].asBalanceShare, appearances: appearances),
              settled: settled,
              amountNumber: amountNumber,
              amountText: amountText,
            ),
          ],
        ],
      ),
    );
  }
}

class _WalletGoalRow extends StatelessWidget {
  final HomeGoalShare share;
  final Color color;
  final bool Function(String accountKey) settled;
  final String Function(int sats) amountNumber;
  final String Function(int sats) amountText;

  const _WalletGoalRow({
    required this.share,
    required this.color,
    required this.settled,
    required this.amountNumber,
    required this.amountText,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final nameStyle = CoconutTypography.body2_14.copyWith(color: colors.primaryText);
    // 목표를 정한 지갑만 넘어온다.
    final goal = share.goal!;
    // 수량과 단위는 떼지 않는다(좁으면 '남은 수량' 뒤에서 줄을 바꾼다)
    final remaining = amountText(goal.target - share.balance).replaceAll(' ', '\u00A0');
    return Padding(
      key: ValueKey('goal-amount-wallet-${share.walletId}'),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 색 점은 지갑 이름 첫 줄의 세로 가운데에 둔다(줄이 늘어도 이름 옆에 붙어 있게)
              SizedBox(
                height: LabelValueRow.lineHeightOf(context, nameStyle),
                child: Center(
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // 이름과 달성률이 한 줄에 안 들어가면 달성률을 다음 줄로(이름을 단어 중간에서 끊지 않는다)
              Expanded(
                child: LabelValueRow(
                  label: share.name,
                  labelStyle: nameStyle,
                  value: goal.percentText,
                  valueStyle: CoconutTypography.body2_14_NumberBold.copyWith(color: colors.primaryText),
                ),
              ),
            ],
          ),
          CoconutLayout.spacing_200h,
          GoalSegmentsBar(shares: [share], target: goal.target, height: 6),
          CoconutLayout.spacing_200h,
          // 이 지갑의 부족분(합산과 따로). 다 채운 지갑은 '목표 달성'
          LabelValueRow(
            label: '${amountNumber(share.balance)} / ${amountText(goal.target)}',
            labelStyle: CoconutTypography.body3_12_Number.copyWith(color: colors.secondaryTextStrong),
            value:
                share.balance < goal.target
                    ? '${t.hodl_insights.goal_remaining} $remaining'
                    // 합계와 같은 규칙: 계정 잔액을 믿을 수 있고 확인된 미사용 잔액으로 채웠을 때만 '목표 달성'
                    : settled(share.accountKey) && share.reachBalance >= goal.target
                    ? t.hodl_insights.goal_reached
                    : t.hodl_insights.goal_pending,
            valueKey: ValueKey('goal-amount-wallet-remaining-${share.walletId}'),
            valueStyle: CoconutTypography.body3_12_Bold.copyWith(color: colors.primaryText),
          ),
        ],
      ),
    );
  }
}
