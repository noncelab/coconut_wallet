import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:coconut_wallet/constants/shared_pref_keys.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/goal_plan_card.dart' show GoalPlanCycle;
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// 모으기 알림 설정. 주기는 모으기 계획의 주기를 따른다.
@immutable
class GoalReminderSettings {
  final bool enabled;
  final int hour;
  final int minute;

  /// 매주일 때 요일. 1(월)~7(일)
  final int weekday;

  /// 매월일 때 날짜. 모든 달에 있는 1~28일만 고른다.
  final int dayOfMonth;

  /// 알림에 이번에 모을 수량을 보여 줄지. 잠금 화면에 금액이 보이므로 기본은 숨김.
  final bool showAmount;

  const GoalReminderSettings({
    this.enabled = false,
    this.hour = 21,
    this.minute = 0,
    this.weekday = DateTime.monday,
    this.dayOfMonth = 1,
    this.showAmount = false,
  });

  static const maxDayOfMonth = 28;

  GoalReminderSettings copyWith({
    bool? enabled,
    int? hour,
    int? minute,
    int? weekday,
    int? dayOfMonth,
    bool? showAmount,
  }) => GoalReminderSettings(
    enabled: enabled ?? this.enabled,
    hour: hour ?? this.hour,
    minute: minute ?? this.minute,
    weekday: weekday ?? this.weekday,
    dayOfMonth: dayOfMonth ?? this.dayOfMonth,
    showAmount: showAmount ?? this.showAmount,
  );

  Map<String, Object> toJson() => {
    'enabled': enabled,
    'hour': hour,
    'minute': minute,
    'weekday': weekday,
    'dayOfMonth': dayOfMonth,
    'showAmount': showAmount,
  };

  /// 저장값이 없거나 잘못됐으면 기본값을 쓴다.
  static GoalReminderSettings fromJsonString(String? raw) {
    if (raw == null || raw.isEmpty) return const GoalReminderSettings();
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      int clamp(Object? value, int fallback, int min, int max) =>
          value is int && value >= min && value <= max ? value : fallback;
      const defaults = GoalReminderSettings();
      return GoalReminderSettings(
        enabled: json['enabled'] == true,
        hour: clamp(json['hour'], defaults.hour, 0, 23),
        minute: clamp(json['minute'], defaults.minute, 0, 59),
        weekday: clamp(json['weekday'], defaults.weekday, DateTime.monday, DateTime.sunday),
        dayOfMonth: clamp(json['dayOfMonth'], defaults.dayOfMonth, 1, maxDayOfMonth),
        showAmount: json['showAmount'] == true,
      );
    } catch (_) {
      return const GoalReminderSettings();
    }
  }

  @override
  bool operator ==(Object other) =>
      other is GoalReminderSettings &&
      other.enabled == enabled &&
      other.hour == hour &&
      other.minute == minute &&
      other.weekday == weekday &&
      other.dayOfMonth == dayOfMonth &&
      other.showAmount == showAmount;

  @override
  int get hashCode => Object.hash(enabled, hour, minute, weekday, dayOfMonth, showAmount);
}

/// 알림 제목과 본문
@immutable
class GoalReminderContent {
  final String title;
  final String body;

  const GoalReminderContent(this.title, this.body);

  /// [amount]가 있으면 이번에 모을 수량을 넣는다.
  factory GoalReminderContent.of(GoalPlanCycle cycle, {String? amount}) {
    final copy = t.hodl_insights;
    final body =
        amount == null
            ? switch (cycle) {
              GoalPlanCycle.daily => copy.goal_reminder_body_daily,
              GoalPlanCycle.weekly => copy.goal_reminder_body_weekly,
              GoalPlanCycle.monthly => copy.goal_reminder_body_monthly,
            }
            : switch (cycle) {
              GoalPlanCycle.daily => copy.goal_reminder_body_daily_amount(amount: amount),
              GoalPlanCycle.weekly => copy.goal_reminder_body_weekly_amount(amount: amount),
              GoalPlanCycle.monthly => copy.goal_reminder_body_monthly_amount(amount: amount),
            };
    return GoalReminderContent(copy.goal_reminder_notification_title, body);
  }

  @override
  bool operator ==(Object other) => other is GoalReminderContent && other.title == title && other.body == body;

  @override
  int get hashCode => Object.hash(title, body);
}

