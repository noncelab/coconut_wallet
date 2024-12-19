import 'package:coconut_wallet/styles.dart';
import 'package:flutter/material.dart';

enum CustomTagChipType { fix, select, disable }

class CustomTagChip extends StatelessWidget {
  final String tag;
  final int colorIndex;
  final double fontSize;
  final CustomTagChipType type;

  const CustomTagChip({
    super.key,
    required this.tag,
    required this.colorIndex,
    this.fontSize = 10,
    this.type = CustomTagChipType.fix,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: type == CustomTagChipType.disable
            ? BackgroundColorPalette[colorIndex].withOpacity(0.1)
            : BackgroundColorPalette[colorIndex],
        borderRadius: BorderRadius.circular(50),
        border: Border.all(
          color: (type == CustomTagChipType.disable)
              ? ColorPalette[colorIndex].withOpacity(0.35)
              : ColorPalette[colorIndex],
          width: type == CustomTagChipType.fix ? 0.5 : 1,
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Text(
            '#$tag',
            style: Styles.body2.copyWith(
              color: type == CustomTagChipType.disable
                  ? ColorPalette[colorIndex].withOpacity(0.35)
                  : ColorPalette[colorIndex],
              fontSize: fontSize,
              fontWeight: type == CustomTagChipType.fix
                  ? FontWeight.w400
                  : FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
