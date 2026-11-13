import 'package:coconut_design_system/coconut_design_system.dart' show CoconutChip, CoconutLayout, CoconutTypography;
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
/// 목표가 한 지갑에만 있으면 합산 카드만, 여러 지갑에 걸쳐 있으면 그 지갑 칩과 지갑별 목표도 보여 준다.
/// 칩을 눌러 끈 지갑은 합산 카드와 모으기 계획에서 뺀다. 모으기 계획은 목표 지갑이 하나여도 보여 준다.
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
  /// 칩을 눌러 합산에서 뺀 지갑. 이 화면에 있는 동안만 유지한다.
  final Set<int> _excluded = {};

  late final GoalPlanController _plan = GoalPlanController();

  @override
  void dispose() {
    _plan.dispose();
    super.dispose();
  }

  HodlInsightsViewModel get viewModel => widget.viewModel;

  /// 칩을 눌러 지갑을 빼거나 다시 넣는다. 마지막 남은 지갑은 뺄 수 없다.
  void _toggleWallet(int walletId, List<HomeGoalShare> targeted) {
    setState(() {
      if (_excluded.remove(walletId)) return;
      final included = targeted.where((share) => !_excluded.contains(share.walletId)).length;
      if (included > 1) _excluded.add(walletId);
    });
  }

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
        final shares = viewModel.goalShares;
        // 목표가 여러 지갑에 걸쳐 있을 때만 그 지갑들을 칩과 지갑별 목표로 나눠 보여 준다.
        final targeted = GoalAmountSummary.targetedOf(shares);
        final multiple = targeted.length > 1;
        final kept = [
          for (final share in targeted)
            if (!multiple || !_excluded.contains(share.walletId)) share,
        ];
        // 목표를 고치다 남은 지갑이 모두 꺼진 상태가 되면 다시 모두 넣는다.
        final included = kept.isEmpty ? targeted : kept;
        final goal =
            included.isEmpty
                ? null
                : HomeSavingsGoal(
                  balance: included.fold(0, (sum, share) => sum + share.balance),
                  target: included.fold(0, (sum, share) => sum + share.target!),
                );
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
                if (multiple) ...[
                  _WalletChips(
                    shares: targeted,
                    excluded: _excluded,
                    onToggle: (walletId) => _toggleWallet(walletId, targeted),
                  ),
                  CoconutLayout.spacing_400h,
                ],
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
                                shares: included,
                                amountNumber: _number,
                                amountText: _text,
                              ),
                    ),
                  ),
                ),
                if (multiple) ...[
                  CoconutLayout.spacing_400h,
                  _WalletGoalList(shares: targeted, excluded: _excluded, amountNumber: _number, amountText: _text),
                ],
                if (goal != null) ...[
                  CoconutLayout.spacing_400h,
                  GoalPlanCard(
                    controller: _plan,
                    remainingSats: goal.target - goal.balance,
                    clock: () => viewModel.data.now,
                    amountText: _text,
                    fiatText: _fiat,
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

/// 목표를 정한 지갑만 칩으로 보여 준다. 누르면 합산에서 빼거나 다시 넣는다.
class _WalletChips extends StatelessWidget {
  final List<HomeGoalShare> shares;
  final Set<int> excluded;
  final ValueChanged<int> onToggle;

  const _WalletChips({required this.shares, required this.excluded, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final appearances = context.watchWalletAppearance();
    return Wrap(
      key: const Key('goal-amount-wallet-chips'),
      spacing: 8,
      runSpacing: 0,
      children: [
        for (final share in shares)
          Builder(
            builder: (context) {
              final active = !excluded.contains(share.walletId);
              final walletColor = BalanceByWalletView.colorOf(context, share.asBalanceShare, appearances: appearances);
              // 칩 모양은 그대로. 누르는 곳만 최소 44×44로 넓힌다(짧은 이름도). 넓힌 곳은 화면 읽기에서 빼서
              // 칩 하나가 이름 있는 탭 대상으로 남는다. 칩을 누르면 칩이, 둘레를 누르면 바깥이 받아 한 번만 바뀐다.
              return GestureDetector(
                key: ValueKey('goal-amount-chip-hit-${share.walletId}'),
                behavior: HitTestBehavior.opaque,
                excludeFromSemantics: true,
                onTap: () => onToggle(share.walletId),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                  child: Center(
                    widthFactor: 1,
                    heightFactor: 1,
                    child: CoconutChip(
                      key: ValueKey('goal-amount-chip-${share.walletId}'),
                      color: colors.homeSurface,
                      borderColor: active ? walletColor : colors.border,
                      labelColor: active ? colors.primaryText : colors.tertiaryText,
                      label: share.name,
                      labelSize: 13,
                      isSelected: active,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      onTap: () => onToggle(share.walletId),
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

/// 목표를 정한 지갑마다 목표 진행
class _WalletGoalList extends StatelessWidget {
  final List<HomeGoalShare> shares;

  /// 칩에서 끈 지갑. 흐리게 보여 준다.
  final Set<int> excluded;
  final String Function(int sats) amountNumber;
  final String Function(int sats) amountText;

  const _WalletGoalList({
    required this.shares,
    required this.excluded,
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
            AnimatedOpacity(
              opacity: excluded.contains(shares[i].walletId) ? 0.35 : 1,
              duration: const Duration(milliseconds: 200),
              child: _WalletGoalRow(
                share: shares[i],
                color: BalanceByWalletView.colorOf(context, shares[i].asBalanceShare, appearances: appearances),
                amountNumber: amountNumber,
                amountText: amountText,
              ),
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
  final String Function(int sats) amountNumber;
  final String Function(int sats) amountText;

  const _WalletGoalRow({
    required this.share,
    required this.color,
    required this.amountNumber,
    required this.amountText,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final nameStyle = CoconutTypography.body2_14.copyWith(color: colors.primaryText);
    // 목표를 정한 지갑만 넘어온다.
    final goal = share.goal!;
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
          Text(
            '${amountNumber(share.balance)} / ${amountText(goal.target)}',
            style: CoconutTypography.body3_12_Number.copyWith(color: colors.secondaryTextStrong),
          ),
        ],
      ),
    );
  }
}
