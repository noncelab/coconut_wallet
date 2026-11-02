import 'dart:async';

import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/widgets/features/qr/qr_scanner_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class _OccupiedCameraPlatform extends MobileScannerPlatform {
  _OccupiedCameraPlatform({required this.occupied, this.releasesOnStop = true});

  bool occupied;
  final bool releasesOnStop;
  int startCalls = 0;
  int stopCalls = 0;

  @override
  Stream<BarcodeCapture?> get barcodesStream => const Stream.empty();

  @override
  Stream<TorchState> get torchStateStream => const Stream.empty();

  @override
  Stream<double> get zoomScaleStateStream => const Stream.empty();

  @override
  Future<MobileScannerViewAttributes> start(StartOptions options) async {
    startCalls++;
    if (occupied) {
      throw const MobileScannerException(errorCode: MobileScannerErrorCode.controllerAlreadyInitialized);
    }
    return const MobileScannerViewAttributes(
      cameraDirection: CameraFacing.back,
      currentTorchMode: TorchState.off,
      size: Size(640, 480),
    );
  }

  @override
  Widget buildCameraView() => const SizedBox.expand();

  @override
  Future<void> updateScanWindow(Rect? window) async {}

  @override
  Future<void> stop() async {
    stopCalls++;
    if (releasesOnStop) occupied = false;
  }

  @override
  Future<void> dispose() => stop();
}

Future<MobileScannerController> _pumpScanner(WidgetTester tester, _OccupiedCameraPlatform platform) async {
  final original = MobileScannerPlatform.instance;
  MobileScannerPlatform.instance = platform;
  final controller = MobileScannerController();
  addTearDown(() async {
    await controller.dispose();
    MobileScannerPlatform.instance = original;
  });
  await tester.pumpWidget(
    MaterialApp(
      theme: buildCoconutThemeData(),
      home: QrScannerView(
        controller: controller,
        onDetect: (_) {},
        errorBuilder: (_, error) => Text(error.errorCode.message),
      ),
    ),
  );
  await tester.pump();
  return controller;
}

void main() {
  final alreadyRunningMessage = MobileScannerErrorCode.controllerAlreadyInitialized.message;

  testWidgets('waits for a previous camera to be released without showing the error', (tester) async {
    final platform = _OccupiedCameraPlatform(occupied: true);
    final controller = await _pumpScanner(tester, platform);

    expect(controller.value.error?.errorCode, MobileScannerErrorCode.controllerAlreadyInitialized);
    expect(find.text(alreadyRunningMessage), findsNothing);

    platform.occupied = false;
    await tester.pump(QrScannerView.alreadyRunningRetryDelay);
    await tester.pump();

    expect(controller.value.isRunning, isTrue);
    expect(platform.stopCalls, 0);
    expect(find.text(alreadyRunningMessage), findsNothing);
  });

  testWidgets('releases a leaked camera after retries run out', (tester) async {
    final platform = _OccupiedCameraPlatform(occupied: true);
    final controller = await _pumpScanner(tester, platform);

    for (var i = 0; i <= QrScannerView.alreadyRunningRetryLimit; i++) {
      expect(find.text(alreadyRunningMessage), findsNothing);
      await tester.pump(QrScannerView.alreadyRunningRetryDelay);
      await tester.pump();
    }

    expect(platform.stopCalls, 1);
    expect(controller.value.isRunning, isTrue);
    expect(platform.startCalls, QrScannerView.alreadyRunningRetryLimit + 2);
    expect(find.text(alreadyRunningMessage), findsNothing);
  });

  testWidgets('falls back to the error builder when the camera cannot be released', (tester) async {
    final platform = _OccupiedCameraPlatform(occupied: true, releasesOnStop: false);
    final controller = await _pumpScanner(tester, platform);

    for (var i = 0; i <= QrScannerView.alreadyRunningRetryLimit; i++) {
      await tester.pump(QrScannerView.alreadyRunningRetryDelay);
      await tester.pump();
    }
    await tester.pump(QrScannerView.alreadyRunningRetryDelay * 2);

    expect(controller.value.isRunning, isFalse);
    expect(platform.startCalls, QrScannerView.alreadyRunningRetryLimit + 2);
    expect(find.text(alreadyRunningMessage), findsOneWidget);
  });
}
