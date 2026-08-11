import 'dart:async';

import 'package:coconut_wallet/services/hardware_wallet/trezor_device.dart';
import 'package:flutter/services.dart';

/// Wraps Trezor Safe 7 BLE connectivity: live disconnect stream.
///
/// iOS:     listens for BLE peripheral disconnect via CoreBluetooth.
/// Android: listens for GATT connection state changes.
class TrezorBleConnectivityService {
  static const MethodChannel _channel = MethodChannel('trezor');
  static const EventChannel _eventChannel = EventChannel('trezor/connectivity');

  static StreamSubscription<bool>? _monitorSubscription;

  /// Returns true if the physical device is currently reachable right now.
  ///
  /// iOS:     BLE peripheral is in the connected state.
  /// Android: GATT connection is active.
  static Future<bool> isDeviceConnected([TrezorTransport transport = TrezorTransport.ble]) async {
    try {
      final result = await _channel.invokeMethod<bool>('isConnected', {'transport': transport.name});
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Stream that emits [false] when the physical device disconnects.
  static Stream<bool> get onConnectionChanged {
    return _eventChannel.receiveBroadcastStream().map((event) => event as bool);
  }

  /// Start background monitoring. Auto-clears [TrezorDevice.lastConnected]
  /// when the device disconnects. Call once at app startup.
  static void startMonitoring() {
    _monitorSubscription?.cancel();
    _monitorSubscription = onConnectionChanged.listen((connected) {
      if (!connected) TrezorDevice.lastConnected = null;
    }, onError: (_) {});
  }

  static void stopMonitoring() {
    _monitorSubscription?.cancel();
    _monitorSubscription = null;
  }
}
