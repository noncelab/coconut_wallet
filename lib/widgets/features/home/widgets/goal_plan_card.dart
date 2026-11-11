import 'dart:async';
import 'dart:math' as math;

import 'package:coconut_design_system/coconut_design_system.dart' show CoconutLayout, CoconutTypography;
import 'package:coconut_wallet/constants/shared_pref_keys.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/widgets/common/buttons/shrink_animation_button.dart';
import 'package:coconut_wallet/widgets/common/overlays/common_bottom_sheets.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// 모으기 계획: 언제까지 채울지
enum GoalPlanPeriod {
  oneMonth(1),
  threeMonths(3),
  sixMonths(6),
  oneYear(12),

  /// 날짜를 직접 고른다. 기간은 고른 날짜로 정한다.
  custom(0);

  final int months;
  const GoalPlanPeriod(this.months);

  String get label => switch (this) {
    GoalPlanPeriod.oneMonth => t.hodl_insights.goal_plan_one_month,
    GoalPlanPeriod.threeMonths => t.hodl_insights.goal_plan_three_months,
    GoalPlanPeriod.sixMonths => t.hodl_insights.goal_plan_six_months,
    GoalPlanPeriod.oneYear => t.hodl_insights.goal_plan_one_year,
    GoalPlanPeriod.custom => t.hodl_insights.goal_plan_custom,
  };
}

/// 모으기 계획: 얼마나 자주 모을지
enum GoalPlanCycle {
  daily,
  weekly,
  monthly;

  String get label => switch (this) {
    GoalPlanCycle.daily => t.hodl_insights.goal_plan_daily,
    GoalPlanCycle.weekly => t.hodl_insights.goal_plan_weekly,
    GoalPlanCycle.monthly => t.hodl_insights.goal_plan_monthly,
  };
}

/// 남은 수량을 기간 안의 모으는 횟수로 나눈다.
abstract final class GoalPlanMath {
  /// 직접 고를 수 있는 가장 먼 날: 오늘부터 50년
  static const maxCustomYears = 50;

  static DateTime dateOnly(DateTime time) => DateTime(time.year, time.month, time.day);

  /// 채울 날. 직접 고르면 그 날, 아니면 오늘부터 [period] 뒤의 같은 날(그 달에 없으면 마지막 날).
  static DateTime deadline(DateTime today, GoalPlanPeriod period, {DateTime? customDate}) {
    if (period == GoalPlanPeriod.custom) return dateOnly(customDate!);
    final month = DateTime(today.year, today.month + period.months);
    final lastDay = DateTime(month.year, month.month + 1, 0).day;
    return DateTime(month.year, month.month, math.min(today.day, lastDay));
  }

  /// 기간 안에 모으는 횟수. 최소 1회
  static int installments(DateTime today, GoalPlanPeriod period, GoalPlanCycle cycle, {DateTime? customDate}) {
    final end = deadline(today, period, customDate: customDate);
    // 날짜만 비교한다. 서머타임 경계의 23시간짜리 하루도 하루로 센다.
    final days =
        DateTime.utc(end.year, end.month, end.day).difference(DateTime.utc(today.year, today.month, today.day)).inDays;
    final count = switch (cycle) {
      GoalPlanCycle.daily => days,
      GoalPlanCycle.weekly => days ~/ 7,
      GoalPlanCycle.monthly => period == GoalPlanPeriod.custom ? _wholeMonths(today, end) : period.months,
    };
    return math.max(1, count);
  }

  /// 오늘부터 [end]까지 다 채운 달 수
  static int _wholeMonths(DateTime today, DateTime end) =>
      (end.year - today.year) * 12 + end.month - today.month - (end.day < today.day ? 1 : 0);

  /// 한 번에 모을 수량(sats). 합이 남은 수량보다 모자라지 않게 올림한다.
  static int perInstallment(int remainingSats, int installments) =>
      remainingSats <= 0 ? 0 : (remainingSats + installments - 1) ~/ installments;
}

/// 모으기 계획의 기간·주기. 기기에 저장해 화면을 다시 열어도 그대로이고, 모으기 알림도 이 주기를 따른다.
class GoalPlanController extends ChangeNotifier {
  static const defaultPeriod = GoalPlanPeriod.threeMonths;
  static const defaultCycle = GoalPlanCycle.weekly;

