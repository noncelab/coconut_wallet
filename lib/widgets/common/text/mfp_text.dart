import 'package:flutter/material.dart';

/// Master fingerprint를 4자리씩 나누어 표시합니다.
/// [style]을 생략하면 상위 DefaultTextStyle을 따릅니다.
class MfpText extends StatelessWidget {
  final String mfp;
  final TextStyle? style;
  final double gap;

  const MfpText({super.key, required this.mfp, this.style, this.gap = 4.0});

  @override
  Widget build(BuildContext context) {
    final first = mfp.length >= 4 ? mfp.substring(0, 4) : mfp;
    final second = mfp.length > 4 ? mfp.substring(4) : '';

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: first),
          if (second.isNotEmpty) ...[WidgetSpan(child: SizedBox(width: gap)), TextSpan(text: second)],
        ],
      ),
      style: style,
      semanticsLabel: mfp,
    );
  }
}
