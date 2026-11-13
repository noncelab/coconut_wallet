import 'dart:async';
import 'dart:math' as math;

import 'package:coconut_design_system/coconut_design_system.dart' show CoconutLayout, CoconutTypography;
import 'package:coconut_wallet/constants/shared_pref_keys.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/widgets/common/buttons/fixed_bottom_button.dart';
import 'package:coconut_wallet/widgets/common/buttons/segmented_choice.dart';
import 'package:coconut_wallet/widgets/common/bottom_sheet/selectable_settings_row.dart';
import 'package:coconut_wallet/widgets/common/buttons/value_select_row.dart';
import 'package:coconut_wallet/widgets/common/info/inline_notice.dart';
import 'package:coconut_wallet/widgets/common/overlays/common_bottom_sheets.dart';
import 'package:coconut_wallet/widgets/common/text/keep_words.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart';

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

/// 남은 수량을 마감일 전까지 모으는 날로 나눈다.
abstract final class GoalPlanMath {
  /// 직접 고를 수 있는 기간: 내일부터 50년
  static const maxCustomYears = 50;

  static DateTime dateOnly(DateTime time) => DateTime(time.year, time.month, time.day);

  /// [date]부터 [months]개월 뒤의 같은 날. 그 달에 없으면 마지막 날(1/31 + 1개월 = 2/28). [date]가 UTC면 UTC로 돌려준다.
  static DateTime addMonths(DateTime date, int months) {
    final month = DateTime.utc(date.year, date.month + months);
    final lastDay = DateTime.utc(month.year, month.month + 1, 0).day;
    final day = math.min(date.day, lastDay);
    return date.isUtc ? DateTime.utc(month.year, month.month, day) : DateTime(month.year, month.month, day);
  }

  /// 프리셋을 고른 날 정하는 마감일: [today]부터 [period] 뒤의 같은 날
  static DateTime presetDeadline(DateTime today, GoalPlanPeriod period) => addMonths(dateOnly(today), period.months);

  /// 직접 고를 수 있는 첫날: [today] 다음 날. 하루를 24시간으로 더하면 서머타임이 끝나는 날 같은 날이 나오므로 날짜로 만든다.
  static DateTime firstCustomDay(DateTime today) => DateTime(today.year, today.month, today.day + 1);

  /// 직접 고를 수 있는 마지막 날: 첫날부터 [maxCustomYears]년 뒤. 저장된 마감일도 이보다 뒤면 쓰지 않는다.
  static DateTime lastCustomDay(DateTime today) {
    final first = firstCustomDay(today);
    return DateTime(first.year + maxCustomYears, first.month, first.day);
  }

  /// [first]부터 [cycle]마다 오는 날 중 [deadline]보다 앞선 날(첫날 포함, 마감일 당일 제외).
  /// 매월은 매번 [first]의 날에 맞추고 그 날이 없는 달은 마지막 날을 쓴다(1/31 → 2/28 → 3/31 → 4/30).
  /// 날짜만 본다. 첫날이 마감일과 같거나 뒤면 없다.
  static Iterable<DateTime> dates({
    required DateTime first,
    required DateTime deadline,
    required GoalPlanCycle cycle,
  }) => _utcDates(first, deadline, cycle).map((date) => DateTime(date.year, date.month, date.day));

  /// [dates]의 수. 로컬 날짜를 만들지 않고 센다.
  static int occurrences({required DateTime first, required DateTime deadline, required GoalPlanCycle cycle}) =>
      _utcDates(first, deadline, cycle).length;

