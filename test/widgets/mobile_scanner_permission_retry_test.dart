import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class _CameraPlatform extends MobileScannerPlatform {
  final events = StreamController<BarcodeCapture?>.broadcast(sync: true);
  int activeBarcodeSubscriptions = 0;
  int barcodeSubscriptions = 0;
  int barcodeCancellations = 0;
  bool permissionGranted = false;

  @override
  Stream<BarcodeCapture?> get barcodesStream => Stream<BarcodeCapture?>.multi((sink) {
    barcodeSubscriptions++;
    activeBarcodeSubscriptions++;
    final subscription = events.stream.listen(sink.addSync, onError: sink.addErrorSync, onDone: sink.closeSync);
    sink.onCancel = () async {
      barcodeCancellations++;
      activeBarcodeSubscriptions--;
      await subscription.cancel();
    };
  }, isBroadcast: true);

  @override
  Stream<TorchState> get torchStateStream => const Stream.empty();

  @override
  Stream<double> get zoomScaleStateStream => const Stream.empty();

  @override
  Future<MobileScannerViewAttributes> start(StartOptions options) async {
    if (!permissionGranted) {
      throw const MobileScannerException(errorCode: MobileScannerErrorCode.permissionDenied);
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
  Future<void> stop() async {}

  // Match MethodChannelMobileScanner.dispose: native stop does not close the
  // cached event stream or cancel Dart subscriptions owned by the controller.
  @override
  Future<void> dispose() => stop();
}

class _PendingPermissionPlatform extends _CameraPlatform {
  final permissionResult = Completer<void>();

  @override
  Future<MobileScannerViewAttributes> start(StartOptions options) async {
    await permissionResult.future;
    return super.start(options);
  }
}

class _ScannerOwner extends StatefulWidget {
  const _ScannerOwner({required this.controller, required this.onDetect});

  final MobileScannerController controller;
  final void Function(BarcodeCapture) onDetect;

  @override
  State<_ScannerOwner> createState() => _ScannerOwnerState();
}

class _ScannerOwnerState extends State<_ScannerOwner> {
  @override
  void dispose() {
    unawaited(widget.controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MobileScanner(controller: widget.controller, onDetect: widget.onDetect);
}

void main() {
  testWidgets('permission failure retry delivers one barcode and releases subscriptions on disposal', (tester) async {
    final original = MobileScannerPlatform.instance;
    final platform = _CameraPlatform();
    MobileScannerPlatform.instance = platform;
    final controller = MobileScannerController();
    addTearDown(() async {
      await controller.dispose();
      await platform.events.close();
      MobileScannerPlatform.instance = original;
    });
    var callbacks = 0;
    await tester.pumpWidget(MaterialApp(home: _ScannerOwner(controller: controller, onDetect: (_) => callbacks++)));
    await tester.pumpAndSettle();
    expect(controller.value.error?.errorCode, MobileScannerErrorCode.permissionDenied);
    final subscriptionsAfterDenial = platform.activeBarcodeSubscriptions;

    platform.permissionGranted = true;
    await controller.start();
    await tester.pumpAndSettle();
    expect(controller.value.isRunning, isTrue);
    final subscriptionsAfterRetry = platform.activeBarcodeSubscriptions;
    platform.events.add(const BarcodeCapture(barcodes: [Barcode(rawValue: 'public-test-fixture')]));
    await tester.pumpAndSettle();
    final callbacksForOneEvent = callbacks;

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    final subscriptionsAfterUnmount = platform.activeBarcodeSubscriptions;
    await controller.dispose();
    final subscriptionsAfterDispose = platform.activeBarcodeSubscriptions;
    platform.events.add(const BarcodeCapture(barcodes: [Barcode(rawValue: 'public-test-fixture')]));
    await tester.pumpAndSettle();
    final observed = {
      'subscriptions_after_denial': subscriptionsAfterDenial,
      'subscriptions_after_retry': subscriptionsAfterRetry,
      'callbacks_for_one_event': callbacksForOneEvent,
      'subscriptions_after_unmount': subscriptionsAfterUnmount,
      'subscriptions_after_dispose': subscriptionsAfterDispose,
      'callbacks_after_dispose_event': callbacks - callbacksForOneEvent,
      'total_subscriptions': platform.barcodeSubscriptions,
      'total_cancellations_before_fixture_cleanup': platform.barcodeCancellations,
    };
    debugPrint('real_mobile_scanner_lifecycle=${jsonEncode(observed)}');
    expect(tester.takeException(), isNull);
    expect(subscriptionsAfterRetry, 1, reason: jsonEncode(observed));
    expect(callbacksForOneEvent, 1, reason: jsonEncode(observed));
    expect(subscriptionsAfterUnmount, 0, reason: jsonEncode(observed));
    expect(subscriptionsAfterDispose, 0, reason: jsonEncode(observed));
    expect(callbacks, callbacksForOneEvent);
  });

  testWidgets('disposing during a pending permission request releases listeners before rejection', (tester) async {
    final original = MobileScannerPlatform.instance;
    final platform = _PendingPermissionPlatform();
    MobileScannerPlatform.instance = platform;
    final controller = MobileScannerController();
    addTearDown(() async {
      if (!platform.permissionResult.isCompleted) {
        platform.permissionResult.completeError(
          const MobileScannerException(errorCode: MobileScannerErrorCode.permissionDenied),
        );
      }
      await controller.dispose();
      await platform.events.close();
      MobileScannerPlatform.instance = original;
    });
    var callbacks = 0;
    await tester.pumpWidget(MaterialApp(home: MobileScanner(controller: controller, onDetect: (_) => callbacks++)));
    await tester.pumpAndSettle();
    expect(controller.value.isStarting, isTrue);
    expect(platform.activeBarcodeSubscriptions, 1);

    await controller.dispose();
    final activeBeforeRejection = platform.activeBarcodeSubscriptions;
    final cancellationsBeforeRejection = platform.barcodeCancellations;
    platform.events.add(const BarcodeCapture(barcodes: [Barcode(rawValue: 'public-test-fixture')]));
    platform.permissionResult.completeError(
      const MobileScannerException(errorCode: MobileScannerErrorCode.permissionDenied),
    );
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    debugPrint(
      'real_mobile_scanner_pending_dispose=${jsonEncode({'active_before_rejection': activeBeforeRejection, 'cancellations_before_rejection': cancellationsBeforeRejection, 'active_after_rejection': platform.activeBarcodeSubscriptions, 'total_cancellations': platform.barcodeCancellations, 'callbacks_after_dispose': callbacks})}',
    );
    expect(tester.takeException(), isNull);
    expect(activeBeforeRejection, 0);
    expect(cancellationsBeforeRejection, 1);
    expect(platform.activeBarcodeSubscriptions, 0);
    expect(platform.barcodeCancellations, 1);
    expect(callbacks, 0);
  });
}
