import 'package:coconut_design_system/coconut_design_system.dart' show CoconutLayout, CoconutPopup, CoconutTypography;
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/services/goal_reminder/goal_reminder.dart';
import 'package:coconut_wallet/widgets/common/bottom_sheet/selectable_settings_row.dart';
import 'package:coconut_wallet/widgets/common/buttons/fixed_bottom_button.dart' show InlineActionButton;
import 'package:coconut_wallet/widgets/common/buttons/segmented_choice.dart';
import 'package:coconut_wallet/widgets/common/buttons/switch_row.dart';
import 'package:coconut_wallet/widgets/common/buttons/value_select_row.dart';
import 'package:coconut_wallet/widgets/common/info/inline_notice.dart';
import 'package:coconut_wallet/widgets/common/info/notification_preview.dart';
import 'package:coconut_wallet/widgets/common/overlays/common_bottom_sheets.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/goal_plan_card.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// 목표 수량 화면의 모으기 알림 카드.
/// 주기는 모으기 계획을 따르고, 시각·요일(매주)·날짜(매월)와 알림에 수량을 보여 줄지 고른다.
class GoalReminderCard extends StatelessWidget {
  final GoalReminderController reminder;
  final GoalPlanController plan;

  /// 이번에 모을 수량(sats). 모으기 계획이 없으면(목표 없음·이미 달성) null
  final int? amountSats;

  /// [amountSats]가 없을 때 수량 표시를 켤 수 없는 이유
  final String? amountUnavailableReason;
  final String Function(int sats) amountText;

  const GoalReminderCard({
    super.key,
    required this.reminder,
    required this.plan,
    required this.amountSats,
    required this.amountUnavailableReason,
    required this.amountText,
  });

  static String formatTime(int hour, int minute) =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  static String summaryOf(GoalReminderSettings settings, GoalPlanCycle cycle) {
    final copy = t.hodl_insights;
    final time = formatTime(settings.hour, settings.minute);
    return switch (cycle) {
      GoalPlanCycle.daily => copy.goal_reminder_summary_daily(time: time),
      GoalPlanCycle.weekly => copy.goal_reminder_summary_weekly(
        weekday: copy.goal_reminder_weekdays[settings.weekday - 1],
        time: time,
      ),
      GoalPlanCycle.monthly => copy.goal_reminder_summary_monthly(day: settings.dayOfMonth, time: time),
    };
  }

  Future<void> _toggle(BuildContext context, bool enabled) async {
    final changed = await reminder.setEnabled(enabled);
    if (!changed && enabled && reminder.permissionDenied && context.mounted) {
      await _showPermissionPopup(context);
    }
  }

  /// 알림 권한을 거절했을 때: 이유를 알려 주고 기기 설정의 이 앱 알림 화면으로 보낸다.
  /// OS는 한 번 거절한 권한을 다시 묻지 않으므로 설정에서만 켤 수 있다.
  Future<void> _showPermissionPopup(BuildContext context) => showDialog<void>(
    context: context,
    builder:
        (dialogContext) => CoconutPopup(
          key: const Key('goal-reminder-permission-popup'),
          languageCode: LocaleSettings.currentLocale.languageCode,
          title: t.hodl_insights.goal_reminder_permission_popup_title,
          description: t.hodl_insights.goal_reminder_permission_popup_description,
          leftButtonText: t.cancel,
          rightButtonText: t.hodl_insights.goal_reminder_open_settings,
          rightButtonColor: dialogContext.coconutColors.primaryText,
          onTapLeft: () => Navigator.pop(dialogContext),
          onTapRight: () {
            Navigator.pop(dialogContext);
            reminder.openSettings();
          },
        ),
  );

  Future<void> _pickTime(BuildContext context, GoalReminderSettings settings) async {
    final picked = await _ReminderTimeSheet.open(context, hour: settings.hour, minute: settings.minute);
    if (picked != null) reminder.update(settings.copyWith(hour: picked.hour, minute: picked.minute));
  }

