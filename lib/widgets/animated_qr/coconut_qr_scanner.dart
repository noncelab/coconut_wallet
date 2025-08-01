import 'dart:async';

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/widgets/animated_qr/scan_data_handler/i_fragmented_qr_scan_data_handler.dart';
import 'package:coconut_wallet/widgets/animated_qr/scan_data_handler/i_qr_scan_data_handler.dart';
import 'package:coconut_wallet/widgets/animated_qr/scan_data_handler/scan_data_handler_exceptions.dart';
import 'package:flutter/material.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';

class CoconutQrScanner extends StatefulWidget {
  static String qrFormatErrorMessage = 'Invalid QR format.';
  static String qrInvalidErrorMessage = 'Invalid QR Code.';
  final Function(QRViewController) setQrViewController;
  final Function(dynamic) onComplete;
  final Function(String) onFailed;
  final Color borderColor;
  final IQrScanDataHandler qrDataHandler;

  const CoconutQrScanner({
    super.key,
    required this.setQrViewController,
    required this.onComplete,
    required this.onFailed,
    required this.qrDataHandler,
    this.borderColor = CoconutColors.white,
  });

  @override
  State<CoconutQrScanner> createState() => _CoconutQrScannerState();
}

class _CoconutQrScannerState extends State<CoconutQrScanner> with SingleTickerProviderStateMixin {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  final ValueNotifier<double> _progressNotifier = ValueNotifier(0.0);
  final double _borderWidth = 8;
  double scannerLoadingVerticalPos = 0;

  late AnimationController _loadingBarController;

  Timer? _scanTimeoutTimer;
  bool _showLoadingBar = false;
  bool _isFirstScanData = true;

  @override
  void initState() {
    super.initState();
    _loadingBarController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final rect = getQrViewRect();
      if (rect != null) {
        setState(() {
          scannerLoadingVerticalPos =
              ((MediaQuery.of(context).size.width < 400 || MediaQuery.of(context).size.height < 400)
                      ? 320.0
                      : MediaQuery.of(context).size.width * 0.85) +
                  30;
        });
      } else {
        Logger.log('QRView position not available yet');
      }
    });
  }

  @override
  void dispose() {
    _progressNotifier.dispose();
    _scanTimeoutTimer?.cancel();
    _loadingBarController.dispose();
    super.dispose();
  }

  void resetScanState() {
    widget.qrDataHandler.reset();
    _isFirstScanData = true;
  }

  void _onQrViewCreated(QRViewController controller) {
    widget.setQrViewController(controller);
    var handler = widget.qrDataHandler;
    controller.scannedDataStream.distinct((previous, next) => previous.code == next.code).listen(
        (scanData) async {
      if (scanData.code == null) return;

      _scanTimeoutTimer?.cancel();
      _scanTimeoutTimer = Timer(const Duration(seconds: 1), () {
        setState(() {
          _showLoadingBar = false;
        });
      });
      try {
        if (_isFirstScanData) {
          if (!handler.validateFormat(scanData.code!)) {
            widget.onFailed(CoconutQrScanner.qrFormatErrorMessage);
            setState(() {
              _showLoadingBar = false;
            });
            return;
          }
          _isFirstScanData = false;
        }

        if (!handler.isCompleted()) {
          try {
            bool result = handler.joinData(scanData.code!);
            Logger.log('--> progress: ${handler.progress}');
            _progressNotifier.value = handler.progress;
            if (!result && handler is! IFragmentedQrScanDataHandler) {
              widget.onFailed(CoconutQrScanner.qrInvalidErrorMessage);
              resetScanState();
              return;
            }
            /* handler가 IFragmentedQrScanDataHandler일 땐 joinData 실패해도 무시하고 계속 스캔 진행함.
             왜냐하면 animated qr 스캔 중 노이즈 데이터가 오탐되는 경우가 있는데 매번 처음부터 다시 하면 사용성을 해침 */
          } on SequenceLengthMismatchException catch (_) {
            // QR Density 변경됨
            assert(handler is IFragmentedQrScanDataHandler);
            resetScanState();
            return;
          }
        }

        if (!_showLoadingBar) {
          setState(() {
            _showLoadingBar = true;
          });
        }

        if (handler.isCompleted()) {
          _resetLoadingBarState();
          final result = handler.result!;
          resetScanState();
          widget.onComplete(result);
        }
      } catch (e) {
        Logger.error(e.toString());
        _resetLoadingBarState();
        resetScanState();
        widget.onFailed(e.toString());
      }
    }, onError: (e) {
      _resetLoadingBarState();
      resetScanState();
      widget.onFailed(e.toString());
    });
  }

  void _resetLoadingBarState() {
    _scanTimeoutTimer?.cancel();
    if (_showLoadingBar) {
      setState(() {
        _showLoadingBar = false;
      });
    }
  }

  QrScannerOverlayShape _getOverlayShape() {
    return QrScannerOverlayShape(
      borderColor: widget.borderColor,
      borderRadius: 8,
      borderLength:
          (MediaQuery.of(context).size.width < 400 || MediaQuery.of(context).size.height < 400)
              ? 160.0
              : MediaQuery.of(context).size.width * 0.85 / 2,
      borderWidth: _borderWidth,
      cutOutSize:
          (MediaQuery.of(context).size.width < 400 || MediaQuery.of(context).size.height < 400)
              ? 320.0
              : MediaQuery.of(context).size.width * 0.85,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return Stack(
          children: [
            QRView(
              key: qrKey,
              onQRViewCreated: _onQrViewCreated,
              overlay: _getOverlayShape(),
            ),
            Positioned(
              top: scannerLoadingVerticalPos,
              left: 0,
              right: 0,
              bottom: 0,
              child: Visibility(
                visible: _showLoadingBar,
                child: Center(
                  child: ValueListenableBuilder<double>(
                    valueListenable: _progressNotifier,
                    builder: (context, value, _) {
                      bool isScanningExtraData = value >= 0.99;
                      return Padding(
                        padding: EdgeInsets.only(top: isScanningExtraData ? 24 : 0),
                        child: Text(
                          textAlign: TextAlign.center,
                          isScanningExtraData
                              ? t.coconut_qr_scanner.reading_extra_data
                              : "${(value * 100).toStringAsFixed(1)}%",
                          style: CoconutTypography.body1_16,
                        ),
                      );
                    },
                  ),
                ),
              ),
            )
          ],
        );
      },
    );
  }

  Rect? getQrViewRect() {
    final renderObject = qrKey.currentContext?.findRenderObject();
    if (renderObject is RenderBox && renderObject.hasSize) {
      final position = renderObject.localToGlobal(Offset.zero);
      final size = renderObject.size;
      return position & size;
    }
    return null;
  }
}
