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
  const IdeaSceneBody({super.key, required this.animation, required this.sceneDurationMs});

  final Animation<double> animation;
  final int sceneDurationMs;
  static const int _firstTypingStartMs = 450;
  static const int _entranceSpanMs = 150;
  static const int _line1PauseMs = 800;
  static const int _line2PauseMs = 1350;
  static const int _line3PauseMs = 650;

  static List<int> typingStartMs(List<String> lines) {
    const line1Start = _firstTypingStartMs;
    final line2Start = line1Start + typewriterDurationMs(lines[0]) + _line1PauseMs;
    final line3Start = line2Start + typewriterDurationMs(lines[1]) + _line2PauseMs;
    final line4Start = line3Start + typewriterDurationMs(lines[2]) + _line3PauseMs;
    return [line1Start, line2Start, line3Start, line4Start];
  }

  static int navigationRevealStartMs(List<String> lines) {
    return typingStartMs(lines).last - (_entranceSpanMs ~/ 2);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        final lines = [
          t.ccos.idea_scene.line1,
          t.ccos.idea_scene.line2,
          t.ccos.idea_scene.line3,
          t.ccos.idea_scene.line4,
        ];
        final starts = typingStartMs(lines);

        return Stack(
          children: [
            Positioned(
              top: height * 0.08,
              left: 0,
              right: 48,
              child: _IdeaTypeLine(
                animation: animation,
                sceneDurationMs: sceneDurationMs,
                entranceStartMs: starts[0] - _entranceSpanMs,
                entranceEndMs: starts[0],
                typingStartMs: starts[0],
                text: lines[0],
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
                sceneDurationMs: sceneDurationMs,
                entranceStartMs: starts[1] - _entranceSpanMs,
                entranceEndMs: starts[1],
                typingStartMs: starts[1],
                text: lines[1],
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
                sceneDurationMs: sceneDurationMs,
                entranceStartMs: starts[2] - _entranceSpanMs,
                entranceEndMs: starts[2],
                typingStartMs: starts[2],
                text: lines[2],
                textAlign: TextAlign.right,
                entryOffset: const Offset(48, 24),
              ),
            ),
            Positioned(
              top: height * 0.62,
              left: 16,
              right: 0,
              child: _IdeaQuestionMorphLine(
                animation: animation,
                sceneDurationMs: sceneDurationMs,
                entranceStartMs: starts[3] - _entranceSpanMs,
                entranceEndMs: starts[3],
                typingStartMs: starts[3],
                text: lines[3],
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
    required this.sceneDurationMs,
    required this.entranceStartMs,
    required this.entranceEndMs,
    required this.typingStartMs,
    required this.text,
    required this.textAlign,
    this.highlightPhrases = const <String>{},
    this.entryOffset = Offset.zero,
  });

  final Animation<double> animation;
  final int sceneDurationMs;
  final int entranceStartMs;
  final int entranceEndMs;
  final int typingStartMs;
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
    final strutStyle =
        highlightPhrases.isEmpty
            ? null
            : StrutStyle(fontSize: highlightStyle.fontSize, height: 1.2, forceStrutHeight: true);

    return _AnimatedTypeBlock(
      animation: animation,
      entranceInterval: intervalFromMs(entranceStartMs, entranceEndMs, sceneDurationMs, curve: Curves.easeOutCubic),
      entryOffset: entryOffset,
      textAlign: textAlign,
      builder:
          (animation, textAlign) => RichText(
            textAlign: textAlign,
            strutStyle: strutStyle,
            text: typewriterSpan(
              source: text,
              animation: animation,
              interval: typewriterIntervalFromMs(text, typingStartMs, sceneDurationMs),
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
    required this.sceneDurationMs,
    required this.entranceStartMs,
    required this.entranceEndMs,
    required this.typingStartMs,
    required this.text,
    required this.textAlign,
    this.highlightPhrases = const <String>{},
    this.entryOffset = Offset.zero,
  });

  final Animation<double> animation;
  final int sceneDurationMs;
  final int entranceStartMs;
  final int entranceEndMs;
  final int typingStartMs;
  final String text;
  final Set<String> highlightPhrases;
  final TextAlign textAlign;
  final Offset entryOffset;

  @override
  State<_IdeaQuestionMorphLine> createState() => _IdeaQuestionMorphLineState();
}

class _IdeaQuestionMorphLineState extends State<_IdeaQuestionMorphLine> with SingleTickerProviderStateMixin {
  static const int _suffixDurationMs = 3700;

  late final AnimationController _suffixController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: _suffixDurationMs),
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
    final typingInterval = typewriterIntervalFromMs(widget.text, widget.typingStartMs, widget.sceneDurationMs);
    if (value < typingInterval.begin) {
      if (_hasStartedSuffixAnimation || _suffixController.value != 0) {
        _hasStartedSuffixAnimation = false;
        _suffixController.reset();
      }
      return;
    }

    if (value >= typingInterval.end && !_hasStartedSuffixAnimation) {
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
    final strutStyle =
        widget.highlightPhrases.isEmpty
            ? null
            : StrutStyle(fontSize: highlightStyle.fontSize, height: 1.2, forceStrutHeight: true);

    final typingInterval = typewriterIntervalFromMs(widget.text, widget.typingStartMs, widget.sceneDurationMs);
    final visibleText = typewriterText(widget.text, widget.animation, typingInterval);
    final hasQuestionMark = widget.text.endsWith('?');

    if (!hasQuestionMark || visibleText != widget.text) {
      return _AnimatedTypeBlock(
        animation: widget.animation,
        entranceInterval: intervalFromMs(
          widget.entranceStartMs,
          widget.entranceEndMs,
          widget.sceneDurationMs,
          curve: Curves.easeOutCubic,
        ),
        entryOffset: widget.entryOffset,
        textAlign: widget.textAlign,
        builder:
            (_, textAlign) => RichText(
              textAlign: textAlign,
              strutStyle: strutStyle,
              text: styledSpanFromVisibleText(
                visibleText: visibleText,
                sourceText: widget.text,
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
      entranceInterval: intervalFromMs(
        widget.entranceStartMs,
        widget.entranceEndMs,
        widget.sceneDurationMs,
        curve: Curves.easeOutCubic,
      ),
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
                      sourceText: widget.text,
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

  static const String _questionMark = '?';
  static const String _finalDots = '...';
  static const String _finalMark = '$_finalDots!';

  static const int _questionMarkAppearAtMs = 306; // "?" appears
  static const int _questionMarkHoldMs = 900; // "?" stays for a while before it's erased
  static const int _questionMarkRemoveAtMs = _questionMarkAppearAtMs + _questionMarkHoldMs;

  // "..." starts the moment "?" is erased, but each dot lands slowly and deliberately,
  // like someone pondering, rather than typing at the rest of the line's normal pace.
  static const int _dotsMsPerCharacter = kTypewriterMsPerCharacter * 10;
  static const int _finalDotsTypeEndMs = _questionMarkRemoveAtMs + _finalDots.length * _dotsMsPerCharacter;

  // The pause before "!" lands is longer than the pondering pace of the dots above.
  static const int _exclamationHoldMs = kTypewriterMsPerCharacter * 13;
  static const int _exclamationAppearAtMs = _finalDotsTypeEndMs + _exclamationHoldMs;

  static const double _questionMarkAppearAt = _questionMarkAppearAtMs / _suffixDurationMs;
  static const double _questionMarkRemoveAt = _questionMarkRemoveAtMs / _suffixDurationMs;
  static const double _finalDotsTypeEnd = _finalDotsTypeEndMs / _suffixDurationMs;
  static const double _exclamationAppearAt = _exclamationAppearAtMs / _suffixDurationMs;

  String _suffixText(double progress) {
    if (progress < _questionMarkAppearAt) {
      return '';
    }
    if (progress < _questionMarkRemoveAt) {
      return _questionMark;
    }
    if (progress < _finalDotsTypeEnd) {
      final typeProgress = (progress - _questionMarkRemoveAt) / (_finalDotsTypeEnd - _questionMarkRemoveAt);
      final count = (_finalDots.length * typeProgress).floor().clamp(0, _finalDots.length);
      return _finalDots.substring(0, count);
    }
    if (progress < _exclamationAppearAt) {
      return _finalDots;
    }
    return _finalMark;
  }
}

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
