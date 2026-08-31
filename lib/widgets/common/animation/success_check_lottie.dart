import 'package:coconut_wallet/constants/lottie_path.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

/// check-mark.json 체크 링이 실제로 채우는 캔버스 비율(실기기 실측치)
const double _kVisualFillRatio = 0.685;

class SuccessCheckLottie extends StatefulWidget {
  final double size;
  final Color color;

  const SuccessCheckLottie({super.key, required this.size, required this.color});

  @override
  State<SuccessCheckLottie> createState() => _SuccessCheckLottieState();
}

class _SuccessCheckLottieState extends State<SuccessCheckLottie> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final assetSize = widget.size / _kVisualFillRatio;

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Center(
        child: Lottie.asset(
          CommonLottiePath.checkMark,
          width: assetSize,
          height: assetSize,
          fit: BoxFit.fill,
          repeat: false,
          controller: _controller,
          onLoaded: (composition) {
            _controller
              ..duration = composition.duration
              ..forward();
          },
          delegates: LottieDelegates(
            values: [
              ValueDelegate.colorFilter(const ['**'], value: ColorFilter.mode(widget.color, BlendMode.srcATop)),
            ],
          ),
        ),
      ),
    );
  }
}