/// 다음 알림 시각. [now] 이후 처음 오는 설정 시각.
abstract final class GoalReminderSchedule {
  static DateTime next(DateTime now, GoalReminderSettings settings, GoalPlanCycle cycle) {
    DateTime at(DateTime day) => DateTime(day.year, day.month, day.day, settings.hour, settings.minute);
    switch (cycle) {
      case GoalPlanCycle.daily:
        final today = at(now);
        return today.isAfter(now) ? today : at(DateTime(now.year, now.month, now.day + 1));
      case GoalPlanCycle.weekly:
        final shift = (settings.weekday - now.weekday) % 7;
        final candidate = at(DateTime(now.year, now.month, now.day + shift));
        return candidate.isAfter(now) ? candidate : at(DateTime(now.year, now.month, now.day + shift + 7));
      case GoalPlanCycle.monthly:
        final candidate = at(DateTime(now.year, now.month, settings.dayOfMonth));
        return candidate.isAfter(now) ? candidate : at(DateTime(now.year, now.month + 1, settings.dayOfMonth));
    }
  }
}

/// 기기 알림 예약. 테스트에서는 [instance]를 바꿔 끼운다.
abstract class GoalReminderScheduler {
  static GoalReminderScheduler instance = LocalGoalReminderScheduler();

  /// 알림 권한이 있는지. 확인할 수 없으면 null
  Future<bool?> hasPermission();

  /// 권한을 요청한다. 이미 거절했으면 OS가 다시 묻지 않고 false를 돌려준다.
  Future<bool> requestPermission();

  /// 이전 예약을 지우고 다시 예약한다.
  Future<void> schedule(GoalReminderSettings settings, GoalPlanCycle cycle, GoalReminderContent content);

  Future<void> cancel();

  /// 기기 설정의 이 앱 알림 화면을 연다.
  Future<void> openSettings();

  /// 앱이 켜져 있는 동안 모으기 알림을 누르면 한 번씩 알린다.
  Stream<void> get taps;

  /// 모으기 알림을 눌러 앱이 처음 켜졌는지. 한 번만 true를 돌려준다.
  Future<bool> consumeLaunchTap();
}

/// flutter_local_notifications로 반복 알림을 예약한다.
/// Android는 정확한 알람 권한 없이 쓰도록 inexact 모드라 몇 분 늦게 올 수 있다.
class LocalGoalReminderScheduler implements GoalReminderScheduler {
  static const _notificationId = 7101;
  static const _channelId = 'goal_reminder';

  /// 알림을 눌렀을 때 모으기 알림인지 가려내는 표시
  static const payload = 'goal_reminder';

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  final StreamController<void> _taps = StreamController<void>.broadcast();
  Future<void>? _ready;
  bool _launchTapConsumed = false;

  Future<void> _init() =>
      _ready ??= () async {
        tz_data.initializeTimeZones();
        try {
          final zone = await FlutterTimezone.getLocalTimezone();
          tz.setLocalLocation(tz.getLocation(zone.identifier));
        } catch (error) {
          // 시간대를 모르면 UTC 기준으로 예약돼 시각이 어긋난다. 로그만 남긴다.
          Logger.error('Failed to read the local time zone for goal reminders: $error');
        }
        await _plugin.initialize(
          settings: const InitializationSettings(
            android: AndroidInitializationSettings('ic_stat_goal_reminder'),
            iOS: DarwinInitializationSettings(
              requestAlertPermission: false,
              requestBadgePermission: false,
              requestSoundPermission: false,
            ),
          ),
          onDidReceiveNotificationResponse: (response) {
            if (response.payload == payload) _taps.add(null);
          },
        );
      }();

  @override
  Stream<void> get taps => _taps.stream;

  @override
  Future<bool> consumeLaunchTap() async {
    if (_launchTapConsumed) return false;
    _launchTapConsumed = true;
    await _init();
    final details = await _plugin.getNotificationAppLaunchDetails();
    return (details?.didNotificationLaunchApp ?? false) && details?.notificationResponse?.payload == payload;
  }

  @override
  Future<bool?> hasPermission() async {
    await _init();
    if (Platform.isAndroid) {
      return _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.areNotificationsEnabled();
    }
    if (Platform.isIOS) {
      final options =
          await _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()?.checkPermissions();
      return options?.isEnabled;
    }
    return null;
  }

  @override
  Future<bool> requestPermission() async {
    await _init();
    if (Platform.isAndroid) {
      return await _plugin
              .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
              ?.requestNotificationsPermission() ??
          false;
    }
    if (Platform.isIOS) {
      return await _plugin
              .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
              ?.requestPermissions(alert: true, sound: true) ??
          false;
    }
    return false;
  }

