import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_lib/coconut_lib.dart';
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
          ? Padding(
              padding: const EdgeInsets.all(Sizes.size12),
              child: SvgPicture.asset(
                'assets/svg/coconut-${NetworkType.currentNetworkType.isTestnet ? "regtest" : "mainnet"}.svg',
                colorFilter: const ColorFilter.mode(CoconutColors.white, BlendMode.srcIn),
              ),
            )
          : null,
    );
  }
}
