import 'dart:math' as math;

import 'package:coconut_design_system/coconut_design_system.dart' show CoconutTypography;
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/utils/text_utils.dart';
import 'package:flutter/cupertino.dart';

/// 홈 오른쪽 끝을 가리키며 왼쪽으로 밀면 All Features가 나온다고 알려 주는 말풍선. 누르면 All Features를 연다.
class AllFeaturesHint extends StatefulWidget {
  static const width = 220.0;

  final VoidCallback onOpen;
  final VoidCallback onClose;

  const AllFeaturesHint({super.key, required this.onOpen, required this.onClose});

  @override
  State<AllFeaturesHint> createState() => _AllFeaturesHintState();
}

class _AllFeaturesHintState extends State<AllFeaturesHint> with SingleTickerProviderStateMixin {
  late final AnimationController _swing = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
    ..repeat();

  @override
  void dispose() {
    _swing.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final background = colors.guideBubbleBackground;
    final foreground = colors.guideBubblePrimaryText;
    return GestureDetector(
      key: const Key('all-features-hint'),
      behavior: HitTestBehavior.opaque,
      onTap: widget.onOpen,
      child: SizedBox(
        width: AllFeaturesHint.width,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 6, 12),
                decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(14)),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              AnimatedBuilder(
                                animation: _swing,
                                builder:
                                    (context, child) => Transform.translate(
                                      offset: Offset(-4 * math.sin(_swing.value * math.pi), 0),
                                      child: child,
                                    ),
                                child: Icon(CupertinoIcons.chevron_left_2, size: 14, color: foreground),
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  TextUtils.preventLineBreakInsideWords(t.all_features_hint.title),
                                  style: CoconutTypography.body2_14_Bold.copyWith(color: foreground),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            TextUtils.preventLineBreakInsideWords(t.all_features_hint.description),
                            style: CoconutTypography.body3_12.copyWith(color: foreground),
                          ),
                        ],
                      ),
                    ),
                    CupertinoButton(
                      key: const Key('all-features-hint-close'),
                      padding: const EdgeInsets.all(4),
                      minimumSize: const Size(28, 28),
                      onPressed: widget.onClose,
                      child: Icon(CupertinoIcons.xmark, size: 16, color: foreground),
                    ),
                  ],
                ),
              ),
            ),
            CustomPaint(size: const Size(8, 16), painter: _RightTailPainter(background)),
          ],
        ),
      ),
    );
  }
}

class _RightTailPainter extends CustomPainter {
  final Color color;

  const _RightTailPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final path =
        Path()
          ..moveTo(0, 0)
          ..lineTo(size.width, size.height / 2)
          ..lineTo(0, size.height)
          ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _RightTailPainter oldDelegate) => oldDelegate.color != color;
}
