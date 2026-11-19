import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/services/notification/local_notification_service.dart';
import 'package:coconut_wallet/utils/app_settings_util.dart';
import 'package:coconut_wallet/utils/logger.dart';

/// 앱이 꺼져 있어 자동 갱신을 못 할 때를 대비한 갱신 알림
abstract interface class ArkExpiryReminder {
  /// [at]에 갱신하라고 알림, null이면 지움
  Future<void> remindAt(DateTime? at);

  /// 기기에서 알림을 띄울 수 있음
  Future<bool> isAllowed();

  /// 알림 허용을 물음. 이미 거절했으면 앱 설정을 염
  Future<bool> askToAllow();
}

/// 기기 로컬 알림으로
class LocalArkExpiryReminder implements ArkExpiryReminder {
  const LocalArkExpiryReminder();

  static const _id = 7401;
  static const payload = 'ark-wallet-expiry';

  @override
  Future<void> remindAt(DateTime? at) async {
    final notifications = LocalNotificationService.instance;
    try {
      await notifications.cancel(_id);
      if (at == null) return;
      await notifications.schedule(
        id: _id,
        channelId: 'ark_wallet_expiry',
        channelName: t.ark_wallet.notification_channel,
        channelDescription: t.ark_wallet.notification_channel,
        title: t.ark_wallet.notification_title,
        body: t.ark_wallet.notification_body,
        payload: payload,
        at: at,
      );
    } catch (error) {
      Logger.error('LocalArkExpiryReminder: failed to schedule: $error');
    }
  }

  @override
  Future<bool> isAllowed() => LocalNotificationService.instance.isAllowed();

  @override
  Future<bool> askToAllow() async {
    if (await LocalNotificationService.instance.requestPermission()) return true;
    await openAppSettings();
    return false;
  }
}
