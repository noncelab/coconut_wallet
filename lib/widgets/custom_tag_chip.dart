import 'package:coconut_wallet/styles.dart';
import 'package:flutter/material.dart';

class CustomTagChip extends StatelessWidget {
  final String tag;
  final int colorIndex;
  final bool isSelected;
  final Function(String) onTap;

  const CustomTagChip({
    super.key,
    required this.tag,
    required this.colorIndex,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        onTap.call(tag);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: BackgroundColorPalette[colorIndex]
              .withOpacity(isSelected ? 0.3 : 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: ColorPalette[colorIndex].withOpacity(isSelected ? 1 : 0.2),
            width: 1,
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(
              '#$tag',
              style: Styles.body2.copyWith(
                color:
                    ColorPalette[colorIndex].withOpacity(isSelected ? 1 : 0.3),
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
