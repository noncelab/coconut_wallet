import 'package:coconut_design_system/coconut_design_system.dart'
    hide
        CoconutAppBar,
        CoconutToolTip,
        CoconutTooltipType,
        CoconutTooltipState,
        CoconutToast,
        CoconutToastLevel,
        CoconutPopup;
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/screens/ccos/coconut_open_store_text_effects.dart';
import 'package:flutter/material.dart';

/// Scene 1 ("IDEA") of the open-store intro story: a handful of lines that fly in and
/// type themselves out in a staggered, cascading sequence.
class IdeaSceneBody extends StatelessWidget {
  const IdeaSceneBody({super.key, required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;

        return Stack(
          children: [
            // Each line quickly settles into place, then types out one character at a time at
            // a constant, readable pace (~100ms/char) - matching scene 2's title/description effect.
            Positioned(
              top: height * 0.08,
              left: 0,
              right: 48,
              child: _IdeaTypeLine(
                animation: animation,
                entranceInterval: const Interval(0.0341, 0.0511, curve: Curves.easeOutCubic),
                typingInterval: const Interval(0.0511, 0.2102, curve: Curves.linear),
                text: t.ccos.idea_scene.line1,
                textAlign: TextAlign.left,
                entryOffset: const Offset(-44, 22),
              ),
            ),
            Positioned(
              top: height * 0.20,
              left: 0,
              right: 32,
              child: _IdeaTypeLine(
                animation: animation,
                entranceInterval: const Interval(0.1989, 0.2159, curve: Curves.easeOutCubic),
                typingInterval: const Interval(0.2159, 0.5114, curve: Curves.linear),
                text: t.ccos.idea_scene.line2,
                highlightPhrases: {t.ccos.idea_scene.highlight_network_effect},
                textAlign: TextAlign.left,
                entryOffset: const Offset(-54, 28),
              ),
            ),
            Positioned(
              top: height * 0.50,
              left: 72,
              right: 0,
              child: _IdeaTypeLine(
                animation: animation,
                entranceInterval: const Interval(0.5000, 0.5170, curve: Curves.easeOutCubic),
                typingInterval: const Interval(0.5170, 0.6420, curve: Curves.linear),
                text: t.ccos.idea_scene.line3,
                textAlign: TextAlign.right,
                entryOffset: const Offset(48, 24),
              ),
            ),
            Positioned(
              top: height * 0.62,
              left: 64,
              right: 0,
              child: _IdeaQuestionMorphLine(
                animation: animation,
                entranceInterval: const Interval(0.6307, 0.6477, curve: Curves.easeOutCubic),
                typingInterval: const Interval(0.6477, 0.9545, curve: Curves.linear),
                text: t.ccos.idea_scene.line4,
                highlightPhrases: {t.ccos.idea_scene.highlight_bitcoin_standard},
                textAlign: TextAlign.right,
                entryOffset: const Offset(64, 30),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _IdeaTypeLine extends StatelessWidget {
  const _IdeaTypeLine({
    required this.animation,
    required this.entranceInterval,
    required this.typingInterval,
    required this.text,
    required this.textAlign,
    this.highlightPhrases = const <String>{},
    this.entryOffset = Offset.zero,
  });

  final Animation<double> animation;
  final Interval entranceInterval;
  final Interval typingInterval;
  final String text;
  final Set<String> highlightPhrases;
  final TextAlign textAlign;
  final Offset entryOffset;

  @override
  Widget build(BuildContext context) {
    final baseStyle = CoconutTypography.heading3_21_Bold.setColor(Colors.white).copyWith(height: 1.32);
    final highlightStyle = baseStyle.copyWith(
      fontSize: (baseStyle.fontSize ?? 18) * 1.4,
      fontWeight: FontWeight.w900,
      height: 1.2,
    );
    // Reserve every line's height up front for the bigger highlighted run, so a line doesn't
    // suddenly grow taller (shoving later lines down) the instant typing reaches a highlight -
    // without this the line box only expands once a highlighted character actually appears.
    final strutStyle =
        highlightPhrases.isEmpty
            ? null
            : StrutStyle(fontSize: highlightStyle.fontSize, height: 1.2, forceStrutHeight: true);

    return _AnimatedTypeBlock(
      animation: animation,
      entranceInterval: entranceInterval,
      entryOffset: entryOffset,
      textAlign: textAlign,
      builder:
          (animation, textAlign) => RichText(
            textAlign: textAlign,
            strutStyle: strutStyle,
            text: typewriterSpan(
              source: text,
              animation: animation,
              interval: typingInterval,
              baseStyle: baseStyle,
              highlightStyle: highlightStyle,
              highlightPhrases: highlightPhrases,
            ),
          ),
    );
  }
}

class _IdeaQuestionMorphLine extends StatefulWidget {
  const _IdeaQuestionMorphLine({
    required this.animation,
    required this.entranceInterval,
    required this.typingInterval,
    required this.text,
    required this.textAlign,
    this.highlightPhrases = const <String>{},
    this.entryOffset = Offset.zero,
  });

  final Animation<double> animation;
  final Interval entranceInterval;
  final Interval typingInterval;
  final String text;
  final Set<String> highlightPhrases;
  final TextAlign textAlign;
  final Offset entryOffset;

  @override
  State<_IdeaQuestionMorphLine> createState() => _IdeaQuestionMorphLineState();
}

class _IdeaQuestionMorphLineState extends State<_IdeaQuestionMorphLine> with SingleTickerProviderStateMixin {
  late final AnimationController _suffixController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2300),
  );
  bool _hasStartedSuffixAnimation = false;

  @override
  void initState() {
    super.initState();
    widget.animation.addListener(_handleParentAnimation);
  }

  @override
  void didUpdateWidget(covariant _IdeaQuestionMorphLine oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animation != widget.animation) {
      oldWidget.animation.removeListener(_handleParentAnimation);
      widget.animation.addListener(_handleParentAnimation);
    }
    _handleParentAnimation();
  }

  @override
  void dispose() {
    widget.animation.removeListener(_handleParentAnimation);
    _suffixController.dispose();
    super.dispose();
  }

  void _handleParentAnimation() {
    final value = widget.animation.value;
    if (value < widget.typingInterval.begin) {
      if (_hasStartedSuffixAnimation || _suffixController.value != 0) {
        _hasStartedSuffixAnimation = false;
        _suffixController.reset();
      }
      return;
    }

    if (value >= widget.typingInterval.end && !_hasStartedSuffixAnimation) {
      _hasStartedSuffixAnimation = true;
      _suffixController.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final baseStyle = CoconutTypography.heading3_21_Bold.setColor(Colors.white).copyWith(height: 1.32);
    final highlightStyle = baseStyle.copyWith(
      fontSize: (baseStyle.fontSize ?? 18) * 1.4,
      fontWeight: FontWeight.w900,
      height: 1.2,
    );
    // Reserve every line's height up front for the bigger highlighted run, so a line doesn't
    // suddenly grow taller the instant typing reaches a highlight.
    final strutStyle =
        widget.highlightPhrases.isEmpty
            ? null
            : StrutStyle(fontSize: highlightStyle.fontSize, height: 1.2, forceStrutHeight: true);

    final visibleText = typewriterText(widget.text, widget.animation, widget.typingInterval);
    final hasQuestionMark = widget.text.endsWith('?');

    if (!hasQuestionMark || visibleText != widget.text) {
      return _AnimatedTypeBlock(
        animation: widget.animation,
        entranceInterval: widget.entranceInterval,
        entryOffset: widget.entryOffset,
        textAlign: widget.textAlign,
        builder:
            (_, textAlign) => RichText(
              textAlign: textAlign,
              strutStyle: strutStyle,
              text: styledSpanFromVisibleText(
                visibleText: visibleText,
                baseStyle: baseStyle,
                highlightStyle: highlightStyle,
                highlightPhrases: widget.highlightPhrases,
              ),
            ),
      );
    }

    final prefixText = widget.text.substring(0, widget.text.length - 1);

    return _AnimatedTypeBlock(
      animation: widget.animation,
      entranceInterval: widget.entranceInterval,
      entryOffset: widget.entryOffset,
      textAlign: widget.textAlign,
      builder:
          (_, textAlign) => AnimatedBuilder(
            animation: _suffixController,
            builder: (context, child) {
              final progress = _suffixController.value;
              final suffix = _suffixText(progress);

              return RichText(
                textAlign: textAlign,
                strutStyle: strutStyle,
                text: TextSpan(
                  style: baseStyle,
                  children: [
                    styledSpanFromVisibleText(
                      visibleText: prefixText,
                      baseStyle: baseStyle,
                      highlightStyle: highlightStyle,
                      highlightPhrases: widget.highlightPhrases,
                    ),
                    TextSpan(text: suffix, style: baseStyle),
                  ],
                ),
              );
            },
          ),
    );
  }

  // '...?' types out, then erases from the last character back to nothing, then '!' appears -
  // ordinary typed/erased text throughout, so there's no separate glyph swap (and no risk of
  // a line-height hiccup from mismatched cursor-character metrics).
  // The type/erase of '...?' runs at ~76.5ms/char (70% slower than the previous 45ms/char pace),
  // and there's now a much longer pause after it's fully erased before '!' lands.
  static const String _trailingDots = '...?';
  static const double _typeDotsEnd = 0.1330; // 306ms
  static const double _eraseStart = 0.2722; // hold full "...?" until 626ms
  static const double _eraseEnd = 0.4052; // erase finishes at 932ms
  static const double _finalMarkStart = 0.7965; // "!" appears at 1832ms

  String _suffixText(double progress) {
    if (progress < _typeDotsEnd) {
      final count = (_trailingDots.length * (progress / _typeDotsEnd)).floor().clamp(0, _trailingDots.length);
      return _trailingDots.substring(0, count);
    }
    if (progress < _eraseStart) {
      return _trailingDots;
    }
    if (progress < _eraseEnd) {
      final eraseProgress = (progress - _eraseStart) / (_eraseEnd - _eraseStart);
      final remaining = (_trailingDots.length * (1 - eraseProgress)).ceil().clamp(0, _trailingDots.length);
      return _trailingDots.substring(0, remaining);
    }
    if (progress < _finalMarkStart) {
      return '';
    }
    return '!';
  }
}

// Quickly settles a text block into place (fade + slide + scale), fully decoupled from
// whatever reveals its content (e.g. a typewriter effect on a separate interval) so the
// entrance doesn't smear together with in-progress typing.
class _AnimatedTypeBlock extends StatelessWidget {
  const _AnimatedTypeBlock({
    required this.animation,
    required this.entranceInterval,
    required this.entryOffset,
    required this.textAlign,
    required this.builder,
  });

  final Animation<double> animation;
  final Interval entranceInterval;
  final Offset entryOffset;
  final TextAlign textAlign;
  final Widget Function(Animation<double> animation, TextAlign textAlign) builder;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final t = entranceInterval.transform(animation.value);
        final dx = entryOffset.dx * (1 - t);
        final dy = entryOffset.dy * (1 - t);
        final scale = 0.9 + (0.16 * t);
        final settleScale = scale > 1.0 ? 1.0 + ((scale - 1.0) * 0.35) : scale;

        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(dx, dy),
            child: Transform.scale(
              scale: settleScale,
              alignment: textAlign == TextAlign.right ? Alignment.centerRight : Alignment.centerLeft,
              child: builder(animation, textAlign),
            ),
          ),
        );
      },
    );
  }
}
