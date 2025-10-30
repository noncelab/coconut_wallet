import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class NetworkErrorTooltip extends StatelessWidget {
  final bool isNetworkOn;
  const NetworkErrorTooltip({super.key, required this.isNetworkOn});

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: isNetworkOn ? 0.0 : 1.0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      alignment: Alignment.center,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: CoconutLayout.defaultPadding),
        child: CoconutToolTip(
          richText: RichText(text: TextSpan(text: t.errors.network_error, style: CoconutTypography.body3_12)),
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