  Future<void> _pickWeekday(BuildContext context, GoalReminderSettings settings) async {
    final picked = await GoalReminderWeekdaySheet.open(context, weekday: settings.weekday);
    if (picked != null) reminder.update(settings.copyWith(weekday: picked));
  }

  Future<void> _pickDay(BuildContext context, GoalReminderSettings settings) async {
    final picked = await _ReminderDaySheet.open(context, day: settings.dayOfMonth);
    if (picked != null) reminder.update(settings.copyWith(dayOfMonth: picked));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([reminder, plan]),
      builder: (context, _) {
        final colors = context.coconutColors;
        final copy = t.hodl_insights;
        final settings = reminder.settings;
        final cycle = plan.cycle;
        final enabled = settings.enabled;
        final amountAvailable = amountSats != null;
        final showsAmount = settings.showAmount && amountAvailable;
        final preview = GoalReminderContent.of(cycle, amount: showsAmount ? amountText(amountSats!) : null);
        final labelStyle = CoconutTypography.body3_12.copyWith(color: colors.secondaryTextStrong);
        return Container(
          key: const Key('goal-reminder-card'),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: colors.homeSurface, borderRadius: BorderRadius.circular(20)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 줄 어디를 눌러도 켜고 끄며, 화면 읽기에서는 제목·요약·켜짐 상태를 한 번에 읽는다.
              IgnorePointer(
                ignoring: reminder.isBusy,
                child: SwitchRow(
                  key: const Key('goal-reminder-toggle'),
                  title: copy.goal_reminder_title,
                  titleStyle: CoconutTypography.body1_16_Bold.copyWith(color: colors.primaryText),
                  subtitle: enabled ? summaryOf(settings, cycle) : copy.goal_reminder_off,
                  subtitleKey: const Key('goal-reminder-summary'),
                  subtitleStyle: labelStyle,
                  value: enabled,
                  switchKey: const Key('goal-reminder-switch'),
                  onChanged: (value) => _toggle(context, value),
                ),
              ),
              if (reminder.permissionDenied) ...[
                CoconutLayout.spacing_300h,
                InlineNotice(
                  key: const Key('goal-reminder-permission-denied'),
                  icon: CupertinoIcons.bell_slash,
                  message: copy.goal_reminder_permission_denied,
                  actionLabel: copy.goal_reminder_open_settings,
                  actionKey: const Key('goal-reminder-open-settings'),
                  onAction: reminder.openSettings,
                ),
              ],
              if (enabled) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Divider(height: 1, thickness: 0.5, color: colors.border),
                ),
                // 모으기 계획이 있으면 그 주기를 따르고, 없으면(목표 없음·이미 달성) 여기서 주기를 고른다.
                // 고른 주기는 모으기 계획과 같은 저장값이라 나중에 계획이 생기면 그대로 이어진다.
                if (amountAvailable)
                  Text(
                    '${copy.goal_reminder_cycle_hint} · ${cycle.label}',
                    key: const Key('goal-reminder-cycle'),
                    style: CoconutTypography.caption_10.copyWith(color: colors.tertiaryText),
                  )
                else ...[
                  Text(copy.goal_reminder_cycle_question, style: labelStyle),
                  CoconutLayout.spacing_200h,
                  KeyedSubtree(
                    key: const Key('goal-reminder-cycle-options'),
                    child: SegmentedChoice<GoalPlanCycle>(
                      keyOf: (value) => 'goal-reminder-cycle-${value.name}',
                      values: GoalPlanCycle.values,
                      selected: cycle,
                      label: (value) => value.label,
                      onSelected: plan.selectCycle,
                    ),
                  ),
                ],
                CoconutLayout.spacing_300h,
                // 요일은 날짜·시각과 같은 값 줄 + 시트로 고른다. 7칸 막대는 320px에서 한 칸이 약 31dp라 누르기 어렵다.
                if (cycle == GoalPlanCycle.weekly) ...[
                  ValueSelectRow(
                    key: const Key('goal-reminder-weekday'),
                    icon: CupertinoIcons.calendar,
                    label: copy.goal_reminder_weekday,
                    value: copy.goal_reminder_weekdays[settings.weekday - 1],
                    onPressed: () => _pickWeekday(context, settings),
                  ),
                  CoconutLayout.spacing_200h,
                ],
                if (cycle == GoalPlanCycle.monthly) ...[
                  ValueSelectRow(
                    key: const Key('goal-reminder-day'),
                    icon: CupertinoIcons.calendar,
                    label: copy.goal_reminder_day,
                    value: copy.goal_reminder_day_value(day: settings.dayOfMonth),
                    onPressed: () => _pickDay(context, settings),
                  ),
                  CoconutLayout.spacing_200h,
                ],
                ValueSelectRow(
                  key: const Key('goal-reminder-time'),
                  icon: CupertinoIcons.clock,
                  label: copy.goal_reminder_time,
                  value: formatTime(settings.hour, settings.minute),
                  onPressed: () => _pickTime(context, settings),
                ),
                CoconutLayout.spacing_400h,
                _AmountOption(
                  isOn: showsAmount,
                  available: amountAvailable,
                  unavailableReason: amountUnavailableReason,
                  onChanged: (value) => reminder.update(settings.copyWith(showAmount: value)),
                ),
                CoconutLayout.spacing_400h,
                Text(copy.goal_reminder_preview, style: labelStyle),
                CoconutLayout.spacing_200h,
                NotificationPreview(
                  key: const Key('goal-reminder-preview'),
                  title: preview.title,
                  body: preview.body,
                  bodyKey: const Key('goal-reminder-preview-body'),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// 알림에 수량을 보여 줄지. 모으기 계획이 없으면 끄고 그 이유를 바로 아래에 보여 준다.
class _AmountOption extends StatelessWidget {
  final bool isOn;
  final bool available;
  final String? unavailableReason;
  final ValueChanged<bool> onChanged;

  const _AmountOption({
    required this.isOn,
    required this.available,
    required this.unavailableReason,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final copy = t.hodl_insights;
    return Column(
      key: const Key('goal-reminder-amount-option'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchRow(
          key: const Key('goal-reminder-amount-toggle'),
          title: copy.goal_reminder_show_amount,
          subtitle: copy.goal_reminder_show_amount_hint,
          subtitleStyle: CoconutTypography.caption_10.copyWith(color: colors.tertiaryText),
          value: isOn,
          switchKey: const Key('goal-reminder-amount-switch'),
          // 모으기 계획이 없으면 흐리게 두고 누를 수 없게 한다(이유는 바로 아래)
          onChanged: available ? onChanged : null,
        ),
        if (!available && unavailableReason != null) ...[
          CoconutLayout.spacing_200h,
          InlineNotice(
            key: const Key('goal-reminder-amount-disabled-reason'),
            iconKey: const Key('goal-reminder-amount-disabled-icon'),
            icon: CupertinoIcons.info_circle,
            message: unavailableReason!,
            backgroundColor: Colors.transparent,
          ),
        ],
      ],
    );
  }
}

class _ReminderTimeSheet extends StatefulWidget {
  final int hour;
  final int minute;

  const _ReminderTimeSheet({required this.hour, required this.minute});

  static Future<({int hour, int minute})?> open(BuildContext context, {required int hour, required int minute}) =>
      CommonBottomSheets.showBottomSheet<({int hour, int minute})>(
        context: context,
        screenName: '/goal-reminder-time',
        title: t.hodl_insights.goal_reminder_time_title,
        showCloseButton: true,
        child: _ReminderTimeSheet(hour: hour, minute: minute),
      );

  @override
  State<_ReminderTimeSheet> createState() => _ReminderTimeSheetState();
}

class _ReminderTimeSheetState extends State<_ReminderTimeSheet> {
  late int _hour = widget.hour;
  late int _minute = widget.minute;

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
            child: CupertinoTheme(
              data: CupertinoThemeData(
                brightness: Theme.of(context).brightness,
                textTheme: CupertinoTextThemeData(
                  dateTimePickerTextStyle: CoconutTypography.heading4_18.copyWith(color: colors.primaryText),
                ),
              ),
              child: CupertinoDatePicker(
                key: const Key('goal-reminder-time-picker'),
                mode: CupertinoDatePickerMode.time,
                use24hFormat: true,
                initialDateTime: DateTime(2000, 1, 1, _hour, _minute),
                onDateTimeChanged: (time) {
                  _hour = time.hour;
                  _minute = time.minute;
                },
              ),
            ),
          ),
          CoconutLayout.spacing_400h,
          InlineActionButton(
            key: const Key('goal-reminder-time-done'),
            text: t.complete,
            onPressed: () => Navigator.of(context).pop((hour: _hour, minute: _minute)),
          ),
        ],
      ),
    );
  }
}

