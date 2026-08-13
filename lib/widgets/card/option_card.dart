import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class OptionCard extends StatelessWidget {
  final String title;
  final List<TextSpan> subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const OptionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SvgPicture.asset(
              isSelected ? 'assets/svg/square_check.svg' : 'assets/svg/square.svg',
              width: 24,
              colorFilter: ColorFilter.mode(
                isSelected ? context.coconutColors.iconDefault : context.coconutColors.iconSubDefault,
                BlendMode.srcIn,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: CoconutTypography.body1_16, maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 8),
                  Text.rich(
                    TextSpan(
                      style: CoconutTypography.body3_12.setColor(context.coconutColors.secondaryText),
                      children: subtitle,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
