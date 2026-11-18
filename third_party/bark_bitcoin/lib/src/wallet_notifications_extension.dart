import 'dart:async';
import 'generated/bark.dart';

extension WalletNotificationsExtension on WalletInterface {
  /// Returns a broadcast [Stream] of [WalletNotification]s.
  ///
  /// The stream starts a polling loop (backed by a [NotificationHolder]) the
  /// first time a listener subscribes, and cancels the underlying wait when
  /// the last listener unsubscribes. Re-subscribing after all listeners have
  /// cancelled creates a fresh [NotificationHolder] and restarts the loop.
  Stream<WalletNotification> notificationStream() {
    NotificationHolder? holder;
    late StreamController<WalletNotification> controller;

    controller = StreamController<WalletNotification>.broadcast(
      onListen: () {
        // Captured locally so the async loop is independent of later nulling.
        final localHolder = notifications();
        holder = localHolder;
        () async {
          try {
            while (true) {
              final event = await localHolder.nextNotification();
              if (event == null) break; // null signals cancellation
              controller.add(event);
            }
          } catch (e, st) {
            controller.addError(e, st);
          }
        }();
      },
      onCancel: () {
        // Called when the last listener unsubscribes.
        holder?.cancelNextNotificationWait();
        holder = null;
      },
    );

    return controller.stream;
  }
}