/// 알림 요일 고르기. 설정 시트(단위·언어 등)와 같은 선택 줄로, 누르면 고르고 닫힌다.
/// 한 줄 높이 50 이상, 화면 읽기에서 고른 요일을 '선택됨'으로 읽는다.
class GoalReminderWeekdaySheet extends StatelessWidget {
  final int weekday;

  const GoalReminderWeekdaySheet({super.key, required this.weekday});

  static Future<int?> open(BuildContext context, {required int weekday}) => CommonBottomSheets.showBottomSheet<int>(
    context: context,
    screenName: '/goal-reminder-weekday',
    title: t.hodl_insights.goal_reminder_weekday,
    showCloseButton: true,
    child: GoalReminderWeekdaySheet(weekday: weekday),
  );

  @override
  Widget build(BuildContext context) {
    final names = t.hodl_insights.goal_reminder_weekdays;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var day = DateTime.monday; day <= DateTime.sunday; day++)
            SelectableSettingsRow(
              key: ValueKey('goal-reminder-weekday-$day'),
              title: names[day - 1],
              isSelected: day == weekday,
              onTap: () => Navigator.of(context).pop(day),
            ),
        ],
      ),
    );
  }
}

class _ReminderDaySheet extends StatefulWidget {
  final int day;

  const _ReminderDaySheet({required this.day});

