import 'dart:async';
import 'dart:convert';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/view_model/wallet_add/connected/trezor_ble_connect_view_model.dart';
import 'package:coconut_wallet/providers/view_model/wallet_add/connected/trezor_usb_connect_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/services/hardware_wallet/trezor_device.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _Wallets extends Fake implements WalletProvider {}

void main() {
  const channel = MethodChannel('trezor');
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<MethodCall> calls;
  late List<Completer<String>> connections;
  late bool connected;
  late Map<String, Completer<dynamic>> operations;
  // A prompt waiting on the device. Native disconnect queues behind it (Android executor, iOS Rust
  // session lock) until cancel closes the transport.
  Completer<void>? devicePrompt;

  setUp(() {
    calls = [];
    connections = [];
    connected = false;
    operations = {};
    devicePrompt = null;
    NetworkType.setNetworkType(NetworkType.mainnet);
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      switch (call.method) {
        case 'connect':
          final response = Completer<String>();
          connections.add(response);
          final result = await response.future;
          connected = true;
          return result;
        case 'disconnect':
          await devicePrompt?.future;
          connected = false;
          return null;
        case 'isConnected':
          return connected;
        case 'applySettings':
        case 'createSession':
          await devicePrompt?.future;
          return operations[call.method]?.future;
        case 'getXPub':
          return operations[call.method]?.future ?? jsonEncode({'xpub': 'synthetic-cached-xpub'});
        case 'getFingerprint':
          return '00000000';
        case 'cancel':
          if (devicePrompt?.isCompleted == false) devicePrompt!.complete();
          // A native response can race with cancellation, even after cancel succeeds.
          return null;
      }
      throw StateError('Unexpected native call: ${call.method}');
    });
  });

  tearDown(() async {
    await TrezorDevice.lastConnected?.disconnect();
    messenger.setMockMethodCallHandler(channel, null);
    TrezorDevice.lastConnected = null;
    TrezorDevice.onPairingCodeRequested = null;
  });

  String response(TrezorTransport transport) => jsonEncode({
    'device_id': 'synthetic-device',
    'label': 'Synthetic Trezor',
    'transport': transport.name,
    'uses_thp': true,
  });

  for (final transport in TrezorTransport.values) {
    dynamic createVm() =>
        transport == TrezorTransport.ble
            ? TrezorBleConnectViewModel(_Wallets())
            : TrezorUsbConnectViewModel(_Wallets());

    testWidgets('${transport.name}: dispose rejects late native success and disconnects', (tester) async {
      final vm = createVm();
      final Future<void> pending = vm.connect();
      await tester.pump();
      expect(connections, hasLength(1));
      vm.dispose();
      connections.single.complete(response(transport));
      await tester.pump();
      await pending;
      expect(connected, isFalse);
      expect(TrezorDevice.lastConnected, isNull);
      expect(calls.where((call) => call.method == 'disconnect'), hasLength(1));
      expect(TrezorDevice.onPairingCodeRequested, isNull);
      await vm.connect();
      expect(connections, hasLength(1));
    });

    testWidgets('${transport.name}: repeated cancel releases pairing and serializes retry', (tester) async {
      final vm = createVm();
      final Future<void> first = vm.connect();
      await tester.pump();
      expect(connections, hasLength(1));
      expect(TrezorDevice.onPairingCodeRequested, isNotNull);
      final oldCallback = TrezorDevice.onPairingCodeRequested!;
      final pairing = _requestPairingCode();
      await tester.pump();
      vm.cancelPairing();
      vm.cancelPairing();
      vm.reset();
      expect(await pairing, isEmpty);
      expect(await oldCallback(), isEmpty);
      final Future<void> retry = vm.connect();
      await tester.pump();
      expect(connections, hasLength(1));
      connections.first.complete(response(transport));
      await tester.pump();
      await first;
      expect(connections, hasLength(2));
      expect(calls.map((call) => call.method).toList(), ['connect', 'cancel', 'disconnect', 'connect']);
      final retryCallback = TrezorDevice.onPairingCodeRequested;
      expect(retryCallback, isNotNull);
      expect(identical(retryCallback, oldCallback), isFalse);
      expect(await oldCallback(), isEmpty);
      expect(identical(TrezorDevice.onPairingCodeRequested, retryCallback), isTrue);
      connections.last.complete(response(transport));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await retry;
      expect(connected, isTrue);
      expect(TrezorDevice.lastConnected, isNotNull);
      expect(TrezorDevice.lastConnected!.transport, transport);
      await vm.disconnect();
      expect(connected, isFalse);
      expect(TrezorDevice.lastConnected, isNull);
      vm.dispose();
    });

    testWidgets('${transport.name}: old disposal cannot cancel the replacement owner', (tester) async {
      final oldVm = createVm();
      final newVm = createVm();
      final Future<void> first = oldVm.connect();
      await tester.pump();
      oldVm.reset();
      final Future<void> second = newVm.connect();
      connections.first.complete(response(transport));
      await tester.pump();
      await first;
      expect(connections, hasLength(2));
      final callback = TrezorDevice.onPairingCodeRequested;
      oldVm.dispose();
      expect(identical(TrezorDevice.onPairingCodeRequested, callback), isTrue);
      expect(calls.where((call) => call.method == 'cancel'), hasLength(1));
      connections.last.complete(response(transport));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await second;
      expect(connected, isTrue);
      await newVm.disconnect();
      newVm.dispose();
    });

    testWidgets('${transport.name}: wrong pairing code remains a failure', (tester) async {
      final vm = createVm();
      final Future<void> pending = vm.connect();
      await tester.pump();
      connections.single.completeError(PlatformException(code: 'PAIRING_CODE_WRONG', message: 'native detail'));
      await tester.pump();
      await pending;
      expect(vm.isPairingCodeWrong, isTrue);
      expect(connected, isFalse);
      expect(TrezorDevice.lastConnected, isNull);
      vm.dispose();
    });

    for (final operation in ['applySettings', 'createSession', 'getXPub']) {
      testWidgets('${transport.name}: dispose ignores late $operation result', (tester) async {
        final vm = createVm();
        final Future<void> connecting = vm.connect();
        await tester.pump();
        connections.single.complete(response(transport));
        await tester.pump();
        await tester.pump(const Duration(seconds: 2));
        await connecting;
        final device = TrezorDevice.lastConnected!;
        final gate = Completer<dynamic>();
        operations[operation] = gate;
        final Future<void> pending = operation == 'applySettings' ? vm.selectUsePassphrase() : vm.selectNoPassphrase();
        await tester.pump();
        await tester.pump(const Duration(seconds: 2));
        expect(calls.where((call) => call.method == operation), hasLength(1));
        vm.dispose();
        await tester.pump();
        gate.complete(operation == 'getXPub' ? jsonEncode({'xpub': 'late-public-data'}) : null);
        await tester.pump();
        await pending;
        expect(connected, isFalse);
        expect(TrezorDevice.lastConnected, isNull);
        expect(device.cachedXpub, isNull);
        expect(device.passphraseProtection, isFalse);
        expect(calls.where((call) => call.method == 'getFingerprint'), isEmpty);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('${transport.name}: leaving a pending device prompt cancels it so a retry connects', (tester) async {
      final vm = createVm();
      final Future<void> connecting = vm.connect();
      await tester.pump();
      connections.single.complete(response(transport));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await connecting;
      final abandoned = TrezorDevice.lastConnected!;
      final prompt = devicePrompt = Completer<void>();
      final Future<void> enabling = vm.selectUsePassphrase();
      await tester.pump();
      final retryVm = createVm();
      try {
        vm.dispose();
        final Future<void> retry = retryVm.connect();
        await tester.pump();
        await tester.pump();
        expect(
          calls.map((call) => call.method).skipWhile((method) => method != 'applySettings').toList(),
          ['applySettings', 'cancel', 'disconnect', 'connect'],
          reason: 'Disconnect cannot finish while the device prompt is pending.',
        );
        expect(connections, hasLength(2));

        connections.last.complete(response(transport));
        await tester.pump();
        await tester.pump(const Duration(seconds: 2));
        await retry;
        await enabling;
        expect(connected, isTrue);
        expect(abandoned.passphraseProtection, isFalse);
        // The abandoned device no longer owns the transport, so it cannot cancel the retry.
        await abandoned.cancelAndDisconnect();
        expect(calls.where((call) => call.method == 'cancel'), hasLength(1));
        expect(connected, isTrue);
        await retryVm.disconnect();
      } finally {
        if (!prompt.isCompleted) prompt.complete();
        retryVm.dispose();
      }
    });

    testWidgets('${transport.name}: cached session survives successful resume and disposal', (tester) async {
      final pending = TrezorDevice.connect(transport: transport);
      await tester.pump();
      connections.single.complete(response(transport));
      await tester.pump();
      final device = await pending;
      device.cachedXpub = 'synthetic-cached-xpub';
      device.cachedFingerprint = '00000000';
      TrezorDevice.lastConnected = device;
      final vm = createVm();
      expect(vm.resumeFromExistingSession(), isTrue);
      expect(vm.xpub, 'synthetic-cached-xpub');
      expect(vm.fingerprint, '00000000');
      vm.dispose();
      expect(connected, isTrue);
      expect(TrezorDevice.lastConnected, same(device));
      expect(calls.where((call) => call.method == 'cancel' || call.method == 'disconnect'), isEmpty);
      await device.disconnect();
      expect(connected, isFalse);
      expect(TrezorDevice.lastConnected, isNull);
      expect(device.cachedXpub, isNull);
    });
  }

  testWidgets('stale disconnect cannot close a replacement with the same native id', (tester) async {
    final first = TrezorDevice.connect();
    await tester.pump();
    connections.first.complete(response(TrezorTransport.ble));
    await tester.pump();
    final oldDevice = await first;
    TrezorDevice.lastConnected = oldDevice;
    final second = TrezorDevice.connect();
    await tester.pump();
    expect(calls.where((call) => call.method == 'disconnect'), hasLength(1));
    connections.last.complete(response(TrezorTransport.ble));
    await tester.pump();
    final newDevice = await second;
    TrezorDevice.lastConnected = newDevice;
    await oldDevice.disconnect();
    expect(calls.where((call) => call.method == 'disconnect'), hasLength(1));
    expect(connected, isTrue);
    expect(TrezorDevice.lastConnected, same(newDevice));
    await newDevice.disconnect();
  });

  testWidgets('BLE generic native errors stay out of user-facing text', (tester) async {
    final vm = TrezorBleConnectViewModel(_Wallets());
    final pending = vm.connect();
    await tester.pump();
    connections.single.completeError(PlatformException(code: 'CONNECT_FAILED', message: 'internal-stack-token'));
    await tester.pump();
    await pending;
    expect(vm.step, TrezorBleConnectStep.error);
    expect(vm.errorMessage, isNull);
    vm.dispose();
  });

  testWidgets('BLE pairing-removal error preserves localized recovery steps', (tester) async {
    final vm = TrezorBleConnectViewModel(_Wallets());
    final pending = vm.connect();
    await tester.pump();
    connections.single.completeError(PlatformException(code: 'PEER_REMOVED_PAIRING', message: 'native detail'));
    await tester.pump();
    await pending;
    expect(vm.errorMessage, t.wallet_connect_screen.guide_trezor.ios_peer_removed_pairing.description);
    expect(vm.peerRemovedPairingSteps, hasLength(3));
    vm.dispose();
  });
}

Future<String> _requestPairingCode() async {
  const codec = StandardMethodCodec();
  final result = Completer<ByteData?>();
  await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
    'trezor',
    codec.encodeMethodCall(const MethodCall('showPairingCodeDialog')),
    result.complete,
  );
  return codec.decodeEnvelope((await result.future)!) as String;
}
