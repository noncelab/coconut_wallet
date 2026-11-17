import 'dart:math' as math;

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:flutter/material.dart';

const _textPrimary = Color(0xFF10161C);

/// 제작자 한마디. 반투명 흰 상자에 큰 따옴표로 강조
class CoconutOpenStoreBeliefBox extends StatefulWidget {
  const CoconutOpenStoreBeliefBox({super.key, required this.text, this.textAlign = TextAlign.start});

  final String text;
  final TextAlign textAlign;

  @override
  State<CoconutOpenStoreBeliefBox> createState() => _CoconutOpenStoreBeliefBoxState();
}

class _CoconutOpenStoreBeliefBoxState extends State<CoconutOpenStoreBeliefBox> with SingleTickerProviderStateMixin {
  static final RegExp _hangulPattern = RegExp(r'[\u3131-\u318E\uAC00-\uD7A3]');

  late final AnimationController _glowController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context) || MediaQuery.accessibleNavigationOf(context)) {
      _glowController.reset();
    } else if (!_glowController.isAnimating) {
      _glowController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  static String _spaceBoundKoreanText(String text) {
    if (!_hangulPattern.hasMatch(text)) return text;

    final buffer = StringBuffer();
    final word = StringBuffer();

    void flushWord() {
      if (word.isEmpty) return;
      buffer.write(word.toString().characters.join('\u2060'));
      word.clear();
    }

    for (final character in text.characters) {
      if (character.trim().isEmpty) {
        flushWord();
        buffer.write(character);
      } else {
        word.write(character);
      }
    }
    flushWord();

    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final style = CoconutTypography.body2_14_Bold.setColor(_textPrimary.withValues(alpha: 0.96)).copyWith(height: 1.24);
    final text = _spaceBoundKoreanText(widget.text);

    return AnimatedBuilder(
      animation: _glowController,
      builder: (context, child) {
        final glowT = Curves.easeInOut.transform(_glowController.value);
        return DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.58),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.58 + (glowT * 0.2)), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.16 + (glowT * 0.1)),
                blurRadius: 18 + (glowT * 8),
                spreadRadius: 1,
              ),
            ],
          ),
          child: child,
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 15, 18, 17),
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              Positioned(
                left: -4,
                top: -8,
                child: _BeliefQuoteMark(opening: true, color: _textPrimary.withValues(alpha: 0.28), size: 42),
              ),
              Positioned(
                right: 4,
                bottom: -8,
                child: _BeliefQuoteMark(opening: false, color: _textPrimary.withValues(alpha: 0.28), size: 38),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 8),
                child: SizedBox(
                  width: widget.textAlign == TextAlign.center ? double.infinity : null,
                  child: Text(text, style: style, textAlign: widget.textAlign),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BeliefQuoteMark extends StatelessWidget {
  const _BeliefQuoteMark({required this.opening, required this.color, required this.size});

  final bool opening;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size.square(size), painter: _BeliefQuoteMarkPainter(opening: opening, color: color));
  }
}

class _BeliefQuoteMarkPainter extends CustomPainter {
  const _BeliefQuoteMarkPainter({required this.opening, required this.color});

  final bool opening;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;

    if (opening) {
      canvas
        ..translate(size.width, size.height)
        ..rotate(math.pi);
    }

    final markWidth = size.width * 0.3;
    final gap = size.width * 0.12;
    final top = size.height * 0.15;

    for (final left in [size.width * 0.18, size.width * 0.18 + markWidth + gap]) {
      final path =
          Path()
            ..moveTo(left + (markWidth * 0.95), top + (markWidth * 0.46))
            ..cubicTo(
              left + (markWidth * 0.95),
              top + (markWidth * 0.18),
              left + (markWidth * 0.74),
              top,
              left + (markWidth * 0.44),
              top,
            )
            ..cubicTo(left + (markWidth * 0.16), top, left, top + (markWidth * 0.2), left, top + (markWidth * 0.5))
            ..cubicTo(
              left,
              top + (markWidth * 0.78),
              left + (markWidth * 0.2),
              top + (markWidth * 0.98),
              left + (markWidth * 0.48),
              top + (markWidth * 1.0),
            )
            ..cubicTo(
              left + (markWidth * 0.42),
              top + (markWidth * 1.38),
              left + (markWidth * 0.24),
              top + (markWidth * 1.72),
              left + (markWidth * 0.02),
              top + (markWidth * 1.96),
            )
            ..lineTo(left + (markWidth * 0.38), top + (markWidth * 2.02))
            ..cubicTo(
              left + (markWidth * 0.76),
              top + (markWidth * 1.72),
              left + (markWidth * 0.96),
              top + (markWidth * 1.28),
              left + (markWidth * 0.95),
              top + (markWidth * 0.46),
            )
            ..close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_BeliefQuoteMarkPainter oldDelegate) {
    return oldDelegate.opening != opening || oldDelegate.color != color;
  }
}
