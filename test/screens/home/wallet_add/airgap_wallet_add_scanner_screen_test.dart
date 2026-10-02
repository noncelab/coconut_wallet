import 'dart:async';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/model/wallet/watch_only_wallet.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/screens/home/wallet_add/air-gapped/airgap_wallet_add_scanner_screen.dart';
import 'package:coconut_wallet/services/analytics_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

class _FakeWalletProvider extends Fake implements WalletProvider {
  int syncCalls = 0;
  Object? syncError;
  Completer<ResultOfSyncFromVault>? syncGate;

  @override
  List<WalletItemBase> get walletItemList => const [];

  @override
  Future<ResultOfSyncFromVault> syncFromThirdParty(
    WatchOnlyWallet wallet, {
    bool allowExistingHotWallet = false,
  }) async {
    syncCalls++;
    if (syncGate != null) return await syncGate!.future;
    if (syncError != null) throw syncError!;
    return ResultOfSyncFromVault(result: WalletSyncResult.newWalletAdded, walletId: 77);
  }
}

class _FakePreferenceProvider extends Fake implements PreferenceProvider {
  @override
  String get language => 'ko';
}

class _CameraPlatform extends MobileScannerPlatform {
  int starts = 0;
  int stops = 0;
  int disposals = 0;
  bool failNextStop = false;

  @override
  Stream<BarcodeCapture?> get barcodesStream => const Stream.empty();

  @override
  Stream<TorchState> get torchStateStream => const Stream.empty();

  @override
  Stream<double> get zoomScaleStateStream => const Stream.empty();

  @override
  Widget buildCameraView() => const SizedBox.expand();

  @override
  Future<MobileScannerViewAttributes> start(StartOptions options) async {
    starts++;
    return const MobileScannerViewAttributes(
      cameraDirection: CameraFacing.back,
      currentTorchMode: TorchState.off,
      numberOfCameras: 1,
      initialDeviceOrientation: DeviceOrientation.portraitUp,
      size: Size(640, 480),
    );
  }

  @override
  Future<void> stop() async {
    stops++;
    if (failNextStop) {
      failNextStop = false;
      throw PlatformException(code: 'camera_stop_failed');
    }
  }

  @override
  Future<void> updateScanWindow(Rect? window) async {}

  @override
  Future<void> dispose() async => disposals++;
}

class _Harness {
  final camera = _CameraPlatform();
  final wallets = _FakeWalletProvider();
  final navigatorKey = GlobalKey<NavigatorState>();
  int getCalls = 0;
  int hasStringsCalls = 0;
  Future<Object?> Function()? clipboardRead;
  bool failNextHasStrings = false;
  late BuildContext screenContext;

