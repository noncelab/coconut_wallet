import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:flutter/material.dart';

class SuctionAmountText extends StatelessWidget {
  const SuctionAmountText({super.key, required this.amount, required this.unit, required this.progress});

  final String amount;
  final String unit;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final characters = amount.characters.toList();
    final unitCharacters = unit.characters.toList();
    final totalCharacterCount = characters.length + unitCharacters.length;
    final eased = Curves.easeInOutCubic.transform(progress);

    double characterProgress(int index) {
      if (totalCharacterCount <= 1) return progress;
      final delay = index / (totalCharacterCount - 1) * 0.5;
      return ((progress - delay) / (1 - delay)).clamp(0.0, 1.0);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        ...List.generate(characters.length, (index) {
          final localEased = Curves.easeInOutCubic.transform(characterProgress(index));
          return Transform.translate(
            offset: Offset(0, (eased - localEased) * 36),
            child: Text(
              characters[index],
              style: CoconutTypography.heading2_28_NumberBold
                  .setColor(colors.primaryText)
                  .copyWith(fontSize: 28 - 12 * eased),
            ),
          );
        }),
        if (unit.isNotEmpty) ...[
          const SizedBox(width: 1),
          ...List.generate(unitCharacters.length, (index) {
            final localEased = Curves.easeInOutCubic.transform(characterProgress(characters.length + index));
            return Transform.translate(
              offset: Offset(0, (eased - localEased) * 36),
              child: Text(
                unitCharacters[index],
                style: CoconutTypography.heading4_18_Number
                    .setColor(colors.primaryText)
                    .copyWith(fontSize: 18 - 4 * eased, height: 1.6 - 0.2 * eased),
              ),
            );
          }),
        ],
      ],
    );
  }
}
