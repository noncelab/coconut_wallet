import 'dart:ui' as ui;

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:flutter/material.dart';

/// 금액별/태그별 차트 공통 말풍선 위젯 (선택 시에만 노출)
class UtxoChartBubble extends StatelessWidget {
  final String text;
  final TextStyle? textStyle;

  const UtxoChartBubble({super.key, required this.text, this.textStyle});

  static const double height = 32.0;
  static const double radius = 10.0;
  static const double arrowWidth = 12.0;
  static const double arrowHeight = 6.0;

  static Path speechBubblePath(double width, double height) {
    const r = radius;
    const aw = arrowWidth;
    const ah = arrowHeight;
    final bodyBottom = height - ah;
    return Path()
      ..moveTo(r, 0)
      ..lineTo(width - r, 0)
      ..arcToPoint(Offset(width, r), radius: const Radius.circular(r))
      ..lineTo(width, bodyBottom - r)
      ..arcToPoint(Offset(width - r, bodyBottom), radius: const Radius.circular(r))
      ..lineTo(width / 2 + aw / 2, bodyBottom)
      ..lineTo(width / 2, height)
      ..lineTo(width / 2 - aw / 2, bodyBottom)
      ..lineTo(r, bodyBottom)
      ..arcToPoint(Offset(0, bodyBottom - r), radius: const Radius.circular(r))
      ..lineTo(0, r)
      ..arcToPoint(const Offset(r, 0), radius: const Radius.circular(r))
      ..close();
  }

  @override
  Widget build(BuildContext context) {
    final style = textStyle ?? CoconutTypography.caption_10_Bold.setColor(CoconutColors.white);
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 60, maxWidth: 130, minHeight: height + arrowHeight),
      child: SizedBox(
        height: height + arrowHeight,
        child: ClipPath(
          clipper: _UtxoChartBubbleClipper(),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 4 + arrowHeight),
              decoration: BoxDecoration(color: CoconutColors.white.withValues(alpha: 0.08)),
              alignment: Alignment.center,
              child: Text(
                text,
                style: style,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _UtxoChartBubbleClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    return UtxoChartBubble.speechBubblePath(size.width, size.height);
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