  Future<void> mount(WidgetTester tester) async {
    NetworkType.setNetworkType(NetworkType.regtest);
    LocaleSettings.setLocaleSync(AppLocale.ko);
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final previousCamera = MobileScannerPlatform.instance;
    MobileScannerPlatform.instance = camera;
    addTearDown(() => MobileScannerPlatform.instance = previousCamera);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.hasStrings') {
          hasStringsCalls++;
          if (failNextHasStrings) {
            failNextHasStrings = false;
            throw PlatformException(code: 'clipboard_unavailable');
          }
          return {'value': true};
        }
        if (call.method == 'Clipboard.getData') {
          getCalls++;
          return await clipboardRead?.call();
        }
        return null;
      },
    );
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          InheritedProvider<WalletProvider>.value(value: wallets),
          InheritedProvider<PreferenceProvider>.value(value: _FakePreferenceProvider()),
          Provider<AnalyticsService>.value(value: AnalyticsService(null, true)),
        ],
        child: MaterialApp(
          navigatorKey: navigatorKey,
          theme: buildCoconutThemeData(),
          routes: {'/wallet-detail': (_) => const Scaffold(body: Text('imported wallet'))},
          home: LoaderOverlay(
            child: Builder(
              builder: (context) {
                screenContext = context;
                return const WalletAddScannerScreen(importSource: WalletImportSource.extendedPublicKey);
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> paste(WidgetTester tester) async {
    await tester.tap(find.text(t.wallet_add_scanner_screen.paste.paste_button));
    await tester.pumpAndSettle();
  }

  Future<void> dismissError(WidgetTester tester) async {
    await tester.tap(find.text(t.confirm));
    await tester.pumpAndSettle();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final fontLoader =
        FontLoader('Pretendard')
          ..addFont(rootBundle.load('assets/fonts/Pretendard-Regular.ttf'))
          ..addFont(rootBundle.load('assets/fonts/Pretendard-Bold.ttf'));
    await fontLoader.load();
  });
  const publicTestKey =
      'tpubDDMbU29QrSafD2Ui4yGv31Xp3PPSMvudreoohYjR8xLTng7hbsjYwUTeRhiKULFqX16M5M8zZh9siw5i6RRyisc6LtWjr1FwBYTiZUGGYJN';

  testWidgets('clipboard platform failure displays an error and allows another paste attempt', (tester) async {
    final harness = _Harness();
    harness.clipboardRead = () async {
      if (harness.getCalls == 1) throw PlatformException(code: 'paste_denied');
      return null;
    };
    await harness.mount(tester);
    await harness.paste(tester);
    final firstError = tester.takeException();
    if (find.text(t.confirm).evaluate().isNotEmpty) await harness.dismissError(tester);
    await harness.paste(tester);
    expect(harness.getCalls, 2);
    expect(firstError, isNull);
    expect(tester.takeException(), isNull);
    expect(find.text(t.confirm), findsOneWidget);
    expect(harness.screenContext.loaderOverlay.visible, isFalse);
  });

  testWidgets('camera stop failure is caught and does not permanently lock clipboard import', (tester) async {
    final harness = _Harness();
    await harness.mount(tester);
    harness.camera.failNextStop = true;
    await harness.paste(tester);
    final firstError = tester.takeException();
    if (find.text(t.confirm).evaluate().isNotEmpty) await harness.dismissError(tester);
    await harness.paste(tester);
    expect(harness.getCalls, 1);
    expect(firstError, isNull);
    expect(tester.takeException(), isNull);
    expect(find.text(t.confirm), findsOneWidget);
  });

  testWidgets('clipboard availability failure does not throw and a later resume can enable paste', (tester) async {
    final harness = _Harness()..failNextHasStrings = true;
    await harness.mount(tester);
    expect(tester.takeException(), isNull);
    expect(find.text(t.wallet_add_scanner_screen.paste.paste_button), findsNothing);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text(t.wallet_add_scanner_screen.paste.paste_button), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final clipboardResult in [
    null,
    <String, String>{'text': ''},
    <String, String>{'text': 'not-a-wallet-key'},
  ]) {
    testWidgets('denied empty or invalid clipboard remains retryable: $clipboardResult', (tester) async {
      final harness = _Harness()..clipboardRead = () async => clipboardResult;
      await harness.mount(tester);
      await harness.paste(tester);
      expect(find.text(t.confirm), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(harness.camera.stops, 1);
      await harness.dismissError(tester);
      expect(harness.camera.starts, 2);
      expect(harness.screenContext.loaderOverlay.visible, isFalse);
      await harness.paste(tester);
      expect(harness.getCalls, 2);
      expect(find.text(t.confirm), findsOneWidget);
      await harness.dismissError(tester);
    });
  }

  testWidgets('rapid duplicate paste taps share one in-flight clipboard request', (tester) async {
    final gate = Completer<Object?>();
    final harness = _Harness()..clipboardRead = () => gate.future;
    await harness.mount(tester);
    await tester.tap(find.text(t.wallet_add_scanner_screen.paste.paste_button));
    await tester.pump();
    await tester.tap(find.text(t.wallet_add_scanner_screen.paste.paste_button));
    await tester.pump();
    expect(harness.getCalls, 1);
    expect(harness.camera.stops, 1);
    gate.complete(null);
    await tester.pumpAndSettle();
    expect(find.text(t.confirm), findsOneWidget);
    await harness.dismissError(tester);
    expect(harness.camera.starts, 2);
    expect(tester.takeException(), isNull);
  });

  for (final failure in [false, true]) {
    testWidgets('leaving during clipboard ${failure ? 'failure' : 'read'} does not use disposed context', (
      tester,
    ) async {
      final gate = Completer<Object?>();
      final harness = _Harness()..clipboardRead = () => gate.future;
      await harness.mount(tester);
      await tester.tap(find.text(t.wallet_add_scanner_screen.paste.paste_button));
      await tester.pump();
      expect(harness.getCalls, 1);
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      if (failure) {
        gate.completeError(PlatformException(code: 'paste_denied'));
      } else {
        gate.complete(null);
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(harness.camera.disposals, 1);
    });
  }

  testWidgets('valid public key imports once after the optional fingerprint sheet', (tester) async {
    final harness = _Harness()..clipboardRead = () async => {'text': publicTestKey};
    await harness.mount(tester);
    await harness.paste(tester);
    await tester.tap(find.text(t.wallet_add_scanner_screen.paste.mfp_skip));
    await tester.pumpAndSettle();
    expect(harness.wallets.syncCalls, 1);
    expect(find.text('imported wallet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('wallet persistence failure hides the loader and leaves the scanner retryable', (tester) async {
    final harness = _Harness()..clipboardRead = () async => {'text': publicTestKey};
    final gate = Completer<ResultOfSyncFromVault>();
    harness.wallets.syncGate = gate;
    await harness.mount(tester);
    await harness.paste(tester);
    await tester.tap(find.text(t.wallet_add_scanner_screen.paste.mfp_skip));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(harness.screenContext.loaderOverlay.visible, isTrue);
    expect(harness.wallets.syncCalls, 1);
    gate.completeError(StateError('storage unavailable'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text(t.confirm), findsOneWidget);
    await harness.dismissError(tester);
    expect(harness.screenContext.loaderOverlay.visible, isFalse);
    expect(tester.widget<MobileScanner>(find.byType(MobileScanner)).controller!.value.isRunning, isTrue);
    expect(tester.takeException(), isNull);
    harness.wallets.syncGate = null;
    await harness.paste(tester);
    await tester.tap(find.text(t.wallet_add_scanner_screen.paste.mfp_skip));
    await tester.pumpAndSettle();
    expect(harness.wallets.syncCalls, 2);
    expect(find.text('imported wallet'), findsOneWidget);
  });

  testWidgets('leaving while wallet persistence finishes does not navigate or restart a disposed scanner', (
    tester,
  ) async {
    final harness = _Harness()..clipboardRead = () async => {'text': publicTestKey};
    final gate = Completer<ResultOfSyncFromVault>();
    harness.wallets.syncGate = gate;
    await harness.mount(tester);
    await harness.paste(tester);
    await tester.tap(find.text(t.wallet_add_scanner_screen.paste.mfp_skip));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(harness.screenContext.loaderOverlay.visible, isTrue);
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    gate.complete(ResultOfSyncFromVault(result: WalletSyncResult.newWalletAdded, walletId: 77));
    await tester.pumpAndSettle();
    expect(find.text('imported wallet'), findsNothing);
    expect(harness.camera.disposals, 1);
    expect(harness.camera.starts, 1);
    expect(tester.takeException(), isNull);
  });
}
