import 'package:coconut_design_system/coconut_design_system.dart' show CoconutSegmentedControl;
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:flutter/material.dart';

/// 카드 안에서 값 하나를 고르는 선택 막대(`CoconutSegmentedControl`).
/// 기간·주기·요일처럼 몇 개 안 되는 값 중 하나를 고를 때 쓴다. 글자가 길면 칸 안에서 줄여 한 줄로 보인다.
class SegmentedChoice<T> extends StatelessWidget {
  final List<T> values;
  final T selected;
  final String Function(T value) label;
  final ValueChanged<T> onSelected;

  /// 칸마다 붙일 key(테스트에서 칸을 찾을 때). 예: (value) => 'goal-plan-cycle-${value.name}'
  final String Function(T value)? keyOf;

  /// 선택 막대 바탕. 없으면 홈 화면 바탕색(카드 안의 회색 칸)
  final Color? containerColor;

  const SegmentedChoice({
    super.key,
    required this.values,
    required this.selected,
    required this.label,
    required this.onSelected,
    this.keyOf,
    this.containerColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    return CoconutSegmentedControl(
      selectedColor: colors.segmentedControlSelected,
      segmentedControlContainerColor: containerColor ?? colors.homeBackground,
      selectedTextColor: colors.segmentedControlSelectedText,
      unselectedTextColor: colors.segmentedControlUnselectedText,
      labelPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
      isSelected: [for (final value in values) value == selected],
      onPressed: (index) => onSelected(values[index]),
      children: [
        for (final value in values)
          FittedBox(
            key: keyOf == null ? null : ValueKey(keyOf!(value)),
            fit: BoxFit.scaleDown,
            child: Text(label(value), maxLines: 1),
          ),
      ],
    );
  }
}
