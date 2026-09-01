import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:flutter/material.dart';

/// heading 한 줄, subtitle(예: 파일명) 있으면 그 아래 한 줄 더.
class LabelStatusTitle extends StatelessWidget {
  final String heading;
  final String? subtitle;
  final Color color;

  const LabelStatusTitle({super.key, required this.heading, this.subtitle, required this.color});

  @override
  Widget build(BuildContext context) {
    final textScaler = TextScaler.linear(MediaQuery.textScalerOf(context).scale(1.0).clamp(1.0, 1.2));
    return RichText(
      textAlign: TextAlign.center,
      textScaler: textScaler,
      text: TextSpan(
        style: CoconutTypography.heading4_18_Bold.setColor(color),
        children: [
          TextSpan(text: heading),
          if (subtitle != null) ...[
            const TextSpan(text: '\n'),
            TextSpan(text: subtitle, style: CoconutTypography.body1_16.setColor(color)),
          ],
        ],
      ),
    );
  }
}

/// SVG 아이콘은 뷰박스 안 여백 때문에 [renderSize]로 그려야 다른 상태 아이콘과 시각적 지름이 맞는데,
/// 그대로 두면 레이아웃이 차지하는 크기까지 커져서 뒤따르는 요소 위치가 밀린다.
/// 실제 차지하는 크기는 [footprint]로 고정하고 그 안에서만 [renderSize]로 넘치게 그린다.
Widget fixedFootprintIcon({required double footprint, required double renderSize, required Widget child}) {
  return SizedBox(
    width: footprint,
    height: footprint,
    child: OverflowBox(maxWidth: renderSize, maxHeight: renderSize, child: child),
  );
}

/// 라벨 import/export 흐름의 상태 화면(로딩/성공/에러/처리없음 등) 공통 틀.
/// 아이콘(40x40 고정 자리)·제목·그 아래 콘텐츠를 항상 같은 위치에 배치해서,
/// 상태가 바뀌어도 레이아웃이 밀리지 않게 한다. [icon]은 이미 40x40 자리를
/// 차지하도록 되어 있어야 한다([fixedFootprintIcon] 참고, 스피너/체크 로티는 이미 그러함).
class LabelStepLayout extends StatelessWidget {
  final Widget icon;
  final String heading;
  final String? subtitle;
  final Color titleColor;
  final EdgeInsetsGeometry titlePadding;
  final Widget? content;

  const LabelStepLayout({
    super.key,
    required this.icon,
    required this.heading,
    this.subtitle,
    required this.titleColor,
    this.titlePadding = EdgeInsets.zero,
    this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          SizedBox(width: 40, height: 40, child: icon),
          CoconutLayout.spacing_200h,
          Padding(
            padding: titlePadding,
            child: LabelStatusTitle(heading: heading, subtitle: subtitle, color: titleColor),
          ),
          if (content != null) ...[CoconutLayout.spacing_500h, content!],
        ],
      ),
    );
  }
}
