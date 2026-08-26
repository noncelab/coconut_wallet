import 'dart:math' as math;

import 'package:coconut_design_system/coconut_design_system.dart'
    hide
        CoconutAppBar,
        CoconutToolTip,
        CoconutTooltipType,
        CoconutTooltipState,
        CoconutToast,
        CoconutToastLevel,
        CoconutPopup,
        CoconutColors;
import 'package:coconut_wallet/ccos/ccos_feature_registry.dart';
import 'package:coconut_wallet/design_system/tokens/coconut_colors.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/screens/ccos/coconut_open_store_text_effects.dart';
import 'package:flutter/material.dart';

/// Scene 4 ("DISCOVER") of the open-store intro story: a preview image lands first, then
/// three thoughts type themselves out one block at a time with the same readable pacing as IDEA.
class DiscoverSceneBody extends StatelessWidget {
  const DiscoverSceneBody({super.key, required this.animation, required this.sceneDurationMs});

  final Animation<double> animation;
  final int sceneDurationMs;
  static const int _firstTypingStartMs = 2172;
  static const int _entranceSpanMs = 168;
  static const int _line1PauseMs = 1100;
  static const int _line2PauseMs = 900;

  static List<int> typingStartMs(List<String> lines) {
    const line1Start = _firstTypingStartMs;
    final line2Start = line1Start + typewriterDurationMs(lines[0]) + _line1PauseMs;
    final line3Start = line2Start + typewriterDurationMs(lines[1]) + _line2PauseMs;
    return [line1Start, line2Start, line3Start];
  }

  static int navigationRevealStartMs(List<String> lines) {
    return typingStartMs(lines).last - (_entranceSpanMs ~/ 2);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        final lines = [t.ccos.discover_scene.line1, t.ccos.discover_scene.line2, t.ccos.discover_scene.line3];
        final starts = typingStartMs(lines);
        const firstTextTopGap = 40.0;
        const line1And3Height = 35.3;
        const line2Height = 27.8;
        final textHeight =
            (_lineCount(lines[0]) * line1And3Height) +
            (_lineCount(lines[1]) * line2Height) +
            (_lineCount(lines[2]) * line1And3Height);
        final maxImageHeight = height - (height * 0.04) - firstTextTopGap - 20 - 32 - textHeight - 8;
        final imageHeight = math.min((height * 0.28).clamp(140.0, 190.0), maxImageHeight.clamp(110.0, 190.0));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: height * 0.04),
            Align(
              alignment: Alignment.topCenter,
              child: _DiscoverPreviewImage(animation: animation, sceneDurationMs: sceneDurationMs, height: imageHeight),
            ),
            const SizedBox(height: firstTextTopGap),
            _DiscoverTypeLine(
              animation: animation,
              sceneDurationMs: sceneDurationMs,
              entranceStartMs: starts[0] - _entranceSpanMs,
              entranceEndMs: starts[0],
              typingStartMs: starts[0],
              text: lines[0],
              highlightPhrases: {t.ccos.discover_scene.highlight_new_feature},
              textAlign: TextAlign.left,
              entryOffset: const Offset(-46, 24),
            ),
            const SizedBox(height: 20),
            _DiscoverTypeLine(
              animation: animation,
              sceneDurationMs: sceneDurationMs,
              entranceStartMs: starts[1] - _entranceSpanMs,
              entranceEndMs: starts[1],
              typingStartMs: starts[1],
              text: lines[1],
              textAlign: TextAlign.left,
              entryOffset: const Offset(-54, 28),
            ),
            const SizedBox(height: 32),
            Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                width: constraints.maxWidth,
                child: _DiscoverTypeLine(
                  animation: animation,
                  sceneDurationMs: sceneDurationMs,
                  entranceStartMs: starts[2] - _entranceSpanMs,
                  entranceEndMs: starts[2],
                  typingStartMs: starts[2],
                  text: lines[2],
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

  static int _lineCount(String text) => text.split('\n').length;
}

class _DiscoverPreviewImage extends StatelessWidget {
  const _DiscoverPreviewImage({required this.animation, required this.sceneDurationMs, required this.height});

  final Animation<double> animation;
  final int sceneDurationMs;
  final double height;

  // Flat (Z-axis) tilt only, so the mock stays parallel to the screen's XY plane instead of
  // turning away in 3D perspective.
  static const double _tiltAngle = -5 * math.pi / 180;

