import 'package:coconut_design_system/coconut_design_system.dart'
    show CoconutLayout, CoconutPopup, CoconutSwitch, CoconutTypography;
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/services/goal_reminder/goal_reminder.dart';
import 'package:coconut_wallet/widgets/common/buttons/shrink_animation_button.dart';
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
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          copy.goal_reminder_title,
                          style: CoconutTypography.body1_16_Bold.copyWith(color: colors.primaryText),
                        ),
                        CoconutLayout.spacing_100h,
                        Text(
                          enabled ? summaryOf(settings, cycle) : copy.goal_reminder_off,
                          key: const Key('goal-reminder-summary'),
                          style: labelStyle,
                        ),
                      ],
                    ),
                  ),
                  IgnorePointer(
                    ignoring: reminder.isBusy,
                    child: CoconutSwitch(
                      key: const Key('goal-reminder-switch'),
                      isOn: enabled,
                      onChanged: (value) => _toggle(context, value),
                    ),
                  ),
                ],
              ),
              if (reminder.permissionDenied) ...[
                CoconutLayout.spacing_300h,
                _PermissionNotice(onOpenSettings: reminder.openSettings),
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
                  Row(
                    key: const Key('goal-reminder-cycle-options'),
                    children: [
                      for (final value in GoalPlanCycle.values) ...[
                        if (value != GoalPlanCycle.values.first) const SizedBox(width: 6),
                        Expanded(
                          child: _OptionButton(
                            key: ValueKey('goal-reminder-cycle-${value.name}'),
                            label: value.label,
                            selected: cycle == value,
                            onPressed: () => plan.selectCycle(value),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
                CoconutLayout.spacing_300h,
                if (cycle == GoalPlanCycle.weekly) ...[
                  Text(copy.goal_reminder_weekday, style: labelStyle),
                  CoconutLayout.spacing_200h,
                  Row(
                    children: [
                      for (var day = DateTime.monday; day <= DateTime.sunday; day++) ...[
                        if (day > DateTime.monday) const SizedBox(width: 4),
                        Expanded(
                          child: _OptionButton(
                            key: ValueKey('goal-reminder-weekday-$day'),
                            label: copy.goal_reminder_weekdays_short[day - 1],
                            selected: settings.weekday == day,
                            onPressed: () => reminder.update(settings.copyWith(weekday: day)),
                          ),
                        ),
                      ],
                    ],
                  ),
                  CoconutLayout.spacing_300h,
                ],
                if (cycle == GoalPlanCycle.monthly) ...[
                  _ValueRow(
                    key: const Key('goal-reminder-day'),
                    icon: CupertinoIcons.calendar,
                    label: copy.goal_reminder_day,
                    value: copy.goal_reminder_day_value(day: settings.dayOfMonth),
                    onPressed: () => _pickDay(context, settings),
                  ),
                  CoconutLayout.spacing_200h,
                ],
                _ValueRow(
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
                _Preview(content: preview),
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
        Opacity(
          opacity: available ? 1 : 0.4,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      copy.goal_reminder_show_amount,
                      style: CoconutTypography.body2_14.copyWith(color: colors.primaryText),
                    ),
                    CoconutLayout.spacing_100h,
                    Text(
                      copy.goal_reminder_show_amount_hint,
                      style: CoconutTypography.caption_10.copyWith(color: colors.tertiaryText),
                    ),
                  ],
                ),
              ),
              IgnorePointer(
                ignoring: !available,
                child: CoconutSwitch(key: const Key('goal-reminder-amount-switch'), isOn: isOn, onChanged: onChanged),
              ),
            ],
          ),
        ),
        if (!available && unavailableReason != null) ...[
          CoconutLayout.spacing_200h,
          Builder(
            builder: (context) {
              final style = CoconutTypography.body3_12.copyWith(color: colors.secondaryTextStrong);
              // 아이콘을 문구 첫 줄의 세로 가운데에 맞춘다. 한 줄이든 여러 줄이든, 글자 크기 설정이 바뀌어도 맞는다.
              final painter = TextPainter(
                text: TextSpan(text: ' ', style: style),
                textDirection: Directionality.of(context),
                textScaler: MediaQuery.textScalerOf(context),
              )..layout();
              final lineHeight = painter.height;
              painter.dispose();
              return Row(
                key: const Key('goal-reminder-amount-disabled-reason'),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    key: const Key('goal-reminder-amount-disabled-icon'),
                    height: lineHeight,
                    child: Center(child: Icon(CupertinoIcons.info_circle, size: 14, color: colors.secondaryTextStrong)),
                  ),
                  const SizedBox(width: 6),
                  Expanded(child: Text(unavailableReason!, style: style)),
                ],
              );
            },
          ),
        ],
      ],
    );
  }
}

