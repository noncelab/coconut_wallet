import 'package:coconut_design_system/coconut_design_system.dart' show CoconutChip, CoconutLayout, CoconutTypography;
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/home/home_widget_data.dart';
import 'package:coconut_wallet/providers/view_model/home/hodl_insights_view_model.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/price_provider.dart';
import 'package:coconut_wallet/providers/view_model/home/home_widgets_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:provider/provider.dart';
import 'package:coconut_wallet/providers/wallet_appearance_provider.dart';
import 'package:coconut_wallet/model/home/home_widget_settings.dart';
import 'package:coconut_wallet/screens/home/hodl_insights_screen.dart';
import 'package:coconut_wallet/screens/home/widget_configure_sheet.dart';
import 'package:coconut_wallet/screens/home/wallet_balance_history_screen.dart' show walletBalanceHistoryFlight;
import 'package:coconut_wallet/ui/coconut/coconut_app_bar.dart';
import 'package:coconut_wallet/widgets/common/buttons/coconut_icon_button.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/goal_amount_views.dart';
import 'package:coconut_wallet/services/goal_reminder/goal_reminder.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/goal_plan_card.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/goal_reminder_card.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/home_widget_parts.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/wallet_widget_views.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons, CupertinoPageRoute;
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

  /// 지금 열려 있는 목표 수량 화면의 route. 알림을 눌렀을 때 같은 화면을 또 쌓지 않으려고 기억한다.
  static final List<Route<dynamic>> _openRoutes = [];

  /// 모으기 알림을 눌러 들어올 때. 홈 위젯 데이터 없이 인사이트에서 저장한 지갑 선택으로 연다.
  static Future<void> openFromReminder(NavigatorState navigator, BuildContext context) {
    final nodeProvider = context.read<NodeProvider>();
    return pushFromReminder(
      navigator,
      () => HodlInsightsViewModel(
        HomeWidgetsViewModel(
          walletProvider: context.read<WalletProvider>(),
          preferenceProvider: context.read<PreferenceProvider>(),
          priceProvider: context.read<PriceProvider>(),
          targetSatsOf: SharedPrefsRepository().getWalletTargetSats,
          walletUpdates: Listenable.merge([nodeProvider, nodeProvider.currentBlockNotifier]),
          usesFakeBalance: false,
        ),
        initialSection: HodlInsightsSection.goal,
        selectionRepository: SharedPrefsRepository(),
      ),
    );
  }

  /// 지금 화면 위에 호들 인사이트 → 목표 수량을 쌓는다. 뒤로가기를 누르면 인사이트(목표 카드)로,
  /// 한 번 더 누르면 알림을 누르기 전 화면으로 돌아간다. 보던 화면을 닫지 않으므로 입력 중이던 내용도 남는다.
  /// 목표 수량 화면이 이미 열려 있으면 새로 쌓지 않고, 그 위에 열린 시트·팝업만 닫아 그 화면으로 돌아간다.
  static Future<void> pushFromReminder(NavigatorState navigator, HodlInsightsViewModel Function() createViewModel) {
    final open = _openRoutes.where((route) => route.isActive && route.navigator == navigator).lastOrNull;
    if (open != null) {
      navigator.popUntil((route) => route == open);
      return Future<void>.value();
    }
    final viewModel = createViewModel();
    navigator.push<void>(
      CupertinoPageRoute(
        settings: const RouteSettings(name: HodlInsightsScreen.routeName),
        builder:
            (_) => ChangeNotifierProvider<HodlInsightsViewModel>(
              // 목표 수량 화면도 이 모델을 쓰므로 인사이트 화면이 닫힐 때 함께 정리한다.
              create: (_) => viewModel,
              lazy: false,
              child: const HodlInsightsScreen(),
            ),
      ),
    );
    return navigator.push<void>(
      CupertinoPageRoute(
        settings: const RouteSettings(name: routeName),
        builder: (_) => GoalAmountScreen(viewModel: viewModel),
      ),
    );
  }

  @override
  State<GoalAmountScreen> createState() => _GoalAmountScreenState();
}

class _GoalAmountScreenState extends State<GoalAmountScreen> with WidgetsBindingObserver {
  Route<dynamic>? _route;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (identical(route, _route)) return;
    if (_route != null) GoalAmountScreen._openRoutes.remove(_route);
    _route = route;
    if (route != null) GoalAmountScreen._openRoutes.add(route);
  }

  /// 칩을 눌러 합산에서 뺀 지갑. 이 화면에 있는 동안만 유지한다.
  final Set<int> _excluded = {};

  /// 모으기 계획과 모으기 알림. 알림은 계획의 주기와 이번에 모을 수량을 따른다.
  late final GoalPlanController _plan = GoalPlanController(today: viewModel.data.now);
  late final GoalReminderController _reminder = GoalReminderController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _reminder.refreshPermission();
  }

  /// 기기 설정에서 알림을 바꾸고 돌아오면 권한을 다시 확인한다.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _reminder.refreshPermission();
  }

  @override
  void dispose() {
    if (_route != null) GoalAmountScreen._openRoutes.remove(_route);
    WidgetsBinding.instance.removeObserver(this);
    _plan.dispose();
    _reminder.dispose();
    super.dispose();
  }

  /// 그린 뒤에 예약을 지금 계획·설정에 맞춘다. 내용이 같으면 다시 예약하지 않는다.
  void _syncReminder(int? amountSats) {
    final settings = _reminder.settings;
    final content = GoalReminderContent.of(
      _plan.cycle,
      amount: settings.showAmount && amountSats != null ? _text(amountSats) : null,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _reminder.sync(_plan.cycle, content);
    });
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
      listenable: Listenable.merge([viewModel, _plan, _reminder]),
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
        // 모으기 계획이 있을 때만(목표가 있고 아직 못 채움) 이번에 모을 수량이 있다.
        final remaining = goal == null ? 0 : goal.target - goal.balance;
        final amountSats = remaining > 0 ? _plan.perInstallment(remaining) : null;
        _syncReminder(amountSats);
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
                    today: viewModel.data.now,
                    amountText: _text,
                    fiatText: _fiat,
                  ),
                ],
                CoconutLayout.spacing_400h,
                GoalReminderCard(
                  reminder: _reminder,
                  plan: _plan,
                  amountSats: amountSats,
                  amountUnavailableReason:
                      goal == null
                          ? t.hodl_insights.goal_reminder_amount_disabled_no_goal
                          : t.hodl_insights.goal_reminder_amount_disabled_reached,
                  amountText: _text,
                ),
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
      runSpacing: 8,
      children: [
        for (final share in shares)
          Builder(
            builder: (context) {
              final active = !excluded.contains(share.walletId);
              final walletColor = BalanceByWalletView.colorOf(context, share.asBalanceShare, appearances: appearances);
              return CoconutChip(
                key: ValueKey('goal-amount-chip-${share.walletId}'),
                color: colors.homeSurface,
                borderColor: active ? walletColor : colors.border,
                labelColor: active ? colors.primaryText : colors.tertiaryText,
                label: share.name,
                labelSize: 13,
                isSelected: active,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                onTap: () => onToggle(share.walletId),
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
    // 목표를 정한 지갑만 넘어온다.
    final goal = share.goal!;
    return Padding(
      key: ValueKey('goal-amount-wallet-${share.walletId}'),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  share.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: CoconutTypography.body2_14.copyWith(color: colors.primaryText),
                ),
              ),
              Text(goal.percentText, style: CoconutTypography.body2_14_NumberBold.copyWith(color: colors.primaryText)),
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
