import 'package:flutter/material.dart';
import 'package:coconut_wallet/ui/coconut/coconut_animated_dialog.dart';

class AnimatedDialog extends StatelessWidget {
  final BuildContext context;
  final String lottieAddress;
  final String body;
  final int duration;
  final VoidCallback? onAnimationCompleted;

  const AnimatedDialog({
    super.key,
    required this.context,
    required this.lottieAddress,
    this.body = '',
    this.duration = 300,
    this.onAnimationCompleted,
  });

  @override
  Widget build(BuildContext context) {
    return CoconutAnimatedDialog(
      lottieAddress: lottieAddress,
      body: body,
      duration: duration,
      onAnimationCompleted: onAnimationCompleted,
    );
  }
}
