import 'package:coconut_wallet/styles.dart';
import 'package:flutter/material.dart';

/// fix: 고정, select: 선택됨, disable: 선택 안됨
enum CustomTagChipType { fix, select, disable }

@Deprecated("CustomTagChip")
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
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: type == CustomTagChipType.select
            ? BackgroundColorPalette[colorIndex].withOpacity(0.35)
            : BackgroundColorPalette[colorIndex].withOpacity(0.18),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(
          color: (type == CustomTagChipType.disable)
              ? ColorPalette[colorIndex].withOpacity(0.40)
              : ColorPalette[colorIndex],
          width: type == CustomTagChipType.fix ? 0.5 : 1,
        ),
      ),
      child: Center(
        child: Text(
          '#$tag',
          style: Styles.caption2.copyWith(
            color: type == CustomTagChipType.disable
                ? ColorPalette[colorIndex].withOpacity(0.40)
                : ColorPalette[colorIndex],
            fontSize: fontSize,
            fontWeight: type == CustomTagChipType.select
                ? FontWeight.w700
                : FontWeight.w400,
            height: 1,
          ),
        ),
      ),
    );
  }
}
