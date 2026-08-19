import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class OptionCard extends StatelessWidget {
  final String title;
  final List<TextSpan> subtitle;
  final bool isSelected;
  final VoidCallback onTap;
  final bool showBorder;
  final bool isEnabled;

  const OptionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
    this.showBorder = false,
    this.isEnabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor =
        !isEnabled
            ? context.coconutColors.iconDisabled
            : isSelected
            ? context.coconutColors.primaryText
            : context.coconutColors.border;
    final iconColor =
        !isEnabled
            ? context.coconutColors.iconDisabled
            : isSelected
            ? context.coconutColors.iconDefault
            : context.coconutColors.iconSubDefault;
    final titleColor = isEnabled ? context.coconutColors.primaryText : context.coconutColors.mutedText;
    final subtitleColor = isEnabled ? context.coconutColors.secondaryText : context.coconutColors.mutedText;

    return GestureDetector(
      onTap: isEnabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        decoration:
            showBorder
                ? BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor, width: 1),
                )
                : null,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2.0),
              child: SvgPicture.asset(
                isSelected ? 'assets/svg/square_check.svg' : 'assets/svg/square.svg',
                width: 20,
                colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: CoconutTypography.body2_14.setColor(titleColor)),
                  if (subtitle.isNotEmpty) ...[
                    CoconutLayout.spacing_50h,
                    Text.rich(TextSpan(style: CoconutTypography.body3_12.setColor(subtitleColor), children: subtitle)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
