import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class RotateIcon extends StatefulWidget {
  final String iconPath;
  final Color iconColor;
  final double iconSize;
  final int duration;
  const RotateIcon({
    super.key,
    required this.iconPath,
    this.iconColor = CoconutColors.primary,
    this.iconSize = 20,
    this.duration = 2,
  });

  @override
  State<RotateIcon> createState() => _RotateIconState();
}

class _RotateIconState extends State<RotateIcon> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: Duration(seconds: widget.duration))
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.rotate(
          angle: _controller.value * 2.0 * 3.1415927, // 2π radians = 360 degrees
          child: child,
        );
      },
      child: /*Icon(
        widget.iconData,
        color: widget.iconColor,
        size: widget.iconSize,
      ),*/
          SvgPicture.asset(widget.iconPath,
              width: widget.iconSize,
              colorFilter: ColorFilter.mode(widget.iconColor, BlendMode.srcIn)),
    );
  }
}
