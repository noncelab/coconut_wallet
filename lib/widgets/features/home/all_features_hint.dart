import 'dart:math' as math;

import 'package:coconut_design_system/coconut_design_system.dart' show CoconutTypography;
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/utils/text_utils.dart';
import 'package:flutter/cupertino.dart';

/// 왼쪽 스와이프로 이어지는 기능을 안내하는 말풍선.
/// 제목과 설명을 생략하면 홈의 전체 기능 안내 문구를 사용한다.
class AllFeaturesHint extends StatefulWidget {
  static const width = 220.0;
  static const maxWidth = 280.0;
  static const _titleCloseGap = 8.0;
  static const _horizontalChromeWidth = 84.0;
  static const _screenHorizontalInset = 8.0;

  final VoidCallback onOpen;
  final VoidCallback onClose;
  final String? title;
  final String? description;
  final bool showDescription;

  const AllFeaturesHint({
    super.key,
    required this.onOpen,
    required this.onClose,
    this.title,
    this.description,
    this.showDescription = true,
  });

  @override
  State<AllFeaturesHint> createState() => _AllFeaturesHintState();
}

class _AllFeaturesHintState extends State<AllFeaturesHint> with SingleTickerProviderStateMixin {
  late final AnimationController _swing = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context) || MediaQuery.accessibleNavigationOf(context)) {
      _swing.reset();
    } else if (!_swing.isAnimating) {
      _swing.repeat();
    }
  }

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
    final title = TextUtils.preventLineBreakInsideWords(widget.title ?? t.all_features_hint.title);
    final description =
        widget.showDescription
            ? TextUtils.preventLineBreakInsideWords(widget.description ?? t.all_features_hint.description)
            : null;
    final titleStyle = CoconutTypography.body2_14_Bold.copyWith(color: foreground);
    final titlePainter = TextPainter(
      text: TextSpan(text: title, style: titleStyle),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      locale: Localizations.maybeLocaleOf(context),
      maxLines: 1,
    )..layout();
    final availableWidth = math.max(0.0, MediaQuery.sizeOf(context).width - AllFeaturesHint._screenHorizontalInset * 2);
    final maxWidth = math.min(AllFeaturesHint.maxWidth, availableWidth);
    final minWidth = math.min(AllFeaturesHint.width, maxWidth);
    final width = (titlePainter.width + AllFeaturesHint._horizontalChromeWidth).clamp(minWidth, maxWidth);
    titlePainter.dispose();

    return GestureDetector(
      key: const Key('all-features-hint'),
      behavior: HitTestBehavior.opaque,
      onTap: widget.onOpen,
      child: SizedBox(
        width: width,
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
                        mainAxisSize: MainAxisSize.min,
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
                              Flexible(child: Text(title, style: titleStyle)),
                            ],
                          ),
                          if (description != null) ...[
                            const SizedBox(height: 4),
                            Text(description, style: CoconutTypography.body3_12.copyWith(color: foreground)),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: AllFeaturesHint._titleCloseGap),
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