  final DateTime today;
  late GoalPlanPeriod _period;
  late GoalPlanCycle _cycle;

  /// [GoalPlanPeriod.custom]일 때 고른 날
  DateTime? _customDate;

  GoalPlanController({required this.today}) {
    final preferences = _preferences;
    _period = _read(preferences, SharedPrefKeys.kGoalPlanPeriod, GoalPlanPeriod.values, defaultPeriod);
    _cycle = _read(preferences, SharedPrefKeys.kGoalPlanCycle, GoalPlanCycle.values, defaultCycle);
    if (_period == GoalPlanPeriod.custom) {
      final saved = DateTime.tryParse(preferences?.getString(SharedPrefKeys.kGoalPlanCustomDate) ?? '');
      // 고른 날이 지났으면 기본 기간으로 돌아간다.
      if (saved != null && GoalPlanMath.dateOnly(saved).isAfter(GoalPlanMath.dateOnly(today))) {
        _customDate = GoalPlanMath.dateOnly(saved);
      } else {
        _period = defaultPeriod;
      }
    }
  }

  GoalPlanPeriod get period => _period;
  GoalPlanCycle get cycle => _cycle;
  DateTime? get customDate => _customDate;

  int get installments => GoalPlanMath.installments(today, _period, _cycle, customDate: _customDate);

  int perInstallment(int remainingSats) => GoalPlanMath.perInstallment(remainingSats, installments);

  static SharedPrefsRepository? get _preferences {
    final preferences = SharedPrefsRepository();
    return preferences.isInitialized ? preferences : null;
  }

  static T _read<T extends Enum>(SharedPrefsRepository? preferences, String key, List<T> values, T fallback) {
    final name = preferences?.getString(key) ?? '';
    for (final value in values) {
      if (value.name == name) return value;
    }
    return fallback;
  }

  static void _save(String key, String value) {
    final preferences = _preferences;
    if (preferences == null) return;
    unawaited(
      preferences.setStringAndConfirm(key, value).then((saved) {
        if (!saved) Logger.error('Failed to save goal plan: $key');
      }),
    );
  }

  void selectPeriod(GoalPlanPeriod period) {
    if (period == GoalPlanPeriod.custom || period == _period) return;
    _period = period;
    notifyListeners();
    _save(SharedPrefKeys.kGoalPlanPeriod, period.name);
  }

  void selectCustomDate(DateTime date) {
    final day = GoalPlanMath.dateOnly(date);
    _period = GoalPlanPeriod.custom;
    _customDate = day;
    notifyListeners();
    _save(SharedPrefKeys.kGoalPlanCustomDate, day.toIso8601String());
    _save(SharedPrefKeys.kGoalPlanPeriod, GoalPlanPeriod.custom.name);
  }

  void selectCycle(GoalPlanCycle cycle) {
    if (cycle == _cycle) return;
    _cycle = cycle;
    notifyListeners();
    _save(SharedPrefKeys.kGoalPlanCycle, cycle.name);
  }
}

/// 목표 수량 화면의 세 번째 카드. 기간과 주기를 고르면 한 번에 모을 수량을 보여 준다.
/// 고른 값은 기기에 저장해 화면을 다시 열어도 그대로다.
class GoalPlanCard extends StatefulWidget {
  final int remainingSats;
  final DateTime today;
  final String Function(int sats) amountText;

  /// 법정화폐 환산 문구. 시세가 없으면 null
  final String? Function(int sats) fiatText;

  /// 모으기 알림과 함께 쓰려면 넘긴다. 없으면 카드가 직접 만든다.
  final GoalPlanController? controller;

  const GoalPlanCard({
    super.key,
    required this.remainingSats,
    required this.today,
    required this.amountText,
    required this.fiatText,
    this.controller,
  });

  @override
  State<GoalPlanCard> createState() => _GoalPlanCardState();
}

class _GoalPlanCardState extends State<GoalPlanCard> {
  late final GoalPlanController _controller = widget.controller ?? GoalPlanController(today: widget.today);

