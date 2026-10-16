import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:cryptography/helpers.dart';
import 'package:flutter/services.dart' show MethodChannel;
import 'package:coconut_wallet/constants/secure_keys.dart';
import 'package:coconut_wallet/services/security/pin_kdf.dart';

import 'package:coconut_wallet/repository/secure_storage/secure_storage_repository.dart';

export 'pin_kdf.dart';

/// Implementations must never log keys, values, exceptions or authentication payloads.
abstract interface class PinAuthStorage {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class SecurePinAuthStorage implements PinAuthStorage {
  final SecureStorageRepository _storage = SecureStorageRepository();

  @override
  Future<String?> read(String key) => _storage.read(key: key);
  @override
  Future<void> write(String key, String value) async {
    await _storage.write(key: key, value: value);
    if (Platform.isAndroid) await AndroidPinStorageBarrier.flush();
  }

  @override
  Future<void> delete(String key) async {
    await _storage.delete(key: key);
    if (Platform.isAndroid) await AndroidPinStorageBarrier.flush();
  }
}

class AndroidPinStorageBarrier {
  static const channel = MethodChannel('onl.coconut.wallet/pin_auth_storage');

  static Future<void> flush() async {
    try {
      if (await channel.invokeMethod<bool>('flush') != true) {
        throw const PinAuthException(PinAuthError.unavailable);
      }
    } catch (_) {
      throw const PinAuthException(PinAuthError.unavailable);
    }
  }
}

enum PinAuthError { unavailable, invalidRecord, busy, invalidPin, unauthorized, alreadyInUse, stateUncertain }

/// Fixed messages only: do not include the underlying exception or stored record.
class PinAuthException implements Exception {
  final PinAuthError code;
  const PinAuthException(this.code);
  @override
  String toString() => 'PinAuthException(${code.name})';
}

enum PinVerificationOutcome { success, incorrect, blocked, busy, unavailable }

class PinAuthStatus {
  final int failures;
  final Duration remaining;
  final DateTime? unlockAvailableAt;
  const PinAuthStatus({this.failures = 0, this.remaining = Duration.zero, this.unlockAvailableAt});
  bool get isBlocked => remaining > Duration.zero;
  int get remainingSeconds => (remaining.inMilliseconds / 1000).ceil();
  int get remainingAttempts => isBlocked ? 0 : 3 - failures % 3;
}

class PinVerificationResult {
  final PinVerificationOutcome outcome;
  final PinAuthStatus status;
  const PinVerificationResult(this.outcome, [this.status = const PinAuthStatus()]);
}

/// A single versioned record holds both verifier and throttle: a failed attempt is
/// persisted BEFORE hashing, so force-closing during verification still consumes it.
/// New records are authoritative; corrupt records never fall back to legacy SHA-256.
class PinAuthService {
  static const recordKey = 'pin_auth_v1';
  static const maxDelay = Duration(minutes: 15);
  final PinAuthStorage _storage;
  final PinKdf _kdf;
  final DateTime Function() _wallClock;
  final Random _random;
  final Stopwatch _elapsed = Stopwatch()..start();
  late final int Function() _monotonic;
  bool _busy = false;
  int _managementExpiresAt = 0;
  bool get _canManagePin => _managementExpiresAt > _monotonic();

  PinAuthService({
    PinAuthStorage? storage,
    PinKdf? kdf,
    DateTime Function()? now,
    int Function()? monotonicMilliseconds,
    Random? random,
  }) : _storage = storage ?? SecurePinAuthStorage(),
       _kdf = kdf ?? const Argon2PinKdf(),
       _wallClock = now ?? DateTime.now,
       _random = random ?? Random.secure() {
    _monotonic = monotonicMilliseconds ?? (() => _elapsed.elapsedMilliseconds);
  }

  /// 생체인증 성공 시 PIN 실패 횟수와 대기 시간을 초기화합니다.
  /// PIN을 알 수 없으므로 기존 verifier는 이전하지 않습니다.
  Future<void> onBiometricAuthenticationSucceeded() => _exclusive(() async {
    final record = await _loadOrImportLegacy();
    if (record != null) {
      record['failures'] = 0;
      record['nextAllowedAt'] = 0;
      record['lastObservedAt'] = _now;
      await _save(record);
    }
    _managementExpiresAt = _monotonic() + const Duration(minutes: 5).inMilliseconds;
  });

