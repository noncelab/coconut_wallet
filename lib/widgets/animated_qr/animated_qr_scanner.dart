import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/widgets/animated_qr/animated_qr_data_handler.dart';
import 'package:flutter/material.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';

class AnimatedQrScanner extends StatefulWidget {
  final Function(QRViewController) setQRViewController;
  final Function(String) onComplete;
  final Function(String) onFailed;
  final Color borderColor;

  const AnimatedQrScanner(
      {super.key,
      required this.setQRViewController,
      required this.onComplete,
      required this.onFailed,
      this.borderColor = Colors.white});

  @override
  State<AnimatedQrScanner> createState() => _AnimatedQrScannerState();
}

class _AnimatedQrScannerState extends State<AnimatedQrScanner> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  final double _borderWidth = 8;
  List<String>? scannedData;
  int _insertCount = 0;
  int? _totalCount;

  void reset() {
    scannedData = null;
    _insertCount = 0;
    _totalCount = null;
  }

  void _onQRViewCreated(QRViewController controller) {
    widget.setQRViewController(controller);

    controller.scannedDataStream.listen((scanData) async {
      if (scanData.code == null) return;

      try {
        if (!scanData.code!.startsWith(AnimatedQRDataHandler.psbtUrType)) {
          throw 'No psbtUrType';
        }

        // 배열 insert를 위해서 scannedData Size 설정
        if (scannedData == null) {
          int totalCount = AnimatedQRDataHandler.parseTotalCount(scanData.code!);
          scannedData = List<String>.filled(totalCount, '');
          setState(() {
            _totalCount = totalCount;
          });
        }

        final index = AnimatedQRDataHandler.parseIndex(scanData.code!);
        // 이미 저장된 경우
        if (scannedData![index - 1].isNotEmpty) return;

        scannedData![index - 1] = scanData.code!;
        setState(() {
          _insertCount++;
        });

        if (scannedData!.length == _insertCount) {
          String psbt = AnimatedQRDataHandler.joinData(scannedData!);
          reset();
          widget.onComplete(psbt);
        }
      } catch (e) {
        Logger.log(e.toString());
        reset();
        widget.onFailed("Invalid Scheme");
      }
    }, onError: (e) {
      reset();
      widget.onFailed(e.toString());
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
            Positioned(
              bottom: (MediaQuery.of(context).size.width < 400 ||
                      MediaQuery.of(context).size.height < 400)
                  ? (constraints.maxHeight - 320.0) / 2 - _borderWidth - 20
                  : (constraints.maxHeight - MediaQuery.of(context).size.width * 0.85) / 2 -
                      _borderWidth -
                      20, // QRView 아래에 배치되도록 위치 설정
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  _totalCount != null ? '$_insertCount / $_totalCount' : '',
                  style: Styles.body1,
                ),
              ),
            )
          ],
        );
      },
    );
  }
}