  /// [dates]와 같은 연·월·일을 UTC 날짜로 만든다(시각을 UTC로 바꾸는 게 아니다).
  /// 로컬 날짜는 만들 때마다 시간대를 계산해 50년·매일이면 셀 때마다 수 ms가 걸린다.
  static Iterable<DateTime> _utcDates(DateTime first, DateTime deadline, GoalPlanCycle cycle) sync* {
    final start = DateTime.utc(first.year, first.month, first.day);
    final end = DateTime.utc(deadline.year, deadline.month, deadline.day);
    for (var k = 0; ; k++) {
      final date = switch (cycle) {
        GoalPlanCycle.daily => DateTime.utc(start.year, start.month, start.day + k),
        GoalPlanCycle.weekly => DateTime.utc(start.year, start.month, start.day + 7 * k),
        GoalPlanCycle.monthly => addMonths(start, k),
      };
      if (!date.isBefore(end)) return;
      yield date;
    }
  }

  /// 한 번에 모을 수량(sats). 합이 남은 수량보다 모자라지 않게 올림한다.
  /// 모을 날이 없으면([count] 0) 나눌 수 없으므로 null이다.
  static int? perInstallment(int remainingSats, int count) {
    if (count <= 0) return null;
    return remainingSats <= 0 ? 0 : (remainingSats + count - 1) ~/ count;
  }
}

/// 모으기 계획의 기간·주기·마감일. 마감일은 기간을 고른 날 정해 저장하고, 화면을 다시 열어도 그대로 쓴다.
/// 마감일 당일이 되면 남은 날이 없으므로, 그날부터는 기본 3개월을 오늘부터 정한 계획으로 본다([settle]이 저장).
class GoalPlanController extends ChangeNotifier {
  static const defaultPeriod = GoalPlanPeriod.threeMonths;
  static const defaultCycle = GoalPlanCycle.weekly;

  late GoalPlanPeriod _period;
  late GoalPlanCycle _cycle;

  /// 저장된 마감일. 아직 정하지 않았거나 읽을 수 없으면 null
  DateTime? _deadline;

  /// 모으는 요일(1=월~7=일)과 날짜(1~28). 아직 정하지 않았으면 null이고, 그동안은 오늘의 요일·날짜를 쓴다.
  int? _weekday;
  int? _day;

  static const maxDay = 28;

  /// 저장된 계획을 읽기만 한다. 아직 정하지 않은 계획은 카드가 처음 보일 때 [settle]로 저장한다.
  GoalPlanController() {
    final preferences = _preferences;
    _period = _read(preferences, SharedPrefKeys.kGoalPlanPeriod, GoalPlanPeriod.values, defaultPeriod);
    _cycle = _read(preferences, SharedPrefKeys.kGoalPlanCycle, GoalPlanCycle.values, defaultCycle);
    _deadline = _readDay(preferences, SharedPrefKeys.kGoalPlanDeadline);
    _weekday = _readNumber(preferences, SharedPrefKeys.kGoalPlanWeekday, DateTime.monday, DateTime.sunday);
    _day = _readNumber(preferences, SharedPrefKeys.kGoalPlanDay, 1, maxDay);
  }

  /// [today]의 모으는 요일. 정하지 않았으면 오늘의 요일
  int weekdayOn(DateTime today) => _weekday ?? today.weekday;

  /// [today]의 모으는 날짜. 정하지 않았으면 오늘 날짜(29~31일이면 28일)
  int dayOn(DateTime today) => _day ?? math.min(today.day, maxDay);

  /// 오늘부터 처음 오는 모으는 날(오늘이 그날이면 오늘). 횟수는 이날부터 마감일 전날까지 센다.
  DateTime firstSaveDayOn(DateTime today) {
    final day = GoalPlanMath.dateOnly(today);
    switch (_cycle) {
      case GoalPlanCycle.daily:
        return day;
      case GoalPlanCycle.weekly:
        // 하루를 24시간으로 더하면 서머타임이 끝나는 날 전날 23시가 되므로 달력 날짜로 만든다(firstCustomDay와 같음).
        return DateTime(day.year, day.month, day.day + (weekdayOn(today) - day.weekday) % 7);
      case GoalPlanCycle.monthly:
        final thisMonth = DateTime(day.year, day.month, dayOn(today));
        return thisMonth.isBefore(day) ? DateTime(day.year, day.month + 1, dayOn(today)) : thisMonth;
    }
  }

