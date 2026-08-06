import 'package:coconut_wallet/model/wallet/hot_wallet_secret.dart';
import 'package:coconut_wallet/services/security/device_dek_keystore.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('onl.coconut.wallet/device-dek');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  test('하드웨어 보호 종류와 암호화된 DEK를 반환한다', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'wrap');
      return <String, dynamic>{
        'ciphertext': Uint8List.fromList([4, 5, 6]),
        'protection': 'androidTee',
      };
    });

    final wrapped = await DeviceDekKeystore().wrap(alias: 'alias', dek: Uint8List(32));

    expect(wrapped.alias, 'alias');
    expect(wrapped.protection, DeviceKeyProtection.androidTee);
    expect(wrapped.ciphertext, [4, 5, 6]);
  });

  test('네이티브 키로 복호화한 DEK를 반환한다', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'unwrap');
      return Uint8List.fromList(List<int>.filled(32, 7));
    });

    final dek = await DeviceDekKeystore().unwrap(alias: 'alias', ciphertext: Uint8List.fromList([1, 2, 3]));

    expect(dek, List<int>.filled(32, 7));
  });
}
