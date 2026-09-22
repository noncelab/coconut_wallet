import 'dart:async';

import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/widgets/features/qr/animated_qr/coconut_qr_scanner.dart';
import 'package:coconut_wallet/widgets/features/qr/animated_qr/scan_data_handler/i_qr_scan_data_handler.dart';
import 'package:coconut_wallet/widgets/features/qr/body/address_qr_scanner_body.dart';
import 'package:coconut_wallet/widgets/features/qr/overlay/scanner_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class _CameraPlatform extends MobileScannerPlatform {
  final captures = StreamController<BarcodeCapture>.broadcast();
  final windows = <Rect?>[];

  @override
  Stream<BarcodeCapture> get barcodesStream => captures.stream;
  @override
  Stream<TorchState> get torchStateStream => const Stream.empty();
  @override
  Stream<double> get zoomScaleStateStream => const Stream.empty();
  @override
  Future<MobileScannerViewAttributes> start(StartOptions options) async => MobileScannerViewAttributes(
    cameraDirection: options.cameraDirection,
    currentTorchMode: TorchState.off,
    size: const Size(400, 600),
  );
  @override
  Widget buildCameraView() => const ColoredBox(color: Colors.white);
  @override
  Future<void> updateScanWindow(Rect? window) async => windows.add(window);
  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {}
}

class _UnusedQrHandler extends Fake implements IQrScanDataHandler {}

void main() {
  late MobileScannerPlatform originalPlatform;
  late _CameraPlatform platform;

  setUp(() {
    originalPlatform = MobileScannerPlatform.instance;
    platform = _CameraPlatform();
    MobileScannerPlatform.instance = platform;
  });

  tearDown(() async {
    MobileScannerPlatform.instance = originalPlatform;
    await platform.captures.close();
  });

  for (final addressScanner in [false, true]) {
    final scannerName = addressScanner ? 'address' : 'wallet/PSBT';
    for (final example in [
      (size: const Size(390, 600), rect: const Rect.fromLTWH(35, 140, 320, 320)),
      (size: const Size(400, 600), rect: const Rect.fromLTWH(30, 130, 340, 340)),
      (size: const Size(720, 900), rect: const Rect.fromLTWH(110, 200, 500, 500)),
      (size: const Size(280, 600), rect: const Rect.fromLTWH(0, 160, 280, 280)),
      (size: const Size(800, 300), rect: const Rect.fromLTWH(250, 0, 300, 300)),
    ]) {
      testWidgets('$scannerName limits scanning to the painted window at ${example.size}', (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(1000, 1200);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        late MobileScannerController controller;
        final Widget scanner =
            addressScanner
                ? AddressQrScannerBody(
                  qrKey: GlobalKey(),
                  onDetect: (_) {},
                  setMobileScannerController: (value) => controller = value,
                )
                : CoconutQrScanner(
                  setMobileScannerController: (value) => controller = value,
                  onComplete: (_) {},
                  onFailed: (_, __) {},
                  qrDataHandler: _UnusedQrHandler(),
                );

        Widget buildScanner(Size size) => MaterialApp(
          theme: buildCoconutThemeData(),
          home: Align(alignment: Alignment.topLeft, child: SizedBox.fromSize(size: size, child: scanner)),
        );
        await tester.pumpWidget(buildScanner(example.size));
        await tester.pumpAndSettle();

        expect(tester.widget<MobileScanner>(find.byType(MobileScanner)).scanWindow, example.rect);
        expect(
          find.descendant(of: find.byType(ScannerOverlay), matching: find.byType(CustomPaint)),
          paints..rrect(rrect: RRect.fromRectAndRadius(example.rect, const Radius.circular(8))),
        );
        expect(platform.windows.last, isNotNull);
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(buildScanner(const Size(800, 300)));
        await tester.pumpAndSettle();
        const resizedWindow = Rect.fromLTWH(250, 0, 300, 300);
        expect(tester.widget<MobileScanner>(find.byType(MobileScanner)).scanWindow, resizedWindow);
        expect(
          find.descendant(of: find.byType(ScannerOverlay), matching: find.byType(CustomPaint)),
          paints..rrect(rrect: RRect.fromRectAndRadius(resizedWindow, const Radius.circular(8))),
        );
        // BoxFit.cover crops the 400x600 camera texture in the 800x300 preview.
        expect(platform.windows.last, const Rect.fromLTRB(0.3125, 0.375, 0.6875, 0.625));
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(const SizedBox.shrink());
        if (addressScanner) await controller.dispose();
        await tester.pumpAndSettle();
      });
    }
  }
}