  GoalPlanPeriod get _period => _controller.period;
  GoalPlanCycle get _cycle => _controller.cycle;
  DateTime? get _customDate => _controller.customDate;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  Future<void> _selectPeriod(GoalPlanPeriod period) async {
    if (period == GoalPlanPeriod.custom) {
      // 이미 직접 고른 상태여도 다시 눌러 날짜를 바꿀 수 있다.
      final picked = await _GoalDateSheet.open(
        context,
        today: widget.today,
        initial: _customDate ?? GoalPlanMath.deadline(widget.today, _period),
      );
      if (picked == null || !mounted) return;
      _controller.selectCustomDate(picked);
      return;
    }
    _controller.selectPeriod(period);
  }

  void _selectCycle(GoalPlanCycle cycle) => _controller.selectCycle(cycle);

  static String _formatDate(DateTime date) => '${date.year}.${date.month}.${date.day}';

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final copy = t.hodl_insights;
    final reached = widget.remainingSats <= 0;
    final count = GoalPlanMath.installments(widget.today, _period, _cycle, customDate: _customDate);
    final per = GoalPlanMath.perInstallment(widget.remainingSats, count);
    final end = GoalPlanMath.deadline(widget.today, _period, customDate: _customDate);
    final fiat = widget.fiatText(per);
    final questionStyle = CoconutTypography.body3_12.copyWith(color: colors.secondaryTextStrong);
    return Container(
      key: const Key('goal-plan-card'),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: colors.homeSurface, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(copy.goal_plan_title, style: CoconutTypography.body1_16_Bold.copyWith(color: colors.primaryText)),
          CoconutLayout.spacing_400h,
          if (reached)
            Text(copy.goal_plan_reached, key: const Key('goal-plan-reached'), style: questionStyle)
          else ...[
            Text(copy.goal_plan_period_question, style: questionStyle),
            CoconutLayout.spacing_200h,
            _Segments<GoalPlanPeriod>(
              keyPrefix: 'goal-plan-period',
              values: GoalPlanPeriod.values,
              selected: _period,
              label: (value) => value.label,
              onSelected: _selectPeriod,
            ),
            if (_period == GoalPlanPeriod.custom && _customDate != null) ...[
              CoconutLayout.spacing_200h,
              ShrinkAnimationButton(
                key: const Key('goal-plan-custom-date'),
                onPressed: () => _selectPeriod(GoalPlanPeriod.custom),
                defaultColor: colors.homeBackground,
                pressedOverlayColor: colors.primaryText,
                pressedOverlayOpacity: 0.16,
                borderRadius: 10,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      Icon(CupertinoIcons.calendar, size: 16, color: colors.secondaryTextStrong),
                      const SizedBox(width: 8),
                      Expanded(child: Text(copy.goal_plan_custom_date, style: questionStyle)),
                      Text(
                        _formatDate(_customDate!),
                        key: const Key('goal-plan-custom-date-text'),
                        style: CoconutTypography.body3_12_Bold.copyWith(color: colors.primaryText),
                      ),
                      const SizedBox(width: 4),
                      Icon(CupertinoIcons.chevron_right, size: 14, color: colors.tertiaryText),
                    ],
                  ),
                ),
              ),
            ],
            CoconutLayout.spacing_400h,
            Text(copy.goal_plan_cycle_question, style: questionStyle),
            CoconutLayout.spacing_200h,
            _Segments<GoalPlanCycle>(
              keyPrefix: 'goal-plan-cycle',
              values: GoalPlanCycle.values,
              selected: _cycle,
              label: (value) => value.label,
              onSelected: _selectCycle,
            ),
            CoconutLayout.spacing_400h,
            Container(
              key: const Key('goal-plan-result'),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: colors.homeBackground, borderRadius: BorderRadius.circular(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    copy.goal_plan_until(date: _formatDate(end), cycle: _cycle.label),
                    key: const Key('goal-plan-until'),
                    style: questionStyle,
                  ),
                  CoconutLayout.spacing_100h,
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      widget.amountText(per),
                      key: const Key('goal-plan-per'),
                      style: CoconutTypography.heading3_21_NumberBold.copyWith(color: colors.primaryText),
                    ),
                  ),
                  CoconutLayout.spacing_100h,
                  Text(
                    [if (fiat != null) '≈ $fiat', copy.goal_plan_count(count: count)].join(' · '),
                    key: const Key('goal-plan-count'),
                    style: CoconutTypography.body3_12.copyWith(color: colors.secondaryTextStrong),
                  ),
                ],
              ),
            ),
            CoconutLayout.spacing_200h,
            Text(copy.goal_plan_note, style: CoconutTypography.caption_10.copyWith(color: colors.tertiaryText)),
          ],
        ],
      ),
    );
  }
}

