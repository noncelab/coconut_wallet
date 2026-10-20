import 'dart:async';
import 'dart:math' as math;

import 'package:coconut_design_system/coconut_design_system.dart' show CoconutLayout, CoconutTypography;
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/home/home_widget_data.dart';
import 'package:coconut_wallet/model/home/home_widget_settings.dart';
import 'package:coconut_wallet/providers/view_model/home/hodl_insights_view_model.dart';
import 'package:coconut_wallet/providers/view_model/home/home_widgets_view_model.dart';
import 'package:coconut_wallet/screens/home/widget_configure_sheet.dart';
import 'package:coconut_wallet/screens/home/wallet_balance_history_screen.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/balance_history_period_chips.dart';
import 'package:coconut_wallet/services/home/wallet_widget_definitions.dart';
import 'package:coconut_wallet/ui/coconut/coconut_app_bar.dart';
import 'package:coconut_wallet/widgets/features/home/wallet_onboarding_view.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/activity_widget_views.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/utxo_summary_view.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/home_widget_parts.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/wallet_widget_views.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/foundation.dart' show precisionErrorTolerance;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

/// 호들 인사이트: 잔액 추이, 목표, 지갑별 잔액, UTXO 요약, 거래 활동을 한 화면에서 기간을 바꿔 가며 본다.
class HodlInsightsScreen extends StatefulWidget {
  static const transitionDuration = Duration(milliseconds: 480);

  /// 홈 위젯에서 열면 해당 인사이트 카드로 날아오며 바뀐다.
  final Object? heroTag;
  final HodlInsightsSection? heroSection;

  const HodlInsightsScreen({super.key, this.heroTag, this.heroSection});

