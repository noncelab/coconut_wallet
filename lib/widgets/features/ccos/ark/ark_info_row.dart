import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:flutter/material.dart';

/// 왼쪽 이름, 오른쪽 값. 값은 오른쪽 정렬로 줄바꿈
class ArkInfoRow extends StatelessWidget {
  const ArkInfoRow({super.key, required this.label, required this.value, this.isNumber = false, this.valueColor});

  final String label;
  final String value;
  final bool isNumber;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final valueStyle = (isNumber ? CoconutTypography.body2_14_Number : CoconutTypography.body2_14).setColor(
      valueColor ?? colors.primaryText,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: CoconutTypography.body2_14.setColor(colors.secondaryText)),
          CoconutLayout.spacing_400w,
          Expanded(child: Text(value, textAlign: TextAlign.right, style: valueStyle)),
        ],
      ),
    );
  }
}
