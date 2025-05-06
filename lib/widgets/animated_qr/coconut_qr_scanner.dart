import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/widgets/animated_qr/scan_data_handler/i_qr_scan_data_handler.dart';
import 'package:flutter/material.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';

class CoconutQrScanner extends StatefulWidget {
  final Function(QRViewController) setQRViewController;
  final Function(dynamic) onComplete;
  final Function(String) onFailed;
  final Color borderColor;
  final IQrScanDataHandler qrDataHandler;

  const CoconutQrScanner({
    super.key,
    required this.setQRViewController,
    required this.onComplete,
    required this.onFailed,
    required this.qrDataHandler,
    this.borderColor = CoconutColors.white,
  });

  @override
  State<CoconutQrScanner> createState() => _CoconutQrScannerState();
}

class _CoconutQrScannerState extends State<CoconutQrScanner> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  final double _borderWidth = 8;

  void _onQRViewCreated(QRViewController controller) {
    widget.setQRViewController(controller);
    var handler = widget.qrDataHandler;
    controller.scannedDataStream.listen((scanData) async {
      if (scanData.code == null) return;

      try {
        if (!handler.isCompleted() && !handler.joinData(scanData.code!)) {
          widget.onFailed('Invalid QR code');
          handler.reset();
          return;
        }

        if (handler.isCompleted()) {
          widget.onComplete(handler.result!);
          handler.reset();
        }
      } catch (e) {
        Logger.log(e.toString());
        widget.onFailed(e.toString());
      }
    }, onError: (e) {
      widget.onFailed(e.toString());
      handler.reset();
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
              onQRViewCreated: _onQRViewCreated,
              overlay: _getOverlayShape(),
            ),
          ],
        );
      },
    );
  }
}
