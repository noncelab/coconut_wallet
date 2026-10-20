import 'package:flutter/material.dart';

class CenterTriangleBubbleClipper extends CustomClipper<Path> {
  final double? arrowPosition;

  CenterTriangleBubbleClipper({this.arrowPosition});

  @override
  Path getClip(Size size) {
    final center = (arrowPosition ?? size.width / 2).clamp(24.0, size.width - 24.0);
    return Path()
      ..moveTo(15, 15)
      ..lineTo(center - 9, 15)
      ..lineTo(center, 5)
      ..lineTo(center + 9, 15)
      ..lineTo(size.width - 15, 15)
      ..quadraticBezierTo(size.width, 15, size.width, 30)
      ..lineTo(size.width, size.height - 15)
      ..quadraticBezierTo(size.width, size.height, size.width - 15, size.height)
      ..lineTo(15, size.height)
      ..quadraticBezierTo(0, size.height, 0, size.height - 15)
      ..lineTo(0, 30)
      ..quadraticBezierTo(0, 15, 15, 15)
      ..close();
  }

  @override
  bool shouldReclip(covariant CenterTriangleBubbleClipper oldClipper) => oldClipper.arrowPosition != arrowPosition;
}

class RightTriangleBubbleClipper extends CustomClipper<Path> {
  final double arrowOffset;
  final double? arrowPosition;

  RightTriangleBubbleClipper({this.arrowOffset = 0.0, this.arrowPosition});

  @override
  Path getClip(Size size) {
    var path = Path();
    final offset = arrowPosition == null ? arrowOffset : size.width - 19 - arrowPosition!;

    // 삼각형 꼭지점 부분 (클릭 지점 기준 위치라서 이동하지 않음)
    // 모서리 접점을 삼각형 밑변점과 같은 좌표로 합쳐서 gap 없이 이어지도록 함
    path.moveTo(size.width - 10 - offset, 15);
    path.lineTo(size.width - 19 - offset, 5);
    path.lineTo(size.width - 28 - offset, 15);
    path.lineTo(15, 15);
    path.quadraticBezierTo(0, 15, 0, 30);
    path.lineTo(0, size.height - 15);
    path.quadraticBezierTo(0, size.height, 15, size.height);
    path.lineTo(size.width - 15, size.height);
    path.quadraticBezierTo(size.width, size.height, size.width, size.height - 15);
    path.lineTo(size.width, 30);
    path.quadraticBezierTo(size.width, 15, size.width - 10 - offset, 15);
    return path;
  }

  @override
  bool shouldReclip(CustomClipper oldClipper) => true;
}

class LeftTriangleBubbleClipper extends CustomClipper<Path> {
  /// 꼭지점 위치(말풍선 왼쪽 위 기준). 말풍선을 아이콘에 맞춰 놓을 때 쓴다.
  static const Offset arrowTip = Offset(39, 5);

  @override
  Path getClip(Size size) {
    var path = Path();
    path.moveTo(15, 15);
    path.lineTo(arrowTip.dx - 9, 15);
    path.lineTo(arrowTip.dx, arrowTip.dy);
    path.lineTo(arrowTip.dx + 9, 15);
    path.lineTo(size.width - 15, 15);
    path.quadraticBezierTo(size.width, 15, size.width, 30);
    path.lineTo(size.width, size.height - 15);
    path.quadraticBezierTo(size.width, size.height, size.width - 15, size.height);
    path.lineTo(15, size.height);
    path.quadraticBezierTo(0, size.height, 0, size.height - 15);
    path.lineTo(0, 30);
    path.quadraticBezierTo(0, 15, 15, 15);
    return path;
  }

  @override
  bool shouldReclip(CustomClipper oldClipper) => true;
}
