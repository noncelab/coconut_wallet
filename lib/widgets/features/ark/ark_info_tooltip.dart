import 'package:coconut_design_system/coconut_design_system.dart'
    hide CoconutAppBar, CoconutToolTip, CoconutTooltipType, CoconutTooltipState, CoconutToast, CoconutPopup;
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/ui/coconut/coconut_overlays.dart';
import 'package:coconut_wallet/utils/text_utils.dart';
import 'package:coconut_wallet/widgets/common/clipper/bubble_clipper.dart';
import 'package:flutter/material.dart';

/// 라벨 옆 정보 아이콘, 누르면 [onTap]에 아이콘 위치를 넘김
class ArkInfoIcon extends StatelessWidget {
  const ArkInfoIcon({super.key, required this.onTap});

  final ValueChanged<Rect> onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        final box = context.findRenderObject() as RenderBox?;
        if (box == null || !box.hasSize) return;
        onTap(box.localToGlobal(Offset.zero) & box.size);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Icon(Icons.info_outline_rounded, color: context.coconutColors.iconSecondary, size: 18),
      ),
    );
  }
}

/// [anchor] 아래에 띄우는 말풍선, 화면 전체를 덮는 Stack 안에 둠
class ArkInfoTooltip extends StatelessWidget {
  const ArkInfoTooltip({super.key, required this.anchor, required this.text, required this.onDismiss});

  final Rect anchor;
  final String text;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final style = CoconutTypography.body3_12
        .setColor(context.coconutColors.popoverText)
        .merge(const TextStyle(height: 1.3));
    final shown = LocaleSettings.currentLocale == AppLocale.ko ? TextUtils.preventLineBreakInsideWords(text) : text;
    final painter = TextPainter(
      text: TextSpan(text: shown, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: MediaQuery.sizeOf(context).width * 0.6);
    final width = painter.width + 32;
    painter.dispose();
    final arrowHeight = LeftTriangleBubbleClipper.arrowTip.dy + 10;
    return Positioned(
      top: anchor.bottom - LeftTriangleBubbleClipper.arrowTip.dy + 2,
      left: anchor.center.dx - LeftTriangleBubbleClipper.arrowTip.dx,
      child: SizedBox(
        width: width,
        child: CoconutToolTip(
          width: width,
          isBubbleClipperSideLeft: true,
          tooltipType: CoconutTooltipType.placement,
          isPlacementTooltipVisible: true,
          backgroundColor: context.coconutColors.popoverBackground,
          padding: EdgeInsets.fromLTRB(16, arrowHeight + 12, 16, 12),
          richText: RichText(text: TextSpan(text: shown, style: style)),
          onTapRemove: onDismiss,
        ),
      ),
    );
  }
}
