import 'package:coconut_design_system/coconut_design_system.dart' show CoconutLayout, CoconutPopup, CoconutTypography;
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/services/goal_reminder/goal_reminder.dart';
import 'package:coconut_wallet/widgets/common/buttons/fixed_bottom_button.dart' show InlineActionButton;
import 'package:coconut_wallet/widgets/common/buttons/switch_row.dart';
import 'package:coconut_wallet/widgets/common/buttons/value_select_row.dart';
import 'package:coconut_wallet/widgets/common/info/inline_notice.dart';
import 'package:coconut_wallet/widgets/common/info/notification_preview.dart';
import 'package:coconut_wallet/widgets/common/overlays/common_bottom_sheets.dart';
import 'package:coconut_wallet/widgets/common/text/keep_words.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/goal_plan_card.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// 목표 수량 화면의 모으기 알림 카드. 목표가 있을 때만 보인다.
/// 언제 오는지(주기·요일·날짜)는 모으기 계획의 모으는 날을 따르고, 여기서는 받을지·시각·수량을 넣을지만 고른다.
class GoalReminderCard extends StatelessWidget {
  final GoalReminderController reminder;
  final GoalPlanController plan;

  /// 화면과 같은 오늘. 모으는 요일·날짜와 마지막 알림 날을 여기서 정한다.
  final DateTime today;

  /// 이번 계획 수량(sats). 동기화를 기다리는 동안에는 걸어 둔 예약의 수량(6-2 A). 넣을 수 없으면(이미 채움·확인 대기·
  /// 잔액 가림) null
  final int? amountSats;

  /// [amountSats]의 기준일(마지막으로 잔액 동기화가 끝난 때). 수량이 없으면 null
  final DateTime? amountAsOf;

  /// [amountSats]가 없을 때 수량을 넣을 수 없는 이유
  final String? amountUnavailableReason;

  /// 확인된 잔액으로 목표를 채웠으면 false. 그동안은 켤 수 없다(이유는 스위치 아래).
  final bool canEnable;
  final String Function(int sats) amountText;

  const GoalReminderCard({
    super.key,
    required this.reminder,
    required this.plan,
    required this.today,
    required this.amountSats,
    required this.amountAsOf,
    required this.amountUnavailableReason,
    required this.canEnable,
    required this.amountText,
  });

  static String formatTime(int hour, int minute) =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  /// 마지막 알림 날·수량 기준일. 앱의 날짜 모양(yyyy.MM.dd)
  static String formatDate(DateTime date) => GoalReminderContent.formatDate(date);

  /// "매주 목요일 21:00". 요일·날짜는 계획의 모으는 날
  static String summaryOf(GoalReminderSettings settings, GoalPlanController plan, DateTime today) {
    final copy = t.hodl_insights;
    final time = formatTime(settings.hour, settings.minute);
    return switch (plan.cycle) {
      GoalPlanCycle.daily => copy.goal_reminder_summary_daily(time: time),
      GoalPlanCycle.weekly => copy.goal_reminder_summary_weekly(
        weekday: copy.goal_reminder_weekdays[plan.weekdayOn(today) - 1],
        time: time,
      ),
      GoalPlanCycle.monthly => copy.goal_reminder_summary_monthly(day: plan.dayOn(today), time: time),
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

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([reminder, plan]),
      builder: (context, _) {
        final colors = context.coconutColors;
        final copy = t.hodl_insights;
        final settings = reminder.settings;
        final enabled = settings.enabled;
        final amountAvailable = amountSats != null;
        final showsAmount = settings.showAmount && amountAvailable;
        final preview = GoalReminderContent.of(
          plan.cycle,
          amount: showsAmount ? amountText(amountSats!) : null,
          asOf: amountAsOf == null ? '' : formatDate(amountAsOf!),
        );
        final labelStyle = CoconutTypography.body3_12.copyWith(color: colors.secondaryTextStrong);
        final noteStyle = CoconutTypography.caption_10.copyWith(color: colors.tertiaryText);
        // 앱이 끈 이유. 이미 채웠는데 사용자가 켠 적이 없으면 켤 수 없는 이유를 대신 보여 준다.
        final offReason = switch (settings.offReason) {
          GoalReminderOffReason.reached => copy.goal_reminder_off_reached,
          GoalReminderOffReason.deadlinePassed => copy.goal_reminder_off_deadline,
          GoalReminderOffReason.noGoal => copy.goal_reminder_off_no_goal,
          null => canEnable ? null : copy.goal_reminder_amount_disabled_reached,
        };
        // 날짜별 예약은 마감일 전날까지(D1). 한 번에 걸어 두는 개수로 마감일 전날까지 다 걸 수 없으면(매일·긴 계획)
        // 걸어 둔 마지막 날과, 앱을 열면 이어서 건다는 것을 밝힌다(④ "그 사실을 밝힘")
        final deadline = plan.deadlineOn(today);
        final lastDay = formatDate(DateTime(deadline.year, deadline.month, deadline.day - 1));
        final schedule = settings.copyWith(weekday: plan.weekdayOn(today), dayOfMonth: plan.dayOn(today));
        final booked = GoalReminderSchedule.upcoming(today, schedule, plan.cycle, until: deadline);
        final capped =
            booked.length == GoalReminderSchedule.maxScheduled &&
            GoalReminderSchedule.next(
              booked.last,
              schedule,
              plan.cycle,
            ).isBefore(DateTime(deadline.year, deadline.month, deadline.day));
        final until =
            capped
                ? copy.goal_reminder_until_booked(booked: formatDate(booked.last), date: lastDay)
                : copy.goal_reminder_until(date: lastDay);
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
                  subtitle: enabled ? summaryOf(settings, plan, today) : copy.goal_reminder_off,
                  subtitleKey: const Key('goal-reminder-summary'),
                  subtitleStyle: labelStyle,
                  value: enabled,
                  switchKey: const Key('goal-reminder-switch'),
                  // 확인된 잔액으로 목표를 채운 동안은 켤 수 없다
                  onChanged: enabled || canEnable ? (value) => _toggle(context, value) : null,
                ),
              ),
              if (!enabled && offReason != null) ...[
                CoconutLayout.spacing_300h,
                InlineNotice(
                  key: const Key('goal-reminder-off-reason'),
                  icon: CupertinoIcons.bell_slash,
                  message: offReason,
                  backgroundColor: Colors.transparent,
                ),
              ],
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
                ValueSelectRow(
                  key: const Key('goal-reminder-time'),
                  icon: CupertinoIcons.clock,
                  label: copy.goal_reminder_time,
                  value: formatTime(settings.hour, settings.minute),
                  onPressed: () => _pickTime(context, settings),
                ),
                CoconutLayout.spacing_200h,
                Text(keepWords(until), key: const Key('goal-reminder-until'), semanticsLabel: until, style: noteStyle),
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

/// 알림에 계획 수량을 넣을지. 넣을 수 없으면(이미 채움·확인 대기·잔액 가림) 끄고 그 이유를 바로 아래에 보여 준다.
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
          // 넣을 수 없으면 흐리게 두고 누를 수 없게 한다(이유는 바로 아래)
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
