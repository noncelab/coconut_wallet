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
              child: Transform.rotate(
                angle: _tiltAngle,
                child: SizedBox(
                  width: width,
                  height: height,
                  child: _ThemeSettingsMock(listing: listing, width: width),
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
// lib/screens/settings/theme_bottom_sheet.dart), showing the Coconut Pulp theme selected with
// its creator credit - illustrating what "discovering" a feature looks like once it's added.
class _ThemeSettingsMock extends StatelessWidget {
  const _ThemeSettingsMock({required this.listing, required this.width});

  final CcosFeatureListing listing;
  // The box's actual width, so the row text column can be sized as "whatever's left after
  // padding and the check icon" instead of a fixed pixel cap that goes out of proportion when
  // the box itself shrinks/grows (its height, and thus width, is device-dependent).
  final double width;

  static const double _horizontalPadding = 16 * 2;
  static const double _checkIconReserve = 21;

  @override
  Widget build(BuildContext context) {
    final pulpColors = CoconutColors.coconutPulp();
    final rowTextMaxWidth = (width - _horizontalPadding - _checkIconReserve).clamp(80.0, double.infinity);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: pulpColors.surfaceBottomSheet,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: pulpColors.surfaceBottomSheet, width: 1.2),
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
                  _ThemeMockRow(title: t.theme_dark, textColor: pulpColors.primaryText, maxWidth: rowTextMaxWidth),
                  Divider(height: 24, thickness: 1, color: pulpColors.primaryText.withAlpha(30)),
                  _ThemeMockRow(title: t.theme_light, textColor: pulpColors.primaryText, maxWidth: rowTextMaxWidth),
                  Divider(height: 24, thickness: 1, color: pulpColors.primaryText.withAlpha(30)),
                  _ThemeMockRow(
                    title: t.theme_coconut_pulp,
                    isSelected: true,
                    subtitle: '${listing.author} · ${listing.authorBio}',
                    textColor: pulpColors.primaryText,
                    maxWidth: rowTextMaxWidth,
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
  });

  final String title;
  final Color textColor;
  final double maxWidth;
  final bool isSelected;
  final String? subtitle;

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
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: CoconutTypography.caption_10
                      .setColor(textColor.withValues(alpha: 0.55))
                      .copyWith(fontSize: 8.5),
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
