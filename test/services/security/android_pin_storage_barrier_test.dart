import 'dart:async';
import 'package:coconut_wallet/services/security/pin_auth_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(AndroidPinStorageBarrier.channel, null));

  test('the durability barrier waits for completion and sends no authentication payload', () async {
    final gate = Completer<bool>();
    var completed = false;
    messenger.setMockMethodCallHandler(AndroidPinStorageBarrier.channel, (call) {
      expect(call.method, 'flush');
      expect(call.arguments, isNull);
      return gate.future;
    });
    final pending = AndroidPinStorageBarrier.flush().then((_) => completed = true);
    await Future<void>.delayed(Duration.zero);
    expect(completed, isFalse);
    gate.complete(true);
    await pending;
    expect(completed, isTrue);
  });

  test('a failed native commit cannot succeed or expose exception details', () async {
    messenger.setMockMethodCallHandler(AndroidPinStorageBarrier.channel, (_) async {
      throw PlatformException(
        code: 'PRIVATE_DATA',
        message: 'do not forward platform payload',
        details: {'secret': 'synthetic'},
      );
    });
    await expectLater(
      AndroidPinStorageBarrier.flush(),
      throwsA(isA<PinAuthException>().having((e) => e.toString(), 'safe message', 'PinAuthException(unavailable)')),
    );
  });

  test('a missing native handler fails closed', () async {
    await expectLater(AndroidPinStorageBarrier.flush(), throwsA(isA<PinAuthException>()));
  });
}
