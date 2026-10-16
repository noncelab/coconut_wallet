import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:coconut_wallet/constants/secure_keys.dart';
import 'package:coconut_wallet/services/security/pin_auth_service.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';

class MemoryStorage implements PinAuthStorage {
  final values = <String, String>{};
  bool failRead = false;
  bool failWrite = false;
  bool failDelete = false;
  bool ignoreDelete = false;
  bool corruptNextWrite = false;
  bool failAfterNextWrite = false;
  bool Function(String value)? rejectWrite;
  @override
  Future<String?> read(String key) async {
    if (failRead) throw StateError('storage secret must not escape');
    return values[key];
  }

  @override
  Future<void> write(String key, String value) async {
    if (failWrite || (rejectWrite?.call(value) ?? false)) throw StateError('storage secret must not escape');
    values[key] = corruptNextWrite ? '{}' : value;
    corruptNextWrite = false;
    if (failAfterNextWrite) {
      failAfterNextWrite = false;
      throw StateError('storage secret must not escape');
    }
  }

  @override
  Future<void> delete(String key) async {
    if (failDelete) throw StateError('storage secret must not escape');
    if (!ignoreDelete) values.remove(key);
  }

  Map<String, dynamic> get record => jsonDecode(values[PinAuthService.recordKey]!) as Map<String, dynamic>;
}

class TestKdf implements PinKdf {
  int calls = 0;
  bool fail = false;
  Completer<void>? gate;
  Uint8List? lastPin;
  Uint8List? lastSalt;
  Uint8List? lastHash;
  @override
  Future<Uint8List> derive(Uint8List pin, Uint8List salt, PinKdfParameters parameters) async {
    calls++;
    lastPin = pin;
    lastSalt = salt;
    if (gate != null) await gate!.future;
    if (fail) throw StateError('KDF secret must not escape');
    return lastHash = Uint8List.fromList(crypto.sha256.convert([...pin, ...salt]).bytes);
  }
}

class TestClock {
  DateTime wall = DateTime.utc(2026, 10, 13);
  int elapsed = 0;
  void advance(Duration duration) {
    wall = wall.add(duration);
    elapsed += duration.inMilliseconds;
  }
}

