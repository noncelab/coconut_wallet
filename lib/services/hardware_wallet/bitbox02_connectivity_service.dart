import 'dart:async';
import 'dart:io';

import 'package:coconut_wallet/services/hardware_wallet/bitbox02_device.dart';
import 'package:flutter/services.dart';

/// Wraps BitBox02 physical connectivity: point-in-time check + live disconnect stream.
///
/// Android: checks USB device list via [UsbManager] / listens for ACTION_USB_DEVICE_DETACHED.
/// iOS:     checks CoreBluetooth peripheral state / listens for BLE peripheral disconnect.
class BitBox02ConnectivityService {
  static const MethodChannel _channel = MethodChannel('bitbox02');
  static const EventChannel _eventChannel = EventChannel('bitbox02/connectivity');

  static StreamSubscription<bool>? _monitorSubscription;

  /// Returns true if the physical device is currently reachable right now.
  ///
  /// Android: BitBox02 Nova found in UsbManager.deviceList.
  /// iOS:     BLE peripheral is in the connected state.
  static Future<bool> isDeviceConnected() async {
    try {
      final result = await _channel.invokeMethod<bool>('isConnected');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Stream that emits [false] when the physical device disconnects.
  ///
  /// On Android this fires on USB cable removal.
  /// On iOS this fires when the BLE peripheral disconnects.
  static Stream<bool> get onConnectionChanged {
    return _eventChannel.receiveBroadcastStream().map((event) => event as bool);
  }

  /// Start background monitoring. Auto-clears [BitBox02Device.lastConnected]
  /// when the device disconnects. Call once at app startup.
  static void startMonitoring() {
    _monitorSubscription?.cancel();
    // iOS BLE connections are not persistent across sessions; the disconnect
    // event stream still correctly clears lastConnected if BLE drops mid-flow.
    if (Platform.isIOS) {
      _monitorSubscription = onConnectionChanged.listen((connected) {
        if (!connected) BitBox02Device.lastConnected = null;
      }, onError: (_) {});
    } else {
      _monitorSubscription = onConnectionChanged.listen((connected) {
        if (!connected) BitBox02Device.lastConnected = null;
      }, onError: (_) {});
    }
  }

  static void stopMonitoring() {
    _monitorSubscription?.cancel();
    _monitorSubscription = null;
  }
}