  /// 홈 위젯이나 모든 기능에서 연다. 위젯에서 열면 그 위젯의 지갑 범위와 기간으로 시작한다.
  static Future<void> open(
    BuildContext context, {
    List<int>? walletIds,
    HomeWidgetPeriod balancePeriod = HomeWidgetPeriod.week,
    HomeWidgetPeriod activityPeriod = HomeWidgetPeriod.week,
    HodlInsightsSection section = HodlInsightsSection.balance,
    Object? heroTag,
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
      child: HodlInsightsScreen(heroTag: heroTag, heroSection: section),
    );
    const settings = RouteSettings(name: '/hodl-insights');
    if (heroTag == null) {
      return Navigator.of(context).push(CupertinoPageRoute(settings: settings, builder: page));
    }
    return Navigator.of(context).push(
      PageRouteBuilder(
        settings: settings,
        transitionDuration: transitionDuration,
        reverseTransitionDuration: transitionDuration,
        pageBuilder: (context, _, __) => page(context),
        transitionsBuilder:
            (context, animation, __, child) => ColoredBox(
              color: context.coconutColors.homeBackground,
              child: FadeTransition(
                opacity: CurvedAnimation(parent: animation, curve: const Interval(0, 0.6, curve: Curves.easeOut)),
                child: child,
              ),
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
  double _leadingSpace = 0;
  Animation<double>? _routeAnimation;
  bool _cardHeroActive = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final animation = ModalRoute.of(context)?.animation;
    if (identical(animation, _routeAnimation)) return;
    _routeAnimation?.removeStatusListener(_onRouteStatus);
    _routeAnimation = animation;
    _cardHeroActive = animation?.status != AnimationStatus.completed;
    animation?.addStatusListener(_onRouteStatus);
  }

  void _onRouteStatus(AnimationStatus status) {
    final active = status != AnimationStatus.completed;
    if (active != _cardHeroActive && mounted) setState(() => _cardHeroActive = active);
  }

  @override
  void dispose() {
    _routeAnimation?.removeStatusListener(_onRouteStatus);
    super.dispose();
  }

  /// 처음 그려진 직후 한 번만, 위젯에서 고른 구역으로 스크롤하고 잠깐 강조한다.
  void _moveToInitialSection(HodlInsightsSection section) {
    if (_movedToInitialSection) return;
    _movedToInitialSection = true;
    if (section == HodlInsightsSection.balance) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => _centerInitialSection(section));
  }

  Future<void> _centerInitialSection(HodlInsightsSection section) async {
    final target = _sectionKeys[section]!.currentContext;
    if (target == null || !mounted) return;
    final scrollable = Scrollable.maybeOf(target);
    final viewport = scrollable?.context.findRenderObject();
    final card = target.findRenderObject();
    if (_leadingSpace == 0 && section != HodlInsightsSection.activity && viewport is RenderBox && card is RenderBox) {
      final viewportCenter = viewport.localToGlobal(viewport.size.center(Offset.zero)).dy;
      final cardCenter = card.localToGlobal(card.size.center(Offset.zero)).dy;
      if (cardCenter < viewportCenter) {
        setState(() => _leadingSpace = viewportCenter - cardCenter);
        WidgetsBinding.instance.addPostFrameCallback((_) => _centerInitialSection(section));
        return;
      }
    }
    await Scrollable.ensureVisible(
      target,
      alignment: 0.5,
      duration: widget.heroTag == null ? const Duration(milliseconds: 350) : Duration.zero,
      curve: Curves.easeOutCubic,
    );
    if (mounted) setState(() => _highlighted = section);
  }

  Widget _section(HodlInsightsSection section, {Widget? title, required Widget child}) {
    final card =
        widget.heroTag != null &&
                widget.heroSection == section &&
                (section != HodlInsightsSection.balance || _cardHeroActive)
            ? Hero(tag: widget.heroTag!, flightShuttleBuilder: _cardShuttle, child: child)
            : child;
    return RepaintBoundary(
      key: ValueKey('hodl-insights-repaint-${section.name}'),
      child: _InitialSectionTarget(
        key: _sectionKeys[section],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null) title,
            _SectionHighlight(
              key: ValueKey('hodl-insights-highlight-${section.name}'),
              active: _highlighted == section && widget.heroTag == null,
              child: card,
            ),
          ],
        ),
      ),
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
    if (!viewModel.isLoading && widget.heroTag == null) _moveToInitialSection(viewModel.initialSection);
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
                // A box viewport corrects overscroll during child relayout, even while a pointer is held.
                // Keep the native bounce with a sliver viewport when reveal/data updates relayout these cards.
                : CustomScrollView(
                  // Match SingleChildScrollView's inherited physics, including content that fits.
                  physics: ScrollConfiguration.of(context).getScrollPhysics(context),
                  key: const Key('hodl-insights-list'),
                  slivers: [
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        0,
                        widget.heroTag == null ? 8 + _leadingSpace : 0,
                        0,
                        _contentBottomPadding,
                      ),
                      sliver: _InitialSectionSliver(
                        targetKey:
                            widget.heroTag != null && viewModel.initialSection != HodlInsightsSection.balance
                                ? _sectionKeys[viewModel.initialSection]
                                : null,
                        topPadding: widget.heroTag != null ? 8 : 0,
                        allowLeadingSpace: viewModel.initialSection != HodlInsightsSection.activity,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _section(HodlInsightsSection.balance, child: _BalanceCard(viewModel: viewModel)),
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
                                    child: _UtxoSummaryCard(
                                      viewModel: viewModel,
                                      animateEntry:
                                          widget.heroTag == null || widget.heroSection != HodlInsightsSection.utxo,
                                    ),
                                  ),
                                  _section(
                                    HodlInsightsSection.activity,
                                    title: _SectionTitle(
                                      t.hodl_insights.transaction_activity,
                                      top: _sectionGap,
                                      trailing: BalanceHistoryPeriodChips(
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
                  ],
                ),
      ),
    );
  }
}

const _contentBottomPadding = 96.0;

