import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:flutter/material.dart';

/// 위젯 크기(열×행)를 테두리 사각형으로 보여 주는 선택 버튼. 홈 위젯 크기 변경과 지갑 배경화면 미리보기가 같이 쓴다.
class SpanSizeOption extends StatelessWidget {
  final int columns;
  final int rows;
  final bool isSelected;
  final VoidCallback onTap;

  const SpanSizeOption({
    super.key,
    required this.columns,
    required this.rows,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 52,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? colors.primaryText.withValues(alpha: 0.08) : null,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Container(
          width: columns >= 4 ? 30 : 18,
          height: rows >= 2 ? 16 : 10,
          decoration: BoxDecoration(
            border: Border.all(color: colors.primaryText, width: 1.6),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }
}
