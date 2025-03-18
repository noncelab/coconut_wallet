import 'package:flutter/material.dart';

class AnimationUtil {
  static Animation<Offset> buildSlideInAnimation(Animation<double> animation) {
    // 오른쪽에서 나타나는 애니메이션
    const begin = Offset(1.0, 0.0);
    const end = Offset.zero;
    const curve = Curves.easeOutExpo;

    var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
    return animation.drive(tween);
  }

  static Animation<Offset> buildSlideOutAnimation(Animation<double> animation) {
    // 왼쪽으로 사라지는 애니메이션
    const begin = Offset(-1.0, 0.0);
    const end = Offset.zero;
    const curve = Curves.easeOutExpo;

    var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
    return animation.drive(tween);
  }
}