void main() {
  late MemoryStorage storage;
  late TestKdf kdf;
  late TestClock clock;
  late PinAuthService service;
  PinAuthService recreate() => PinAuthService(
    storage: storage,
    kdf: kdf,
    now: () => clock.wall,
    monotonicMilliseconds: () => clock.elapsed,
    random: Random(10),
  );
  setUp(() {
    storage = MemoryStorage();
    kdf = TestKdf();
    clock = TestClock();
    service = recreate();
  });

  test('new verifier stores version, KDF costs and a random salt, never plaintext or SHA-256', () async {
    await service.setPin('0012');
    final verifier = storage.record['verifier'] as Map<String, dynamic>;
    expect(storage.record['version'], 1);
    expect(verifier['algorithm'], 'argon2id');
    expect(verifier['pinLength'], 4);
    expect(verifier['memory'], 19456);
    expect(verifier['iterations'], 2);
    expect(verifier['parallelism'], 1);
    expect(base64Decode(verifier['salt'] as String).length, 16);
    expect(storage.values.containsKey(kSecureStoragePinKey), isFalse);
    expect(storage.values.values.join(), isNot(contains('0012')));
    expect((await service.verify('0012')).outcome, PinVerificationOutcome.success);
    expect((await service.verify('0120')).outcome, PinVerificationOutcome.incorrect);
  });

  test('PIN change needs authentication, refreshes salt and does not count new PIN equality as failure', () async {
    await service.setPin('1234');
    final salt = (storage.record['verifier'] as Map)['salt'];
    await expectLater(
      service.setPin('654321'),
      throwsA(isA<PinAuthException>().having((e) => e.code, 'code', PinAuthError.unauthorized)),
    );
    await service.verify('1234');
    await expectLater(
      service.setPin('1234'),
      throwsA(isA<PinAuthException>().having((e) => e.code, 'code', PinAuthError.alreadyInUse)),
    );
    expect(storage.record['failures'], 0);
    await service.setPin('654321');
    expect((storage.record['verifier'] as Map)['salt'], isNot(salt));
    expect((await service.verify('654321')).outcome, PinVerificationOutcome.success);
  });

  test('successful legacy authentication migrates without requiring PIN reset', () async {
    storage.values[kSecureStoragePinKey] = crypto.sha256.convert(utf8.encode('000123')).toString();
    expect((await service.verify('000123')).outcome, PinVerificationOutcome.success);
    expect((storage.record['verifier'] as Map)['algorithm'], 'argon2id');
    expect((storage.record['verifier'] as Map)['pinLength'], 6);
    expect(storage.values.containsKey(kSecureStoragePinKey), isFalse);
    expect((await recreate().verify('000123')).outcome, PinVerificationOutcome.success);
  });

  test('wrong legacy PIN persists a failure without upgrading or deleting the verifier', () async {
    storage.values[kSecureStoragePinKey] = crypto.sha256.convert(utf8.encode('1234')).toString();
    expect((await service.verify('4321')).outcome, PinVerificationOutcome.incorrect);
    expect(storage.record['failures'], 1);
    expect((storage.record['verifier'] as Map)['algorithm'], 'sha256-legacy');
    expect(kdf.calls, 0);
    expect(storage.values.containsKey(kSecureStoragePinKey), isTrue);
  });

  test('third failure blocks all entry points and survives service recreation', () async {
    await service.setPin('1234');
    for (var i = 0; i < 3; i++) {
      await service.verify('4321');
    }
    final calls = kdf.calls;
    final restarted = recreate();
    final blocked = await restarted.verify('1234');
    expect(blocked.outcome, PinVerificationOutcome.blocked);
    expect(blocked.status.remainingSeconds, 30);
    expect(kdf.calls, calls);
    clock.advance(const Duration(seconds: 30));
    expect((await restarted.verify('1234')).outcome, PinVerificationOutcome.success);
    expect((await service.status()).failures, 0);
  });

  test('failure delay increases and is capped at 15 minutes', () async {
    await service.setPin('1234');
    for (var failure = 1; failure <= 24; failure++) {
      final result = await service.verify('4321');
      final delay = PinAuthService.delayForFailures(failure);
      expect(result.status.remaining, delay);
      clock.advance(delay);
    }
    expect(PinAuthService.delayForFailures(3), const Duration(seconds: 30));
    expect(PinAuthService.delayForFailures(4), Duration.zero);
    expect(PinAuthService.delayForFailures(5), Duration.zero);
    expect(PinAuthService.delayForFailures(6), const Duration(seconds: 60));
    expect(PinAuthService.delayForFailures(18), const Duration(minutes: 15));
    expect(PinAuthService.delayForFailures(999999), const Duration(minutes: 15));
  });

  test('each completed cooldown restores three attempts even across screen or app restarts', () async {
    await service.setPin('1234');
    for (var i = 0; i < 3; i++) {
      await service.verify('4321');
    }
    clock.advance(const Duration(seconds: 30));
    for (final count in [4, 5]) {
      final result = await recreate().verify('4321');
      expect(result.outcome, PinVerificationOutcome.incorrect);
      expect(result.status.failures, count);
      expect(result.status.isBlocked, isFalse);
    }
    final third = await recreate().verify('4321');
    expect(third.status.failures, 6);
    expect(third.status.remainingSeconds, 60);
    expect((await recreate().verify('1234')).outcome, PinVerificationOutcome.blocked);
    clock.advance(const Duration(seconds: 60));
    expect((await recreate().verify('1234')).outcome, PinVerificationOutcome.success);
  });

  test('the counter ceiling retains three attempts and the maximum delay', () async {
    await service.setPin('1234');
    final record = storage.record;
    record['failures'] = 999999;
    storage.values[PinAuthService.recordKey] = jsonEncode(record);
    expect((await service.verify('4321')).status.isBlocked, isFalse);
    expect((await service.verify('4321')).status.isBlocked, isFalse);
    expect((await service.verify('4321')).status.remaining, const Duration(minutes: 15));
  });

  test('biometric success resets failures without migrating legacy PINs', () async {
    storage.values[kSecureStoragePinKey] = crypto.sha256.convert(utf8.encode('1234')).toString();
    await service.verify('4321');
    await service.onBiometricAuthenticationSucceeded();
    expect((await service.status()).failures, 0);
    expect((storage.record['verifier'] as Map)['algorithm'], 'sha256-legacy');
    expect(kdf.calls, 0);
  });

  test('biometric success clears an active cooldown and persists it across restarts', () async {
    await service.setPin('1234');
    final verifier = storage.record['verifier'];
    for (var i = 0; i < 3; i++) {
      await service.verify('4321');
    }
    expect((await service.status()).isBlocked, isTrue);
    final calls = kdf.calls;
    await service.onBiometricAuthenticationSucceeded();
    final restored = await recreate().status();
    expect(restored.failures, 0);
    expect(restored.isBlocked, isFalse);
    expect(storage.record['verifier'], verifier);
    expect(kdf.calls, calls);
  });

  test('a failed biometric reset does not grant PIN management or clear the stored cooldown', () async {
    await service.setPin('1234');
    for (var i = 0; i < 3; i++) {
      await service.verify('4321');
    }
    storage.failWrite = true;
    await expectLater(service.onBiometricAuthenticationSucceeded(), throwsA(isA<PinAuthException>()));
    storage.failWrite = false;
    expect((await service.status()).failures, 3);
    expect((await service.status()).isBlocked, isTrue);
    await expectLater(service.deletePin(), throwsA(isA<PinAuthException>()));
  });

  test('a corrupt new record never falls back to a valid legacy verifier', () async {
    storage.values[kSecureStoragePinKey] = crypto.sha256.convert(utf8.encode('1234')).toString();
    storage.values[PinAuthService.recordKey] = '{}';
    expect((await service.verify('1234')).outcome, PinVerificationOutcome.unavailable);
    expect(kdf.calls, 0);
  });

  test('unsupported or expensive KDF parameters are rejected before hashing', () async {
    await service.setPin('1234');
    final record = storage.record;
    (record['verifier'] as Map)['memory'] = 2147483647;
    storage.values[PinAuthService.recordKey] = jsonEncode(record);
    final calls = kdf.calls;
    expect((await service.verify('1234')).outcome, PinVerificationOutcome.unavailable);
    expect(kdf.calls, calls);
  });

  test('failure state write errors prevent hashing and never grant authentication', () async {
    await service.setPin('1234');
    final calls = kdf.calls;
    storage.rejectWrite = (raw) => (jsonDecode(raw) as Map)['failures'] > 0;
    expect((await service.verify('1234')).outcome, PinVerificationOutcome.unavailable);
    expect(kdf.calls, calls);
  });

  test('KDF failure keeps the reserved attempt and clears sensitive buffers', () async {
    await service.setPin('1234');
    kdf.fail = true;
    expect((await service.verify('1234')).outcome, PinVerificationOutcome.unavailable);
    expect(storage.record['failures'], 1);
    expect(kdf.lastPin, everyElement(0));
    expect(kdf.lastSalt, everyElement(0));
  });

  test('migration failure preserves legacy verifier and reserved failure state', () async {
    storage.values[kSecureStoragePinKey] = crypto.sha256.convert(utf8.encode('1234')).toString();
    kdf.fail = true;
    expect((await service.verify('1234')).outcome, PinVerificationOutcome.unavailable);
    expect(storage.values.containsKey(kSecureStoragePinKey), isTrue);
    expect(storage.record['failures'], 1);
    kdf.fail = false;
    expect((await recreate().verify('1234')).outcome, PinVerificationOutcome.success);
  });

  test('interrupted verification reserves a failure; parallel calls do not start a second KDF', () async {
    await service.setPin('1234');
    kdf.gate = Completer<void>();
    final first = service.verify('4321');
    while (kdf.calls < 2) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(storage.record['failures'], 1);
    expect((await service.verify('1234')).outcome, PinVerificationOutcome.busy);
    await expectLater(service.resetStorage(() async => storage.values.clear()), throwsA(isA<PinAuthException>()));
    kdf.gate!.complete();
    expect((await first).outcome, PinVerificationOutcome.incorrect);
    expect((await recreate().status()).failures, 1);
  });

  test('time spent with the app closed is deducted from the saved cooldown', () async {
    await service.setPin('1234');
    for (var i = 0; i < 3; i++) {
      await service.verify('4321');
    }
    clock.advance(const Duration(seconds: 10));
    expect((await recreate().status()).remainingSeconds, 20);
    clock.advance(const Duration(seconds: 20));
    expect((await recreate().verify('1234')).outcome, PinVerificationOutcome.success);
  });

  test('backward clock changes extend the wait until the saved unlock time', () async {
    await service.setPin('1234');
    for (var i = 0; i < 3; i++) {
      await service.verify('4321');
    }
    clock.wall = clock.wall.subtract(const Duration(days: 1));
    expect((await recreate().status()).remainingSeconds, const Duration(days: 1, seconds: 30).inSeconds);
    clock.advance(const Duration(days: 1, seconds: 30));
    expect((await recreate().verify('1234')).outcome, PinVerificationOutcome.success);
  });

  test('unlock availability uses system time like Vault, including after restarting', () async {
    await service.setPin('1234');
    for (var i = 0; i < 3; i++) {
      await service.verify('4321');
    }
    clock.wall = clock.wall.add(const Duration(minutes: 1));
    expect((await service.status()).isBlocked, isFalse);
    expect((await recreate().verify('1234')).outcome, PinVerificationOutcome.success);
  });

  test('management permission expires and deletion records explicit disabled state', () async {
    await service.setPin('1234');
    await service.verify('1234');
    clock.advance(const Duration(minutes: 5));
    await expectLater(service.deletePin(), throwsA(isA<PinAuthException>()));
    await service.onBiometricAuthenticationSucceeded();
    await service.deletePin();
    expect(storage.record['disabled'], isTrue);
    expect(storage.record.containsKey('verifier'), isFalse);
    expect((await recreate().configuration()).explicitlyDisabled, isTrue);
    await recreate().setPin('654321');
    expect((await recreate().verify('654321')).outcome, PinVerificationOutcome.success);
  });

  test('legacy cleanup failure during change leaves the original PIN active', () async {
    await service.setPin('1234');
    await service.verify('1234');
    storage.failDelete = true;
    await expectLater(service.setPin('654321'), throwsA(isA<PinAuthException>()));
    storage.failDelete = false;
    expect((await recreate().verify('1234')).outcome, PinVerificationOutcome.success);
    expect((await recreate().configuration()).length, 4);
  });

  test('replacement readback failure restores the previous verifier', () async {
    await service.setPin('1234');
    await service.verify('1234');
    storage.corruptNextWrite = true;
    await expectLater(service.setPin('654321'), throwsA(isA<PinAuthException>()));
    expect((await recreate().verify('1234')).outcome, PinVerificationOutcome.success);
  });

  test('failure after writing the replacement restores the original PIN', () async {
    await service.setPin('1234');
    await service.verify('1234');
    storage.failAfterNextWrite = true;
    await expectLater(service.setPin('654321'), throwsA(isA<PinAuthException>()));
    expect((await recreate().configuration()).length, 4);
    expect((await recreate().verify('1234')).outcome, PinVerificationOutcome.success);
  });

  test('failed rollback reports uncertain state and consumes management permission', () async {
    await service.setPin('1234');
    await service.verify('1234');
    storage.failWrite = true;
    await expectLater(
      service.setPin('654321'),
      throwsA(isA<PinAuthException>().having((e) => e.code, 'code', PinAuthError.stateUncertain)),
    );
    storage.failWrite = false;
    await expectLater(
      service.deletePin(),
      throwsA(isA<PinAuthException>().having((e) => e.code, 'code', PinAuthError.unauthorized)),
    );
    expect((await recreate().verify('1234')).outcome, PinVerificationOutcome.success);
  });

  test('failed disable write retains the original PIN', () async {
    await service.setPin('1234');
    await service.verify('1234');
    storage.corruptNextWrite = true;
    await expectLater(service.deletePin(), throwsA(isA<PinAuthException>()));
    expect((await recreate().verify('1234')).outcome, PinVerificationOutcome.success);
  });

  test('readback mismatch fails closed and exception messages contain no payload', () async {
    storage.corruptNextWrite = true;
    await expectLater(
      service.setPin('1234'),
      throwsA(isA<PinAuthException>().having((e) => e.toString(), 'safe message', 'PinAuthException(unavailable)')),
    );
    storage.failRead = true;
    expect((await service.verify('1234')).outcome, PinVerificationOutcome.unavailable);
  });

  test('a legacy verifier that was not deleted cannot produce an authentication success', () async {
    storage.values[kSecureStoragePinKey] = crypto.sha256.convert(utf8.encode('1234')).toString();
    storage.ignoreDelete = true;
    expect((await service.verify('1234')).outcome, PinVerificationOutcome.unavailable);
    expect((storage.record['verifier'] as Map)['algorithm'], 'argon2id');
    expect(storage.values.containsKey(kSecureStoragePinKey), isTrue);
    storage.ignoreDelete = false;
    expect((await service.verify('1234')).outcome, PinVerificationOutcome.success);
    expect(storage.values.containsKey(kSecureStoragePinKey), isFalse);
  });

  test('all caller-owned PIN, salt and result buffers are cleared after derivation', () async {
    await service.setPin('1234');
    expect(kdf.lastPin, everyElement(0));
    expect(kdf.lastSalt, everyElement(0));
    expect(kdf.lastHash, everyElement(0));
    await service.verify('1234');
    expect(kdf.lastPin, everyElement(0));
    expect(kdf.lastSalt, everyElement(0));
    expect(kdf.lastHash, everyElement(0));
  });

  test('invalid PIN lengths and non-ASCII digits cannot be stored', () async {
    for (final pin in ['123', '12345', '1234567', '１２３４', '12a4']) {
      await expectLater(service.setPin(pin), throwsA(isA<PinAuthException>()));
    }
    expect(storage.values, isEmpty);
  });

  test('RFC 9106 Argon2id known-answer vector matches the selected algorithm', () async {
    final result = await Argon2id(memory: 32, iterations: 3, parallelism: 4, hashLength: 32).deriveKey(
      secretKey: SecretKey(List.filled(32, 1)),
      nonce: List.filled(16, 2),
      optionalSecret: List.filled(8, 3),
      associatedData: List.filled(12, 4),
    );
    final bytes = await result.extractBytes();
    expect(
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
      '0d640df58d78766c08c037a34a8b53c9d01ef0452d75b65eb52520e96b01e659',
    );
    result.destroy();
  });

  test(
    'production isolate KDF verifies a leading-zero PIN and allows the UI isolate to run',
    () async {
      final real = PinAuthService(storage: storage);
      var ticks = 0;
      final timer = Timer.periodic(const Duration(milliseconds: 10), (_) => ticks++);
      try {
        await real.setPin('001234');
        expect((await real.verify('001234')).outcome, PinVerificationOutcome.success);
        expect((await real.verify('123400')).outcome, PinVerificationOutcome.incorrect);
        expect(ticks, greaterThan(0));
      } finally {
        timer.cancel();
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