class _InitialSectionTarget extends SingleChildRenderObjectWidget {
  const _InitialSectionTarget({super.key, required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderInitialSectionTarget();
}

class _RenderInitialSectionTarget extends RenderProxyBox {
  Rect layoutBounds = Rect.zero;

  @override
  void performLayout() {
    super.performLayout();
    layoutBounds = Offset.zero & size;
  }
}

/// Position the first Hero destination during layout, before HeroController measures it.
class _InitialSectionSliver extends SingleChildRenderObjectWidget {
  final GlobalKey? targetKey;
  final double topPadding;
  final bool allowLeadingSpace;

  const _InitialSectionSliver({
    required this.targetKey,
    required this.topPadding,
    required this.allowLeadingSpace,
    required super.child,
  });

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderInitialSectionSliver(targetKey, topPadding, allowLeadingSpace);
}

class _RenderInitialSectionSliver extends RenderSliverToBoxAdapter {
  final GlobalKey? targetKey;
  final bool allowLeadingSpace;
  double _leading;
  bool _positioned = false;

  _RenderInitialSectionSliver(this.targetKey, this._leading, this.allowLeadingSpace);

  @override
  void performLayout() {
    super.performLayout();
    if (child == null) return;
    assert(constraints.axisDirection == AxisDirection.down && constraints.growthDirection == GrowthDirection.forward);
    if (!_positioned && targetKey != null) {
      final target = targetKey!.currentContext?.findRenderObject();
      if (target is _RenderInitialSectionTarget && target.hasSize) {
        final bounds = MatrixUtils.transformRect(target.getTransformTo(child), target.layoutBounds);
        final desired = bounds.center.dy + _leading - constraints.viewportMainAxisExtent / 2;
        if (allowLeadingSpace && desired < 0) _leading -= desired;
        final maxOffset = math.max(
          0.0,
          child!.size.height + _leading + _contentBottomPadding - constraints.viewportMainAxisExtent,
        );
        final offset = (bounds.center.dy + _leading - constraints.viewportMainAxisExtent / 2).clamp(0.0, maxOffset);
        _positioned = true;
        final correction = offset - constraints.scrollOffset;
        if (correction.abs() > precisionErrorTolerance) {
          geometry = SliverGeometry(scrollOffsetCorrection: correction);
          return;
        }
      }
    }
    if (_leading == 0) return;
    final extent = child!.size.height + _leading;
    final painted = calculatePaintOffset(constraints, from: 0, to: extent);
    geometry = SliverGeometry(
      scrollExtent: extent,
      paintExtent: painted,
      cacheExtent: calculateCacheOffset(constraints, from: 0, to: extent),
      maxPaintExtent: extent,
      hitTestExtent: painted,
      hasVisualOverflow: extent > constraints.remainingPaintExtent || constraints.scrollOffset > 0,
    );
    setChildParentData(child!, constraints, geometry!);
    final data = child!.parentData! as SliverPhysicalParentData;
    data.paintOffset += Offset(0, _leading);
  }

  @override
  double childMainAxisPosition(RenderBox child) => _leading - constraints.scrollOffset;

  @override
  double childScrollOffset(RenderObject child) => _leading;
}

/// 지갑별 잔액 · UTXO 요약 · 거래 활동 사이: 위 카드 아래에서 다음 제목 글자까지
const _sectionGap = 40.0;

/// 카드 이동 중 출발 내용을 먼저 걷고 도착 내용을 나타낸다. 각 내용은 제 크기에서 폭에 맞춰 줄인다.
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
  double? revealed;
  if (!push) {
    void visit(Element element) {
      if (element is StatefulElement && element.state is _OpenProgressState) {
        revealed = (element.state as _OpenProgressState)._value;
        return;
      }
      element.visitChildren(visit);
    }

    (cardContext as Element).visitChildren(visit);
  }
  Widget sized(BuildContext heroContext) {
    final size = (heroContext.findRenderObject() as RenderBox?)?.size ?? Size.zero;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: FittedBox(
        fit: BoxFit.fitWidth,
        alignment: Alignment.topCenter,
        clipBehavior: Clip.hardEdge,
        child: SizedBox.fromSize(
          size: size,
          child: InheritedTheme.capture(from: heroContext, to: Navigator.of(heroContext).context).wrap(
            HomeCardSurface(
              color: HomeCardSurface.of(heroContext),
              child: _HeroFlightRoute(
                animation: ModalRoute.of(heroContext)?.animation ?? kAlwaysCompleteAnimation,
                revealed: revealed,
                child: (heroContext.widget as Hero).child,
              ),
            ),
          ),
        ),
      ),
    );
  }

  return Builder(
    builder: (context) {
      // Keep the shared app palette live while retaining route-local card surfaces.
      Theme.of(context);
      return Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(color: HomeCardSurface.of(cardContext), borderRadius: BorderRadius.circular(20)),
          ),
          FadeTransition(
            opacity: ReverseAnimation(CurvedAnimation(parent: progress, curve: const Interval(0, 0.5))),
            child: sized(widgetContext),
          ),
          FadeTransition(
            opacity: CurvedAnimation(parent: progress, curve: const Interval(0.5, 1)),
            child: sized(cardContext),
          ),
        ],
      );
    },
  );
}

/// Shuttle copies keep the owning route's progress instead of starting entry effects in the overlay.
class _HeroFlightRoute extends InheritedWidget {
  final Animation<double> animation;
  final double? revealed;

