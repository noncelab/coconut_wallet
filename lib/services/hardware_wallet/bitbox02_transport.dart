import 'dart:io';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/services/hardware_wallet/bitbox02_device.dart';

class BitBox02Transport {
  BitBox02Transport._();

  /// Returns the transport string for BitBox02Device.connect().
  ///
  /// TCP (simulator) is only allowed on testnet/regtest.
  /// On Android, defaults to 'usb'. On iOS, defaults to 'ble'.
  static String resolve({String? preferred}) {
    if (preferred == 'tcp') {
      if (!NetworkType.currentNetworkType.isTestnet) {
        throw const BitBox02TransportException(
          'TCP transport is only available on testnet/regtest',
        );
      }
      return 'tcp';
    }

    if (preferred != null) return preferred; // e.g. 'usb', 'ble'

    if (Platform.isAndroid) return 'usb';
    if (Platform.isIOS) return 'ble';
    return 'usb'; // fallback
  }

  /// Resolves transport for signing, preferring the last-connected device's
  /// transport if available. Falls back to TCP on testnet, platform default
  /// on mainnet.
  static String resolveForSign() {
    final lastTransport = BitBox02Device.lastConnected?.transport;
    if (lastTransport != null) return resolve(preferred: lastTransport);
    return resolve(
      preferred: NetworkType.currentNetworkType.isTestnet ? 'tcp' : null,
    );
  }

  /// Whether TCP transport is currently allowed.
  static bool get canUseTcp => NetworkType.currentNetworkType.isTestnet;
}

class BitBox02TransportException implements Exception {
  final String message;
  const BitBox02TransportException(this.message);

  @override
  String toString() => 'BitBox02TransportException: $message';
}
