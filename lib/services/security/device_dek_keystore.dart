import 'package:coconut_wallet/model/wallet/hot_wallet_secret.dart';
import 'package:flutter/services.dart';

class HardwareWrappedDek {
  const HardwareWrappedDek({required this.alias, required this.protection, required this.ciphertext});

  final String alias;
  final DeviceKeyProtection protection;
  final Uint8List ciphertext;
}

/// Wraps a hot-wallet DEK with a non-exportable, hardware-backed OS key.
///
/// The native implementation must reject software-backed Android Keystore
/// keys. Unsupported devices are handled by the repository's SecureStorage
/// fallback rather than by this class.
class DeviceDekKeystore {
  static const MethodChannel _channel = MethodChannel('onl.coconut.wallet/device-dek');

  Future<HardwareWrappedDek> wrap({required String alias, required Uint8List dek}) async {
    final result = await _channel.invokeMapMethod<String, dynamic>('wrap', <String, dynamic>{
      'alias': alias,
      'plaintext': dek,
    });
    final ciphertext = result?['ciphertext'];
    final protectionName = result?['protection'];
    if (ciphertext is! Uint8List || protectionName is! String) {
      throw PlatformException(code: 'INVALID_RESULT', message: 'Device DEK wrapping returned an invalid result');
    }
    return HardwareWrappedDek(
      alias: alias,
      protection: DeviceKeyProtection.fromName(protectionName),
      ciphertext: ciphertext,
    );
  }

  Future<Uint8List> unwrap({required String alias, required Uint8List ciphertext}) async {
    final result = await _channel.invokeMethod<Uint8List>('unwrap', <String, dynamic>{
      'alias': alias,
      'ciphertext': ciphertext,
    });
    if (result == null) {
      throw PlatformException(code: 'INVALID_RESULT', message: 'Device DEK unwrapping returned no plaintext');
    }
    return result;
  }

  Future<void> delete(String alias) => _channel.invokeMethod<void>('delete', <String, dynamic>{'alias': alias});
}
