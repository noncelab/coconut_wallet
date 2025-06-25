import 'dart:async';

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/widgets/animated_qr/scan_data_handler/i_qr_scan_data_handler.dart';
import 'package:flutter/material.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';

class CoconutQrScanner extends StatefulWidget {
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
  final double _borderWidth = 8;
  double scannerLoadingVerticalPos = 0;

  late AnimationController _loadingBarController;
  late Animation<double> _animation;

  Timer? _scanTimeoutTimer;
  bool _showLoadingBar = false;

  @override
  void initState() {
    super.initState();
    _loadingBarController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: -1.0, end: 1.0).animate(CurvedAnimation(
      parent: _loadingBarController,
      curve: Curves.easeInOut,
    ));
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
    _scanTimeoutTimer?.cancel();
    _loadingBarController.dispose();
    super.dispose();
  }

  void _onQrViewCreated(QRViewController controller) {
    widget.setQrViewController(controller);
    var handler = widget.qrDataHandler;
    controller.scannedDataStream.listen((scanData) async {
      if (scanData.code == null) return;

      _scanTimeoutTimer?.cancel();
      _scanTimeoutTimer = Timer(const Duration(seconds: 1), () {
        setState(() {
          _showLoadingBar = false;
        });
      });
      try {
        if (!handler.isCompleted() && !handler.joinData(scanData.code!)) {
          if (!scanData.code!.startsWith('ur')) {
            widget.onFailed('Invalid QR code');
          }
          handler.reset();
          setState(() {
            _showLoadingBar = false;
          });
          return;
        }

        setState(() {
          _showLoadingBar = true;
        });

        if (handler.isCompleted()) {
          setState(() {
            _showLoadingBar = false;
          });
          widget.onComplete(handler.result!);
          handler.reset();
          _scanTimeoutTimer?.cancel();
        }
      } catch (e) {
        Logger.log(e.toString());
        setState(() {
          _showLoadingBar = false;
        });
        widget.onFailed(e.toString());
        handler.reset();
        _scanTimeoutTimer?.cancel();
      }
    }, onError: (e) {
      setState(() {
        _showLoadingBar = false;
      });
      widget.onFailed(e.toString());
      handler.reset();
      _scanTimeoutTimer?.cancel();
    });
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
                  child: Container(
                    width: MediaQuery.sizeOf(context).width,
                    height: 4,
                    margin: const EdgeInsets.symmetric(horizontal: 100),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: _showLoadingBar
                        ? AnimatedBuilder(
                            animation: _animation,
                            builder: (context, child) {
                              return Align(
                                alignment: Alignment(_animation.value, 0),
                                child: child,
                              );
                            },
                            child: Container(
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
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
