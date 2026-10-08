import 'dart:async';
import 'dart:math' as math;

import 'package:coconut_design_system/coconut_design_system.dart' show CoconutColors, CoconutLayout, CoconutTypography;
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/home/home_widget_data.dart';
import 'package:coconut_wallet/model/home/home_widget_settings.dart';
import 'package:coconut_wallet/providers/view_model/home/hodl_insights_view_model.dart';
import 'package:coconut_wallet/providers/view_model/home/home_widgets_view_model.dart';
import 'package:coconut_wallet/screens/home/widget_configure_sheet.dart';
import 'package:coconut_wallet/services/home/wallet_widget_definitions.dart';
import 'package:coconut_wallet/ui/coconut/coconut_app_bar.dart';
import 'package:coconut_wallet/widgets/features/home/wallet_onboarding_view.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/activity_widget_views.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/home_widget_parts.dart';
import 'package:coconut_wallet/utils/legible_color_util.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/wallet_widget_views.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

/// 호들 인사이트: 잔액 추이, 목표, 지갑별 잔액, UTXO 요약, 거래 활동을 한 화면에서 기간을 바꿔 가며 본다.
class HodlInsightsScreen extends StatefulWidget {
  static const transitionDuration = Duration(milliseconds: 480);

  /// 잔액 위젯에서 열면 그 위젯 카드가 총 잔액 카드로 날아오며 바뀐다.
  final Object? balanceHeroTag;

  const HodlInsightsScreen({super.key, this.balanceHeroTag});

  /// 홈 위젯이나 모든 기능에서 연다. 위젯에서 열면 그 위젯의 지갑 범위와 기간으로 시작한다.
  static Future<void> open(
    BuildContext context, {
    List<int>? walletIds,
    HomeWidgetPeriod balancePeriod = HomeWidgetPeriod.week,
    HomeWidgetPeriod activityPeriod = HomeWidgetPeriod.week,
    HodlInsightsSection section = HodlInsightsSection.balance,
    Object? balanceHeroTag,
  }) {
    final data = context.read<HomeWidgetsViewModel>().withoutFakeBalance();
    Widget page(BuildContext _) => ChangeNotifierProvider(
      create:
          (_) => HodlInsightsViewModel(
            data,
            initialSection: section,
            walletIds: walletIds,
            balancePeriod: balancePeriod,
            activityPeriod: activityPeriod,
          ),
      child: HodlInsightsScreen(balanceHeroTag: balanceHeroTag),
    );
    const settings = RouteSettings(name: '/hodl-insights');
    if (balanceHeroTag == null) {
      return Navigator.of(context).push(CupertinoPageRoute(settings: settings, builder: page));
    }
    return Navigator.of(context).push(
      PageRouteBuilder(
        settings: settings,
        transitionDuration: transitionDuration,
        reverseTransitionDuration: transitionDuration,
        pageBuilder: (context, _, __) => page(context),
        transitionsBuilder:
            (_, animation, __, child) => FadeTransition(
              opacity: CurvedAnimation(parent: animation, curve: const Interval(0, 0.6, curve: Curves.easeOut)),
              child: child,
            ),
      ),
    );
  }

  @override
  State<HodlInsightsScreen> createState() => _HodlInsightsScreenState();
}

class _HodlInsightsScreenState extends State<HodlInsightsScreen> {
  final Map<HodlInsightsSection, GlobalKey> _sectionKeys = {
    for (final section in HodlInsightsSection.values) section: GlobalKey(),
  };
  bool _movedToInitialSection = false;
  HodlInsightsSection? _highlighted;

