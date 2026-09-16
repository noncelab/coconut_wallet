import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class CoconutAnimatedDialog extends StatefulWidget {
  final String lottieAddress;
  final String body;
  final int duration;
  final VoidCallback? onAnimationCompleted;

  const CoconutAnimatedDialog({
    super.key,
    required this.lottieAddress,
    this.body = '',
    this.duration = 300,
    this.onAnimationCompleted,
  });

  @override
  State<CoconutAnimatedDialog> createState() => _CoconutAnimatedDialogState();
}

class _CoconutAnimatedDialogState extends State<CoconutAnimatedDialog> with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _offsetAnimation;
  late final AnimationController _lottieController;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: Duration(milliseconds: widget.duration), vsync: this);
    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0.0, 1.0),
      end: const Offset(0.0, 0.0),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _controller.forward();

    _lottieController = AnimationController(vsync: this);
    _lottieController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onAnimationCompleted?.call();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _lottieController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;

    return Center(
      child: SlideTransition(
        position: _offsetAnimation,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.all(Radius.circular(16)),
            color: colors.surface.withValues(alpha: 0.95),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 24, offset: const Offset(0, 8)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Lottie.asset(
                widget.lottieAddress,
                width: 80,
                height: 80,
                fit: BoxFit.fill,
                repeat: false,
                controller: _lottieController,
                onLoaded: (composition) {
                  _lottieController
                    ..duration = composition.duration
                    ..forward();
                },
                delegates: LottieDelegates(
                  values: [
                    ValueDelegate.colorFilter(['**'], value: ColorFilter.mode(colors.primaryText, BlendMode.srcATop)),
                  ],
                ),
              ),
              if (widget.body.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    widget.body,
                    style: CoconutTypography.body2_14_Bold.setColor(colors.primaryText),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
