import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class PinBox extends StatelessWidget {
  final bool isSet;
  final double? size;

  const PinBox({super.key, required this.isSet, this.size});

  @override
  Widget build(BuildContext context) {
    final boxSize = size ?? 50.0;
    return SizedBox(
      width: boxSize,
      child: AspectRatio(
        aspectRatio: 1.0,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: context.coconutColors.primaryText.withValues(alpha: 0.2),
          ),
          child:
              isSet
                  ? Padding(
                    padding: const EdgeInsets.all(Sizes.size12),
                    child: SvgPicture.asset(
                      'assets/svg/coconut-${NetworkType.currentNetworkType.isTestnet ? "regtest" : "mainnet"}.svg',
                      colorFilter: ColorFilter.mode(context.coconutColors.primaryText, BlendMode.srcIn),
                    ),
                  )
                  : null,
        ),
      ),
    );
  }
}