class _PermissionNotice extends StatelessWidget {
  final VoidCallback onOpenSettings;

  const _PermissionNotice({required this.onOpenSettings});

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    return Container(
      key: const Key('goal-reminder-permission-denied'),
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(color: colors.homeBackground, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Icon(CupertinoIcons.bell_slash, size: 16, color: colors.secondaryTextStrong),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              t.hodl_insights.goal_reminder_permission_denied,
              style: CoconutTypography.body3_12.copyWith(color: colors.secondaryTextStrong),
            ),
          ),
          ShrinkAnimationButton(
            key: const Key('goal-reminder-open-settings'),
            onPressed: onOpenSettings,
            defaultColor: colors.homeSurface,
            pressedOverlayColor: colors.homeSurfacePressOverlay,
            pressedOverlayOpacity: colors.homeSurfacePressOverlayOpacity,
            borderRadius: 8,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Text(
                t.hodl_insights.goal_reminder_open_settings,
                style: CoconutTypography.body3_12_Bold.copyWith(color: colors.primaryText),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  final GoalReminderContent content;

  const _Preview({required this.content});

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          t.hodl_insights.goal_reminder_preview,
          style: CoconutTypography.body3_12.copyWith(color: colors.secondaryTextStrong),
        ),
        CoconutLayout.spacing_200h,
        Container(
          key: const Key('goal-reminder-preview'),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: colors.homeBackground, borderRadius: BorderRadius.circular(12)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(content.title, style: CoconutTypography.body3_12_Bold.copyWith(color: colors.primaryText)),
              CoconutLayout.spacing_100h,
              Text(
                content.body,
                key: const Key('goal-reminder-preview-body'),
                style: CoconutTypography.body3_12.copyWith(color: colors.secondaryTextStrong),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OptionButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onPressed;

  const _OptionButton({super.key, required this.label, required this.selected, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    return ShrinkAnimationButton(
      onPressed: onPressed,
      defaultColor: selected ? colors.primaryText : colors.homeBackground,
      pressedOverlayColor: colors.homeSurfacePressOverlay,
      pressedOverlayOpacity: colors.homeSurfacePressOverlayOpacity,
      borderRadius: 10,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: (selected ? CoconutTypography.body3_12_Bold : CoconutTypography.body3_12).copyWith(
                color: selected ? colors.background : colors.secondaryTextStrong,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ValueRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onPressed;

  const _ValueRow({super.key, required this.icon, required this.label, required this.value, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    return ShrinkAnimationButton(
      onPressed: onPressed,
      defaultColor: colors.homeBackground,
      pressedOverlayColor: colors.homeSurfacePressOverlay,
      pressedOverlayOpacity: colors.homeSurfacePressOverlayOpacity,
      borderRadius: 10,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 16, color: colors.secondaryTextStrong),
            const SizedBox(width: 8),
            Expanded(child: Text(label, style: CoconutTypography.body3_12.copyWith(color: colors.secondaryTextStrong))),
            Text(value, style: CoconutTypography.body3_12_Bold.copyWith(color: colors.primaryText)),
            const SizedBox(width: 4),
            Icon(CupertinoIcons.chevron_right, size: 14, color: colors.tertiaryText),
          ],
        ),
      ),
    );
  }
}

/// 바텀시트 아래 완료 버튼
class _DoneButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _DoneButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    return ShrinkAnimationButton(
      onPressed: onPressed,
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
          _DoneButton(
            key: const Key('goal-reminder-time-done'),
            onPressed: () => Navigator.of(context).pop((hour: _hour, minute: _minute)),
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
          _DoneButton(key: const Key('goal-reminder-day-done'), onPressed: () => Navigator.of(context).pop(_day)),
        ],
      ),
    );
  }
}