  Future<T> _exclusive<T>(Future<T> Function() operation) async {
    if (_busy) throw const PinAuthException(PinAuthError.busy);
    _busy = true;
    try {
      return await operation();
    } on PinAuthException {
      rethrow;
    } catch (_) {
      throw const PinAuthException(PinAuthError.unavailable);
    } finally {
      _busy = false;
    }
  }

  int get _now => _wallClock().millisecondsSinceEpoch;

  static Duration delayForFailures(int failures) {
    // 대기 후에도 매 회차 3번의 기회를 제공하고, 세 번째 실패에서만 지연합니다.
    if (failures < 3 || failures % 3 != 0) return Duration.zero;
    final turn = failures ~/ 3;
    return Duration(seconds: min(900, 30 * (1 << min(5, turn - 1))));
  }

  Future<Map<String, dynamic>?> _load() async {
    final raw = await _storage.read(recordKey);
    if (raw == null) return null;
    if (raw.length > 4096) throw const PinAuthException(PinAuthError.invalidRecord);
    try {
      final record = jsonDecode(raw) as Map<String, dynamic>;
      if (record['version'] != 1 ||
          record['failures'] is! int ||
          record['failures'] < 0 ||
          record['failures'] > 1000000 ||
          record['nextAllowedAt'] is! int ||
          record['lastObservedAt'] is! int ||
          record['nextAllowedAt'] < 0 ||
          record['lastObservedAt'] < 0 ||
          record['nextAllowedAt'] > record['lastObservedAt'] + maxDelay.inMilliseconds) {
        throw const PinAuthException(PinAuthError.invalidRecord);
      }
      if (record['disabled'] == true) {
        if (record.containsKey('verifier') || record['failures'] != 0 || record['nextAllowedAt'] != 0) {
          throw const PinAuthException(PinAuthError.invalidRecord);
        }
        return record;
      }
      final verifier = record['verifier'] as Map<String, dynamic>;
      if (verifier['algorithm'] == 'sha256-legacy') {
        if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(verifier['hash'] as String)) {
          throw const PinAuthException(PinAuthError.invalidRecord);
        }
      } else {
        if (verifier['algorithm'] != 'argon2id' ||
            verifier['argonVersion'] != 19 ||
            ![4, 6].contains(verifier['pinLength']) ||
            verifier['memory'] != PinKdfParameters.current.memory ||
            verifier['iterations'] != PinKdfParameters.current.iterations ||
            verifier['parallelism'] != PinKdfParameters.current.parallelism ||
            verifier['salt'] is! String ||
            (verifier['salt'] as String).length != 24 ||
            verifier['hash'] is! String ||
            (verifier['hash'] as String).length != 44 ||
            base64Decode(verifier['salt'] as String).length != 16 ||
            base64Decode(verifier['hash'] as String).length != 32) {
          throw const PinAuthException(PinAuthError.invalidRecord);
        }
      }
      return record;
    } catch (_) {
      throw const PinAuthException(PinAuthError.invalidRecord);
    }
  }

