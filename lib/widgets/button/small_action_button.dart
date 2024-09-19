import 'package:flutter/cupertino.dart';

import '../../styles.dart';

class SmallActionButton extends StatelessWidget {
  final Widget? child;
  final String text;
  final VoidCallback onPressed;
  final double? width;
  final double? height;
  final TextStyle? textStyle;
  final Color? backgroundColor;
  final BorderRadiusGeometry? borderRadius;

  const SmallActionButton(
      {super.key,
      required this.onPressed,
      this.child,
      this.text = '',
      this.width,
      this.height,
      this.textStyle,
      this.backgroundColor = MyColors.transparentWhite_15,
      this.borderRadius});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 4),
      decoration: BoxDecoration(
        borderRadius: borderRadius ?? MyBorder.defaultRadius,
        color: backgroundColor,
      ),
      width: width, // 넘겨받은 width가 적용되거나 null이면 자동으로 조절됩니다.
      height: height, // 넘겨받은 height가 적용되거나 null이면 자동으로 조절됩니다.
      child: CupertinoButton(
        padding: const EdgeInsets.symmetric(
            vertical: 0, horizontal: 12), // 기본 패딩을 제거하여 컨테이너 크기에 꽉 차게 만듭니다.
        onPressed: onPressed,
        child: child ??
            Text(text,
                textAlign: TextAlign.center, // 텍스트를 가운데 정렬합니다.
                style: Styles.body2.merge(textStyle)),
      ),
    );
  }
}
