import 'dart:async';

import 'package:coconut_design_system/coconut_design_system.dart'
    hide CoconutToolTip, CoconutTooltipType, CoconutTooltipState;
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/ui/coconut/coconut_overlays.dart';
import 'package:coconut_wallet/utils/text_utils.dart';
import 'package:coconut_wallet/widgets/common/clipper/bubble_clipper.dart';
import 'package:flutter/material.dart';

/// 인포 아이콘, 누르면 지갑 정보 화면과 같은 말풍선(아이콘이 오른쪽 절반이면 UTXO 상세처럼 꼭지점이 오른쪽). 5초 뒤, 바깥을 누르거나 스크롤하면 닫힘
class ArkInfoTooltip extends StatefulWidget {
  const ArkInfoTooltip({super.key, required this.message, this.iconKey, this.iconSize = 18});

  final String message;

  /// 12 크기 글자 옆이면 14
  final double iconSize;

  /// 테스트에서 아이콘을 찾는 키
  final Key? iconKey;

  @override
  State<ArkInfoTooltip> createState() => _ArkInfoTooltipState();
}

class _ArkInfoTooltipState extends State<ArkInfoTooltip> {
  static const Duration _tooltipDuration = Duration(seconds: 5);
  static const double _tooltipPadding = 16;

  final GlobalKey _iconKey = GlobalKey();
  final OverlayPortalController _portal = OverlayPortalController();
  Rect? _anchor;
  Timer? _timer;
  ScrollPosition? _scroll;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scroll?.removeListener(_hide);
    _scroll = Scrollable.maybeOf(context)?.position;
    _scroll?.addListener(_hide);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scroll?.removeListener(_hide);
    super.dispose();
  }

  void _toggle() {
    if (_anchor != null) {
      _hide();
      return;
    }
    final box = _iconKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    setState(() => _anchor = box.localToGlobal(Offset.zero) & box.size);
    _portal.show();
    _timer?.cancel();
    _timer = Timer(_tooltipDuration, _hide);
  }

  void _hide() {
    _timer?.cancel();
    if (_anchor == null || !mounted) return;
    _portal.hide();
    setState(() => _anchor = null);
  }

  Widget _bubble(BuildContext context) {
    final anchor = _anchor;
    if (anchor == null) return const SizedBox.shrink();
    final style = CoconutTypography.body3_12
        .setColor(context.coconutColors.popoverText)
        .merge(const TextStyle(height: 1.3));
    final text = TextUtils.preventLineBreakInsideWords(widget.message);
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final screenWidth = MediaQuery.sizeOf(context).width;
    final pointsLeft = anchor.center.dx <= screenWidth / 2;
    final left = anchor.center.dx - LeftTriangleBubbleClipper.arrowTip.dx;
    final right = RightTriangleBubbleClipper.rightOffsetForAnchor(viewportWidth: screenWidth, anchor: anchor);
    final width = ((painter.width + 36) * 1.1).clamp(0.0, screenWidth - 16 - (pointsLeft ? left : right));
    painter.dispose();
    final arrowHeight = LeftTriangleBubbleClipper.arrowTip.dy + 10;
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTapDown: (details) {
              if (anchor.inflate(8).contains(details.globalPosition)) return;
              _hide();
            },
          ),
        ),
        Positioned(
          top: anchor.bottom - LeftTriangleBubbleClipper.arrowTip.dy + 2,
          left: pointsLeft ? left : null,
          right: pointsLeft ? null : right,
          child: SizedBox(
            width: width,
            child: CoconutToolTip(
              width: width,
              isBubbleClipperSideLeft: pointsLeft,
              tooltipType: CoconutTooltipType.placement,
              backgroundColor: context.coconutColors.popoverBackground,
              padding: EdgeInsets.fromLTRB(
                _tooltipPadding,
                arrowHeight + _tooltipPadding,
                _tooltipPadding,
                _tooltipPadding,
              ),
              richText: RichText(text: TextSpan(text: text, style: style)),
              onTapRemove: _hide,
              isPlacementTooltipVisible: true,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => OverlayPortal(
    controller: _portal,
    overlayChildBuilder: _bubble,
    child: GestureDetector(
      key: _iconKey,
      behavior: HitTestBehavior.opaque,
      onTap: _toggle,
      child: Padding(
        key: widget.iconKey,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Icon(Icons.info_outline_rounded, color: context.coconutColors.iconSecondary, size: widget.iconSize),
      ),
    ),
  );
}