  @override
  Widget build(BuildContext context) {
    final width = height * 1.82;
    final listing = CcosFeatureRegistrySource.featuredListing;

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final progress = intervalFromMs(
          392,
          1764,
          sceneDurationMs,
          curve: Curves.easeOutCubic,
        ).transform(animation.value);
        final dx = 18 * (1 - progress);
        final dy = -22 * (1 - progress);
        final scale = 0.9 + (0.12 * progress);
        final settleScale = scale > 1.0 ? 1.0 + ((scale - 1.0) * 0.35) : scale;
        final floatReady = intervalFromMs(
          1764,
          2200,
          sceneDurationMs,
          curve: Curves.easeOut,
        ).transform(animation.value);
        final floatDy = math.sin(animation.value * math.pi * 8) * 1.8 * floatReady;
        final highlightPulse = (0.5 + (0.5 * math.sin((animation.value * math.pi * 6) - (math.pi / 2)))) * floatReady;

        return Opacity(
          opacity: progress,
          child: Transform.translate(
            offset: Offset(dx, dy + floatDy),
            child: Transform.scale(
              scale: settleScale,
              child: Transform.rotate(
                angle: _tiltAngle,
                child: SizedBox(
                  width: width,
                  height: height,
                  child: _ThemeSettingsMock(listing: listing, width: width, highlightPulse: highlightPulse),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// A small non-interactive mock of the app's own theme settings screen (see
// lib/screens/settings/theme_bottom_sheet.dart), showing the Coconut Theme selected with
// its creator credit - illustrating what "discovering" a feature looks like once it's added.
class _ThemeSettingsMock extends StatelessWidget {
  const _ThemeSettingsMock({required this.listing, required this.width, required this.highlightPulse});

  final CcosFeatureListing listing;
  // The box's actual width, so the row text column can be sized as "whatever's left after
  // padding and the check icon" instead of a fixed pixel cap that goes out of proportion when
  // the box itself shrinks/grows (its height, and thus width, is device-dependent).
  final double width;
  final double highlightPulse;

  static const double _horizontalPadding = 16 * 2;
  static const double _checkIconReserve = 21;

  @override
  Widget build(BuildContext context) {
    final themeColors = CoconutColors.coconutTheme();
    final rowTextMaxWidth = (width - _horizontalPadding - _checkIconReserve).clamp(80.0, double.infinity);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: themeColors.surfaceBottomSheet,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: themeColors.surfaceBottomSheet, width: 1.2),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 24, offset: const Offset(0, 12)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: IntrinsicWidth(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ThemeMockRow(title: t.theme_dark, textColor: themeColors.primaryText, maxWidth: rowTextMaxWidth),
                  Divider(height: 24, thickness: 1, color: themeColors.primaryText.withAlpha(30)),
                  _ThemeMockRow(title: t.theme_light, textColor: themeColors.primaryText, maxWidth: rowTextMaxWidth),
                  Divider(height: 24, thickness: 1, color: themeColors.primaryText.withAlpha(30)),
                  _ThemeMockRow(
                    title: t.theme_coconut,
                    isSelected: true,
                    subtitle: '${listing.author} · ${listing.authorBio}',
                    textColor: themeColors.primaryText,
                    maxWidth: rowTextMaxWidth,
                    highlightPulse: highlightPulse,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ThemeMockRow extends StatelessWidget {
  const _ThemeMockRow({
    required this.title,
    required this.textColor,
    required this.maxWidth,
    this.isSelected = false,
    this.subtitle,
    this.highlightPulse = 0,
  });

  final String title;
  final Color textColor;
  final double maxWidth;
  final bool isSelected;
  final String? subtitle;
  final double highlightPulse;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: CoconutTypography.body3_12_Bold.setColor(textColor),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: textColor.withValues(alpha: 0.025 + (0.035 * highlightPulse)),
                    boxShadow: [
                      BoxShadow(
                        color: textColor.withValues(alpha: 0.05 + (0.10 * highlightPulse)),
                        blurRadius: 8 + (5 * highlightPulse),
                        spreadRadius: 0.4,
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2.5),
                    child: Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: CoconutTypography.caption_10
                          .setColor(textColor.withValues(alpha: 0.56 + (0.12 * highlightPulse)))
                          .copyWith(
                            fontSize: 8.5,
                            shadows: [Shadow(color: textColor.withValues(alpha: 0.08 * highlightPulse), blurRadius: 4)],
                          ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (isSelected)
          Padding(
            padding: const EdgeInsets.only(left: 8, top: 1),
            child: Icon(Icons.check, size: 13, color: textColor),
          ),
      ],
    );
  }
}

class _DiscoverTypeLine extends StatelessWidget {
  const _DiscoverTypeLine({
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
      sceneDurationMs: sceneDurationMs,
      entranceStartMs: entranceStartMs,
      entranceEndMs: entranceEndMs,
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

class _AnimatedTypeBlock extends StatelessWidget {
  const _AnimatedTypeBlock({
    required this.animation,
    required this.sceneDurationMs,
    required this.entranceStartMs,
    required this.entranceEndMs,
    required this.entryOffset,
    required this.textAlign,
    required this.builder,
  });

  final Animation<double> animation;
  final int sceneDurationMs;
  final int entranceStartMs;
  final int entranceEndMs;
  final Offset entryOffset;
  final TextAlign textAlign;
  final Widget Function(Animation<double> animation, TextAlign textAlign) builder;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final entranceInterval = intervalFromMs(
          entranceStartMs,
          entranceEndMs,
          sceneDurationMs,
          curve: Curves.easeOutCubic,
        );
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
