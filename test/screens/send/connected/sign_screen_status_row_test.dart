import 'dart:io';

import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/screens/send/connected/bitbox02_sign_screen.dart';
import 'package:coconut_wallet/screens/send/connected/trezor_sign_screen.dart';
import 'package:coconut_wallet/services/hardware_wallet/bitbox02_device.dart';
import 'package:coconut_wallet/services/hardware_wallet/trezor_device.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../../mock/wallet_mock.dart';

class _Wallets extends Fake with ChangeNotifier implements WalletProvider {
  final WalletItemBase wallet = WalletMock.createSingleSigWalletItem(id: 1);

  @override
  WalletItemBase getWalletById(int id) => wallet;

  @override
  String? findWalletNameByFingerprint(String fingerprint) => 'Wallet';

  @override
  String? findWalletNameByXpub(String xpub) => 'Wallet';
}

class _Preferences extends Fake with ChangeNotifier implements PreferenceProvider {
  @override
  BitcoinUnit get currentUnit => BitcoinUnit.btc;
}

Future<void> _pumpSignScreen(WidgetTester tester, Widget screen, double textScale) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<WalletProvider>.value(value: _Wallets()),
        ChangeNotifierProvider<PreferenceProvider>.value(value: _Preferences()),
      ],
      child: MaterialApp(
        theme: buildCoconutThemeData(variant: CoconutThemeVariant.dark),
        builder:
            (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!,
            ),
        home: screen,
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> _failSigning(WidgetTester tester, String signLabel) async {
  await tester.tap(find.text(signLabel));
  for (var i = 0; i < 10; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  setUpAll(() async {
    for (final (family, filenames) in [
      ('Pretendard', ['Pretendard-Regular.ttf', 'Pretendard-Bold.ttf']),
      ('SpaceGrotesk', ['SpaceGrotesk-Regular.ttf', 'SpaceGrotesk-Bold.ttf']),
    ]) {
      final loader = FontLoader(family);
      for (final filename in filenames) {
        loader.addFont(Future.value(ByteData.sublistView(File('assets/fonts/$filename').readAsBytesSync())));
      }
      await loader.load();
    }
    LocaleSettings.setLocaleSync(AppLocale.de);
  });

  tearDownAll(() => LocaleSettings.setLocaleSync(AppLocale.ko));

  for (final textScale in [1.0, 2.0]) {
    testWidgets('BitBox02 sign error with a fingerprint fits a 320px screen at text scale $textScale', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 640);
      addTearDown(tester.view.reset);
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('bitbox02'), (call) async {
        if (call.method == 'connect') return 'device';
        if (call.method == 'isConnected') return true;
        if (call.method == 'setLoggerEnabled') return null;
        throw PlatformException(code: 'DEVICE', message: 'Device error');
      });
      addTearDown(() {
        BitBox02Device.lastConnected = null;
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('bitbox02'), null);
      });
      final device = await BitBox02Device.connect(transport: 'usb');
      device.cachedFingerprint = 'a1b2c3d4';
      BitBox02Device.lastConnected = device;

      await _pumpSignScreen(
        tester,
        const BitBox02SignScreen(walletId: 1, psbtBase64: 'invalid', walletName: 'Wallet'),
        textScale,
      );
      await _failSigning(tester, t.bitbox02_sign_screen.btn.sign);

      expect(find.text(t.bitbox02_sign_screen.error_title), findsOneWidget);
      expect(find.text('A1B2'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('Trezor sign error with a fingerprint fits a 320px screen at text scale $textScale', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 640);
      addTearDown(tester.view.reset);
      var connectionChecks = 0;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('trezor'), (call) async {
        if (call.method == 'connect') return '{"device_id": "device", "transport": "usb"}';
        if (call.method == 'isConnected') return ++connectionChecks == 1;
        return null;
      });
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('trezor/connectivity'),
        (_) async => null,
      );
      addTearDown(() {
        TrezorDevice.lastConnected = null;
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('trezor'), null);
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel('trezor/connectivity'),
          null,
        );
      });
      final device = await TrezorDevice.connect(transport: TrezorTransport.usb);
      device.cachedFingerprint = 'a1b2c3d4';
      TrezorDevice.lastConnected = device;

      await _pumpSignScreen(
        tester,
        const TrezorSignScreen(
          walletId: 1,
          psbtBase64: 'invalid',
          walletName: 'Wallet',
          transport: TrezorTransport.usb,
        ),
        textScale,
      );
      await _failSigning(tester, t.trezor_sign_screen.btn.sign);

      expect(find.text(t.trezor_sign_screen.error_title), findsOneWidget);
      expect(find.text('A1B2'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