  /// 처음 그려진 직후 한 번만, 위젯에서 고른 구역으로 스크롤하고 잠깐 강조한다.
  void _moveToInitialSection(HodlInsightsSection section) {
    if (_movedToInitialSection) return;
    _movedToInitialSection = true;
    if (section == HodlInsightsSection.balance) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final target = _sectionKeys[section]!.currentContext;
      if (target == null || !mounted) return;
      await Scrollable.ensureVisible(target, duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic);
      if (mounted) setState(() => _highlighted = section);
    });
  }

  Widget _section(HodlInsightsSection section, {Widget? title, required Widget child}) {
    return Column(
      key: _sectionKeys[section],
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null) title,
        _SectionHighlight(
          key: ValueKey('hodl-insights-highlight-${section.name}'),
          active: _highlighted == section,
          child: child,
        ),
      ],
    );
  }

  Future<void> _openSettings(BuildContext context, HodlInsightsViewModel viewModel) async {
    final settings = await WidgetConfigureSheet.openSettings(
      context,
      title: t.hodl_insights.settings_title,
      heading: t.hodl_insights.title,
      description: t.hodl_insights.settings_description,
      spec: const HomeWidgetSettingsSpec(wallets: true, goals: true),
      wallets: viewModel.data.wallets,
      initial: HomeWidgetSettings(walletIds: viewModel.walletIds),
    );
    if (settings == null) return;
    viewModel.setWalletIds(settings.walletIds);
    viewModel.data.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final viewModel = context.watch<HodlInsightsViewModel>();
    if (!viewModel.isLoading) _moveToInitialSection(viewModel.initialSection);
    return Scaffold(
      backgroundColor: colors.homeBackground,
      appBar: CoconutAppBar.build(
        context: context,
        backgroundColor: colors.homeBackground,
        title: t.hodl_insights.title,
        actionButtonList: [
          if (!viewModel.hasNoWallets)
            CupertinoButton(
              key: const Key('hodl-insights-settings'),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              minimumSize: const Size(40, 40),
              onPressed: () => _openSettings(context, viewModel),
              child: SvgPicture.asset(
                FeatureSettingsIconPath.settings,
                colorFilter: ColorFilter.mode(colors.iconPrimary, BlendMode.srcIn),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child:
            viewModel.isLoading
                ? const Center(child: CircularProgressIndicator())
                : viewModel.hasNoWallets
                ? const _NoWalletsView()
                : SingleChildScrollView(
                  key: const Key('hodl-insights-list'),
                  padding: const EdgeInsets.fromLTRB(0, 8, 0, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _section(
                              HodlInsightsSection.balance,
                              child:
                                  widget.balanceHeroTag == null
                                      ? _BalanceCard(viewModel: viewModel)
                                      : Hero(
                                        tag: widget.balanceHeroTag!,
                                        flightShuttleBuilder: _cardShuttle,
                                        child: _BalanceCard(viewModel: viewModel),
                                      ),
                            ),
                            CoconutLayout.spacing_400h,
                            _section(
                              HodlInsightsSection.goal,
                              child: _GoalCard(
                                viewModel: viewModel,
                                onSetGoal: () => _openSettings(context, viewModel),
                              ),
                            ),
                          ],
                        ),
                      ),
                      _LowerBand(
                        children: [
                          _section(
                            HodlInsightsSection.balanceByWallet,
                            title: _SectionTitle(t.home_widgets.balance_by_wallet, top: 10),
                            child: SizedBox(
                              height: 200,
                              child: _OpenProgress(
                                progress: 1,
                                builder:
                                    (context, reveal) => BalanceByWalletView(
                                      key: const Key('hodl-insights-balance-by-wallet'),
                                      shares: viewModel.balanceShares(t.home_widgets.others),
                                      total: _btcAmount(viewModel, viewModel.balance),
                                      amountText: (sats) => _btcNumber(viewModel, sats),
                                      reveal: reveal,
                                    ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _section(
                              HodlInsightsSection.utxo,
                              title: _SectionTitle(t.hodl_insights.utxo_summary, top: 0),
                              child: _UtxoSummaryCard(viewModel: viewModel),
                            ),
                            _section(
                              HodlInsightsSection.activity,
                              title: _SectionTitle(
                                t.hodl_insights.transaction_activity,
                                top: _sectionGap,
                                trailing: _PeriodChips(
                                  key: const Key('hodl-insights-activity-periods'),
                                  selected: viewModel.activityPeriod,
                                  onSelected: viewModel.selectActivityPeriod,
                                ),
                              ),
                              child: _ActivityCard(viewModel: viewModel),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
      ),
    );
  }
}

/// 지갑별 잔액 · UTXO 요약 · 거래 활동 사이: 위 카드 아래에서 다음 제목 글자까지
const _sectionGap = 40.0;

/// 홈 위젯 카드와 인사이트 카드가 날아가는 동안 내용을 겹쳐 바꾼다. 두 카드는 제 크기로 그린 뒤 폭에 맞춰 줄이고 넘치는 아래는 자른다.
Widget _cardShuttle(
  BuildContext flightContext,
  Animation<double> animation,
  HeroFlightDirection direction,
  BuildContext fromHeroContext,
  BuildContext toHeroContext,
) {
  final push = direction == HeroFlightDirection.push;
  final widgetContext = push ? fromHeroContext : toHeroContext;
  final cardContext = push ? toHeroContext : fromHeroContext;
  final progress = CurvedAnimation(
    parent: ModalRoute.of(cardContext)?.animation ?? animation,
    curve: const Interval(0.15, 0.85),
  );
  Widget sized(BuildContext heroContext) {
    final size = (heroContext.findRenderObject() as RenderBox?)?.size ?? Size.zero;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: FittedBox(
        fit: BoxFit.fitWidth,
        alignment: Alignment.topCenter,
        clipBehavior: Clip.hardEdge,
        child: SizedBox.fromSize(size: size, child: (heroContext.widget as Hero).child),
      ),
    );
  }

  return Stack(
    fit: StackFit.expand,
    children: [
      FadeTransition(opacity: ReverseAnimation(progress), child: sized(widgetContext)),
      FadeTransition(opacity: progress, child: sized(cardContext)),
    ],
  );
}

String _btcNumber(HodlInsightsViewModel viewModel, int sats) => viewModel.data.unit.displayBitcoinAmount(sats);

String _btcText(HodlInsightsViewModel viewModel, int sats) =>
    viewModel.data.unit.displayBitcoinAmount(sats, withUnit: true);

HomeAmount _btcAmount(HodlInsightsViewModel viewModel, int sats) =>
    HomeAmount(_btcNumber(viewModel, sats), viewModel.data.unit.symbol, unitFirst: viewModel.data.unit.isPrefixSymbol);

/// 잔액 숫자와 단위. [HomeAmountText]와 같은 순서지만 FittedBox 없이 그려서 옆 글자와 기준선을 맞출 수 있다.
List<TextSpan> _amountSpans(HomeAmount amount, TextStyle numberStyle, TextStyle unitStyle, Color color) {
  final number = TextSpan(
    text: amount.number,
    style: numberStyle.copyWith(color: color, fontFeatures: const [FontFeature.tabularFigures()]),
  );
  if (amount.unit.isEmpty) return [number];
  final unit = TextSpan(text: amount.unit, style: unitStyle.copyWith(color: color));
  final gap = TextSpan(text: ' ', style: unitStyle);
  return amount.unitFirst ? [unit, gap, number] : [number, gap, unit];
}

/// [Text.rich]가 그릴 때와 같은 조건(주변 기본 스타일, 글자 배율, 언어)으로 잰 한 줄 폭
double _spanWidth(BuildContext context, List<TextSpan> spans) {
  final painter = TextPainter(
    text: TextSpan(style: DefaultTextStyle.of(context).style, children: spans),
    textDirection: Directionality.maybeOf(context) ?? TextDirection.ltr,
    textScaler: MediaQuery.textScalerOf(context),
    locale: Localizations.maybeLocaleOf(context),
    maxLines: 1,
  )..layout();
  final width = painter.width.ceilToDouble();
  painter.dispose();
  return width;
}

/// 위젯에서 들어온 구역을 옅은 색으로 덮었다가 서서히 걷어 낸다.
class _SectionHighlight extends StatefulWidget {
  static const duration = Duration(milliseconds: 1200);

  final bool active;
  final Widget child;

  const _SectionHighlight({super.key, required this.active, required this.child});

  @override
  State<_SectionHighlight> createState() => _SectionHighlightState();
}

class _SectionHighlightState extends State<_SectionHighlight> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: _SectionHighlight.duration);

  @override
  void didUpdateWidget(covariant _SectionHighlight oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) _controller.reverse(from: 1);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder:
          (context, child) => DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(
              color: CoconutColors.white.withValues(alpha: 0.16 * Curves.easeIn.transform(_controller.value)),
              borderRadius: BorderRadius.circular(20),
            ),
            child: child,
          ),
    );
  }
}

/// 지갑이 없을 때: 인사이트로 볼 수 있는 것을 소개하고 첫 지갑 추가로 이끈다.
class _NoWalletsView extends StatelessWidget {
  const _NoWalletsView();

  @override
  Widget build(BuildContext context) {
    final copy = t.hodl_insights.empty;
    Widget svg(String asset) => WalletOnboardingView.svgIcon(context, asset);
    return KeyedSubtree(
      key: const Key('hodl-insights-no-wallets'),
      child: WalletOnboardingView(
        heroIconPath: FeatureWalletIconPath.pie,
        title: copy.title,
        onAddWallet: () => openWalletAddFor(context, WalletStackKind.all),
        items: [
          WalletOnboardingItem(
            icon: svg(FeatureWidgetIconPath.trendingUp),
            title: copy.balance_title,
            description: copy.balance_description,
          ),
          WalletOnboardingItem(
            icon: svg(FeatureWidgetIconPath.bullseyeArrow),
            title: copy.goal_title,
            description: copy.goal_description,
          ),
          WalletOnboardingItem(
            icon: svg(FeatureWalletIconPath.pie),
            title: copy.by_wallet_title,
            description: copy.by_wallet_description,
          ),
          WalletOnboardingItem(
            icon: svg(FeatureWidgetIconPath.coinStack),
            title: copy.utxo_title,
            description: copy.utxo_description,
          ),
          WalletOnboardingItem(
            icon: svg(FeatureWidgetIconPath.chartBar),
            title: copy.activity_title,
            description: copy.activity_description,
          ),
        ],
      ),
    );
  }
}

/// 지갑별 잔액 구역: 회색 띠가 카드 중간부터 천천히 옅어져 UTXO 요약 제목에서 끝난다. 띠 위 카드는 바탕색으로 뒤집는다.
class _LowerBand extends StatelessWidget {
  /// 카드 아래 띠의 끝 여백. 띠는 카드 중간부터 천천히 옅어져 이 여백 끝에서 사라진다.
  static const _fadeHeight = _sectionGap;

  final List<Widget> children;

  const _LowerBand({required this.children});

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final surface = colors.homeSurface;
    return Container(
      key: const Key('hodl-insights-lower-band'),
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, _fadeHeight),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [surface, surface, surface.withValues(alpha: 0.55), surface.withValues(alpha: 0)],
          stops: const [0, 0.45, 0.8, 1],
        ),
      ),
      child: HomeCardSurface(
        color: colors.homeBackground,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
      ),
    );
  }
}

