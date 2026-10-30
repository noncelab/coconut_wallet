import 'dart:math' as math;

import 'package:coconut_design_system/coconut_design_system.dart' show CoconutTypography;
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/utils/text_utils.dart';
import 'package:flutter/cupertino.dart';

/// 지갑이 없을 때 앱 바의 지갑 추가 버튼을 가리키는 말풍선. [nudges]가 바뀔 때마다 살짝 흔들린다.
class AddWalletHint extends StatefulWidget {
  static const width = 228.0;
  static const tailHeight = 10.0;

  /// 말풍선 오른쪽 끝에서 꼬리 끝까지의 거리
  final double tailFromRight;
  final int nudges;
  final VoidCallback onClose;

  const AddWalletHint({super.key, required this.tailFromRight, required this.nudges, required this.onClose});

  @override
  State<AddWalletHint> createState() => _AddWalletHintState();
}

class _AddWalletHintState extends State<AddWalletHint> with SingleTickerProviderStateMixin {
  late final AnimationController _shake = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));

  @override
  void didUpdateWidget(covariant AddWalletHint oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.nudges != oldWidget.nudges) _shake.forward(from: 0);
  }

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final background = colors.guideBubbleBackground;
    final foreground = colors.guideBubblePrimaryText;
    return AnimatedBuilder(
      animation: _shake,
      builder: (context, child) {
        final progress = _shake.value;
        final dy = -6 * math.sin(progress * math.pi * 3) * (1 - progress);
        return Transform.translate(offset: Offset(0, dy), child: child);
      },
      child: SizedBox(
        key: const Key('add-wallet-hint'),
        width: AddWalletHint.width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.only(right: widget.tailFromRight - 9),
              child: CustomPaint(size: const Size(18, AddWalletHint.tailHeight), painter: _TailPainter(background)),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 6, 12),
              decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(14)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          TextUtils.preventLineBreakInsideWords(t.add_wallet_hint.title),
                          style: CoconutTypography.body2_14_Bold.copyWith(color: foreground),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          TextUtils.preventLineBreakInsideWords(t.add_wallet_hint.description),
                          style: CoconutTypography.body3_12.copyWith(color: foreground),
                        ),
                      ],
                    ),
                  ),
                  CupertinoButton(
                    key: const Key('add-wallet-hint-close'),
                    padding: const EdgeInsets.all(4),
                    minimumSize: const Size(32, 32),
                    onPressed: widget.onClose,
                    child: Icon(CupertinoIcons.xmark, size: 16, color: foreground),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TailPainter extends CustomPainter {
  final Color color;

  const _TailPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final path =
        Path()
          ..moveTo(0, size.height)
          ..lineTo(size.width / 2, 0)
          ..lineTo(size.width, size.height)
          ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _TailPainter oldDelegate) => oldDelegate.color != color;
}
