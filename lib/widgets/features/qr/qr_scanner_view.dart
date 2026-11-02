import 'dart:async';

import 'package:coconut_wallet/widgets/features/qr/overlay/scanner_overlay.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QrScannerView extends StatefulWidget {
  static const alreadyRunningRetryDelay = Duration(milliseconds: 300);
  static const alreadyRunningRetryLimit = 3;
  static Future<void>? _pendingRelease;

  /// 닫히는 스캐너의 컨트롤러 해제, 다음 스캐너는 해제가 끝난 뒤 카메라 재시작
  static void releaseController(MobileScannerController controller) {
    final previous = _pendingRelease;
    final release = controller.dispose().catchError((_) {});
    late final Future<void> pending;
    pending = (previous == null ? release : Future.wait([previous, release])).whenComplete(() {
      if (identical(_pendingRelease, pending)) _pendingRelease = null;
    });
    _pendingRelease = pending;
  }

  final Key? scannerKey;
  final MobileScannerController controller;
  final void Function(BarcodeCapture) onDetect;
  final Widget Function(BuildContext, MobileScannerException) errorBuilder;
  final Widget Function(BuildContext, Rect)? overlayBuilder;

  const QrScannerView({
    super.key,
    this.scannerKey,
    required this.controller,
    required this.onDetect,
    required this.errorBuilder,
    this.overlayBuilder,
  });

  @override
  State<QrScannerView> createState() => _QrScannerViewState();
}

class _QrScannerViewState extends State<QrScannerView> {
  Timer? _retryTimer;
  int _retryCount = 0;
  bool _forcedRestart = false;

  bool get _isRecovering => !_forcedRestart || _retryTimer != null;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(QrScannerView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
      _resetRecovery();
    }
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _resetRecovery() {
    _retryTimer?.cancel();
    _retryTimer = null;
    _retryCount = 0;
    _forcedRestart = false;
  }

  void _onControllerChanged() {
    final value = widget.controller.value;
    if (value.isRunning) {
      _resetRecovery();
      return;
    }
    if (value.error?.errorCode != MobileScannerErrorCode.controllerAlreadyInitialized) return;
    if (_retryTimer != null || _forcedRestart) return;
    _retryTimer = Timer(QrScannerView.alreadyRunningRetryDelay, _restart);
  }

  Future<void> _restart() async {
    final pendingRelease = QrScannerView._pendingRelease;
    if (pendingRelease != null) await pendingRelease;
    if (!mounted) return;
    if (_retryCount >= QrScannerView.alreadyRunningRetryLimit) {
      _forcedRestart = true;
      await MobileScannerPlatform.instance.stop();
    } else {
      _retryCount++;
    }
    if (!mounted) return;
    _retryTimer = null;
    await widget.controller.start();
  }

  Widget _buildError(BuildContext context, MobileScannerException error) {
    if (error.errorCode == MobileScannerErrorCode.controllerAlreadyInitialized && _isRecovering) {
      return const ColoredBox(color: Colors.black);
    }
    return widget.errorBuilder(context, error);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scanWindow = ScannerOverlay.calculateScanWindow(constraints.biggest);
        return Stack(
          fit: StackFit.expand,
          children: [
            MobileScanner(
              key: widget.scannerKey,
              controller: widget.controller,
              onDetect: widget.onDetect,
              errorBuilder: _buildError,
              scanWindow: scanWindow,
            ),
            ScannerOverlay(scanWindow: scanWindow),
            if (widget.overlayBuilder != null) widget.overlayBuilder!(context, scanWindow),
          ],
        );
      },
    );
  }
}
