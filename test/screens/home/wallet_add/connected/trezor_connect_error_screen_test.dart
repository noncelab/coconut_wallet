import 'dart:async';

import 'package:coconut_wallet/app/theme/app_cupertino_theme.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/screens/home/wallet_add/connected/trezor_ble_connect_screen.dart';
import 'package:coconut_wallet/screens/home/wallet_add/connected/trezor_usb_connect_screen.dart';
import 'package:coconut_wallet/services/hardware_wallet/trezor_device.dart';
import 'package:coconut_wallet/widgets/common/buttons/coconut_icon_button.dart';
import 'package:coconut_wallet/widgets/features/wallet/connect/wallet_connect_widgets.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _Wallets extends Fake with ChangeNotifier implements WalletProvider {}

class _Preferences extends Fake with ChangeNotifier implements PreferenceProvider {
  @override
  String get language => 'ko';
}

class _Pops extends NavigatorObserver {
  int count = 0;

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    count++;
  }
}

Future<_Pops> _open(WidgetTester tester, TrezorTransport transport) async {
  final observer = _Pops();
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<WalletProvider>.value(value: _Wallets()),
        ChangeNotifierProvider<PreferenceProvider>.value(value: _Preferences()),
      ],
      child: CupertinoApp(
        theme: buildAppCupertinoTheme(),
        localizationsDelegates: const [
          DefaultMaterialLocalizations.delegate,
          DefaultWidgetsLocalizations.delegate,
          DefaultCupertinoLocalizations.delegate,
        ],
        navigatorObservers: [observer],
        builder: (context, child) => Theme(data: buildCoconutThemeData(), child: child!),
        home: Builder(
          builder:
              (context) => Scaffold(
                body: TextButton(
                  onPressed:
                      () => Navigator.of(context).push(
                        CupertinoPageRoute<void>(
                          builder:
                              (context) => Scaffold(
                                body: TextButton(
                                  onPressed:
                                      () => Navigator.of(context).push(
                                        CupertinoPageRoute<void>(
                                          builder:
                                              (_) =>
                                                  transport == TrezorTransport.usb
                                                      ? const TrezorUsbConnectScreen()
                                                      : const TrezorBleConnectScreen(),
                                        ),
                                      ),
                                  child: const Text('Open connection'),
                                ),
                              ),
                        ),
                      ),
                  child: const Text('Open transport selection'),
                ),
              ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open transport selection'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Open connection'));
  await tester.pumpAndSettle();
  return observer;
}

String _connectLabel(TrezorTransport transport) =>
    transport == TrezorTransport.usb
        ? t.wallet_connect_screen.guide_trezor.usb.connect
        : t.wallet_connect_screen.guide_trezor.btn.connect_via_ble;

void main() {
  const channel = MethodChannel('trezor');
  const secret = 'synthetic-device-id synthetic-address synthetic-passphrase';
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    TrezorDevice.lastConnected = null;
    TrezorDevice.onPairingCodeRequested = null;
    TrezorDevice.onPinRequested = null;
    TrezorDevice.onPassphraseRequested = null;
  });

  for (final transport in TrezorTransport.values) {
    testWidgets('${transport.name}: failed connection hides raw exception and retries', (tester) async {
      var attempts = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'connect') {
          attempts++;
          throw PlatformException(code: 'USB_NO_DEVICE', message: secret);
        }
        return null;
      });
      await _open(tester, transport);
      await tester.tap(find.text(_connectLabel(transport)));
      await tester.pumpAndSettle();
      expect(attempts, 1);
      expect(find.byType(WalletConnectErrorCard), findsOneWidget);
      expect(find.textContaining(secret), findsNothing);
      expect(find.textContaining('TrezorException'), findsNothing);
      expect(find.textContaining('USB_NO_DEVICE'), findsNothing);
      expect(find.text('Unknown error'), findsNothing);
      expect(
        find.text(
          transport == TrezorTransport.usb
              ? t.wallet_connect_screen.guide_trezor.error.usb_description
              : t.wallet_connect_screen.guide_trezor.error.ble_description,
        ),
        findsWidgets,
      );
      await tester.tap(find.text(t.wallet_connect_screen.guide_trezor.btn.retry));
      await tester.pumpAndSettle();
      expect(attempts, 2);
      expect(find.byType(WalletConnectErrorCard), findsOneWidget);
      expect(find.textContaining(secret), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('${transport.name}: duplicate close and Back during connection pop only once', (tester) async {
      final pending = Completer<String>();
      var nativeConnectCalls = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'connect') {
          nativeConnectCalls++;
          return pending.future;
        }
        return null;
      });
      final observer = await _open(tester, transport);
      await tester.tap(find.text(_connectLabel(transport)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(nativeConnectCalls, 1, reason: 'The native connection must be pending before testing cancellation.');
      final popScope = tester.widget<PopScope>(find.byWidgetPredicate((widget) => widget is PopScope).last);
      final close = tester.widget<CoconutAppBarActionButton>(find.byType(CoconutAppBarActionButton).first).onPressed!;
      close();
      close();
      popScope.onPopInvokedWithResult!(false, null);
      await tester.pumpAndSettle();
      pending.completeError(PlatformException(code: 'USB_NO_DEVICE', message: secret));
      await tester.pumpAndSettle();
      expect(observer.count, 1);
      expect(find.text('Open connection'), findsOneWidget);
      expect(find.byType(WalletConnectErrorCard), findsNothing);
      expect(TrezorDevice.lastConnected, isNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  for (final code in ['BLE_DISABLED', 'PEER_REMOVED_PAIRING', 'PAIRING_CODE_WRONG']) {
    testWidgets('BLE preserves localized $code guidance without native payload', (tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'connect') throw PlatformException(code: code, message: secret);
        return null;
      });
      await _open(tester, TrezorTransport.ble);
      await tester.tap(find.text(_connectLabel(TrezorTransport.ble)));
      if (code == 'PAIRING_CODE_WRONG') {
        // The mock fails during connecting, so its spinner keeps ticking behind the dialog.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
      } else {
        await tester.pumpAndSettle();
      }
      final expected = switch (code) {
        'BLE_DISABLED' => t.wallet_connect_screen.common.ble_off,
        'PEER_REMOVED_PAIRING' => t.wallet_connect_screen.guide_trezor.ios_peer_removed_pairing.description,
        _ => t.wallet_connect_screen.guide_trezor.pairing_dialog.error_wrong_code_dialog,
      };
      expect(find.text(expected), findsOneWidget);
      if (code == 'PEER_REMOVED_PAIRING') {
        expect(
          find.text('3. ${t.wallet_connect_screen.guide_trezor.ios_peer_removed_pairing.step3}', findRichText: true),
          findsOneWidget,
        );
      }
      expect(find.textContaining(secret), findsNothing);
      expect(tester.takeException(), isNull);
      if (code == 'PAIRING_CODE_WRONG') {
        expect(find.text(t.wallet_connect_screen.guide_trezor.pairing_dialog.error_wrong_code), findsOneWidget);
        await tester.tap(find.text(t.OK));
        await tester.pumpAndSettle();
        expect(find.text(expected), findsNothing);
        expect(find.text(_connectLabel(TrezorTransport.ble)), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.textContaining(secret), findsNothing);
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