  Future<Map<String, dynamic>?> _loadOrImportLegacy() async {
    final record = await _load();
    if (record != null) return record;
    final legacy = await _storage.read(kSecureStoragePinKey);
    if (legacy == null) return null;
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(legacy)) throw const PinAuthException(PinAuthError.invalidRecord);
    final imported = _record({'algorithm': 'sha256-legacy', 'hash': legacy});
    await _save(imported);
    return imported;
  }

  Map<String, dynamic> _record(Map<String, dynamic> verifier) => {
    'version': 1,
    'verifier': verifier,
    'failures': 0,
    'nextAllowedAt': 0,
    'lastObservedAt': _now,
  };

  Future<void> _deleteLegacy() async {
    await _storage.delete(kSecureStoragePinKey);
    if (await _storage.read(kSecureStoragePinKey) != null) {
      throw const PinAuthException(PinAuthError.unavailable);
    }
  }

  Future<void> _save(Map<String, dynamic> record) async {
    final encoded = jsonEncode(record);
    await _storage.write(recordKey, encoded);
    if (await _storage.read(recordKey) != encoded) throw const PinAuthException(PinAuthError.unavailable);
  }

  PinAuthStatus _status(Map<String, dynamic> record) {
    final nextAllowedAt = record['nextAllowedAt'] as int;
    return PinAuthStatus(
      failures: record['failures'] as int,
      remaining: Duration(milliseconds: max(0, nextAllowedAt - _now)),
      unlockAvailableAt: nextAllowedAt == 0 ? null : DateTime.fromMillisecondsSinceEpoch(nextAllowedAt),
    );
  }

  Future<({bool configured, int? length, bool explicitlyDisabled})> configuration() => _exclusive(() async {
    final record = await _load();
    if (record != null) {
      if (record['disabled'] == true) return (configured: false, length: null, explicitlyDisabled: true);
      return (
        explicitlyDisabled: false,
        configured: true,
        length: (record['verifier'] as Map<String, dynamic>)['pinLength'] as int?,
      );
    }
    final legacy = await _storage.read(kSecureStoragePinKey);
    if (legacy == null) return (configured: false, length: null, explicitlyDisabled: false);
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(legacy)) throw const PinAuthException(PinAuthError.invalidRecord);
    return (configured: true, length: null, explicitlyDisabled: false);
  });

  Future<PinAuthStatus> status() => _exclusive(() async {
    final record = await _loadOrImportLegacy();
    if (record == null || record['disabled'] == true) throw const PinAuthException(PinAuthError.unavailable);
    return _status(record);
  });

  Future<PinVerificationResult> verify(String pin) async {
    try {
      return await _exclusive(() async {
        final record = await _loadOrImportLegacy();
        if (record == null || record['disabled'] == true) {
          return const PinVerificationResult(PinVerificationOutcome.unavailable);
        }
        final status = _status(record);
        if (status.isBlocked) return PinVerificationResult(PinVerificationOutcome.blocked, status);
        // 카운터 상한에서도 마지막 회차의 3회 기회와 최대 지연을 유지합니다.
        record['failures'] = status.failures >= 999999 ? 999997 : status.failures + 1;
        record['lastObservedAt'] = _now;
        record['nextAllowedAt'] = _now + delayForFailures(record['failures'] as int).inMilliseconds;
        await _save(record);
        final verifier = record['verifier'] as Map<String, dynamic>;
        final valid = _validPin(pin) && await _matches(pin, verifier);
        if (!valid) return PinVerificationResult(PinVerificationOutcome.incorrect, _status(record));
        if (verifier['algorithm'] == 'sha256-legacy') record['verifier'] = await _createVerifier(pin);
        record['failures'] = 0;
        record['nextAllowedAt'] = 0;
        record['lastObservedAt'] = _now;
        await _save(record);
        await _deleteLegacy();
        _managementExpiresAt = _monotonic() + const Duration(minutes: 5).inMilliseconds;
        return const PinVerificationResult(PinVerificationOutcome.success);
      });
    } on PinAuthException catch (error) {
      return PinVerificationResult(
        error.code == PinAuthError.busy ? PinVerificationOutcome.busy : PinVerificationOutcome.unavailable,
      );
    }
  }

  static bool _validPin(String pin) => RegExp(r'^(?:[0-9]{4}|[0-9]{6})$').hasMatch(pin);

  Future<bool> _matches(String pin, Map<String, dynamic> verifier) async {
    final bytes = utf8.encode(pin);
    Uint8List? actual;
    Uint8List? expected;
    Uint8List? salt;
    try {
      if (verifier['algorithm'] == 'sha256-legacy') {
        actual = Uint8List.fromList(crypto.sha256.convert(bytes).bytes);
        final hex = verifier['hash'] as String;
        expected = Uint8List(32);
        for (var i = 0; i < hex.length; i += 2) {
          expected[i ~/ 2] = int.parse(hex.substring(i, i + 2), radix: 16);
        }
      } else {
        salt = base64Decode(verifier['salt'] as String);
        actual = await _kdf.derive(bytes, salt, PinKdfParameters.current);
        expected = base64Decode(verifier['hash'] as String);
      }
      return constantTimeBytesEquality.equals(actual, expected);
    } finally {
      bytes.fillRange(0, bytes.length, 0);
      actual?.fillRange(0, actual.length, 0);
      expected?.fillRange(0, expected.length, 0);
      salt?.fillRange(0, salt.length, 0);
    }
  }

  Future<Map<String, dynamic>> _createVerifier(String pin) async {
    final salt = Uint8List(16);
    for (var i = 0; i < salt.length; i++) {
      salt[i] = _random.nextInt(256);
    }
    final bytes = utf8.encode(pin);
    Uint8List? hash;
    try {
      hash = await _kdf.derive(bytes, salt, PinKdfParameters.current);
      if (hash.length != 32) throw const PinAuthException(PinAuthError.unavailable);
      return {
        'algorithm': 'argon2id',
        'pinLength': pin.length,
        'argonVersion': 19,
        'memory': PinKdfParameters.current.memory,
        'iterations': PinKdfParameters.current.iterations,
        'parallelism': PinKdfParameters.current.parallelism,
        'salt': base64Encode(salt),
        'hash': base64Encode(hash),
      };
    } finally {
      bytes.fillRange(0, bytes.length, 0);
      salt.fillRange(0, salt.length, 0);
      hash?.fillRange(0, hash.length, 0);
    }
  }

  /// 저장 확인 실패 시 기존 상태를 복구합니다. 복구도 실패하면 상태를 단정하지 않습니다.
  Future<void> _replaceRecord(Map<String, dynamic> replacement, Map<String, dynamic>? previous) async {
    try {
      await _save(replacement);
    } catch (_) {
      try {
        if (previous != null) {
          await _save(previous);
        } else {
          await _storage.delete(recordKey);
          if (await _storage.read(recordKey) != null) throw const PinAuthException(PinAuthError.unavailable);
        }
      } catch (_) {
        _managementExpiresAt = 0;
        throw const PinAuthException(PinAuthError.stateUncertain);
      }
      throw const PinAuthException(PinAuthError.unavailable);
    }
  }

  Future<void> setPin(String pin) => _exclusive(() async {
    if (!_validPin(pin)) throw const PinAuthException(PinAuthError.invalidPin);
    final previous = await _loadOrImportLegacy();
    if (previous != null && previous['disabled'] != true) {
      if (!_canManagePin) throw const PinAuthException(PinAuthError.unauthorized);
      // This is a new-PIN equality check after authentication, NOT a failed login.
      if (await _matches(pin, previous['verifier'] as Map<String, dynamic>)) {
        throw const PinAuthException(PinAuthError.alreadyInUse);
      }
    }
    final replacement = _record(await _createVerifier(pin));
    await _deleteLegacy();
    await _replaceRecord(replacement, previous);
    _managementExpiresAt = 0;
  });

  Future<void> deletePin() => _exclusive(() async {
    if (!_canManagePin) throw const PinAuthException(PinAuthError.unauthorized);
    final previous = await _loadOrImportLegacy();
    // 명시적으로 해제한 상태를 남겨 메타데이터 갱신 중 종료되어도 복구합니다.
    await _deleteLegacy();
    await _replaceRecord({
      'version': 1,
      'disabled': true,
      'failures': 0,
      'nextAllowedAt': 0,
      'lastObservedAt': _now,
    }, previous);
    _managementExpiresAt = 0;
  });

  /// Serialize the explicitly confirmed destructive reset with any verification.
  Future<void> resetStorage(Future<void> Function() deleteAll) => _exclusive(() async {
    await deleteAll();
    // Deleting through the adapter also flushes Android's pending deleteAll().
    await _storage.delete(recordKey);
    await _deleteLegacy();
    _managementExpiresAt = 0;
  });
}
