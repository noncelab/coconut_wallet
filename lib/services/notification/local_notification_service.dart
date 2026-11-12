import 'dart:async';
import 'dart:io';

import 'package:coconut_wallet/utils/logger.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// 앱의 로컬 알림 초기화·권한·예약을 한곳에서. 기능별 알림은 payload로 나눔
class LocalNotificationService {
  LocalNotificationService._();

  static final LocalNotificationService instance = LocalNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  final StreamController<String> _taps = StreamController<String>.broadcast();
  Future<void>? _ready;
  bool _launchPayloadConsumed = false;

  /// 알림을 눌렀을 때의 payload
  Stream<String> get taps => _taps.stream;

  Future<void> ensureInitialized() =>
      _ready ??= () async {
        tz_data.initializeTimeZones();
        try {
          final zone = await FlutterTimezone.getLocalTimezone();
          tz.setLocalLocation(tz.getLocation(zone.identifier));
        } catch (error) {
          Logger.error('LocalNotificationService: failed to read the local time zone: $error');
        }
        await _plugin.initialize(
          settings: const InitializationSettings(
            android: AndroidInitializationSettings('ic_stat_notification'),
            iOS: DarwinInitializationSettings(
              requestAlertPermission: false,
              requestBadgePermission: false,
              requestSoundPermission: false,
            ),
          ),
          onDidReceiveNotificationResponse: (response) {
            final payload = response.payload;
            if (payload != null) _taps.add(payload);
          },
        );
      }();

  /// 알림을 눌러 앱이 켜졌으면 그 payload, 한 번만 돌려줌
  Future<String?> consumeLaunchPayload() async {
    if (_launchPayloadConsumed) return null;
    _launchPayloadConsumed = true;
    await ensureInitialized();
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (!(details?.didNotificationLaunchApp ?? false)) return null;
    return details?.notificationResponse?.payload;
  }

  Future<bool> requestPermission() async {
    await ensureInitialized();
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

  Future<void> schedule({
    required int id,
    required String channelId,
    required String channelName,
    required String channelDescription,
    required String title,
    required String body,
    required String payload,
    required DateTime at,
  }) async {
    await ensureInitialized();
    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      payload: payload,
      scheduledDate: tz.TZDateTime.from(at, tz.local),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(channelId, channelName, channelDescription: channelDescription),
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  Future<void> cancel(int id) async {
    await ensureInitialized();
    await _plugin.cancel(id: id);
  }
}
