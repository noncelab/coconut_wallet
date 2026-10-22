import 'dart:math' as math;
import 'package:coconut_design_system/coconut_design_system.dart' hide CoconutAppBar;
import 'package:coconut_wallet/app/router/app_route_names.dart';
import 'package:coconut_wallet/app/router/route_args.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/home/home_widget_settings.dart';
import 'package:coconut_wallet/providers/view_model/home/hodl_insights_view_model.dart';
import 'package:coconut_wallet/services/home/home_widget_math.dart';
import 'package:coconut_wallet/ui/coconut/coconut_app_bar.dart';
import 'package:coconut_wallet/utils/vibration_util.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/balance_history_period_chips.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/home_widget_parts.dart';
import 'package:coconut_wallet/widgets/features/transaction/card/transaction_item_card.dart';
import 'package:coconut_wallet/model/wallet/wallet_appearance.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/providers/wallet_appearance_provider.dart';
import 'package:coconut_wallet/widgets/features/wallet/card/wallet_card.dart';
import 'package:coconut_wallet/widgets/features/wallet/card/wallet_card_background.dart';
import 'package:coconut_wallet/model/home/home_widget_data.dart';
import 'package:coconut_wallet/utils/transaction_util.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/activity_widget_views.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';

const walletBalanceHistoryHeroTag = 'hodl-balance-history';

Widget walletBalanceHistoryFlight(
  BuildContext context,
  Animation<double> animation,
  HeroFlightDirection direction,
  BuildContext from,
  BuildContext to,
) {
  Widget fitted(BuildContext heroContext) {
    final size = (heroContext.findRenderObject() as RenderBox).size;
    return FittedBox(
      fit: BoxFit.fill,
      child: SizedBox(width: size.width, height: size.height, child: (heroContext.widget as Hero).child),
    );
  }

  final compact = direction == HeroFlightDirection.push ? from : to;
  final detail = direction == HeroFlightDirection.push ? to : from;
  return AnimatedBuilder(
    animation: animation,
    builder:
        (_, __) => Stack(
          fit: StackFit.expand,
          children: [
            Opacity(opacity: 1 - animation.value, child: fitted(compact)),
            Opacity(opacity: animation.value, child: fitted(detail)),
          ],
        ),
  );
}

class WalletBalanceHistoryScreen extends StatefulWidget {
  final HodlInsightsViewModel viewModel;
  const WalletBalanceHistoryScreen({super.key, required this.viewModel});

  static Future<void> open(BuildContext context, HodlInsightsViewModel viewModel) => Navigator.of(context).push<void>(
    PageRouteBuilder<void>(
      settings: const RouteSettings(name: '/wallet-balance-history'),
      opaque: false,
      transitionDuration: const Duration(milliseconds: 450),
      reverseTransitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (_, __, ___) => WalletBalanceHistoryScreen(viewModel: viewModel),
      transitionsBuilder:
          (_, animation, __, child) =>
              FadeTransition(opacity: animation.drive(CurveTween(curve: Curves.easeOutCubic)), child: child),
    ),
  );

  @override
  State<WalletBalanceHistoryScreen> createState() => _WalletBalanceHistoryScreenState();
}

class _WalletBalanceHistoryScreenState extends State<WalletBalanceHistoryScreen> with WidgetsBindingObserver {
  late HomeWidgetPeriod _period;
  List<int>? _walletIds;
  late DateTime _today;
  late int _days;
  late int _allDays;
  late double _span;
  late double _end;
  int? _selected;
  ({int minimum, int maximum})? _axisRange;
  bool _changedOnly = false;
  final Set<int> _expanded = {};
  ScrollController? _walletScrollController;
  final ScrollController _graphScrollController = ScrollController();
  double _compactGraphOffset = 0;
  int _walletScrollRequest = 0;
  final Map<int, double> _cardExtents = {};
  double _cardExtent = 0;
  double _startSpan = 1;
  double _startEnd = 0;
  Offset _startPosition = Offset.zero;
  bool _pinching = false;

  HodlInsightsViewModel get vm => widget.viewModel;
  List<DateTime> get _dates => HomeWidgetMath.lastDays(_today, _days);
  List<int> get _balances => vm.data.dailyBalances(walletIds: _walletIds, days: _days, asOf: _today);
  TextStyle get _dateStyle => CoconutTypography.body2_14.copyWith(color: context.coconutColors.secondaryText);

  int get _first => (_end - _span + 1).round().clamp(0, _days - 1);
  int get _last => _end.round().clamp(_first, _days - 1);

  @override
  void initState() {
    super.initState();
    _walletIds = vm.walletIds?.length == 1 ? [vm.walletIds!.single] : null;
    _readAnchor();
    _period = vm.balancePeriod;
    _span = (_period == HomeWidgetPeriod.all ? _allDays : _period.days).toDouble();
    _end = (_days - 1).toDouble();
    vm.data.addListener(_onData);
    WidgetsBinding.instance.addObserver(this);
  }

