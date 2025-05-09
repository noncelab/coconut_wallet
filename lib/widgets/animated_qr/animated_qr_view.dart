import 'dart:async';

import 'package:coconut_wallet/widgets/animated_qr/view_data_handler/i_qr_view_data_handler.dart';
import 'package:flutter/cupertino.dart';
import 'package:qr_flutter/qr_flutter.dart';

class AnimatedQrView extends StatefulWidget {
  final double qrSize;
  final int milliSeconds;
  final IQrViewDataHandler qrViewDataHandler;

  const AnimatedQrView(
      {super.key, required this.qrSize, required this.qrViewDataHandler, this.milliSeconds = 600});

  @override
  State<AnimatedQrView> createState() => _AnimatedQrViewState();
}

class _AnimatedQrViewState extends State<AnimatedQrView> {
  late String _qrData;
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _qrData = widget.qrViewDataHandler.nextPart();
    _timer = Timer.periodic(Duration(milliseconds: widget.milliSeconds), (timer) {
      setState(() {
        _qrData = widget.qrViewDataHandler.nextPart();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    // 시드사이너가 QR version 11 이상 인식 못하므로 10 이하로 설정해야 합니다.
    // 시드사이너가 QR version 10 인 경우 빠르게 인식이 안되어 9로 설정합니다.
    // 아래 QrImageView의 maxInputLength는 2192bits(274bytes)
    return QrImageView(data: _qrData, size: widget.qrSize, version: 9);
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }
}
