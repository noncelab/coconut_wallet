import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:flutter/material.dart';

class CoconutChecklistTile extends StatefulWidget {
  final String title;
  final bool isChecked;
  final ValueChanged<bool?> onChanged;

  const CoconutChecklistTile({super.key, required this.title, required this.isChecked, required this.onChanged});

  @override
  State<CoconutChecklistTile> createState() => _CoconutChecklistTileState();
}

class _CoconutChecklistTileState extends State<CoconutChecklistTile> {
  late bool isChecked;

  @override
  void initState() {
    super.initState();
    isChecked = widget.isChecked;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final typography = context.coconutTypography;

    return GestureDetector(
      onTap: () {
        setState(() {
          isChecked = !isChecked;
          widget.onChanged(isChecked);
        });
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isChecked ? Icons.check_circle_rounded : Icons.check_circle_outline_rounded,
              size: 20,
              color: colors.primaryText,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.title,
                style: typography.caption.copyWith(
                  color: colors.primaryText,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.start,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
