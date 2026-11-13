import 'package:coconut_wallet/widgets/common/text/keep_words.dart';
import 'package:flutter/material.dart';

/// 이름(왼쪽)과 값(오른쪽) 한 줄. 둘이 한 줄에 들어가면 양 끝에 두고, 안 들어가면 값을 다음 줄 오른쪽으로 내린다.
/// 긴 언어·큰 글자에서도 이름이 단어 중간에서 끊기거나 값과 붙어 보이지 않는다.
class LabelValueRow extends StatelessWidget {
  final String label;
  final TextStyle labelStyle;
  final String value;
  final TextStyle valueStyle;
  final Key? valueKey;

  /// 한 줄일 때 이름과 값 사이 최소 간격
  final double gap;

  const LabelValueRow({
    super.key,
    required this.label,
    required this.labelStyle,
    required this.value,
    required this.valueStyle,
    this.valueKey,
    this.gap = 12,
  });

  /// [Text]가 실제로 그릴 때와 같은 스타일. 기본 글자 스타일을 합치고, 기기의 '굵은 글자'를 반영한다.
  static TextStyle effectiveStyle(BuildContext context, TextStyle style) {
    var effective = DefaultTextStyle.of(context).style.merge(style);
    if (MediaQuery.boldTextOf(context)) effective = effective.merge(const TextStyle(fontWeight: FontWeight.bold));
    return effective;
  }

  /// 한 줄로 그렸을 때의 폭. 글자 크기 배율과 [effectiveStyle]을 실제 [Text]와 같게 쓴다.
  static double widthOf(BuildContext context, String text, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: effectiveStyle(context, style)),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      locale: Localizations.maybeLocaleOf(context),
      maxLines: 1,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  }

  /// 글 한 줄의 높이. 아이콘·색 점을 글 첫 줄의 세로 가운데에 맞출 때 쓴다.
  static double lineHeightOf(BuildContext context, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: ' ', style: effectiveStyle(context, style)),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      locale: Localizations.maybeLocaleOf(context),
    )..layout();
    final height = painter.height;
    painter.dispose();
    return height;
  }

  @override
  Widget build(BuildContext context) {
    // 줄바꿈 막기는 보이는 글에만 하고, 화면 읽기에는 원문을 넘긴다.
    final display = keepWords(label);
    final labelText = Text(display, semanticsLabel: label, style: labelStyle);
    final valueText = Text(value, key: valueKey, style: valueStyle, textAlign: TextAlign.end);
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!constraints.hasBoundedWidth) {
          return Row(mainAxisSize: MainAxisSize.min, children: [labelText, SizedBox(width: gap), valueText]);
        }
        // 1px은 반올림 차이로 실제 줄에서 이름이 넘어가지 않게 두는 여유
        final fits =
            widthOf(context, display, labelStyle) + gap + widthOf(context, value, valueStyle) + 1 <=
            constraints.maxWidth;
        if (fits) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [Expanded(child: labelText), SizedBox(width: gap), valueText],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            labelText,
            const SizedBox(height: 2),
            Align(alignment: AlignmentDirectional.centerEnd, child: valueText),
          ],
        );
      },
    );
  }
}
