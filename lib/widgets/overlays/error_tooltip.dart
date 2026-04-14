import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class ErrorTooltip extends StatelessWidget {
  final bool isShown;
  final String errorMessage;

  const ErrorTooltip({super.key, required this.isShown, required this.errorMessage});

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: isShown ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      alignment: Alignment.center,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: CoconutToolTip(
          richText: RichText(text: TextSpan(text: errorMessage, style: CoconutTypography.body3_12)),
          showIcon: true,
          tooltipType: CoconutTooltipType.fixed,
          tooltipState: CoconutTooltipState.error,
          icon: SvgPicture.asset(
            'assets/svg/triangle-warning.svg',
            colorFilter: const ColorFilter.mode(CoconutColors.hotPink, BlendMode.srcIn),
          ),
        ),
      ),
    );
  }
}