/// 잔액 그래프. 손가락을 올리거나 끌면 그 날의 잔액과 날짜를 보여 준다.
class _BalanceChart extends StatefulWidget {
  final HodlInsightsViewModel viewModel;

  const _BalanceChart({required this.viewModel});

  @override
  State<_BalanceChart> createState() => _BalanceChartState();
}

class _BalanceChartState extends State<_BalanceChart> {
  int? _selected;

  void _select(Offset position, double width, int count) {
    if (count < 2 || width <= 0) return;
    final index = (position.dx.clamp(0.0, width) / width * (count - 1)).round();
    if (index != _selected) setState(() => _selected = index);
  }

  void _clear() {
    if (_selected != null) setState(() => _selected = null);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final viewModel = widget.viewModel;
    final values = viewModel.chartBalances;
    final days = viewModel.chartBalanceDays;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final selected = _selected != null && _selected! < values.length && _selected! < days.length ? _selected : null;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) => _select(details.localPosition, size.width, values.length),
          onTapUp: (_) => _clear(),
          onTapCancel: _clear,
          onHorizontalDragStart: (details) => _select(details.localPosition, size.width, values.length),
          onHorizontalDragUpdate: (details) => _select(details.localPosition, size.width, values.length),
          onHorizontalDragEnd: (_) => _clear(),
          onHorizontalDragCancel: _clear,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(child: HomeSparkline(values: values, selectedIndex: selected)),
              if (selected != null)
                Builder(
                  builder: (context) {
                    final point = HomeSparkline.pointOf(values, selected, size);
                    const labelWidth = 150.0;
                    final left =
                        (point.dx - labelWidth / 2).clamp(0.0, math.max(0.0, size.width - labelWidth)).toDouble();
                    final day = days[selected];
                    return Positioned(
                      left: left,
                      top: -36,
                      width: labelWidth,
                      child: Container(
                        key: const Key('hodl-insights-balance-readout'),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: colors.homeBackground, borderRadius: BorderRadius.circular(8)),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                _btcText(viewModel, values[selected].toInt()),
                                style: CoconutTypography.body3_12_NumberBold.copyWith(color: colors.primaryText),
                              ),
                            ),
                            Text(
                              viewModel.chartUsesMonths
                                  ? '${formatHomeMonth(day)} ${day.year}'
                                  : formatHomeShortDate(day),
                              style: CoconutTypography.caption_10_Number.copyWith(color: colors.tertiaryText),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}

class _InsightCard extends StatelessWidget {
  final Widget child;

  const _InsightCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: HomeCardSurface.of(context), borderRadius: BorderRadius.circular(20)),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;
  final double top;

  const _SectionTitle(this.text, {this.trailing, this.top = 32});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(4, top, 0, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              text,
              style: CoconutTypography.heading4_18_Bold.copyWith(color: context.coconutColors.primaryText),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// 1주 · 1개월 · 3개월 · 1년 · 전체
class _PeriodChips extends StatelessWidget {
  final HomeWidgetPeriod selected;
  final ValueChanged<HomeWidgetPeriod> onSelected;

  const _PeriodChips({super.key, required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: colors.homeBackground, borderRadius: BorderRadius.circular(10)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final period in HodlInsightsViewModel.periods)
            GestureDetector(
              key: ValueKey('hodl-insights-period-${period.name}'),
              behavior: HitTestBehavior.opaque,
              onTap: () => onSelected(period),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: period == selected ? colors.primaryText : null,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  homePeriodLabel(period),
                  style: CoconutTypography.caption_10.copyWith(
                    color: period == selected ? colors.background : colors.tertiaryText,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  /// 총 잔액 라벨, 잔액, 환산액 사이 간격
  static const _rowGap = 0.0;

  /// 줄 위아래 여백을 줄여 세 줄을 촘촘하게 붙인다.
  static const _lineHeight = 1.15;

  final HodlInsightsViewModel viewModel;

  const _BalanceCard({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final data = viewModel.data;
    final delta = viewModel.changeSats;
    final deltaColor = homePriceColorOf(context, delta.sign.toDouble(), neutral: colors.primaryText);
    final days = viewModel.chartDays;
    final rate = viewModel.changeRate;
    final rateColor = homePriceColorOf(context, rate, neutral: colors.tertiaryText);
    final hasChange = rate != null && rate != 0;
    return _InsightCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: MediaQuery(
                  data: MediaQuery.of(context).copyWith(boldText: false),
                  child: Text(
                    t.hodl_insights.total_balance,
                    key: const Key('hodl-insights-total-label'),
                    style: CoconutTypography.body3_12.copyWith(
                      color: colors.secondaryText,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ),
              _PeriodChips(
                key: const Key('hodl-insights-balance-periods'),
                selected: viewModel.balancePeriod,
                onSelected: viewModel.selectBalancePeriod,
              ),
            ],
          ),
          const SizedBox(height: _rowGap),
          LayoutBuilder(
            builder: (context, constraints) {
              final rateStyle = CoconutTypography.body3_12_Number.copyWith(color: rateColor, height: _lineHeight);
              final rateText = hasChange ? formatHomeRate(rate) : '–';
              final rateWidth = measureHomeText(context, rateText, rateStyle) + (hasChange ? 14 + 2 : 0);
              final amount = _btcAmount(viewModel, viewModel.balance);
              final numberStyle = CoconutTypography.heading3_21_NumberBold.copyWith(height: _lineHeight);
              final unitStyle = CoconutTypography.body1_16_Number.copyWith(height: _lineHeight);
              final available = constraints.maxWidth - rateWidth - 12 - 1;
              var scale = 1.0;
              TextStyle scaled(TextStyle style) => style.copyWith(fontSize: style.fontSize! * scale);
              for (var attempt = 0; attempt < 3; attempt++) {
                final width = _spanWidth(
                  context,
                  _amountSpans(amount, scaled(numberStyle), scaled(unitStyle), colors.primaryText),
                );
                if (width <= available || width == 0) break;
                scale *= available / width;
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Expanded(
                    child: Text.rich(
                      key: const Key('hodl-insights-balance'),
                      TextSpan(
                        children: _amountSpans(amount, scaled(numberStyle), scaled(unitStyle), colors.primaryText),
                      ),
                      maxLines: 1,
                      softWrap: false,
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (hasChange) ...[
                    Icon(rate > 0 ? CupertinoIcons.arrow_up : CupertinoIcons.arrow_down, size: 14, color: rateColor),
                    const SizedBox(width: 2),
                  ],
                  Text(rateText, key: const Key('hodl-insights-balance-rate'), style: rateStyle),
                ],
              );
            },
          ),
          const SizedBox(height: _rowGap),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  formatHomeFiat(data.fiatValueOf(viewModel.balance, data.fiat), data.fiat),
                  key: const Key('hodl-insights-balance-fiat'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: CoconutTypography.body2_14_Number.copyWith(color: colors.secondaryText, height: _lineHeight),
                ),
              ),
              CoconutLayout.spacing_300w,
              Text(
                '${delta >= 0 ? '+' : '-'} ${_btcText(viewModel, delta.abs())}',
                key: const Key('hodl-insights-balance-delta'),
                style: CoconutTypography.body3_12_Number.copyWith(color: deltaColor, height: _lineHeight),
              ),
            ],
          ),
          CoconutLayout.spacing_500h,
          SizedBox(
            key: const Key('hodl-insights-balance-chart'),
            height: 88,
            child: _BalanceChart(viewModel: viewModel),
          ),
          CoconutLayout.spacing_200h,
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final day in days)
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      viewModel.chartUsesMonths ? formatHomeMonth(day) : formatHomeShortDate(day),
                      maxLines: 1,
                      style: CoconutTypography.caption_10_Number.copyWith(color: colors.tertiaryText),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 화면을 열 때 차오르는 값(목표 막대, 지갑별 잔액 도넛). 화면이 다 열린 뒤 잠깐 쉬었다가 0에서 천천히 차오르고, 값이 바뀌면 지금 값에서 이어서 움직인다.
class _OpenProgress extends StatefulWidget {
  static const fillDuration = Duration(milliseconds: 1600);
  static const startDelay = Duration(milliseconds: 250);

  final double progress;
  final Widget Function(BuildContext context, double progress) builder;

  const _OpenProgress({required this.progress, required this.builder});

  @override
  State<_OpenProgress> createState() => _OpenProgressState();
}

class _OpenProgressState extends State<_OpenProgress> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: _OpenProgress.fillDuration);
  late final Animation<double> _curve = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
  double _from = 0;
  late double _to = widget.progress;
  Animation<double>? _route;
  Timer? _start;

  double get _value => _from + (_to - _from) * _curve.value;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_route != null) return;
    final route = ModalRoute.of(context)?.animation ?? kAlwaysCompleteAnimation;
    _route = route;
    if (route.isCompleted) {
      _scheduleStart();
    } else {
      route.addStatusListener(_onRouteStatus);
    }
  }

  void _onRouteStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    _route?.removeStatusListener(_onRouteStatus);
    _scheduleStart();
  }

  void _scheduleStart() {
    _start = Timer(_OpenProgress.startDelay, () {
      if (mounted) _controller.forward(from: 0);
    });
  }

  @override
  void didUpdateWidget(covariant _OpenProgress oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.progress == _to) return;
    _from = _value;
    _to = widget.progress;
    if (_start?.isActive ?? false) return;
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _start?.cancel();
    _route?.removeStatusListener(_onRouteStatus);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      AnimatedBuilder(animation: _controller, builder: (context, _) => widget.builder(context, _value));
}

class _GoalCard extends StatelessWidget {
  final HodlInsightsViewModel viewModel;