  void _readAnchor() {
    _today = vm.data.now;
    _allDays = math.max(2, vm.data.daysSinceFirstTransaction(walletIds: _walletIds, asOf: _today));
    _days = math.max(365, _allDays);
  }

  void _onData() => _reanchor();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _reanchor();
  }

  /// Moves the chart onto the data clock's calendar day. A block refresh and an app resume
  /// both land here; the selected calendar date stays, and a window pinned to today follows today.
  void _reanchor() {
    if (!mounted) return;
    final selectedDay = _selected == null ? null : _dates[_selected!];
    final pinnedToEnd = (_end - (_days - 1)).abs() < 0.5;
    final followedAll = _period == HomeWidgetPeriod.all && (_span - _allDays).abs() < 0.5;
    final previousToday = _localDate(_today);
    final previousDays = _days;
    setState(() {
      _readAnchor();
      if (followedAll) _span = _allDays.toDouble();
      _span = _span.clamp(HomeWidgetPeriod.week.days.toDouble(), _days.toDouble());
      final dayShift = _calendarDistance(previousToday, _localDate(_today));
      if (pinnedToEnd) {
        _end = (_days - 1).toDouble();
      } else {
        _end = (_end + (_days - previousDays) - dayShift).clamp(_span - 1, (_days - 1).toDouble());
      }
      if (selectedDay != null) {
        final index = _dates.indexOf(_localDate(selectedDay));
        _selected = index < 0 ? null : index;
      }
    });
  }

  @override
  void dispose() {
    _graphScrollController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    vm.data.removeListener(_onData);
    super.dispose();
  }

  void _selectPeriod(HomeWidgetPeriod period) => setState(() {
    _period = period;
    _span = (period == HomeWidgetPeriod.all ? _allDays : period.days).toDouble();
    _end = (_days - 1).toDouble();
    if (_selected != null) _selected = _selected!.clamp(_first, _last);
    _expanded.clear();
  });

  void _syncPeriod() {
    if ((_span - _allDays).abs() < 0.5 && (_period == HomeWidgetPeriod.all || _allDays > 365)) {
      _period = HomeWidgetPeriod.all;
      return;
    }
    final choices = [...HomeWidgetPeriod.widgetPeriods, HomeWidgetPeriod.all];
    int daysOf(HomeWidgetPeriod period) => period == HomeWidgetPeriod.all ? _allDays : period.days;
    _period = choices.reduce(
      (a, b) => (math.log(_span / daysOf(a))).abs() <= (math.log(_span / daysOf(b))).abs() ? a : b,
    );
  }

  void _focusAt(double x, double width) {
    final index = (_first + (x / width).clamp(0.0, 1.0) * (_last - _first)).round();
    if (index != _selected) {
      final balances = _balances;
      if (index > 0 && balances[index] != balances[index - 1]) vibrateExtraLight();
      setState(() {
        _selected = index;
        _expanded.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final balances = _balances;
    final dates = _dates;
    final selected = _selected;
    final unit = vm.data.unit;
    return Scaffold(
      backgroundColor: colors.homeBackground,
      appBar: CoconutAppBar.build(context: context, title: t.wallet_list.header.balance_history),
      body: SafeArea(
        top: false,
        bottom: selected == null,
        child: Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 12),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  selected == null ? t.hodl_insights.total_balance : DateFormat('yyyy.MM.dd').format(dates[selected]),
                  style: _dateStyle,
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: FittedBox(
                  child: Text(
                    unit.displayBitcoinAmount(balances[selected ?? balances.length - 1], withUnit: true),
                    style: CoconutTypography.heading2_28_NumberBold.copyWith(color: colors.primaryText),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _walletChips(),
              const SizedBox(height: 16),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final maxHeight = constraints.maxHeight;
                      const listGap = 12.0;
                      // Card expansion must not change the nested scroll range during a fling.
                      final preferredChart = selected == null ? maxHeight : maxHeight * 0.52;
                      var listHeight = math.max(0.0, maxHeight - preferredChart - listGap);
                      var chartTarget = preferredChart;
                      // A below-layout card can be a few pixels taller than the 52% leftover.
                      // Yield chart height until that card fits. The floor keeps the plot visible.
                      if (selected != null && _cardExtent > listHeight) {
                        final minChart = math.max(120.0, maxHeight * 0.36);
                        listHeight = math.min(_cardExtent, math.max(0.0, maxHeight - minChart - listGap));
                        chartTarget = math.max(minChart, maxHeight - listHeight - listGap);
                      }
                      // The header follows selection/expansion animations; nested scrolling
                      // consumes its remaining height before moving the lower list.
                      return TweenAnimationBuilder<double>(
                        duration: const Duration(milliseconds: 360),
                        curve: Curves.easeInOutCubic,
                        tween: Tween(end: chartTarget),
                        builder: (context, chartHeight, _) {
                          final graph = Hero(
                            tag: walletBalanceHistoryHeroTag,
                            flightShuttleBuilder: walletBalanceHistoryFlight,
                            child: Material(
                              key: const Key('balance-history-graph-surface'),
                              color: colors.homeSurface,
                              borderRadius: BorderRadius.circular(20),
                              clipBehavior: Clip.antiAlias,
                              child: _chart(balances, dates),
                            ),
                          );
                          if (selected == null || listHeight <= 0) {
                            return SizedBox(height: chartHeight, width: double.infinity, child: graph);
                          }
                          final expandedHeight = math.min(chartHeight, math.max(0.0, maxHeight - 120 - listGap));
                          final minimumHeight = math.min(200.0, expandedHeight);
                          final collapseRange = expandedHeight - minimumHeight;
                          _compactGraphOffset = (expandedHeight - maxHeight * 0.34).clamp(0.0, collapseRange);
                          return Stack(
                            children: [
                              Padding(
                                padding: EdgeInsets.only(top: minimumHeight + listGap),
                                child: NestedScrollView(
                                  key: const Key('balance-history-nested-scroll'),
                                  controller: _graphScrollController,
                                  headerSliverBuilder:
                                      (context, innerScrolled) => [
                                        SliverToBoxAdapter(child: SizedBox(height: collapseRange)),
                                      ],
                                  body: Builder(
                                    builder: (bodyContext) {
                                      _walletScrollController = PrimaryScrollController.of(bodyContext);
                                      return _wallets(dates[selected]);
                                    },
                                  ),
                                ),
                              ),
                              AnimatedBuilder(
                                animation: _graphScrollController,
                                child: graph,
                                builder: (context, child) {
                                  final offset =
                                      _graphScrollController.hasClients ? _graphScrollController.offset : 0.0;
                                  return Positioned(
                                    top: 0,
                                    left: 0,
                                    right: 0,
                                    height: minimumHeight + (collapseRange - offset).clamp(0.0, collapseRange),
                                    child: child!,
                                  );
                                },
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _selectWallet(int? walletId) {
    setState(() {
      _walletIds = walletId == null ? null : [walletId];
      _axisRange = null;
      _expanded.clear();
      _cardExtents.clear();
      _cardExtent = 0;
    });
    _reanchor();
  }

  Widget _walletChips() {
    final colors = context.coconutColors;
    final appearances = context.watchWalletAppearance();
    Widget chip(int? id, String label, {WalletItemBase? wallet}) {
      final background =
          wallet == null ? null : (appearances?.appearanceOf(wallet) ?? WalletAppearance.of(wallet)).background;
      final selected = id == null ? _walletIds == null : _walletIds?.contains(id) == true;
      return RepaintBoundary(
        child: Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Semantics(
            selected: selected,
            button: true,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(CoconutStyles.radius_500),
              child: Stack(
                children: [
                  if (wallet != null)
                    Positioned.fill(
                      child: WalletCardBackground(
                        background: background,
                        photoFile: appearances?.photoFileFor(wallet.id),
                        resizePhotoToDisplaySize: true,
                      ),
                    ),
                  WalletContentTheme(
                    background: background,
                    child: Builder(
                      builder:
                          (chipContext) => ExcludeSemantics(
                            child: CoconutChip(
                              key: ValueKey('balance-history-wallet-${id ?? 'all'}'),
                              label: label,
                              labelSize: 12,
                              minWidth: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              isSelected: selected,
                              color:
                                  wallet != null
                                      ? Colors.transparent
                                      : selected
                                      ? colors.chipSelectedBackground
                                      : colors.chipUnselectedBackground,
                              labelColor:
                                  wallet != null
                                      ? chipContext.coconutColors.primaryText
                                      : selected
                                      ? colors.chipSelectedText
                                      : colors.chipUnselectedText,
                              borderColor:
                                  wallet != null
                                      ? chipContext.coconutColors.primaryText
                                      : selected
                                      ? colors.chipSelectedText
                                      : colors.chipUnselectedText,
                              borderWidth: 0,
                              selectedBorderWidth: 1,
                              onTap: () => _selectWallet(id),
                            ),
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final wallets = vm.data.wallets;
    // 한 줄 칩의 실제 글꼴 배율에 맞춰 가로 뷰포트 높이를 확보한다.
    final labelHeight = _singleLineHeight(
      context,
      'Hg',
      const TextStyle(fontFamily: CoconutTypography.kTextFontFamily, fontSize: 12, fontWeight: FontWeight.bold),
    );
    return SizedBox(
      height: labelHeight.ceilToDouble() + 18,
      child: ListView.builder(
        key: const Key('balance-history-wallet-chips'),
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        cacheExtent: 80,
        itemCount: wallets.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) return chip(null, t.home_edit.all_wallets);
          final wallet = wallets[index - 1];
          return chip(wallet.id, wallet.name, wallet: wallet);
        },
      ),
    );
  }

  Widget _chart(List<int> balances, List<DateTime> dates) {
    final colors = context.coconutColors;
    final values = balances.sublist(_first, _last + 1);
    final dataMinimum = values.reduce(math.min);
    final dataMaximum = values.reduce(math.max);
    final previous = _axisRange;
    // 현재 축 안의 작은 변화에는 축을 유지하고, 충분히 확대했을 때만 다시 맞춘다.
    if (previous == null ||
        dataMinimum < previous.minimum ||
        dataMaximum > previous.maximum ||
        (dataMaximum - dataMinimum) < (previous.maximum - previous.minimum) * 0.2) {
      _axisRange = HomeWidgetMath.balanceAxisRange(dataMinimum, dataMaximum);
    }
    final minimum = _axisRange!.minimum;
    final maximum = _axisRange!.maximum;
    final selected = _selected;
    final localSelected = selected != null && selected >= _first && selected <= _last ? selected - _first : null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              reverse: true,
              child: BalanceHistoryPeriodChips(selected: _period, onSelected: _selectPeriod),
            ),
          ),
          const SizedBox(height: 46),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(vm.data.unit.symbol, style: CoconutTypography.caption_10.copyWith(color: colors.tertiaryText)),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _valueAxis(minimum, maximum),
                const SizedBox(width: 10),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth;
                      return GestureDetector(
                        key: const Key('balance-history-interactive-chart'),
                        behavior: HitTestBehavior.opaque,
                        onTapUp: (details) {
                          if (_selected == null) {
                            _focusAt(details.localPosition.dx, width);
                          } else {
                            setState(() {
                              _selected = null;
                              _expanded.clear();
                            });
                          }
                        },
                        onScaleStart: (details) {
                          _startSpan = _span;
                          _startEnd = _end;
                          _startPosition = details.localFocalPoint;
                          _pinching = details.pointerCount > 1;
                        },
                        onScaleUpdate: (details) {
                          if (details.pointerCount > 1) _pinching = true;
                          if (_selected != null && !_pinching) {
                            _focusAt(details.localFocalPoint.dx, width);
                            return;
                          }
                          if (_pinching && details.pointerCount < 2) return;
                          final delta = details.localFocalPoint - _startPosition;
                          final zoom =
                              _pinching
                                  ? details.scale
                                  : delta.dy.abs() > delta.dx.abs()
                                  ? math.exp(-delta.dy / 160)
                                  : 1.0;
                          final span = (_startSpan / zoom).clamp(
                            HomeWidgetPeriod.week.days.toDouble(),
                            _days.toDouble(),
                          );
                          final anchor =
                              _selected?.toDouble() ?? _startEnd - (_startSpan - 1) * (1 - _startPosition.dx / width);
                          final fraction =
                              _selected == null
                                  ? _startPosition.dx / width
                                  : ((_selected! - (_startEnd - _startSpan + 1)) / (_startSpan - 1)).clamp(0.0, 1.0);
                          setState(() {
                            _span = span;
                            _end = (zoom == 1 && !_pinching
                                    ? _startEnd - delta.dx / width * (_startSpan - 1)
                                    : anchor + (span - 1) * (1 - fraction))
                                .clamp(span - 1, (_days - 1).toDouble());
                            _syncPeriod();
                          });
                        },
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Positioned.fill(
                              child: CustomPaint(
                                key: const Key('balance-history-grid'),
                                painter: _BalanceHistoryGridPainter(
                                  amounts:
                                      _axisTickLayout(
                                        context,
                                        minimum,
                                        maximum,
                                        math.max(0, constraints.maxHeight - 4),
                                        CoconutTypography.caption_10_Number.copyWith(color: colors.tertiaryText),
                                      ).amounts,
                                  minimum: minimum,
                                  maximum: maximum,
                                  color: colors.tertiaryText.withValues(alpha: 0.2),
                                ),
                              ),
                            ),
                            Positioned.fill(
                              child: HomeSparkline(
                                values: values,
                                selectedIndex: localSelected,
                                minimum: minimum,
                                maximum: maximum,
                              ),
                            ),
                            if (localSelected != null)
                              Builder(
                                builder: (context) {
                                  final point = HomeSparkline.pointOf(values, localSelected, constraints.biggest);
                                  return Positioned(
                                    top: -52,
                                    width: 150,
                                    left: (point.dx - 75).clamp(0.0, math.max(0.0, width - 150)),
                                    child: Container(
                                      key: const Key('hodl-insights-balance-readout'),
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: colors.homeBackground,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            DateFormat('yyyy.MM.dd').format(dates[selected!]),
                                            style: CoconutTypography.body3_12.copyWith(color: colors.tertiaryText),
                                          ),
                                          FittedBox(
                                            child: Text(
                                              vm.data.unit.displayBitcoinAmount(values[localSelected], withUnit: true),
                                              style: CoconutTypography.body3_12_NumberBold.copyWith(
                                                color: colors.primaryText,
                                              ),
                                            ),
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
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final index in {_first, (_first + _last) ~/ 2, _last})
                Text(
                  DateFormat('yy.MM.dd').format(dates[index]),
                  style: CoconutTypography.body3_12.copyWith(color: colors.secondaryText),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _toggleWallet(int walletId, DateTime day) async {
    final request = ++_walletScrollRequest;
    final opening = !_expanded.contains(walletId);
    ScrollHoldController? hold;
    if (_graphScrollController.hasClients) {
      hold = _graphScrollController.position.hold(() => hold = null);
    }
    setState(() {
      if (opening) {
        _expanded.add(walletId);
      } else {
        _expanded.remove(walletId);
      }
    });
    if (opening && _graphScrollController.hasClients && _graphScrollController.offset < _compactGraphOffset) {
      // Use the existing collapse range instead of resizing its header underneath a ballistic activity.
      _graphScrollController.animateTo(
        _compactGraphOffset,
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeInOutCubic,
      );
    }
    // Hold remaining momentum until the expanded rows have finished changing height.
    await Future<void>.delayed(const Duration(milliseconds: 380));
    if (mounted && _graphScrollController.hasClients) hold?.cancel();
    if (!opening) return;
    if (!mounted ||
        request != _walletScrollRequest ||
        !_expanded.contains(walletId) ||
        _walletIds != null ||
        _selected == null ||
        _dates[_selected!] != day ||
        _walletScrollController?.hasClients != true) {
      return;
    }
    _WalletCardAnchorRenderBox? target;
    void findAnchor(RenderObject object) {
      if (object is _WalletCardAnchorRenderBox && object.identity == (day, _changedOnly, walletId)) {
        target = object;
      }
      object.visitChildren(findAnchor);
    }

    final scrollContext = _walletScrollController!.position.context.storageContext;
    if (!scrollContext.mounted) return;
    final root = scrollContext.findRenderObject();
    if (root == null) return;
    findAnchor(root);
    final anchor = target;
    if (anchor == null || !anchor.attached) return;
    final position = _walletScrollController!.position;
    final offset = RenderAbstractViewport.of(anchor).getOffsetToReveal(anchor, 0).offset - 12;
    await _walletScrollController!.animateTo(
      offset.clamp(position.minScrollExtent, position.maxScrollExtent),
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeInOutCubic,
    );
  }

  Widget _wallets(DateTime day) {
    if (_walletIds != null) return _transactions(day, _walletIds!.single);
    final colors = context.coconutColors;
    final end = DateTime(day.year, day.month, day.day + 1);
    final states =
        [
          for (final wallet in vm.data.wallets)
            if (_walletIds == null || _walletIds!.contains(wallet.id))
              () {
                final all = vm.data.transactionRecordsOf(wallet.id);
                final today =
                    all.where((tx) => !tx.timestamp.isBefore(day) && tx.timestamp.isBefore(end)).toList()
                      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
                return (
                  wallet: wallet,
                  transactions: today,
                  hasHistory: all.any((tx) => tx.timestamp.isBefore(end)),
                  balance:
                      vm.data.balanceOf(wallet.id) -
                      all.where((tx) => !tx.timestamp.isBefore(end)).fold<int>(0, (s, tx) => s + tx.amount),
                  change: today.fold<int>(0, (s, tx) => s + tx.amount),
                );
              }(),
        ].where((state) => state.hasHistory && (!_changedOnly || state.change != 0)).toList();
    if (_cardExtents.keys.any((index) => index >= states.length)) {
      _cardExtents.removeWhere((index, _) => index >= states.length);
      _scheduleCardExtent();
    }
    final appearances = context.watchWalletAppearance();
    Widget tile(int index) {
      final state = states[index];
      final expanded = _expanded.contains(state.wallet.id);
      final appearance = appearances?.appearanceOf(state.wallet) ?? WalletAppearance.of(state.wallet);
      return _WalletCardAnchor(
        identity: (day, _changedOnly, state.wallet.id),
        child: Container(
          foregroundDecoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border:
                state.transactions.isNotEmpty
                    ? Border.all(color: colors.secondaryText.withValues(alpha: 0.25), width: 1)
                    : null,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: ColoredBox(
              color: colors.homeSurface,
              child: Stack(
                children: [
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: 180,
                    child: WalletCardBackground(
                      background: appearance.background,
                      photoFile: appearances?.photoFileFor(state.wallet.id),
                      resizePhotoToDisplaySize: true,
                    ),
                  ),
                  WalletContentTheme(
                    background: appearance.background,
                    child: Builder(
                      builder:
                          (_) => Column(
                            children: [
                              _CardExtent(
                                onExtent: (height) => _noteCardExtent(index, height),
                                child: SizedBox(
                                  height: 180,
                                  child: WalletCard(
                                    key: ValueKey('balance-history-wallet-card-${state.wallet.id}'),
                                    wallet: state.wallet,
                                    appearance: appearance,
                                    backgroundPhoto: appearances?.photoFileFor(state.wallet.id),
                                    size: WalletCardSize.small,
                                    showBackground: false,
                                    balanceDisplay: vm.data.unit.displayBitcoinAmount(state.balance, withUnit: true),
                                    secondaryText:
                                        '${_changeLabel(state.change)} · ${t.wallet_list.balance_history_detail.transaction_count(n: state.transactions.length)}',
                                    onPressed:
                                        state.transactions.isEmpty ? null : () => _toggleWallet(state.wallet.id, day),
                                  ),
                                ),
                              ),
                              AnimatedSize(
                                duration: const Duration(milliseconds: 280),
                                alignment: Alignment.topCenter,
                                child:
                                    expanded
                                        ? Theme(
                                          data: Theme.of(context),
                                          child: ColoredBox(
                                            color: colors.homeSurface,
                                            child: Padding(
                                              padding: const EdgeInsets.only(bottom: 8),
                                              child: ClipRRect(
                                                borderRadius: BorderRadius.circular(20),
                                                child: Column(
                                                  children: [
                                                    Padding(
                                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                                      child: Divider(height: 1, color: colors.divider),
                                                    ),
                                                    const SizedBox(height: 8),
                                                    for (final tx in state.transactions)
                                                      TransactionItemCard(
                                                        tx: tx,
                                                        id: state.wallet.id,
                                                        currentUnit: vm.data.unit,
                                                        compact: true,
                                                        backgroundColor: Colors.transparent,
                                                        padding: const EdgeInsets.symmetric(
                                                          horizontal: 20,
                                                          vertical: 10,
                                                        ),
                                                        onPressed:
                                                            () => Navigator.pushNamed(
                                                              context,
                                                              AppRouteNames.transactionDetail,
                                                              arguments: TransactionDetailRouteArgs(
                                                                id: state.wallet.id,
                                                                txHash: tx.transactionHash,
                                                              ),
                                                            ),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        )
                                        : const SizedBox.shrink(),
                              ),
                            ],
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _walletSectionHeader(states.length),
        const SizedBox(height: 4),
        Expanded(
          child: Stack(
            children: [
              ListView(
                key: const Key('balance-history-wallet-list'),
                padding: const EdgeInsets.only(top: 8),
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 280),
                    layoutBuilder:
                        (current, previous) => Stack(
                          alignment: Alignment.topCenter,
                          children: [
                            for (final outgoing in previous) ExcludeSemantics(child: IgnorePointer(child: outgoing)),
                            if (current != null) current,
                          ],
                        ),
                    transitionBuilder:
                        (child, animation) => FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween(begin: const Offset(0, 0.08), end: Offset.zero).animate(animation),
                            child: child,
                          ),
                        ),
                    child: Column(
                      key: ValueKey((day, _changedOnly, states.isEmpty)),
                      children: [
                        if (states.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Text(
                              t.wallet_list.balance_history_detail.no_wallets,
                              textAlign: TextAlign.center,
                              style: CoconutTypography.body2_14.copyWith(color: colors.secondaryText),
                            ),
                          )
                        else
                          for (var index = 0; index < states.length; index++) ...[
                            tile(index),
                            if (index != states.length - 1) const SizedBox(height: 8),
                          ],
                        SizedBox(height: MediaQuery.viewPaddingOf(context).bottom),
                      ],
                    ),
                  ),
                ],
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 12,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [colors.homeBackground, colors.homeBackground.withValues(alpha: 0)],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _transactions(DateTime day, int walletId) {
    final colors = context.coconutColors;
    final wallet = vm.data.wallets.firstWhere((wallet) => wallet.id == walletId);
    final end = DateTime(day.year, day.month, day.day + 1);
    final records =
        vm.data
            .transactionRecordsOf(walletId)
            .where((tx) => !tx.timestamp.isBefore(day) && tx.timestamp.isBefore(end))
            .toList()
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final transactions = [
      for (final tx in records)
        HomeRecentTransaction(
          walletId: walletId,
          walletName: wallet.name,
          amount: tx.amount,
          time: tx.timestamp,
          type: tx.transactionType,
          status: TransactionUtil.getStatus(tx),
          txHash: tx.transactionHash,
        ),
    ];
    final history = RecentTransactionsView(
      key: ValueKey((walletId, day)),
      transactions: transactions,
      showAllTransactions: true,
      emptyMessage: t.wallet_list.balance_history_detail.no_transactions_at_date,
      amountText: (amount) => vm.data.unit.displayBitcoinAmount(amount, withUnit: true),
      now: vm.data.now,
      onTransactionSelected:
          (tx) => Navigator.pushNamed(
            context,
            AppRouteNames.transactionDetail,
            arguments: TransactionDetailRouteArgs(id: walletId, txHash: tx.txHash!),
          ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${t.wallet_list.balance_history_detail.transactions_at_date} · ${transactions.length}',
          key: const Key('balance-history-transactions-header'),
          style: CoconutTypography.body1_16_Bold.copyWith(color: colors.primaryText),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: Stack(
            children: [
              ListView(
                padding: const EdgeInsets.only(top: 8),
                children: [
                  if (transactions.isEmpty) SizedBox(height: 140, child: history) else history,
                  SizedBox(height: MediaQuery.viewPaddingOf(context).bottom),
                ],
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 12,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [colors.homeBackground, colors.homeBackground.withValues(alpha: 0)],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _walletSectionHeader(int count) {
    final colors = context.coconutColors;
    final title = '${t.wallet_list.balance_history_detail.wallets_at_date} · $count';
    final filterLabel = t.wallet_list.balance_history_detail.changed_wallets_only;
    final titleStyle = CoconutTypography.body1_16_Bold.copyWith(color: colors.primaryText);
    final filterStyle = CoconutTypography.caption_10.copyWith(color: colors.secondaryText);
    return LayoutBuilder(
      key: const Key('balance-history-wallet-header'),
      builder: (context, constraints) {
        final titleWidth = _singleLineWidth(context, title, titleStyle);
        final filterWidth = _singleLineWidth(context, filterLabel, filterStyle) + 14 + 6;
        final sideBySide = titleWidth + 8 + filterWidth <= constraints.maxWidth;
        final titleText = Text(title, style: titleStyle);
        final filter = _changedOnlyFilter(expandLabel: !sideBySide);
        if (sideBySide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [Expanded(child: titleText), const SizedBox(width: 8), filter],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [titleText, const SizedBox(height: 8), filter],
        );
      },
    );
  }

  Widget _changedOnlyFilter({required bool expandLabel}) {
    final colors = context.coconutColors;
    final label = Text(
      t.wallet_list.balance_history_detail.changed_wallets_only,
      textAlign: expandLabel ? TextAlign.start : TextAlign.end,
      style: CoconutTypography.caption_10.copyWith(color: colors.secondaryText),
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _changedOnly = !_changedOnly),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: Sizes.size44),
        child: Row(
          mainAxisSize: expandLabel ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: expandLabel ? MainAxisAlignment.start : MainAxisAlignment.end,
          children: [
            CoconutCheckbox(
              isSelected: _changedOnly,
              width: 14,
              color: colors.iconPrimary,
              unSelectedColor: colors.iconSecondary,
              inactiveColor: colors.iconDisabled,
              onChanged: (_) => setState(() => _changedOnly = !_changedOnly),
            ),
            const SizedBox(width: 6),
            if (expandLabel) Expanded(child: label) else label,
          ],
        ),
      ),
    );
  }

  /// Right-aligned caption ticks. Five labels while their measured heights fit, or while
  /// fitting them stays at least the 1× caption height. Fewer ticks only after that.
  /// A stack of measured slots, not a flex column, so a subpixel miss cannot overflow.
  ({List<int> amounts, double scale}) _axisTickLayout(
    BuildContext context,
    int minimum,
    int maximum,
    double maxHeight,
    TextStyle style,
  ) {
    final designHeight = _singleLineHeight(context, '0', style, textScaler: TextScaler.noScaling);
    var amounts = _axisTickAmounts(minimum, maximum, 4);
    var scale = 1.0;
    var accepted = false;
    for (final intervals in const [4, 2, 1]) {
      final candidate = _axisTickAmounts(minimum, maximum, intervals);
      final heights = [
        for (final amount in candidate) _singleLineHeight(context, vm.data.unit.displayBitcoinAmount(amount), style),
      ];
      final sum = heights.fold<double>(0, (total, height) => total + height);
      if (sum <= 0) continue;
      final candidateScale = sum <= maxHeight ? 1.0 : maxHeight / sum;
      final shortest = heights.reduce(math.min) * candidateScale;
      if (candidateScale == 1.0 || shortest >= designHeight) {
        amounts = candidate;
        scale = candidateScale;
        accepted = true;
        break;
      }
    }
    if (!accepted) {
      amounts = [maximum.round()];
      final height = _singleLineHeight(context, vm.data.unit.displayBitcoinAmount(amounts.first), style);
      scale = height <= maxHeight ? 1.0 : maxHeight / height;
    }
    return (amounts: amounts, scale: scale);
  }

  Widget _valueAxis(int minimum, int maximum) {
    final style = CoconutTypography.caption_10_Number.copyWith(color: context.coconutColors.tertiaryText);
    return SizedBox(
      key: const Key('balance-history-value-axis'),
      width: 46,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxHeight = constraints.maxHeight;
            if (!constraints.hasBoundedHeight || maxHeight <= 0) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [for (final amount in _axisTickAmounts(minimum, maximum, 4)) _axisLabel(amount, style)],
              );
            }
            final layout = _axisTickLayout(context, minimum, maximum, maxHeight, style);
            final amounts = layout.amounts;
            final scale = layout.scale;
            final boxHeights = [
              for (final amount in amounts)
                math.min(
                  maxHeight,
                  _singleLineHeight(context, vm.data.unit.displayBitcoinAmount(amount), style) * scale,
                ),
            ];
            final count = amounts.length;
            final used = boxHeights.fold<double>(0, (total, height) => total + height);
            final gap = scale == 1 && count > 1 ? math.max(0.0, (maxHeight - used) / (count - 1)) : 0.0;
            final ticks = <Widget>[];
            var cursor = 0.0;
            for (var index = 0; index < count; index++) {
              final top =
                  count == 1 && minimum == maximum
                      ? math.max(0.0, (maxHeight - boxHeights[index]) / 2)
                      : index == count - 1
                      ? math.max(0.0, maxHeight - boxHeights[index])
                      : cursor;
              ticks.add(
                Positioned(
                  top: top,
                  left: 0,
                  right: 0,
                  height: boxHeights[index],
                  child: Align(
                    alignment:
                        count == 1
                            ? Alignment.centerRight
                            : index == 0
                            ? Alignment.topRight
                            : index == count - 1
                            ? Alignment.bottomRight
                            : Alignment.centerRight,
                    child: _axisLabel(amounts[index], style),
                  ),
                ),
              );
              cursor += boxHeights[index] + gap;
            }
            return SizedBox(
              width: constraints.maxWidth,
              height: maxHeight,
              child: Stack(clipBehavior: Clip.none, children: ticks),
            );
          },
        ),
      ),
    );
  }

  Widget _axisLabel(int amount, TextStyle style) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerRight,
      child: Text(vm.data.unit.displayBitcoinAmount(amount), style: style),
    );
  }

  void _noteCardExtent(int index, double height) {
    final previous = _cardExtents[index];
    if (previous != null && (previous - height).abs() < 0.5) return;
    _cardExtents[index] = height;
    _scheduleCardExtent();
  }

  void _scheduleCardExtent() {
    var next = 0.0;
    for (final value in _cardExtents.values) {
      if (value > next) next = value;
    }
    if ((next - _cardExtent).abs() < 0.5) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      var resolved = 0.0;
      for (final value in _cardExtents.values) {
        if (value > resolved) resolved = value;
      }
      if ((resolved - _cardExtent).abs() < 0.5) return;
      setState(() => _cardExtent = resolved);
    });
  }

  String _changeLabel(int change) =>
      '${change > 0 ? '+' : ''}${vm.data.unit.displayBitcoinAmount(change, withUnit: true)}';
}

DateTime _localDate(DateTime time) {
  final local = time.toLocal();
  return DateTime(local.year, local.month, local.day);
}

int _calendarDistance(DateTime from, DateTime to) =>
    DateTime.utc(to.year, to.month, to.day).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

double _singleLineWidth(BuildContext context, String text, TextStyle style) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    maxLines: 1,
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
  )..layout();
  final width = painter.width;
  painter.dispose();
  return width;
}

double _singleLineHeight(BuildContext context, String text, TextStyle style, {TextScaler? textScaler}) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    maxLines: 1,
    textDirection: Directionality.of(context),
    textScaler: textScaler ?? MediaQuery.textScalerOf(context),
  )..layout();
  final height = painter.height;
  painter.dispose();
  return height;
}

List<int> _axisTickAmounts(int minimum, int maximum, int intervals) {
  return {
    for (var tick = intervals; tick >= 0; tick--) (minimum + (maximum - minimum) * tick / intervals).round(),
  }.toList();
}

class _BalanceHistoryGridPainter extends CustomPainter {
  final List<int> amounts;
  final int minimum;
  final int maximum;
  final Color color;

  const _BalanceHistoryGridPainter({
    required this.amounts,
    required this.minimum,
    required this.maximum,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final paint =
        Paint()
          ..color = color
          ..strokeWidth = 1;
    for (final amount in amounts) {
      final ratio = maximum == minimum ? 0.5 : (amount - minimum) / (maximum - minimum);
      // Match HomeSparkline's two-pixel inset and balance scale.
      final y = 2 + (size.height - 4) * (1 - ratio);
      for (var x = 0.0; x < size.width; x += 8) {
        canvas.drawLine(Offset(x, y), Offset(math.min(x + 4, size.width), y), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BalanceHistoryGridPainter oldDelegate) =>
      oldDelegate.minimum != minimum ||
      oldDelegate.maximum != maximum ||
      oldDelegate.color != color ||
      !listEquals(oldDelegate.amounts, amounts);
}

/// A local render marker avoids sharing GlobalKeys with AnimatedSwitcher's outgoing cards.
class _WalletCardAnchor extends SingleChildRenderObjectWidget {
  final (DateTime, bool, int) identity;

  const _WalletCardAnchor({required this.identity, required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => _WalletCardAnchorRenderBox(identity);

  @override
  void updateRenderObject(BuildContext context, _WalletCardAnchorRenderBox renderObject) {
    renderObject.identity = identity;
  }
}

class _WalletCardAnchorRenderBox extends RenderProxyBox {
  (DateTime, bool, int) identity;
  _WalletCardAnchorRenderBox(this.identity);
}

class _CardExtent extends SingleChildRenderObjectWidget {
  const _CardExtent({required this.onExtent, required super.child});

  final ValueChanged<double> onExtent;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderCardExtent(onExtent);

  @override
  void updateRenderObject(BuildContext context, _RenderCardExtent renderObject) {
    renderObject.onExtent = onExtent;
  }
}

class _RenderCardExtent extends RenderProxyBox {
  _RenderCardExtent(this.onExtent);

  ValueChanged<double> onExtent;
  double? _reported;

  @override
  void performLayout() {
    super.performLayout();
    final height = size.height;
    if (_reported != null && (height - _reported!).abs() < 0.5) return;
    _reported = height;
    WidgetsBinding.instance.addPostFrameCallback((_) => onExtent(height));
  }
}