  static Future<int?> open(BuildContext context, {required int day}) => CommonBottomSheets.showBottomSheet<int>(
    context: context,
    screenName: '/goal-reminder-day',
    title: t.hodl_insights.goal_reminder_day_title,
    showCloseButton: true,
    child: _ReminderDaySheet(day: day),
  );

  @override
  State<_ReminderDaySheet> createState() => _ReminderDaySheetState();
}

class _ReminderDaySheetState extends State<_ReminderDaySheet> {
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
          SizedBox(
            height: 216,
            child: CupertinoPicker(
              key: const Key('goal-reminder-day-picker'),
              itemExtent: 40,
              scrollController: FixedExtentScrollController(initialItem: _day - 1),
              onSelectedItemChanged: (index) => _day = index + 1,
              children: [
                for (var day = 1; day <= GoalReminderSettings.maxDayOfMonth; day++)
                  Center(
                    child: Text(
                      t.hodl_insights.goal_reminder_day_value(day: day),
                      style: CoconutTypography.heading4_18.copyWith(color: colors.primaryText),
                    ),
                  ),
              ],
            ),
          ),
          CoconutLayout.spacing_400h,
          InlineActionButton(
            key: const Key('goal-reminder-day-done'),
            text: t.complete,
            onPressed: () => Navigator.of(context).pop(_day),
          ),
        ],
      ),
    );
  }
}
