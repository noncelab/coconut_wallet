import 'package:flutter/material.dart';

class RightTriangleBubbleClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    var path = Path();
    path.moveTo(size.width - 15, 15);
    path.lineTo(size.width - 10, 15);
    path.lineTo(size.width - 19, 5);
    path.lineTo(size.width - 28, 15);
    path.lineTo(15, 15);
    path.quadraticBezierTo(0, 15, 0, 30);
    path.lineTo(0, size.height - 15);
    path.quadraticBezierTo(0, size.height, 15, size.height);
    path.lineTo(size.width - 15, size.height);
    path.quadraticBezierTo(
        size.width, size.height, size.width, size.height - 15);
    path.lineTo(size.width, 30);
    path.quadraticBezierTo(size.width, 15, size.width - 15, 14.5);
    return path;
  }

  @override
  bool shouldReclip(CustomClipper oldClipper) => true;
}

class LeftTriangleBubbleClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    var path = Path();
    path.moveTo(15, 15);
    path.lineTo(30, 15);
    path.lineTo(39, 5);
    path.lineTo(48, 15);
    path.lineTo(size.width - 15, 15);
    path.quadraticBezierTo(size.width, 15, size.width, 30);
    path.lineTo(size.width, size.height - 15);
    path.quadraticBezierTo(
        size.width, size.height, size.width - 15, size.height);
    path.lineTo(15, size.height);
    path.quadraticBezierTo(0, size.height, 0, size.height - 15);
    path.lineTo(0, 30);
    path.quadraticBezierTo(0, 15, 15, 15);
    return path;
  }

  @override
  bool shouldReclip(CustomClipper oldClipper) => true;
}