  void selectWeekday(int weekday) {
    _weekday = weekday;
    notifyListeners();
    _save(SharedPrefKeys.kGoalPlanWeekday, '$weekday');
  }

  void selectDay(int day) {
    _day = day;
    notifyListeners();
    _save(SharedPrefKeys.kGoalPlanDay, '$day');
  }

  GoalPlanCycle get cycle => _cycle;

  /// 저장된 마감일. [settle]이 새로 정하기 전까지는 지난 마감일도 그대로 읽을 수 있다.
  DateTime? get savedDeadline => _deadline;

  /// 저장된 마감일이 [today]보다 뒤이고 날짜 선택으로 고를 수 있는 마지막 날까지면 그대로 쓴다.
  bool _isValidOn(DateTime today) {
    final deadline = _deadline;
    final day = GoalPlanMath.dateOnly(today);
    return deadline != null && day.isBefore(deadline) && !deadline.isAfter(GoalPlanMath.lastCustomDay(day));
  }

  /// 저장된 마감일이 [today]에 됐거나 지났는지(남은 날이 없음)
  bool isExpiredOn(DateTime today) => _deadline != null && !GoalPlanMath.dateOnly(today).isBefore(_deadline!);

  /// [today]에 아직 저장하지 않은 계획을 보여 주고 있는지([settle]이 필요한지)
  bool needsSettleOn(DateTime today) => !_isValidOn(today);

  /// 모으는 요일·날짜를 저장했는지(아직이면 카드가 처음 보일 때 [settle]로 오늘 것을 저장한다)
  bool get hasSaveDays => _weekday != null && _day != null;

  /// [today]의 기간. 저장된 마감일을 쓸 수 없으면 기본 3개월
  GoalPlanPeriod periodOn(DateTime today) => _isValidOn(today) ? _period : defaultPeriod;

  /// [today]의 마감일. 저장된 마감일을 쓸 수 없으면 오늘부터 기본 3개월
  DateTime deadlineOn(DateTime today) =>
      _isValidOn(today) ? _deadline! : GoalPlanMath.presetDeadline(today, defaultPeriod);

  /// [first](기본은 [today])부터 마감일 전까지 모으는 횟수
  int occurrencesOn(DateTime today, {DateTime? first}) =>
      GoalPlanMath.occurrences(first: first ?? firstSaveDayOn(today), deadline: deadlineOn(today), cycle: _cycle);

  int? perInstallment(int remainingSats, DateTime today, {DateTime? first}) =>
      GoalPlanMath.perInstallment(remainingSats, occurrencesOn(today, first: first));

  /// [today]에 보여 주는 계획을 저장한다. 저장된 마감일을 쓸 수 없으면(아직 없음, 당일·지남, 손상)
  /// 기본 3개월을 오늘부터 정한다. 다시 정하기 전에 저장돼 있던 마감일을 돌려준다(없었거나 그대로 쓰면 null).
  /// 지난 계획에 알림이 있으면 [isExpiredOn]·[savedDeadline]으로 먼저 끈 뒤에 부른다.
  DateTime? settle(DateTime today) {
    // 모으는 요일·날짜를 아직 정하지 않았으면 오늘 것으로 정해 둔다(날마다 바뀌지 않게).
    if (_weekday == null || _day == null) {
      _weekday ??= today.weekday;
      _day ??= math.min(today.day, maxDay);
      _save(SharedPrefKeys.kGoalPlanWeekday, '$_weekday');
      _save(SharedPrefKeys.kGoalPlanDay, '$_day');
    }
    if (_isValidOn(today)) return null;
    final previous = _deadline;
    _period = defaultPeriod;
    _deadline = GoalPlanMath.presetDeadline(today, defaultPeriod);
    notifyListeners();
    _save(SharedPrefKeys.kGoalPlanPeriod, _period.name);
    _save(SharedPrefKeys.kGoalPlanDeadline, _formatDay(_deadline!));
    return previous;
  }

