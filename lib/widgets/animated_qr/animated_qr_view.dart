import 'dart:async';

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/providers/view_model/send/unsigned_transaction_view_model.dart';
import 'package:coconut_wallet/widgets/animated_qr/view_data_handler/i_qr_view_data_handler.dart';
import 'package:coconut_wallet/widgets/overlays/coconut_loading_overlay.dart';
import 'package:flutter/cupertino.dart';
import 'package:qr_flutter/qr_flutter.dart';

class AnimatedQrView extends StatefulWidget {
  final int milliSeconds;
  final QrScanDensity qrScanDensity;
  final IQrViewDataHandler qrViewDataHandler;

  const AnimatedQrView({
    super.key,
    required this.qrViewDataHandler,
    required this.qrScanDensity,
    this.milliSeconds = 600,
  });

  @override
  State<AnimatedQrView> createState() => _AnimatedQrViewState();
}

class _AnimatedQrViewState extends State<AnimatedQrView> {
  final maxBitsInFastMode = 1840;
  final maxBitsInNormalMode = 1232;
  final maxBitsInSlowMode = 848;

  late int maxBits;
  late String _qrData;
  late final Timer _timer;

  int _qrVersion = 9;

  @override
  void initState() {
    super.initState();
    maxBits =
        widget.qrScanDensity == QrScanDensity.fast
            ? maxBitsInFastMode
            : widget.qrScanDensity == QrScanDensity.normal
            ? maxBitsInNormalMode
            : maxBitsInSlowMode;
    _qrData = widget.qrViewDataHandler.nextPart();
    _qrVersion =
        widget.qrScanDensity == QrScanDensity.fast
            ? 9
            : widget.qrScanDensity == QrScanDensity.normal
            ? 7
            : 5;
    _timer = Timer.periodic(Duration(milliseconds: widget.milliSeconds), (timer) {
      final next = widget.qrViewDataHandler.nextPart();
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
    final int estimatedBits = _qrData.runes.fold<int>(0, (prev, c) => prev + (c.bitLength));
    if (_qrData.isEmpty || estimatedBits > maxBits) {
      // QR 전환이 바로 안될 때를 대비한 위젯 - 실제로는 렌더링 되지 않을 가능성 높음
      return Stack(
        children: [
          QrImageView(data: _qrData, version: _qrVersion),
          Positioned(
            left: 70,
            right: 70,
            top: 70,
            bottom: 70,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 100,
                height: 100,
                decoration: const BoxDecoration(color: CoconutColors.gray300),
                child: const CoconutLoadingOverlay(applyFullScreen: true),
              ),
            ),
          ),
        ],
      );
    }

    // 시드사이너가 QR version 11 이상 인식 못하므로 10 이하로 설정해야 합니다.
    // 시드사이너가 QR version 10 인 경우 빠르게 인식이 안되어 9로 설정합니다.
    // 아래 QrImageView의 maxInputLength는 2192bits(274bytes)

    return QrImageView(data: _qrData, version: _qrVersion);
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }
}
