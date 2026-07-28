import 'dart:convert';

import 'package:coconut_wallet/services/hardware_wallet/trezor_exceptions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum TrezorTransport { ble, usb }

enum TrezorPassphraseType { cancel, standard, hidden, onDevice }

class TrezorPassphraseResponse {
  final TrezorPassphraseType type;
  final String value;

  const TrezorPassphraseResponse(this.type, {this.value = ''});

  String encode() => jsonEncode({
    'type': switch (type) {
      TrezorPassphraseType.cancel => 'cancel',
      TrezorPassphraseType.standard => 'standard',
      TrezorPassphraseType.hidden => 'hidden',
      TrezorPassphraseType.onDevice => 'on_device',
    },
    'value': value,
  });
}

class TrezorDevice {
  static const MethodChannel _channel = MethodChannel('trezor');

  // Called by native when Trezor shows a 6-digit pairing code.
  // The registered handler must show a dialog and return the entered code,
  // or null/empty to cancel.
  static Future<String> Function()? onPairingCodeRequested;
  static Future<String?> Function()? onPinRequested;
  static Future<TrezorPassphraseResponse> Function(bool onDevice)? onPassphraseRequested;

  static void _ensureHandlerRegistered() {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'showPairingCodeDialog':
          return await onPairingCodeRequested?.call() ?? '';
        case 'showPinMatrix':
          return await onPinRequested?.call() ?? '';
        case 'showPassphraseDialog':
          final onDevice = (call.arguments as Map?)?['onDevice'] == true;
          final response =
              await onPassphraseRequested?.call(onDevice) ??
              const TrezorPassphraseResponse(TrezorPassphraseType.cancel);
          return response.encode();
      }
      return null;
    });
  }

  final String id;
  final String label;
  final String model;
  final TrezorTransport transport;

  /// Whether passphrase protection is enabled on the device.
  /// True if the user has turned on passphrase in Trezor settings;
  /// the device can open passphrase (hidden) wallets, not just the standard wallet.
  /// May be updated in-place after calling [applySettings].
  bool passphraseProtection;

  /// Whether the device is configured to always require passphrase entry on the device itself.
  final bool passphraseAlwaysOnDevice;

  /// Whether the device supports entering a passphrase on its own screen.
  /// True for Trezor Safe 3/5/7 (has a keypad); false for Trezor One (two buttons, no keypad).
  final bool supportsPassphraseEntry;

  /// Whether the device uses the THP (Trezor Hardware Protocol).
  /// True for Safe 3/5/7; false for legacy models (Trezor One, Model T).
  final bool usesThp;

  /// Last successfully paired device, reused for signing to avoid re-pairing.
  static TrezorDevice? lastConnected;

  /// Fingerprint cached from [getFingerprint], may be set by callers.
  String? cachedFingerprint;

  /// xpub cached from [getXPub] at the standard derivation path, may be set by callers.
  String? cachedXpub;

  TrezorDevice._({
    required this.id,
    required this.label,
    required this.model,
    required this.transport,
    this.passphraseProtection = false,
    this.passphraseAlwaysOnDevice = false,
    this.supportsPassphraseEntry = false,
    this.usesThp = false,
  });

  static Future<TrezorDevice> connect({TrezorTransport transport = TrezorTransport.ble}) async {
    _ensureHandlerRegistered();
    try {
      final raw = await _channel.invokeMethod<String>('connect', {'transport': transport.name});
      if (raw == null) {
        throw const TrezorConnectException('NULL_RESPONSE', 'Connect returned null');
      }
      // Rust returns JSON: {"device_id": "...", "label": "..."}
      // Fall back to treating raw string as plain device_id for backward compat.
      try {
        final json = jsonDecode(raw) as Map<String, dynamic>;
        final parsedTransport = TrezorTransport.values.firstWhere(
          (value) => value.name == json['transport'],
          orElse: () => transport,
        );
        final usesThp = json['uses_thp'] as bool? ?? false;
        debugPrint(
          'TREZOR_CONNECT transport=${parsedTransport.name} '
          'passphraseProtection=${json['passphrase_protection']} '
          'passphraseAlwaysOnDevice=${json['passphrase_always_on_device']} '
          'passphraseEntry=${json['passphrase_entry']} '
          'usesThp=$usesThp',
        );
        return TrezorDevice._(
          id: json['device_id'] as String? ?? raw,
          label: json['label'] as String? ?? '',
          model: json['model'] as String? ?? '',
          transport: parsedTransport,
          passphraseProtection: json['passphrase_protection'] as bool? ?? false,
          passphraseAlwaysOnDevice: json['passphrase_always_on_device'] as bool? ?? false,
          supportsPassphraseEntry: json['passphrase_entry'] as bool? ?? false,
          usesThp: usesThp,
        );
      } catch (_) {
        return TrezorDevice._(id: raw, label: '', model: '', transport: transport);
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
      if (e.code == 'PEER_REMOVED_PAIRING') {
        // iOS only
        throw TrezorConnectException(e.code, e.message ?? 'Peer removed pairing information');
      }
      throw TrezorConnectException(e.code, e.message ?? 'Connect failed');
    }
  }

  static Future<void> cancel() async {
    //try {
    await _channel.invokeMethod('cancel');
    //} on PlatformException catch (_) {}
  }

  static Future<bool> isConnected(TrezorTransport transport) async {
    try {
      return await _channel.invokeMethod<bool>('isConnected', {'transport': transport.name}) ?? false;
    } on PlatformException {
      return false;
    }
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

  /// Create a THP session with the given passphrase.
  ///
  /// Only meaningful for THP devices (Safe 3/5/7). For V1 devices this is a no-op.
  /// Must be called after [connect] and before [getXPub] / [signTransaction].
  ///
  /// [type] determines the passphrase mode:
  /// - [TrezorPassphraseType.standard] → standard wallet (no passphrase)
  /// - [TrezorPassphraseType.hidden] → hidden wallet with [value]
  /// - [TrezorPassphraseType.onDevice] → enter passphrase on device
  Future<void> createSession({TrezorPassphraseType type = TrezorPassphraseType.standard, String value = ''}) async {
    try {
      final typeStr = switch (type) {
        TrezorPassphraseType.cancel => 'cancel',
        TrezorPassphraseType.standard => 'standard',
        TrezorPassphraseType.hidden => 'hidden',
        TrezorPassphraseType.onDevice => 'on_device',
      };
      await _channel.invokeMethod('createSession', {'id': id, 'passphraseType': typeStr, 'passphraseValue': value});
    } on PlatformException catch (e) {
      throw TrezorConnectException(e.code, e.message ?? 'createSession failed');
    }
  }

  /// Apply settings to the device (e.g. enable/disable passphrase protection).
  ///
  /// [usePassphrase] controls the passphrase protection setting:
  /// - `true` → enable passphrase protection
  /// - `false` → disable passphrase protection
  /// - `null` → no change
  ///
  /// The device will prompt the user to confirm on its screen.
  Future<void> applySettings({bool? usePassphrase}) async {
    try {
      await _channel.invokeMethod('applySettings', {'id': id, 'usePassphrase': usePassphrase});
    } on PlatformException catch (e) {
      throw TrezorConnectException(e.code, e.message ?? 'applySettings failed');
    }
  }

  Future<void> setPrevTxHex(int inputIndex, String rawTxHex) async {
    try {
      await _channel.invokeMethod('setPrevTxHex', {'id': id, 'inputIndex': inputIndex, 'rawTxHex': rawTxHex});
    } on PlatformException catch (e) {
      debugPrint('TREZOR_SET_PREV_TX_ERROR: code=${e.code} message=${e.message}');
      throw TrezorSignException(e.code, e.message ?? 'setPrevTxHex failed');
    }
  }

  Future<void> clearPrevTxHexes() async {
    try {
      await _channel.invokeMethod('clearPrevTxHexes', {'id': id});
    } on PlatformException catch (_) {}
  }

  Future<String> signTransaction({required String psbtBase64, String network = 'mainnet'}) async {
    try {
      final result = await _channel.invokeMethod<String>('signTransaction', {
        'id': id,
        'psbtBase64': psbtBase64,
        'network': network,
      });
      if (result == null) {
        throw const TrezorSignException('NULL_RESPONSE', 'signTransaction returned null');
      }
      return result;
    } on PlatformException catch (e) {
      debugPrint('TREZOR_SIGN_ERROR: code=${e.code} message=${e.message}');
      throw TrezorSignException(e.code, e.message ?? 'signTransaction failed');
    }
  }

  Future<void> disconnect() async {
    try {
      await _channel.invokeMethod('disconnect', {'id': id, 'transport': transport.name});
    } on PlatformException catch (_) {}

    if (lastConnected == this) {
      lastConnected = null;
      cachedFingerprint = null;
      cachedXpub = null;
    }
  }
}
