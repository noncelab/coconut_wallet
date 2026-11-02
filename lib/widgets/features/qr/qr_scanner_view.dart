import 'dart:async';

import 'package:coconut_wallet/widgets/features/qr/overlay/scanner_overlay.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QrScannerView extends StatefulWidget {
  static const alreadyRunningRetryDelay = Duration(milliseconds: 300);
  static const alreadyRunningRetryLimit = 3;

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