  static SharedPrefsRepository? get _preferences {
    final preferences = SharedPrefsRepository();
    return preferences.isInitialized ? preferences : null;
  }

  /// 저장된 글자. 글자가 아닌 값(숫자 등)이 저장돼 있으면 저장값이 없는 것으로 본다.
  static String _readString(SharedPrefsRepository? preferences, String key) {
    try {
      return preferences?.getString(key) ?? '';
    } on TypeError {
      return '';
    }
  }

  static T _read<T extends Enum>(SharedPrefsRepository? preferences, String key, List<T> values, T fallback) {
    final name = _readString(preferences, key);
    for (final value in values) {
      if (value.name == name) return value;
    }
    return fallback;
  }

  /// 저장된 날짜. 저장할 때 쓰는 yyyy-MM-dd 그대로가 아니면(없는 날 2027-02-31 포함) 저장값이 없는 것으로 본다.
  static int? _readNumber(SharedPrefsRepository? preferences, String key, int min, int max) {
    final value = int.tryParse(_readString(preferences, key));
    return value != null && value >= min && value <= max ? value : null;
  }

  static DateTime? _readDay(SharedPrefsRepository? preferences, String key) {
    final text = _readString(preferences, key);
    final date = DateTime.tryParse(text);
    return date != null && _formatDay(date) == text ? date : null;
  }

