import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:coconut_wallet/styles.dart';

class AnimatedDialog extends StatefulWidget {
  final BuildContext context;
  final String lottieAddress;
  final String body;
  final int duration;

  const AnimatedDialog({
    super.key,
    required this.context,
    required this.lottieAddress,
    this.body = '',
    this.duration = 300,
  });

  @override
  _AnimatedDialogState createState() => _AnimatedDialogState();
}

class _AnimatedDialogState extends State<AnimatedDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(milliseconds: widget.duration),
      vsync: this,
    );

    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0.0, 1.0),
      end: const Offset(0.0, 0.0),
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SlideTransition(
        position: _offsetAnimation,
        child: Container(
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.all(Radius.circular(16)),
            color: MyColors.transparentWhite_12,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Lottie.asset(
                widget.lottieAddress,
                width: 120,
                height: 120,
                fit: BoxFit.fill,
                repeat: false,
              ),
              if (widget.body.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 10.0),
                  child: Text(
                    widget.body,
                    style: Styles.body2Bold,
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
