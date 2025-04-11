import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class PinBox extends StatelessWidget {
  final bool isSet;

  const PinBox({super.key, required this.isSet});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: CoconutColors.white.withOpacity(0.2),
      ),
      child: isSet
          ? SvgPicture.asset(
              'assets/svg/coconut.svg',
              width: 12,
              height: 12,
              fit: BoxFit.scaleDown,
              colorFilter: const ColorFilter.mode(CoconutColors.white, BlendMode.srcIn),
            )
          : null,
    );
  }
}