  static String _formatDay(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

  /// 저장에 실패하면 이번 화면에서는 고른 계획을 그대로 쓰고, 다음에 열 때 다시 정한다(로그를 남긴다).
  static void _save(String key, String value) {
    final preferences = _preferences;
    if (preferences == null) return;
    unawaited(
      preferences
          .setStringAndConfirm(key, value)
          .then((saved) {
            if (!saved) Logger.error('Failed to save goal plan: $key');
          })
          .catchError((Object error) {
            Logger.error('Failed to save goal plan: $key, $error');
          }),
    );
  }

  /// 프리셋을 고르면 [today]부터 그 기간 뒤로 마감일을 정한다. 지금 계획과 같은 기간이면 그대로 둔다.
  void selectPeriod(GoalPlanPeriod period, {required DateTime today}) {
    if (period == GoalPlanPeriod.custom || (_isValidOn(today) && period == _period)) return;
    _period = period;
    _deadline = GoalPlanMath.presetDeadline(today, period);
    notifyListeners();
    _save(SharedPrefKeys.kGoalPlanPeriod, period.name);
    _save(SharedPrefKeys.kGoalPlanDeadline, _formatDay(_deadline!));
  }

  void selectCustomDate(DateTime date) {
    _period = GoalPlanPeriod.custom;
    _deadline = GoalPlanMath.dateOnly(date);
    notifyListeners();
    _save(SharedPrefKeys.kGoalPlanPeriod, GoalPlanPeriod.custom.name);
    _save(SharedPrefKeys.kGoalPlanDeadline, _formatDay(_deadline!));
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

  /// 화면과 같은 시계. 그릴 때와 누를 때마다 오늘을 여기서 읽는다.
  /// 날짜가 바뀐 뒤 화면을 다시 그리기 전에 눌러도 누른 날로 정한다.
  final DateTime Function() clock;
  final String Function(int sats) amountText;

  /// 법정화폐 환산 문구. 시세가 없으면 null
  final String? Function(int sats) fiatText;

  /// 화면이 계획을 함께 쓰려면 넘긴다. 없으면 카드가 직접 만든다.
  final GoalPlanController? controller;

  /// 처음 모으는 날. 없으면 오늘
  final DateTime? first;

  /// 남은 수량은 없지만 아직 달성이 아님(동기화 중·확인 전 입출금·확인된 잔액 부족). '이미 채웠어요' 대신 잔액을 확인하는
  /// 중이라는 한 줄(입금인지 송금인지 가리지 않는 문구)
  final bool awaitingConfirmation;

  /// 같은 계정 지갑끼리 잔액이 달라 확인 대기 중(B1-a). 회당 수량과 달성을 미루고 그 이유 한 줄
  final bool amountOnHold;

  const GoalPlanCard({
    super.key,
    required this.remainingSats,
    required this.clock,
    required this.amountText,
    required this.fiatText,
    this.controller,
    this.first,
    this.awaitingConfirmation = false,
    this.amountOnHold = false,
  });

  @override
  State<GoalPlanCard> createState() => _GoalPlanCardState();
}

class _GoalPlanCardState extends State<GoalPlanCard> {
  late final GoalPlanController _controller = widget.controller ?? GoalPlanController();

  GoalPlanCycle get _cycle => _controller.cycle;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
  }

  /// [today]에 보여 준 계획(처음 기본값, 마감일 당일·지남의 새 3개월)을 저장한다. 그리는 중에는 저장하지 않는다.
  /// 저장된 마감일이 지나 오늘부터 3개월로 다시 잡았으면 그 마감일. 이 카드에서 기간·날짜를 새로 정하면 지운다.
  /// 화면에만 두는 값이라 화면을 다시 열면 보이지 않는다.
  DateTime? _resetFrom;

  void _settleAfterFrame(DateTime today) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // 마감일이 실제로 지났을 때만 알린다(고를 수 없는 먼 날짜·손상된 값을 다시 잡을 때는 알리지 않는다).
      final expired = _controller.isExpiredOn(today);
      final previous = _controller.settle(today);
      if (expired && previous != null && mounted) setState(() => _resetFrom = previous);
    });
  }

  void _clearReset() {
    if (_resetFrom != null) setState(() => _resetFrom = null);
  }

  Future<void> _pickWeekday() async {
    final picked = await GoalPlanWeekdaySheet.open(context, weekday: _controller.weekdayOn(widget.clock()));
    if (picked != null && mounted) _controller.selectWeekday(picked);
  }

  Future<void> _pickDay() async {
    final picked = await GoalPlanDaySheet.open(context, day: _controller.dayOn(widget.clock()));
    if (picked != null && mounted) _controller.selectDay(picked);
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
    // 마지막으로 그린 날이 아니라 누른 날로 정한다.
    final today = widget.clock();
    if (period == GoalPlanPeriod.custom) {
      // '목표 날짜' 줄로 직접 고른 날을 바꿀 때도 여기로 온다.
      final picked = await _GoalDateSheet.open(context, today: today, initial: _controller.deadlineOn(today));
      if (!mounted) return;
      if (picked == null) {
        // 기간 선택 칸은 누른 칸을 먼저 표시한다. 닫았으면 다시 그려 원래 기간을 표시하게 한다.
        setState(() {});
        return;
      }
      _controller.selectCustomDate(picked);
      _clearReset();
      return;
    }
    _controller.selectPeriod(period, today: today);
    _clearReset();
  }

  void _selectCycle(GoalPlanCycle cycle) => _controller.selectCycle(cycle);

  static String _formatDate(DateTime date) => DateFormat('yyyy.MM.dd').format(date);

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final copy = t.hodl_insights;
    final today = widget.clock();
    // 같은 계정 잔액을 확인하는 동안은 달성으로 보지 않고 계획을 그대로 보여 준다
    final reached = widget.remainingSats <= 0 && !widget.amountOnHold;
    // 화면을 연 채 날짜가 바뀌어도 다시 열었을 때와 같게 한다.
    if (!reached && (_controller.needsSettleOn(today) || !_controller.hasSaveDays)) _settleAfterFrame(today);
    final period = _controller.periodOn(today);
    final end = _controller.deadlineOn(today);
    final count = _controller.occurrencesOn(today, first: widget.first);
    // 모을 날이 없으면(처음 모으는 날이 마감일과 같거나 뒤) 회당 수량과 횟수를 보여 주지 않는다.
    final per = widget.amountOnHold ? null : GoalPlanMath.perInstallment(widget.remainingSats, count);
    final fiat = per == null ? null : widget.fiatText(per);
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
          if (reached && widget.awaitingConfirmation)
            InlineNotice(
              key: const Key('goal-plan-pending'),
              icon: CupertinoIcons.clock,
              message: copy.goal_plan_pending,
            )
          else if (reached)
            Text(
              keepWords(copy.goal_plan_reached),
              key: const Key('goal-plan-reached'),
              semanticsLabel: copy.goal_plan_reached,
              style: questionStyle,
            )
          else ...[
            if (_resetFrom != null) ...[
              InlineNotice(
                key: const Key('goal-plan-reset'),
                icon: CupertinoIcons.arrow_counterclockwise,
                message: copy.goal_plan_reset_notice(date: _formatDate(_resetFrom!)),
              ),
              CoconutLayout.spacing_300h,
            ],
            Text(copy.goal_plan_period_question, style: questionStyle),
            CoconutLayout.spacing_200h,
            SegmentedChoice<GoalPlanPeriod>(
              keyOf: (value) => 'goal-plan-period-${value.name}',
              values: GoalPlanPeriod.values,
              selected: period,
              label: (value) => value.label,
              onSelected: _selectPeriod,
            ),
            if (period == GoalPlanPeriod.custom) ...[
              CoconutLayout.spacing_200h,
              ValueSelectRow(
                key: const Key('goal-plan-custom-date'),
                icon: CupertinoIcons.calendar,
                label: copy.goal_plan_custom_date,
                value: _formatDate(end),
                valueKey: const Key('goal-plan-custom-date-text'),
                onPressed: () => _selectPeriod(GoalPlanPeriod.custom),
              ),
            ],
            CoconutLayout.spacing_400h,
            Text(copy.goal_plan_cycle_question, style: questionStyle),
            CoconutLayout.spacing_200h,
            SegmentedChoice<GoalPlanCycle>(
              keyOf: (value) => 'goal-plan-cycle-${value.name}',
              values: GoalPlanCycle.values,
              selected: _cycle,
              label: (value) => value.label,
              onSelected: _selectCycle,
            ),
            // 모으는 날: 매주면 요일, 매월이면 날짜(1~28일). 알림도 이 날을 따른다.
            if (_cycle == GoalPlanCycle.weekly) ...[
              CoconutLayout.spacing_200h,
              ValueSelectRow(
                key: const Key('goal-plan-weekday'),
                icon: CupertinoIcons.calendar,
                label: copy.goal_plan_weekday,
                value: copy.goal_plan_weekdays[_controller.weekdayOn(today) - 1],
                onPressed: _pickWeekday,
              ),
            ],
            if (_cycle == GoalPlanCycle.monthly) ...[
              CoconutLayout.spacing_200h,
              ValueSelectRow(
                key: const Key('goal-plan-day'),
                icon: CupertinoIcons.calendar,
                label: copy.goal_plan_day,
                value: copy.goal_plan_day_value(day: _controller.dayOn(today)),
                onPressed: _pickDay,
              ),
            ],
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
                  if (widget.amountOnHold) ...[
                    CoconutLayout.spacing_100h,
                    Text(
                      keepWords(copy.goal_plan_amount_on_hold),
                      key: const Key('goal-plan-on-hold'),
                      semanticsLabel: copy.goal_plan_amount_on_hold,
                      style: CoconutTypography.body3_12_Bold.copyWith(color: colors.primaryText),
                    ),
                  ],
                  if (per != null) ...[
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
                ],
              ),
            ),
            CoconutLayout.spacing_200h,
            Text(
              keepWords(copy.goal_plan_note),
              semanticsLabel: copy.goal_plan_note,
              style: CoconutTypography.caption_10.copyWith(color: colors.tertiaryText),
            ),
          ],
        ],
      ),
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
  late final DateTime _first = GoalPlanMath.firstCustomDay(widget.today);
  late final DateTime _last = GoalPlanMath.lastCustomDay(widget.today);
  late DateTime _value = _clamp(GoalPlanMath.dateOnly(widget.initial));

  DateTime _clamp(DateTime date) => date.isBefore(_first) ? _first : (date.isAfter(_last) ? _last : date);

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + MediaQuery.paddingOf(context).bottom),
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
          // FixedBottomButton과 같은 모양의 버튼을 글자 크기에 맞는 높이로 둔다.
          InlineActionButton(
            key: const Key('goal-plan-date-done'),
            text: t.complete,
            onPressed: () => Navigator.of(context).pop(_value),
          ),
        ],
      ),
    );
  }
}

