import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class CoconutAnimatedDialog extends StatefulWidget {
  final String lottieAddress;
  final String body;
  final int duration;

  const CoconutAnimatedDialog({super.key, required this.lottieAddress, this.body = '', this.duration = 300});

  @override
  State<CoconutAnimatedDialog> createState() => _CoconutAnimatedDialogState();
}

class _CoconutAnimatedDialogState extends State<CoconutAnimatedDialog> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _offsetAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: Duration(milliseconds: widget.duration), vsync: this);
    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0.0, 1.0),
      end: const Offset(0.0, 0.0),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final typography = context.coconutTypography;

    return Center(
      child: SlideTransition(
        position: _offsetAnimation,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.all(Radius.circular(16)),
            color: colors.surface.withValues(alpha: 0.7),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Lottie.asset(widget.lottieAddress, width: 120, height: 120, fit: BoxFit.fill, repeat: false),
              if (widget.body.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    widget.body,
                    style: typography.bodyBold.copyWith(color: colors.primaryText),
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
