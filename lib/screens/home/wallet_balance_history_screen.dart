import 'dart:math' as math;
import 'package:coconut_design_system/coconut_design_system.dart' hide CoconutAppBar;
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/constants/shared_pref_keys.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:coconut_wallet/widgets/common/buttons/shrink_animation_button.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/home/home_widget_settings.dart';
import 'package:coconut_wallet/providers/view_model/home/hodl_insights_view_model.dart';
import 'package:coconut_wallet/services/home/home_widget_math.dart';
import 'package:coconut_wallet/ui/coconut/coconut_app_bar.dart';
import 'package:coconut_wallet/utils/vibration_util.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/balance_history_period_chips.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/home_widget_parts.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/balance_history_wallet_breakdown.dart';
import 'package:coconut_wallet/model/wallet/wallet_appearance.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/providers/wallet_appearance_provider.dart';
import 'package:coconut_wallet/widgets/features/wallet/card/wallet_card_background.dart';
import 'package:coconut_wallet/widgets/features/wallet/card/wallet_card.dart' show WalletContentTheme;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode, listEquals;
import 'package:flutter_svg/svg.dart';
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
  double _startSpan = 1;
  double _startEnd = 0;
  Offset _startPosition = Offset.zero;
  bool _pinching = false;
  double _edgeOverscroll = 0;
  late bool _showGestureGuide;

  HodlInsightsViewModel get vm => widget.viewModel;
  List<DateTime> get _dates => HomeWidgetMath.lastDays(_today, _days);
  List<int> get _balances => vm.data.dailyBalances(walletIds: _walletIds, days: _days, asOf: _today);

  int get _first => (_end - _span + 1).round().clamp(0, _days - 1);
  int get _last => _end.round().clamp(_first, _days - 1);

  @override
  void initState() {
    super.initState();
    final preferences = SharedPrefsRepository();
    _showGestureGuide =
        kDebugMode ||
        !preferences.isInitialized ||
        !preferences.getBool(SharedPrefKeys.kBalanceHistoryGestureGuideDismissed);
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
    WidgetsBinding.instance.removeObserver(this);
    vm.data.removeListener(_onData);
    super.dispose();
  }

  void _selectPeriod(HomeWidgetPeriod period) => setState(() {
    _edgeOverscroll = 0;
    _period = period;
    _span = (period == HomeWidgetPeriod.all ? _allDays : period.days).toDouble();
    _end = (_days - 1).toDouble();
    if (_selected != null) _selected = _selected!.clamp(_first, _last);
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
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final balances = _balances;
    final dates = _dates;
    return Scaffold(
      backgroundColor: colors.homeBackground,
      appBar: CoconutAppBar.build(context: context, title: t.wallet_list.header.balance_history),
      body: SafeArea(
        top: false,
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 12),
          child: Column(
            children: [
              _walletChips(),
              const SizedBox(height: 16),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final graphHeight = math.min(
                        constraints.maxWidth / 1.43,
                        math.max(0.0, constraints.maxHeight - 120),
                      );
                      return Column(
                        children: [
                          SizedBox(
                            height: graphHeight,
                            width: double.infinity,
                            child: Hero(
                              tag: walletBalanceHistoryHeroTag,
                              flightShuttleBuilder: walletBalanceHistoryFlight,
                              child: Material(
                                key: const Key('balance-history-graph-surface'),
                                color: colors.homeSurface,
                                borderRadius: BorderRadius.circular(20),
                                clipBehavior: Clip.antiAlias,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    ExcludeSemantics(excluding: _showGestureGuide, child: _chart(balances, dates)),
                                    if (_showGestureGuide) _BalanceHistoryGestureGuide(onDismiss: _dismissGestureGuide),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Expanded(child: _walletBreakdown(dates, balances)),
                        ],
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
      _edgeOverscroll = 0;
      _walletIds = walletId == null ? null : [walletId];
      _axisRange = null;
    });
    _reanchor();
  }

  Future<void> _dismissGestureGuide() async {
    setState(() => _showGestureGuide = false);
    final preferences = SharedPrefsRepository();
    if (preferences.isInitialized) {
      await preferences.setBool(SharedPrefKeys.kBalanceHistoryGestureGuideDismissed, true);
    }
  }

  Widget _walletChips() {
    final colors = context.coconutColors;
    final appearances = context.watchWalletAppearance();
    Widget chip(int? id, String label, {WalletItemBase? wallet, bool isLast = false}) {
      final background =
          wallet == null ? null : (appearances?.appearanceOf(wallet) ?? WalletAppearance.of(wallet)).background;
      final selected = id == null ? _walletIds == null : _walletIds?.contains(id) == true;
      return RepaintBoundary(
        child: Padding(
          padding: EdgeInsets.only(right: isLast ? 0 : 8),
          child: Semantics(
            selected: selected,
            button: true,
            child: Align(
              widthFactor: 1,
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
                              child: DefaultTextStyle.merge(
                                style: const TextStyle(height: 1.4, leadingDistribution: TextLeadingDistribution.even),
                                child: DecoratedBox(
                                  position: DecorationPosition.foreground,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(CoconutStyles.radius_500),
                                    border:
                                        selected
                                            ? Border.all(
                                              color:
                                                  wallet != null
                                                      ? chipContext.coconutColors.primaryText
                                                      : colors.chipSelectedText,
                                            )
                                            : null,
                                  ),
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
                                    borderColor: Colors.transparent,
                                    borderWidth: 0,
                                    selectedBorderWidth: 0,
                                    onTap: () => _selectWallet(id),
                                  ),
                                ),
                              ),
                            ),
                      ),
                    ),
                  ],
                ),
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
      const TextStyle(
        fontFamily: CoconutTypography.kTextFontFamily,
        fontSize: 12,
        fontWeight: FontWeight.bold,
        height: 1.4,
        leadingDistribution: TextLeadingDistribution.even,
      ),
    );
    return SizedBox(
      height: labelHeight.ceilToDouble() + 18,
      child: ListView.builder(
        key: const Key('balance-history-wallet-chips'),
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        cacheExtent: 80,
        itemCount: wallets.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) return chip(null, t.home_edit.all_wallets, isLast: wallets.isEmpty);
          final wallet = wallets[index - 1];
          return chip(wallet.id, wallet.name, wallet: wallet, isLast: index == wallets.length);
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
    final axisStyle = CoconutTypography.caption_10_Number.copyWith(color: colors.tertiaryText);
    final axisWidth = _axisTickAmounts(minimum, maximum, 4)
        .map((amount) => _singleLineWidth(context, vm.data.unit.displayBitcoinAmount(amount), axisStyle))
        .reduce(math.max)
        .clamp(0.0, 46.0);
    final selected = _selected;
    final localSelected = selected != null && selected >= _first && selected <= _last ? selected - _first : null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
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
          const SizedBox(height: 8),
          Padding(
            padding: EdgeInsets.only(left: axisWidth + 10),
            child: Row(
              key: const Key('balance-history-date-axis'),
              children: [
                for (var i = 0; i < 7; i++)
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _displayDate(dates[_first + ((_last - _first) * i / 6).round()]),
                        style: CoconutTypography.caption_10.copyWith(color: colors.secondaryText),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _valueAxis(minimum, maximum, axisWidth),
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
                            });
                          }
                        },
                        onScaleStart: (details) {
                          setState(() => _edgeOverscroll = 0);
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
                          final panning = zoom == 1 && !_pinching;
                          final requestedEnd =
                              panning
                                  ? _startEnd - delta.dx / width * (_startSpan - 1)
                                  : anchor + (span - 1) * (1 - fraction);
                          final end = requestedEnd.clamp(span - 1, (_days - 1).toDouble());
                          setState(() {
                            _span = span;
                            _end = end;
                            _edgeOverscroll =
                                panning ? ((requestedEnd - end) * width / (_startSpan - 1)).clamp(-width, width) : 0;
                            _syncPeriod();
                          });
                        },
                        onScaleEnd: (_) => setState(() => _edgeOverscroll = 0),
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
                                    top: 8,
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
                            Positioned.fill(
                              child: IgnorePointer(
                                child: TweenAnimationBuilder<double>(
                                  key: const Key('balance-history-edge-feedback'),
                                  tween: Tween(end: _edgeOverscroll),
                                  duration: Duration(milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 160),
                                  curve: Curves.easeOutCubic,
                                  builder:
                                      (context, amount, _) =>
                                          CustomPaint(painter: _BalanceHistoryEdgePainter(amount, colors.tertiaryText)),
                                ),
                              ),
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
        ],
      ),
    );
  }

  Widget _walletBreakdown(List<DateTime> dates, List<int> balances) {
    final index = _selected ?? _last;
    final start = dates[_selected ?? _first];
    final end = dates[index];
    final exclusiveEnd = DateTime(end.year, end.month, end.day + 1);
    final period =
        _selected == null ? '${_displayDate(start)} ~ ${_displayDate(end)}' : DateFormat('yyyy.MM.dd').format(end);
    final slices = [
      for (final wallet in vm.data.wallets)
        if (_walletIds == null || _walletIds!.contains(wallet.id))
          BalanceHistoryWalletSlice(
            wallet: wallet,
            balance: vm.data.dailyBalances(walletIds: [wallet.id], days: _days, asOf: _today)[index],
            transactions:
                vm.data
                    .transactionRecordsOf(wallet.id)
                    .where((tx) => !tx.timestamp.isBefore(start) && tx.timestamp.isBefore(exclusiveEnd))
                    .toList(),
          ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Wrap(
            key: const Key('balance-history-breakdown-header'),
            alignment: WrapAlignment.spaceBetween,
            spacing: 12,
            runSpacing: 4,
            children: [
              Text(period, style: CoconutTypography.body2_14_Bold.copyWith(color: context.coconutColors.primaryText)),
              if (_selected != null)
                Text(
                  vm.data.unit.displayBitcoinAmount(balances[index], withUnit: true),
                  style: CoconutTypography.body2_14_NumberBold.copyWith(color: context.coconutColors.primaryText),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: SingleChildScrollView(
            key: const Key('balance-history-breakdown-scroll'),
            padding: EdgeInsets.only(bottom: MediaQuery.viewPaddingOf(context).bottom + 16),
            child: BalanceHistoryWalletBreakdown(
              slices: slices,
              periodLabel: period,
              focusedDate: _selected == null ? null : end,
              singleWallet: _walletIds != null,
              amountText: (sats) => vm.data.unit.displayBitcoinAmount(sats, withUnit: true),
            ),
          ),
        ),
      ],
    );
  }

  String _displayDate(DateTime date) => switch (LocaleSettings.currentLocale) {
    AppLocale.ko => DateFormat('M/d').format(date),
    AppLocale.en => DateFormat('MMM d', 'en_US').format(date).toUpperCase(),
    _ => DateFormat(t.wallet_card_detail_screen.chart_date_format).format(date),
  };

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

  Widget _valueAxis(int minimum, int maximum, double width) {
    final style = CoconutTypography.caption_10_Number.copyWith(color: context.coconutColors.tertiaryText);
    return SizedBox(
      key: const Key('balance-history-value-axis'),
      width: width,
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
            final ticks = <Widget>[];
            for (var index = 0; index < amounts.length; index++) {
              final ratio = maximum == minimum ? 0.5 : (amounts[index] - minimum) / (maximum - minimum);
              // Padding supplies the same 2px inset used by the graph and grid.
              final top = maxHeight * (1 - ratio) - boxHeights[index] / 2;
              ticks.add(
                Positioned(
                  top: top,
                  left: 0,
                  right: 0,
                  height: boxHeights[index],
                  child: Align(alignment: Alignment.centerRight, child: _axisLabel(amounts[index], style)),
                ),
              );
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

class _BalanceHistoryGestureGuide extends StatelessWidget {
  final VoidCallback onDismiss;
  const _BalanceHistoryGestureGuide({required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    Widget instruction(SvgPicture icon, String text) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        icon,
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: CoconutTypography.body3_12.copyWith(color: colors.primaryText))),
      ],
    );
    return GestureDetector(
      key: const Key('balance-history-gesture-guide'),
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: ColoredBox(
        color: colors.homeSurface.withValues(alpha: 0.7),
        child: LayoutBuilder(
          builder:
              (context, constraints) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          t.wallet_list.balance_history_detail.gesture_guide_title,
                          style: CoconutTypography.body2_14_Bold.copyWith(color: colors.primaryText),
                        ),
                        const SizedBox(height: 12),
                        instruction(
                          SvgPicture.asset(CommonNavigationIconPath.arrowLeftRight),
                          t.wallet_list.balance_history_detail.gesture_guide_pan,
                        ),
                        const SizedBox(height: 10),
                        instruction(
                          SvgPicture.asset(CommonNavigationIconPath.arrowUpDown),
                          t.wallet_list.balance_history_detail.gesture_guide_zoom,
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: ShrinkAnimationButton(
                            key: const Key('balance-history-gesture-guide-dismiss'),
                            onPressed: onDismiss,
                            defaultColor: colors.primaryText,
                            borderWidth: 0,
                            borderRadius: 12,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                              child: Text(
                                t.confirm,
                                style: CoconutTypography.body3_12_Bold.copyWith(color: colors.homeSurface),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
        ),
      ),
    );
  }
}

class _BalanceHistoryEdgePainter extends CustomPainter {
  final double overscroll;
  final Color color;
  const _BalanceHistoryEdgePainter(this.overscroll, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || overscroll.abs() < 0.1) return;
    final extent = (overscroll.abs() / 4).clamp(0.0, 24.0);
    final right = overscroll > 0;
    final x = right ? size.width : 0.0;
    final direction = right ? -1 : 1;
    final edge =
        Path()
          ..moveTo(x, 0)
          ..quadraticBezierTo(x + direction * extent * 2, size.height / 2, x, size.height)
          ..close();
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.drawPath(
      edge,
      Paint()
        ..shader = LinearGradient(
          begin: right ? Alignment.centerRight : Alignment.centerLeft,
          end: right ? Alignment.centerLeft : Alignment.centerRight,
          colors: [color.withValues(alpha: 0.3), color.withValues(alpha: 0)],
        ).createShader(Rect.fromLTWH(right ? size.width - extent : 0, 0, extent, size.height)),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _BalanceHistoryEdgePainter oldDelegate) =>
      overscroll != oldDelegate.overscroll || color != oldDelegate.color;
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
