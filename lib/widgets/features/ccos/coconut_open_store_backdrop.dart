import 'package:flutter/material.dart';

/// 오픈 스토어 소개·스토어 화면의 밝은 배경과 은은한 빛번짐
class CoconutOpenStoreBackdrop extends StatelessWidget {
  const CoconutOpenStoreBackdrop({super.key});

  /// 배경 맨 위 색. 스크롤된 내용 위에 덮는 상단 그라데이션에 씀
  static const Color topColor = Color(0xFFD6DCDF);

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [topColor, Color(0xFFCDD4D7), Color(0xFFC6D0D5)],
            ),
          ),
        ),
        Align(
          alignment: const Alignment(-0.95, -1),
          child: Container(
            width: 320,
            height: 320,
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                colors: [Color(0x557AA2FF), Color(0x226E8EFF), Colors.transparent],
                stops: [0, 0.4, 1],
              ),
            ),
          ),
        ),
        Align(
          alignment: const Alignment(0.9, -0.74),
          child: Container(
            width: 260,
            height: 260,
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                colors: [Color(0x44B684FF), Color(0x15937FC5), Colors.transparent],
                stops: [0, 0.42, 1],
              ),
            ),
          ),
        ),
        Align(
          alignment: const Alignment(0.2, 1.0),
          child: Container(
            width: 420,
            height: 300,
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                colors: [Color(0x2274DCE0), Color(0x1167A7D0), Colors.transparent],
                stops: [0, 0.4, 1],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
