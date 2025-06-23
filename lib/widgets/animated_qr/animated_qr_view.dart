import 'dart:async';

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/widgets/animated_qr/view_data_handler/i_qr_view_data_handler.dart';
import 'package:coconut_wallet/widgets/overlays/coconut_loading_overlay.dart';
import 'package:flutter/cupertino.dart';
import 'package:qr_flutter/qr_flutter.dart';

class AnimatedQrView extends StatefulWidget {
  final double qrSize;
  final int milliSeconds;
  final bool isFastMode;
  final IQrViewDataHandler qrViewDataHandler;

  const AnimatedQrView(
      {super.key,
      required this.qrSize,
      required this.qrViewDataHandler,
      this.isFastMode = true,
      this.milliSeconds = 600});

  @override
  State<AnimatedQrView> createState() => _AnimatedQrViewState();
}

class _AnimatedQrViewState extends State<AnimatedQrView> {
  final maxBitsInFastMode = 1856;
  final maxBitsInNormalMode = 1248;

  late String _qrData;
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _qrData = widget.qrViewDataHandler.nextPart();
    _timer = Timer.periodic(Duration(milliseconds: widget.milliSeconds), (timer) {
      final next = widget.qrViewDataHandler.nextPart();
      final int maxBits = widget.isFastMode ? maxBitsInFastMode : maxBitsInNormalMode;
      final int estimatedBits = next.runes.fold<int>(0, (prev, c) => prev + c.bitLength);

      if (estimatedBits <= maxBits) {
        setState(() {
          _qrData = next;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final int maxBits = widget.isFastMode ? maxBitsInFastMode : maxBitsInNormalMode;

    final int estimatedBits = _qrData.runes.fold<int>(0, (prev, c) => prev + (c.bitLength));
    if (_qrData.isEmpty || estimatedBits > maxBits) {
      // QR 전환이 바로 안될 때를 대비한 위젯 - 실제로는 렌더링 되지 않을 가능성 높음
      return Stack(
        children: [
          QrImageView(data: _qrData, size: widget.qrSize, version: 9),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            bottom: 0,
            child: SizedBox(
              width: widget.qrSize,
              height: widget.qrSize,
              child: const CoconutLoadingOverlay(
                applyFullScreen: true,
              ),
            ),
          ),
        ],
      );
    }

    // 시드사이너가 QR version 11 이상 인식 못하므로 10 이하로 설정해야 합니다.
    // 시드사이너가 QR version 10 인 경우 빠르게 인식이 안되어 9로 설정합니다.
    // 아래 QrImageView의 maxInputLength는 2192bits(274bytes)
    return QrImageView(data: _qrData, size: widget.qrSize, version: widget.isFastMode ? 9 : 7);
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }
}