  /// 목표가 없을 때 카드를 누르면 설정을 연다.
  final VoidCallback onSetGoal;

  const _GoalCard({required this.viewModel, required this.onSetGoal});

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final goal = viewModel.goal;
    return _InsightCard(
      child: Column(
        key: const Key('hodl-insights-goal'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HomeWidgetHeader(
            iconPath: FeatureWidgetIconPath.bullseyeArrow,
            title: t.hodl_insights.goal,
            style: CoconutTypography.body1_16_Bold,
          ),
          CoconutLayout.spacing_300h,
          if (goal == null)
            GestureDetector(
              key: const Key('hodl-insights-goal-empty'),
              behavior: HitTestBehavior.opaque,
              onTap: onSetGoal,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      t.hodl_insights.no_goal,
                      style: CoconutTypography.body3_12.copyWith(color: colors.secondaryText),
                    ),
                  ),
                  Icon(CupertinoIcons.chevron_right, size: 14, color: colors.tertiaryText),
                ],
              ),
            )
          else ...[
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                '${_btcNumber(viewModel, goal.balance)} / ${_btcText(viewModel, goal.target)}',
                style: CoconutTypography.heading4_18_NumberBold.copyWith(color: colors.primaryText),
              ),
            ),
            CoconutLayout.spacing_200h,
            Builder(
              builder: (context) {
                final percentStyle = CoconutTypography.heading4_18_NumberBold.copyWith(
                  color: colors.primaryText,
                  fontFeatures: const [FontFeature.tabularFigures()],
                );
                return _OpenProgress(
                  progress: goal.ratio,
                  builder:
                      (context, ratio) => Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: SizedBox(
                                height: 12,
                                child: Stack(
                                  children: [
                                    Container(color: colors.surfaceMuted),
                                    FractionallySizedBox(
                                      key: const Key('goal-progress-fill'),
                                      widthFactor: ratio.clamp(0.0, 1.0),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: colors.success,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          CoconutLayout.spacing_400w,
                          SizedBox(
                            width: measureHomeText(context, goal.percentText, percentStyle) + 1,
                            child: Text(
                              formatGoalPercent(ratio),
                              key: const Key('goal-progress-percent'),
                              textAlign: TextAlign.right,
                              maxLines: 1,
                              style: percentStyle,
                            ),
                          ),
                        ],
                      ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _UtxoSummaryCard extends StatelessWidget {
  static const bucketLabels = UtxoStatusView.bucketLabels;
  static const _columnGap = 8.0;

  final HodlInsightsViewModel viewModel;

  const _UtxoSummaryCard({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final buckets = viewModel.utxoBuckets;
    final total = buckets.total;
    final bucketColors = [for (final color in viewModel.data.utxoBucketColors) legibleOn(color, colors.homeSurface)];
    return _InsightCard(
      child: _OpenProgress(
        progress: 1,
        builder: (context, shown) {
          int counted(int value) => (value * shown).round();
          return Column(
            key: const Key('hodl-insights-utxo'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t.hodl_insights.total_utxos(count: counted(total)),
                key: const Key('hodl-insights-utxo-total'),
                style: CoconutTypography.body2_14_Bold.copyWith(color: colors.primaryText),
              ),
              CoconutLayout.spacing_300h,
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  height: 12,
                  child: ColoredBox(
                    color: colors.surfaceMuted,
                    child:
                        total == 0
                            ? const SizedBox.expand()
                            : LayoutBuilder(
                              builder:
                                  (context, constraints) => Row(
                                    children: [
                                      for (var i = 0; i < buckets.counts.length; i++)
                                        if (buckets.counts[i] > 0)
                                          Container(
                                            key: ValueKey('hodl-insights-utxo-segment-$i'),
                                            width: constraints.maxWidth * buckets.counts[i] / total * shown,
                                            padding: const EdgeInsets.symmetric(horizontal: 1),
                                            child: ColoredBox(color: bucketColors[i]),
                                          ),
                                    ],
                                  ),
                            ),
                  ),
                ),
              ),
              CoconutLayout.spacing_200h,
              for (var i = 0; i < buckets.counts.length; i++) ...[
                if (i > 0) Divider(height: 1, color: colors.divider),
                Padding(
                  key: ValueKey('hodl-insights-utxo-row-$i'),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(color: bucketColors[i], shape: BoxShape.circle),
                      ),
                      CoconutLayout.spacing_200w,
                      Expanded(
                        flex: 4,
                        child: FittedBox(
                          key: ValueKey('hodl-insights-utxo-label-$i'),
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '${bucketLabels[i]} BTC',
                            maxLines: 1,
                            style: CoconutTypography.body3_12_Number.copyWith(color: colors.secondaryText),
                          ),
                        ),
                      ),
                      const SizedBox(width: _columnGap),
                      Expanded(
                        flex: 2,
                        child: FittedBox(
                          key: ValueKey('hodl-insights-utxo-count-$i'),
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(
                            t.hodl_insights.utxo_count(count: counted(buckets.counts[i])),
                            maxLines: 1,
                            style: CoconutTypography.body3_12_Number.copyWith(color: colors.primaryText),
                          ),
                        ),
                      ),
                      const SizedBox(width: _columnGap),
                      Expanded(
                        flex: 2,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(
                            '${total == 0 ? 0 : (buckets.counts[i] * 100 / total * shown).toStringAsFixed(1)}%',
                            maxLines: 1,
                            style: CoconutTypography.body3_12_Number.copyWith(color: colors.primaryText),
                          ),
                        ),
                      ),
                      const SizedBox(width: _columnGap),
                      Expanded(
                        flex: 4,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(
                            buckets.amounts.length > i ? _btcText(viewModel, counted(buckets.amounts[i])) : '-',
                            maxLines: 1,
                            style: CoconutTypography.body3_12_Number.copyWith(color: colors.primaryText),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  final HodlInsightsViewModel viewModel;

  const _ActivityCard({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final bars = viewModel.activityBars;
    final totals = viewModel.activityTotals;
    return KeyedSubtree(
      key: const Key('hodl-insights-activity'),
      child: TransactionActivityView(
        detailed: true,
        days: bars.bars,
        rangeEnd: DateTime.now(),
        monthly: bars.monthly,
        amountTexts: [
          totals.receivedSats == 0 ? '-' : '+ ${_btcNumber(viewModel, totals.receivedSats)}',
          totals.sentSats == 0 ? '-' : '- ${_btcNumber(viewModel, totals.sentSats)}',
          totals.organizedFeeSats == 0
              ? '-'
              : '${t.hodl_insights.fee} ${_btcNumber(viewModel, totals.organizedFeeSats)}',
        ],
      ),
    );
  }
}
