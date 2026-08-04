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

/// Scene 4 ("DISCOVER") of the open-store intro story: a preview image lands first, then
/// three thoughts type themselves out one block at a time with the same readable pacing as IDEA.
class DiscoverSceneBody extends StatelessWidget {
  const DiscoverSceneBody({super.key, required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        final imageHeight = (height * 0.28).clamp(150.0, 210.0);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: height * 0.04),
            Align(
              alignment: Alignment.topCenter,
              child: _DiscoverPreviewImage(animation: animation, height: imageHeight),
            ),
            const SizedBox(height: 28),
            _DiscoverTypeLine(
              animation: animation,
              entranceInterval: const Interval(0.2045, 0.2216, curve: Curves.easeOutCubic),
              typingInterval: const Interval(0.2216, 0.3864, curve: Curves.linear),
              text: t.ccos.discover_scene.line1,
              highlightPhrases: {t.ccos.discover_scene.highlight_new_feature},
              textAlign: TextAlign.left,
              entryOffset: const Offset(-46, 24),
            ),
            const SizedBox(height: 28),
            _DiscoverTypeLine(
              animation: animation,
              entranceInterval: const Interval(0.3977, 0.4148, curve: Curves.easeOutCubic),
              typingInterval: const Interval(0.4148, 0.6193, curve: Curves.linear),
              text: t.ccos.discover_scene.line2,
              textAlign: TextAlign.left,
              entryOffset: const Offset(-54, 28),
            ),
            const SizedBox(height: 48),
            Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                width: constraints.maxWidth * 0.88,
                child: _DiscoverTypeLine(
                  animation: animation,
                  entranceInterval: const Interval(0.6477, 0.6648, curve: Curves.easeOutCubic),
                  typingInterval: const Interval(0.6648, 0.9602, curve: Curves.linear),
                  text: t.ccos.discover_scene.line3,
                  highlightPhrases: {
                    t.ccos.discover_scene.highlight_bitcoin_builder,
                    t.ccos.discover_scene.highlight_can_shine,
                  },
                  textAlign: TextAlign.right,
                  entryOffset: const Offset(60, 30),
                ),
              ),
            ),
            const Spacer(),
          ],
        );
      },
    );
  }
}

class _DiscoverPreviewImage extends StatelessWidget {
  const _DiscoverPreviewImage({required this.animation, required this.height});

  final Animation<double> animation;
  final double height;

  @override
  Widget build(BuildContext context) {
    final width = height * 1.22;

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final progress = Curves.easeOutCubic.transform(const Interval(0.04, 0.18).transform(animation.value));
        final dx = 18 * (1 - progress);
        final dy = -22 * (1 - progress);
        final scale = 0.9 + (0.12 * progress);
        final settleScale = scale > 1.0 ? 1.0 + ((scale - 1.0) * 0.35) : scale;

        return Opacity(
          opacity: progress,
          child: Transform.translate(
            offset: Offset(dx, dy),
            child: Transform.scale(
              scale: settleScale,
              child: SizedBox(
                width: width,
                height: height,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: 10,
                      right: 42,
                      top: 18,
                      bottom: 30,
                      child: _PreviewGlassCard(
                        label: t.ccos.discover_scene.preview_open_store,
                        align: Alignment.topLeft,
                        tint: const Color(0x33FFFFFF),
                      ),
                    ),
                    Positioned(
                      left: 48,
                      right: 10,
                      top: 46,
                      bottom: 0,
                      child: _PreviewGlassCard(
                        label: t.ccos.discover_scene.preview_created_by,
                        align: Alignment.bottomRight,
                        tint: const Color(0x40DCEEFF),
                      ),
                    ),
                    Positioned(
                      left: 34,
                      right: 68,
                      top: 62,
                      bottom: 42,
                      child: _PreviewGlassCard(
                        label: t.ccos.discover_scene.preview_feature,
                        align: Alignment.center,
                        tint: const Color(0x36B4E3FF),
                        isForeground: true,
                      ),
                    ),
                    Positioned(
                      right: 30,
                      top: 28,
                      child: _PreviewFlowDot(animation: animation, interval: const Interval(0.14, 0.30)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PreviewGlassCard extends StatelessWidget {
  const _PreviewGlassCard({required this.label, required this.align, required this.tint, this.isForeground = false});

  final String label;
  final Alignment align;
  final Color tint;
  final bool isForeground;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: isForeground ? 0.62 : 0.38), width: 1.1),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white.withValues(alpha: 0.54), tint],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7E8B95).withValues(alpha: isForeground ? 0.16 : 0.08),
            blurRadius: isForeground ? 24 : 16,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Align(
          alignment: align,
          child: Text(
            label,
            style: CoconutTypography.caption_10_Bold.setColor(const Color(0xFF10161C).withValues(alpha: 0.78)),
          ),
        ),
      ),
    );
  }
}

class _PreviewFlowDot extends StatelessWidget {
  const _PreviewFlowDot({required this.animation, required this.interval});

  final Animation<double> animation;
  final Interval interval;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final t = Curves.easeOut.transform(interval.transform(animation.value));
        return Opacity(
          opacity: t,
          child: Transform.scale(
            scale: 0.6 + (0.4 * t),
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.8),
                boxShadow: const [BoxShadow(color: Color(0x66A6DFFF), blurRadius: 18, spreadRadius: 2)],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DiscoverTypeLine extends StatelessWidget {
  const _DiscoverTypeLine({
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
