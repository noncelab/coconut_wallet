import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class SvgBoxContainer extends StatelessWidget {
  final String svgPath;
  final Color backgroundColor;

  const SvgBoxContainer({super.key, required this.svgPath, required this.backgroundColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: const Color.fromRGBO(76, 110, 244, 1.0),
        borderRadius: BorderRadius.circular(21),
        border: Border.all(color: const Color.fromRGBO(202, 212, 252, 1.0), width: 4.0),
      ),
      child: Center(
        child: SvgPicture.asset(
          svgPath,
          width: 20,
          height: 20,
          colorFilter: const ColorFilter.mode(Color.fromRGBO(255, 255, 225, 1.0), BlendMode.srcIn),
        ),
      ),
    );
  }
}
