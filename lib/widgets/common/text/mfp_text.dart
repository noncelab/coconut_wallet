import 'package:flutter/material.dart';

/// Master fingerprint를 4자리씩 나누어 표시합니다.
/// [style]을 생략하면 상위 DefaultTextStyle을 따릅니다.
class MfpText extends StatelessWidget {
  final String mfp;
  final TextStyle? style;
  final double gap;
  final TextAlign? textAlign;

  const MfpText({super.key, required this.mfp, this.style, this.gap = 4.0, this.textAlign});

  @override
  Widget build(BuildContext context) {
    final first = mfp.length >= 4 ? mfp.substring(0, 4) : mfp;
    final second = mfp.length > 4 ? mfp.substring(4) : '';
    final defaults = DefaultTextStyle.of(context);
    final alignment = textAlign ?? defaults.textAlign ?? TextAlign.start;
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final wrapAlignment = switch (alignment) {
      TextAlign.left => WrapAlignment.start,
      TextAlign.right => WrapAlignment.end,
      TextAlign.center => WrapAlignment.center,
      TextAlign.end => isRtl ? WrapAlignment.start : WrapAlignment.end,
      TextAlign.start || TextAlign.justify => isRtl ? WrapAlignment.end : WrapAlignment.start,
    };
    final fontSize = defaults.style.merge(style).fontSize ?? 14;
    final textScale = fontSize == 0 ? 0.0 : MediaQuery.textScalerOf(context).scale(fontSize) / fontSize;

    return Semantics(
      label: mfp,
      excludeSemantics: true,
      child: Wrap(
        alignment: wrapAlignment,
        textDirection: TextDirection.ltr,
        // Spacing between groups never leaves a gap at the end of a wrapped line.
        spacing: gap * textScale,
        children: [
          Text(first, style: style, textAlign: alignment),
          if (second.isNotEmpty) Text(second, style: style, textAlign: alignment),
        ],
      ),
    );
  }
}
