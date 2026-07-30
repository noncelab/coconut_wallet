import 'dart:async';
import 'dart:convert';

import 'package:coconut_wallet/services/hardware_wallet/trezor_device.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('trezor');

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    TrezorDevice.lastConnected = null;
    TrezorDevice.onPairingCodeRequested = null;
    TrezorDevice.onPinRequested = null;
    TrezorDevice.onPassphraseRequested = null;
  });

  test('connect sends USB transport and parses device metadata', () async {
    MethodCall? received;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      received = call;
      return jsonEncode({'device_id': 'usb:model-one', 'label': 'My Trezor', 'model': '1', 'transport': 'usb'});
    });

    final device = await TrezorDevice.connect(transport: TrezorTransport.usb);

    expect(received?.method, 'connect');
    expect(received?.arguments, {'transport': 'usb'});
    expect(device.id, 'usb:model-one');
    expect(device.label, 'My Trezor');
    expect(device.model, '1');
    expect(device.transport, TrezorTransport.usb);
  });

  test('passphrase response uses the USB callback JSON contract', () {
    expect(
      const TrezorPassphraseResponse(TrezorPassphraseType.hidden, value: 'secret').encode(),
      jsonEncode({'type': 'hidden', 'value': 'secret'}),
    );
    expect(
      const TrezorPassphraseResponse(TrezorPassphraseType.standard).encode(),
      jsonEncode({'type': 'standard', 'value': ''}),
    );
  });

  test('native USB callbacks return PIN and passphrase responses', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (call) async => jsonEncode({'device_id': 'usb:model-one', 'transport': 'usb'}),
    );
    await TrezorDevice.connect(transport: TrezorTransport.usb);
    TrezorDevice.onPinRequested = () async => '1234';
    TrezorDevice.onPassphraseRequested =
        (onDevice) async => TrezorPassphraseResponse(
          onDevice ? TrezorPassphraseType.onDevice : TrezorPassphraseType.hidden,
          value: onDevice ? '' : 'secret',
        );

    expect(await invokeNativeMethod(const MethodCall('showPinMatrix')), '1234');
    expect(
      await invokeNativeMethod(const MethodCall('showPassphraseDialog', {'onDevice': false})),
      jsonEncode({'type': 'hidden', 'value': 'secret'}),
    );
    expect(
      await invokeNativeMethod(const MethodCall('showPassphraseDialog', {'onDevice': true})),
      jsonEncode({'type': 'on_device', 'value': ''}),
    );
  });
}

Future<dynamic> invokeNativeMethod(MethodCall call) async {
  final completer = Completer<ByteData?>();
  final codec = const StandardMethodCodec();
  await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
    'trezor',
    codec.encodeMethodCall(call),
    completer.complete,
  );
  final response = await completer.future;
  return codec.decodeEnvelope(response!);
}
