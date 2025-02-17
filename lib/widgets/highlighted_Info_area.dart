import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:flutter/material.dart';

class HighlightedInfoArea extends StatelessWidget {
  final Widget? child;
  final List<String>? textList;
  final double? width;
  final double? height;
  final TextStyle? textStyle;

  const HighlightedInfoArea(
      {super.key,
      this.child,
      this.textList,
      this.width,
      this.height,
      this.textStyle});

  Widget _buildTextListWidget() {
    if (textList == null || textList!.isEmpty) {
      return const SizedBox(); // textList가 null이거나 비어있는 경우 빈 위젯 반환
    }
    // textList의 각 요소를 Text 위젯으로 변환하고, 요소 사이에 SizedBox(width: 1)를 추가
    var children = textList!
        .map<Widget>((text) => Text(
              text,
              textAlign: TextAlign.center,
              style: CoconutTypography.body2_14_Number.copyWith(
                color: CoconutColors.white,
              ),
            ))
        .expand((widget) => [
              widget,
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Container(
                  width: 1,
                  height: 12,
                  color: CoconutColors.white.withOpacity(0.4),
                ),
              )
            ])
        .toList();

    // 마지막 SizedBox 제거
    if (children.isNotEmpty) {
      children.removeLast();
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: children,
    );
  }

  @override
  Widget build(BuildContext context) {
    return CoconutChip(
      color: CoconutColors.white.withOpacity(0.1),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
      borderWidth: 0,
      child: child ?? _buildTextListWidget(),
    );
  }
}