  const _HeroFlightRoute({required this.animation, this.revealed, required super.child});

  @override
  bool updateShouldNotify(_HeroFlightRoute oldWidget) =>
      animation != oldWidget.animation || revealed != oldWidget.revealed;
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
  bool _reduceMotion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context) || MediaQuery.accessibleNavigationOf(context);
    if (_reduceMotion) _controller.value = 0;
  }

  @override
  void didUpdateWidget(covariant _SectionHighlight oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active && !_reduceMotion) _controller.reverse(from: 1);
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
              color: context.coconutColors.primaryText.withValues(
                alpha: 0.16 * Curves.easeIn.transform(_controller.value),
              ),
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

/// 상세 화면으로 확대되는 잔액 그래프.
class _BalanceChart extends StatelessWidget {
  final HodlInsightsViewModel viewModel;
  const _BalanceChart({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final chart = Material(color: Colors.transparent, child: HomeSparkline(values: viewModel.chartBalances));
    final hasCardHero = context.findAncestorWidgetOfExactType<Hero>() != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: hasCardHero ? null : () => WalletBalanceHistoryScreen.open(context, viewModel),
      child:
          hasCardHero
              ? chart
              : Hero(tag: walletBalanceHistoryHeroTag, flightShuttleBuilder: walletBalanceHistoryFlight, child: chart),
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
                      color: colors.secondaryTextStrong,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ),
              BalanceHistoryPeriodChips(
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
                  style: CoconutTypography.body2_14_Number.copyWith(
                    color: colors.secondaryTextStrong,
                    height: _lineHeight,
                  ),
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
            child: RepaintBoundary(child: _BalanceChart(viewModel: viewModel)),
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
  final bool animateEntry;
  final Widget Function(BuildContext context, double progress) builder;

  const _OpenProgress({required this.progress, required this.builder, this.animateEntry = true});

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
  bool _reduceMotion = false;
  double? _flightValue;

  double get _value => _from + (_to - _from) * _curve.value;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final flight = context.dependOnInheritedWidgetOfExactType<_HeroFlightRoute>();
    _flightValue = flight?.revealed;
    if (_flightValue != null) return;
    _reduceMotion =
        !widget.animateEntry || MediaQuery.disableAnimationsOf(context) || MediaQuery.accessibleNavigationOf(context);
    if (_reduceMotion) {
      _start?.cancel();
      _route?.removeStatusListener(_onRouteStatus);
      _controller.value = 1;
    }
    if (_route != null) return;
    final route = flight?.animation ?? ModalRoute.of(context)?.animation ?? kAlwaysCompleteAnimation;
    _route = route;
    if (_reduceMotion) return;
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
    if (_reduceMotion) {
      _controller.value = 1;
      return;
    }
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
      AnimatedBuilder(animation: _controller, builder: (context, _) => widget.builder(context, _flightValue ?? _value));
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
                      style: CoconutTypography.body3_12.copyWith(color: colors.secondaryTextStrong),
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
  final HodlInsightsViewModel viewModel;
  final bool animateEntry;

  const _UtxoSummaryCard({required this.viewModel, this.animateEntry = true});

  @override
  Widget build(BuildContext context) {
    return _InsightCard(
      child: _OpenProgress(
        progress: 1,
        animateEntry: animateEntry,
        builder:
            (context, shown) => UtxoSummaryView(
              keyPrefix: 'hodl-insights',
              buckets: viewModel.utxoBuckets,
              bucketColors: viewModel.data.utxoBucketColors,
              amountText: (sats) => _btcText(viewModel, sats),
              shown: shown,
            ),
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
      child: _OpenProgress(
        progress: 1,
        builder:
            (context, shown) => TransactionActivityView(
              detailed: true,
              reveal: shown,
              days: bars.bars,
              rangeEnd: DateTime.now(),
              monthly: bars.monthly,
              amountTexts: [
                totals.receivedSats == 0 ? '-' : '+ ${_btcNumber(viewModel, (totals.receivedSats * shown).round())}',
                totals.sentSats == 0 ? '-' : '- ${_btcNumber(viewModel, (totals.sentSats * shown).round())}',
                totals.organizedFeeSats == 0
                    ? '-'
                    : '${t.hodl_insights.fee} ${_btcNumber(viewModel, (totals.organizedFeeSats * shown).round())}',
              ],
            ),
      ),
    );
  }
}
