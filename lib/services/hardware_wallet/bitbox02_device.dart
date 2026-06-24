import 'dart:convert';

import 'package:coconut_wallet/services/hardware_wallet/bitbox02_exceptions.dart';
import 'package:coconut_wallet/services/hardware_wallet/bitbox02_types.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class BitBox02Device {
  static const MethodChannel _channel = MethodChannel('bitbox02');

  final String id;
  final String transport;

  /// Last successfully paired device, reused for signing to avoid re-seeding.
  static BitBox02Device? lastConnected;

  BitBox02Device._({required this.id, required this.transport});

  static Future<BitBox02Device> connect({
    required String transport,
    String configJson = '',
    String? host,
    int? port,
  }) async {
    try {
      final args = <String, dynamic>{
        'transport': transport,
        'config': configJson,
      };
      if (host != null) args['host'] = host;
      if (port != null) args['port'] = port;

      final deviceId = await _channel.invokeMethod<String>('connect', args);
      if (deviceId == null) {
        throw const BitBox02ConnectException('NULL_RESPONSE', 'Connect returned null');
      }
      return BitBox02Device._(id: deviceId, transport: transport);
    } on PlatformException catch (e) {
      throw BitBox02ConnectException(e.code, e.message ?? 'Connect failed');
    }
  }

  Future<String> init() async {
    try {
      final status = await _channel.invokeMethod<String>('init', {'id': id});
      if (status == null) {
        throw const BitBox02InitException('NULL_RESPONSE', 'Init returned null');
      }
      return status;
    } on PlatformException catch (e) {
      throw BitBox02InitException(e.code, e.message ?? 'Init failed');
    }
  }

  Future<String> rootFingerprint() async {
    try {
      final fingerprint = await _channel.invokeMethod<String>('rootFingerprint', {'id': id});
      if (fingerprint == null) {
        throw const BitBox02SignException('NULL_RESPONSE', 'rootFingerprint returned null');
      }
      return fingerprint;
    } on PlatformException catch (e) {
      throw BitBox02SignException(e.code, e.message ?? 'rootFingerprint failed');
    }
  }

  Future<void> restoreFromMnemonic() async {
    try {
      await _channel.invokeMethod('restoreFromMnemonic', {'id': id});
    } on PlatformException catch (e) {
      throw BitBox02InitException(e.code, e.message ?? 'restoreFromMnemonic failed');
    }
  }

  Future<void> setPassword({int seedLen = 32}) async {
    try {
      await _channel.invokeMethod('setPassword', {'id': id, 'seedLen': seedLen});
    } on PlatformException catch (e) {
      throw BitBox02InitException(e.code, e.message ?? 'setPassword failed');
    }
  }

  Future<void> channelHashVerify({bool ok = true}) async {
    try {
      await _channel.invokeMethod('channelHashVerify', {'id': id, 'ok': ok});
    } on PlatformException catch (e) {
      throw BitBox02InitException(e.code, e.message ?? 'channelHashVerify failed');
    }
  }

  Future<bool> deviceInitialized() async {
    try {
      final result = await _channel.invokeMethod<bool>('deviceInitialized', {'id': id});
      return result ?? false;
    } on PlatformException catch (e) {
      throw BitBox02InitException(e.code, e.message ?? 'deviceInitialized failed');
    }
  }

  Future<String> btcXPub({
    required String keypath,
    BitBox02Coin coin = BitBox02Coin.btc,
    BitBox02XPubType xpubType = BitBox02XPubType.zpub,
    bool display = false,
  }) async {
    try {
      final result = await _channel.invokeMethod<String>('btcXPub', {
        'id': id,
        'coin': coin.value,
        'keypath': keypath,
        'xpubType': xpubType.value,
        'display': display,
      });
      if (result == null) {
        throw const BitBox02SignException('NULL_RESPONSE', 'btcXPub returned null');
      }
      final json = jsonDecode(result) as Map<String, dynamic>;
      final xpub = json['xpub'] as String?;
      if (xpub == null) {
        throw const BitBox02SignException('INVALID_RESPONSE', 'btcXPub response missing xpub field');
      }
      return xpub;
    } on PlatformException catch (e) {
      throw BitBox02SignException(e.code, e.message ?? 'btcXPub failed');
    }
  }

  Future<String> btcAddress({
    required String keypath,
    BitBox02Coin coin = BitBox02Coin.btc,
    BitBox02ScriptType scriptType = BitBox02ScriptType.p2wpkh,
    bool display = false,
  }) async {
    try {
      final result = await _channel.invokeMethod<String>('btcAddress', {
        'id': id,
        'coin': coin.value,
        'keypath': keypath,
        'scriptType': scriptType.value,
        'display': display,
      });
      if (result == null) {
        throw const BitBox02SignException('NULL_RESPONSE', 'btcAddress returned null');
      }
      final json = jsonDecode(result) as Map<String, dynamic>;
      final address = json['address'] as String?;
      if (address == null) {
        throw const BitBox02SignException('INVALID_RESPONSE', 'btcAddress response missing address field');
      }
      return address;
    } on PlatformException catch (e) {
      throw BitBox02SignException(e.code, e.message ?? 'btcAddress failed');
    }
  }

  /// Pre-loads a previous transaction hex for signing.
  /// Must be called before [btcSignPSBT] for each input that lacks NonWitnessUtxo.
  Future<void> setPrevTxHex(int inputIndex, String rawTxHex) async {
    try {
      await _channel.invokeMethod('setPrevTxHex', {
        'id': id,
        'inputIndex': inputIndex,
        'rawTxHex': rawTxHex,
      });
    } on PlatformException catch (e) {
      throw BitBox02SignException(e.code, e.message ?? 'setPrevTxHex failed');
    }
  }

  Future<Uint8List> btcSignPSBT({
    required Uint8List psbtBytes,
    BitBox02Coin coin = BitBox02Coin.btc,
    BitBox02FormatUnit formatUnit = BitBox02FormatUnit.defaultUnit,
  }) async {
    try {
      final signed = await _channel.invokeMethod<Uint8List>('btcSignPSBT', {
        'id': id,
        'coin': coin.value,
        'psbtBytes': psbtBytes,
        'formatUnit': formatUnit.value,
      });
      if (signed == null) {
        throw const BitBox02SignException('NULL_RESPONSE', 'btcSignPSBT returned null');
      }
      return signed;
    } on PlatformException catch (e) {
      debugPrint('BB02_SIGN_ERROR: code=${e.code} message=${e.message}');
      throw BitBox02SignException(e.code, e.message ?? 'btcSignPSBT failed');
    }
  }

  Future<String> btcSignPSBTBase64(String base64Psbt) async {
    final psbtBytes = base64Decode(base64Psbt);
    final signedBytes = await btcSignPSBT(psbtBytes: psbtBytes);
    return base64Encode(signedBytes);
  }

  Future<BitBox02SignMessageResult> btcSignMessage({
    required String keypath,
    required String message,
    BitBox02Coin coin = BitBox02Coin.btc,
    BitBox02ScriptType scriptType = BitBox02ScriptType.p2wpkh,
  }) async {
    try {
      final sigJson = await _channel.invokeMethod<String>('btcSignMessage', {
        'id': id,
        'coin': coin.value,
        'keypath': keypath,
        'scriptType': scriptType.value,
        'message': Uint8List.fromList(utf8.encode(message)),
      });
      if (sigJson == null) {
        throw const BitBox02SignException('NULL_RESPONSE', 'btcSignMessage returned null');
      }
      return BitBox02SignMessageResult.fromJson(jsonDecode(sigJson) as Map<String, dynamic>);
    } on PlatformException catch (e) {
      throw BitBox02SignException(e.code, e.message ?? 'btcSignMessage failed');
    }
  }

  Future<String> saveConfig() async {
    try {
      final configJson = await _channel.invokeMethod<String>('saveConfig', {'id': id});
      if (configJson == null) {
        throw const BitBox02ConfigException('NULL_RESPONSE', 'saveConfig returned null');
      }
      return configJson;
    } on PlatformException catch (e) {
      throw BitBox02ConfigException(e.code, e.message ?? 'saveConfig failed');
    }
  }

  Future<void> loadConfig(String configJson) async {
    try {
      await _channel.invokeMethod('loadConfig', {
        'id': id,
        'config': configJson,
      });
    } on PlatformException catch (e) {
      throw BitBox02ConfigException(e.code, e.message ?? 'loadConfig failed');
    }
  }

  Future<void> disconnect() async {
    try {
      await _channel.invokeMethod('disconnect', {'id': id});
    } on PlatformException catch (e) {
      throw BitBox02Exception(e.code, e.message ?? 'disconnect failed');
    }
  }

  static Future<void> setLoggerEnabled(bool enabled) async {
    try {
      await _channel.invokeMethod('setLoggerEnabled', {'enabled': enabled});
    } on PlatformException {
      // ignore logger errors
    }
  }
}