  @override
  Future<void> schedule(GoalReminderSettings settings, GoalPlanCycle cycle, GoalReminderContent content) async {
    await _init();
    await _plugin.cancel(id: _notificationId);
    final next = GoalReminderSchedule.next(DateTime.now(), settings, cycle);
    await _plugin.zonedSchedule(
      id: _notificationId,
      title: content.title,
      body: content.body,
      payload: payload,
      scheduledDate: tz.TZDateTime(tz.local, next.year, next.month, next.day, next.hour, next.minute),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          t.hodl_insights.goal_reminder_channel,
          channelDescription: t.hodl_insights.goal_reminder_channel_description,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: switch (cycle) {
        GoalPlanCycle.daily => DateTimeComponents.time,
        GoalPlanCycle.weekly => DateTimeComponents.dayOfWeekAndTime,
        GoalPlanCycle.monthly => DateTimeComponents.dayOfMonthAndTime,
      },
    );
  }

  @override
  Future<void> cancel() async {
    await _init();
    await _plugin.cancel(id: _notificationId);
  }

  @override
  Future<void> openSettings() async {
    await _init();
    if (Platform.isAndroid) {
      await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.openAppNotificationSettings();
    } else if (Platform.isIOS) {
      await _plugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.openAppNotificationSettings();
    }
  }
}

/// 목표 수량 화면의 모으기 알림 상태. 설정은 기기에 저장한다.
class GoalReminderController extends ChangeNotifier {
  final GoalReminderScheduler _scheduler;
  GoalReminderSettings _settings;

  /// 알림 권한. 아직 확인하지 않았으면 null
  bool? _permission;
  bool _busy = false;
  bool _disposed = false;

  /// 마지막으로 맞춘 내용. 같으면 다시 예약하지 않는다. 실패해도 남겨 두어 다시 그릴 때마다 재시도하지 않는다.
  Object? _lastSync;

  /// 기기에 예약된 알림이 있을 수 있는지. 한 번도 켜지 않았으면 지울 것이 없으니 플러그인을 부르지 않는다.
  bool _mayHaveScheduled;

  GoalReminderController({GoalReminderScheduler? scheduler})
    : this._(scheduler ?? GoalReminderScheduler.instance, _loadSettings());

  GoalReminderController._(this._scheduler, this._settings) : _mayHaveScheduled = _settings.enabled;

  static GoalReminderSettings _loadSettings() =>
      GoalReminderSettings.fromJsonString(_preferences?.getString(SharedPrefKeys.kGoalReminder));

  static SharedPrefsRepository? get _preferences {
    final preferences = SharedPrefsRepository();
    return preferences.isInitialized ? preferences : null;
  }

  GoalReminderSettings get settings => _settings;
  bool get isBusy => _busy;

  /// 켜 두었는데 기기 설정에서 알림을 끈 상태
  bool get permissionDenied => _permission == false;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> refreshPermission() async {
    if (!_settings.enabled) return;
    try {
      final permission = await _scheduler.hasPermission();
      if (permission != _permission) {
        _permission = permission;
        _notify();
      }
    } catch (error) {
      Logger.error('Failed to check goal reminder permission: $error');
    }
  }

  /// 켤 때 권한을 묻는다. 거절하면 꺼진 채로 두고 false를 돌려준다.
  Future<bool> setEnabled(bool enabled) async {
    if (_busy || enabled == _settings.enabled) return enabled == _settings.enabled;
    _busy = true;
    _notify();
    try {
      if (enabled) {
        final granted = await _scheduler.requestPermission();
        _permission = granted;
        if (!granted) return false;
      }
      _update(_settings.copyWith(enabled: enabled));
      return true;
    } catch (error) {
      Logger.error('Failed to change goal reminder: $error');
      return false;
    } finally {
      _busy = false;
      _notify();
    }
  }

  void update(GoalReminderSettings settings) => _update(settings.copyWith(enabled: _settings.enabled));

  void _update(GoalReminderSettings settings) {
    if (settings == _settings) return;
    _settings = settings;
    _notify();
    final preferences = _preferences;
    if (preferences == null) return;
    unawaited(
      preferences.setStringAndConfirm(SharedPrefKeys.kGoalReminder, jsonEncode(settings.toJson())).then((saved) {
        if (!saved) Logger.error('Failed to save goal reminder settings');
      }),
    );
  }

  /// 지금 설정과 계획으로 예약을 맞춘다. 꺼져 있으면 지운다.
  Future<void> sync(GoalPlanCycle cycle, GoalReminderContent content) async {
    final key = (_settings, cycle, content);
    if (key == _lastSync) return;
    _lastSync = key;
    if (!_settings.enabled && !_mayHaveScheduled) return;
    try {
      if (_settings.enabled) {
        _mayHaveScheduled = true;
        await _scheduler.schedule(_settings, cycle, content);
      } else {
        await _scheduler.cancel();
        _mayHaveScheduled = false;
      }
    } catch (error) {
      Logger.error('Failed to schedule goal reminder: $error');
    }
  }

  void openSettings() => unawaited(
    _scheduler.openSettings().catchError((Object error) {
      Logger.error('Failed to open notification settings: $error');
    }),
  );

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
