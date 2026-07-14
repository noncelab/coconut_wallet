import 'dart:convert';

import 'package:coconut_wallet/services/hardware_wallet/trezor_exceptions.dart';
import 'package:flutter/services.dart';

class TrezorDevice {
  static const MethodChannel _channel = MethodChannel('trezor');

  // Called by native when Trezor shows a 6-digit pairing code.
  // The registered handler must show a dialog and return the entered code,
  // or null/empty to cancel.
  static Future<String> Function()? onPairingCodeRequested;

  static void _ensureHandlerRegistered() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'showPairingCodeDialog') {
        final handler = onPairingCodeRequested;
        if (handler != null) {
          return await handler();
        }
        return '';
      }
      return null;
    });
  }

  final String id;
  final String label;

  TrezorDevice._({required this.id, required this.label});

  static Future<TrezorDevice> connect() async {
    _ensureHandlerRegistered();
    try {
      final raw = await _channel.invokeMethod<String>('connect');
      if (raw == null) {
        throw const TrezorConnectException('NULL_RESPONSE', 'Connect returned null');
      }
      // Rust returns JSON: {"device_id": "...", "label": "..."}
      // Fall back to treating raw string as plain device_id for backward compat.
      try {
        final json = jsonDecode(raw) as Map<String, dynamic>;
        return TrezorDevice._(id: json['device_id'] as String? ?? raw, label: json['label'] as String? ?? '');
      } catch (_) {
        return TrezorDevice._(id: raw, label: '');
      }
    } on PlatformException catch (e) {
      if (e.code == 'PAIRING_CANCELLED') {
        throw const TrezorPairingException('PAIRING_CANCELLED', 'Pairing cancelled by user');
      }
      if (e.code == 'PAIRING_CODE_WRONG') {
        throw TrezorPairingCodeWrongException(e.code, e.message ?? 'Wrong pairing code');
      }
      if (e.code == 'PAIRING_FAILED') {
        throw TrezorPairingException(e.code, e.message ?? 'Pairing failed');
      }
      throw TrezorConnectException(e.code, e.message ?? 'Connect failed');
    }
  }

  static Future<void> cancel() async {
    //try {
    await _channel.invokeMethod('cancel');
    //} on PlatformException catch (_) {}
  }

  Future<String> getXPub({required String keypath, String network = 'mainnet'}) async {
    try {
      final result = await _channel.invokeMethod<String>('getXPub', {'id': id, 'keypath': keypath, 'network': network});
      if (result == null) {
        throw const TrezorXPubException('NULL_RESPONSE', 'getXPub returned null');
      }
      final json = jsonDecode(result) as Map<String, dynamic>;
      final xpub = json['xpub'] as String?;
      if (xpub == null) {
        throw const TrezorXPubException('INVALID_RESPONSE', 'getXPub response missing xpub field');
      }
      return xpub;
    } on PlatformException catch (e) {
      throw TrezorXPubException(e.code, e.message ?? 'getXPub failed');
    }
  }

  Future<String> getFingerprint() async {
    try {
      final result = await _channel.invokeMethod<String>('getFingerprint', {'id': id});
      if (result == null) {
        throw const TrezorXPubException('NULL_RESPONSE', 'getFingerprint returned null');
      }
      return result;
    } on PlatformException catch (e) {
      throw TrezorXPubException(e.code, e.message ?? 'getFingerprint failed');
    }
  }

  Future<void> disconnect() async {
    try {
      await _channel.invokeMethod('disconnect', {'id': id});
    } on PlatformException catch (_) {}
  }
}
