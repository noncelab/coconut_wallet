import 'package:flutter/material.dart';

import '../styles.dart';

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
              style: Styles.body2Number.merge(textStyle),
            ))
        .expand((widget) => [
              widget,
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Container(
                  width: 1,
                  height: 12,
                  color: MyColors.transparentWhite_70,
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
    return Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
        decoration: BoxDecoration(
          borderRadius: MyBorder.defaultRadius,
          color: MyColors.transparentWhite_15,
        ),
        width: width, // 넘겨받은 width가 적용되거나 null이면 자동으로 조절됩니다.
        height: height, // 넘겨받은 height가 적용되거나 null이면 자동으로 조절됩니다.
        child: child ?? _buildTextListWidget());
  }
}