/// 모으는 요일 고르기. 설정 시트(단위·언어)와 같은 선택 줄로, 누르면 고르고 닫힌다.
class GoalPlanWeekdaySheet extends StatelessWidget {
  final int weekday;

  const GoalPlanWeekdaySheet({super.key, required this.weekday});

  static Future<int?> open(BuildContext context, {required int weekday}) => CommonBottomSheets.showBottomSheet<int>(
    context: context,
    screenName: '/goal-plan-weekday',
    title: t.hodl_insights.goal_plan_weekday,
    showCloseButton: true,
    child: GoalPlanWeekdaySheet(weekday: weekday),
  );

  @override
  Widget build(BuildContext context) {
    final names = t.hodl_insights.goal_plan_weekdays;
    // 큰 글자·작은 화면에서는 7줄이 다 안 들어가서 목록을 스크롤한다.
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var day = DateTime.monday; day <= DateTime.sunday; day++)
            SelectableSettingsRow(
              key: ValueKey('goal-plan-weekday-$day'),
              title: names[day - 1],
              isSelected: day == weekday,
              onTap: () => Navigator.of(context).pop(day),
            ),
        ],
      ),
    );
  }
}

/// 모으는 날짜(1~28일) 고르기. 휠에서 고르고 '완료'로 닫는다(목표 날짜 시트와 같은 버튼).
class GoalPlanDaySheet extends StatefulWidget {
  final int day;