class _Segments<T extends Enum> extends StatelessWidget {
  final String keyPrefix;
  final List<T> values;
  final T selected;
  final String Function(T value) label;
  final ValueChanged<T> onSelected;

  const _Segments({
    required this.keyPrefix,
    required this.values,
    required this.selected,
    required this.label,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    return Row(
      children: [
        for (var i = 0; i < values.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: ShrinkAnimationButton(
              key: ValueKey('$keyPrefix-${values[i].name}'),
              onPressed: () => onSelected(values[i]),
              defaultColor: values[i] == selected ? colors.primaryText : colors.homeBackground,
              pressedOverlayColor: values[i] == selected ? colors.background : colors.primaryText,
              pressedOverlayOpacity: values[i] == selected ? 0.12 : 0.16,
              borderRadius: 10,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label(values[i]),
                      maxLines: 1,
                      style: (values[i] == selected ? CoconutTypography.body3_12_Bold : CoconutTypography.body3_12)
                          .copyWith(color: values[i] == selected ? colors.background : colors.secondaryTextStrong),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// 모으기 계획의 '직접' 기간: 채울 날을 고른다. 내일부터 [GoalPlanMath.maxCustomYears]년 뒤까지.
class _GoalDateSheet extends StatefulWidget {
  final DateTime today;
  final DateTime initial;

  const _GoalDateSheet({required this.today, required this.initial});

  static Future<DateTime?> open(BuildContext context, {required DateTime today, required DateTime initial}) =>
      CommonBottomSheets.showBottomSheet<DateTime>(
        context: context,
        screenName: '/goal-plan-date',
        title: t.hodl_insights.goal_plan_custom_title,
        showCloseButton: true,
        child: _GoalDateSheet(today: today, initial: initial),
      );

  @override
  State<_GoalDateSheet> createState() => _GoalDateSheetState();
}

class _GoalDateSheetState extends State<_GoalDateSheet> {
  late final DateTime _first = GoalPlanMath.dateOnly(widget.today).add(const Duration(days: 1));
  late final DateTime _last = DateTime(_first.year + GoalPlanMath.maxCustomYears, _first.month, _first.day);
  late DateTime _value = _clamp(GoalPlanMath.dateOnly(widget.initial));

  DateTime _clamp(DateTime date) => date.isBefore(_first) ? _first : (date.isAfter(_last) ? _last : date);

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 216,
            // 앱은 기본(영어) Cupertino 문구만 등록한다. 날짜 휠만 앱 언어로 보여 준다.
            child: Localizations.override(
              context: context,
              locale: LocaleSettings.currentLocale.flutterLocale,
              delegates: const [GlobalCupertinoLocalizations.delegate],
              child: CupertinoTheme(
                data: CupertinoThemeData(
                  brightness: Theme.of(context).brightness,
                  textTheme: CupertinoTextThemeData(
                    dateTimePickerTextStyle: CoconutTypography.heading4_18.copyWith(color: colors.primaryText),
                  ),
                ),
                child: CupertinoDatePicker(
                  key: const Key('goal-plan-date-picker'),
                  mode: CupertinoDatePickerMode.date,
                  initialDateTime: _value,
                  minimumDate: _first,
                  maximumDate: _last,
                  onDateTimeChanged: (date) => _value = _clamp(GoalPlanMath.dateOnly(date)),
                ),
              ),
            ),
          ),
          CoconutLayout.spacing_400h,
          ShrinkAnimationButton(
            key: const Key('goal-plan-date-done'),
            onPressed: () => Navigator.of(context).pop(_value),
            defaultColor: colors.primaryText,
            pressedOverlayColor: colors.homeSurfacePressOverlay,
            pressedOverlayOpacity: colors.homeSurfacePressOverlayOpacity,
            borderRadius: 12,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Center(
                child: Text(t.complete, style: CoconutTypography.body2_14_Bold.copyWith(color: colors.background)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