  const GoalPlanDaySheet({super.key, required this.day});

  static Future<int?> open(BuildContext context, {required int day}) => CommonBottomSheets.showBottomSheet<int>(
    context: context,
    screenName: '/goal-plan-day',
    title: t.hodl_insights.goal_plan_day,
    showCloseButton: true,
    child: GoalPlanDaySheet(day: day),
  );

  @override
  State<GoalPlanDaySheet> createState() => _GoalPlanDaySheetState();
}

class _GoalPlanDaySheetState extends State<GoalPlanDaySheet> {
  late int _day = widget.day;

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 목표 날짜 휠(CupertinoDatePicker)처럼 글자 배율을 따르지 않는다. 칸 높이가 고정이라 키우면 글자가 잘린다.
          SizedBox(
            height: 216,
            child: MediaQuery.withNoTextScaling(
              child: CupertinoPicker(
                key: const Key('goal-plan-day-picker'),
                itemExtent: 40,
                scrollController: FixedExtentScrollController(initialItem: _day - 1),
                onSelectedItemChanged: (index) => _day = index + 1,
                children: [
                  for (var day = 1; day <= GoalPlanController.maxDay; day++)
                    Center(
                      child: Text(
                        t.hodl_insights.goal_plan_day_value(day: day),
                        style: CoconutTypography.heading4_18.copyWith(color: colors.primaryText),
                      ),
                    ),
                ],
              ),
            ),
          ),
          CoconutLayout.spacing_400h,
          InlineActionButton(
            key: const Key('goal-plan-day-done'),
            text: t.complete,
            onPressed: () => Navigator.of(context).pop(_day),
          ),
        ],
      ),
    );
  }
}
