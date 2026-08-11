import 'dart:math' as math;

import 'package:coconut_design_system/coconut_design_system.dart'
    hide
        CoconutAppBar,
        CoconutToolTip,
        CoconutTooltipType,
        CoconutTooltipState,
        CoconutToast,
        CoconutToastLevel,
        CoconutPopup;
import 'package:coconut_wallet/ccos/ccos_feature_registry.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/screens/ccos/coconut_open_store_text_effects.dart';
import 'package:coconut_wallet/widgets/common/effects/liquid_glass_surface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

const _featureImagePath = 'assets/images/ccos/feature.png';
const _creatorImagePath = 'assets/images/ccos/creator.png';
const _deliveryImagePath = 'assets/images/ccos/delivery.png';
const _featureHeroTag = 'ccos-first-pow-feature-image';
const _creatorHeroTag = 'ccos-first-pow-creator-image';
const _deliveryHeroTag = 'ccos-first-pow-delivery-image';

const _previewTxCardImagePath = 'assets/images/ccos/preview_transaction_card.png';
const _previewWalletIconImagePath = 'assets/images/ccos/preview_wallet_icon.png';
const _previewDownArrowImagePath = 'assets/images/ccos/preview_arrow_down.png';
const _previewUpArrowImagePath = 'assets/images/ccos/preview_arrow_up.png';
const _previewAddressBarImagePath = 'assets/images/ccos/preview_address_bar.png';

const _textPrimary = Color(0xFF10161C);
const _screenBackground = Color(0xFFCDD4D7);

String get _creatorFeedbackQuote => t.ccos.first_pow_scene.creator_detail.feedback_quote;
String get _creatorFeedbackAttribution => t.ccos.first_pow_scene.creator_detail.feedback_attribution;
String get _creatorStoryParagraph1 => t.ccos.first_pow_scene.creator_detail.story_paragraph1;
String get _creatorStoryParagraph2 => t.ccos.first_pow_scene.creator_detail.story_paragraph2;
String get _creatorStoryParagraph3 => t.ccos.first_pow_scene.creator_detail.story_paragraph3;
String get _creatorBeliefStatement => t.ccos.first_pow_scene.creator_detail.belief_statement;

const _deliveryProposeIconPath = 'assets/svg/brand/motifs/bulb.svg';
const _deliveryReviewIconPath = 'assets/svg/brand/motifs/shield-check.svg';
const _deliveryIntroIconPath = 'assets/svg/brand/motifs/users.svg';
String get _deliveryProposeTitle => t.ccos.first_pow_scene.delivery_detail.propose_title;
String get _deliveryProposeBody => t.ccos.first_pow_scene.delivery_detail.propose_body;
String get _deliveryReviewTitle => t.ccos.first_pow_scene.delivery_detail.review_title;
String get _deliveryReviewBody => t.ccos.first_pow_scene.delivery_detail.review_body;
String get _deliveryIntroTitle => t.ccos.first_pow_scene.delivery_detail.intro_title;
String get _deliveryIntroBody => t.ccos.first_pow_scene.delivery_detail.intro_body;

enum _FirstPowCardKind { creator, feature, delivery }

const List<_FirstPowCardKind> _firstPowDetailOrder = [
  _FirstPowCardKind.creator,
  _FirstPowCardKind.feature,
  _FirstPowCardKind.delivery,
];

class _FirstPowCardDetail {
  const _FirstPowCardDetail({
    required this.kind,
    required this.imagePath,
    required this.heroTag,
    required this.panelLabel,
  });

  final _FirstPowCardKind kind;
  final String imagePath;
  final String heroTag;
  final String panelLabel;
}

_FirstPowCardDetail _firstPowCardDetailForKind(_FirstPowCardKind kind) {
  return switch (kind) {
    _FirstPowCardKind.creator => _FirstPowCardDetail(
      kind: _FirstPowCardKind.creator,
      imagePath: _creatorImagePath,
      heroTag: _creatorHeroTag,
      panelLabel: t.ccos.first_pow_scene.creator_detail.panel_label,
    ),
    _FirstPowCardKind.feature => _FirstPowCardDetail(
      kind: _FirstPowCardKind.feature,
      imagePath: _featureImagePath,
      heroTag: _featureHeroTag,
      panelLabel: t.ccos.first_pow_scene.feature_detail.panel_label,
    ),
    _FirstPowCardKind.delivery => _FirstPowCardDetail(
      kind: _FirstPowCardKind.delivery,
      imagePath: _deliveryImagePath,
      heroTag: _deliveryHeroTag,
      panelLabel: t.ccos.first_pow_scene.delivery_detail.panel_label,
    ),
  };
}

// Given a card rotated by [angle] around its own center, returns the translate offset that
// makes [localCorner] (a corner in the card's own unrotated local frame, relative to its
// center) land exactly on [targetPoint] (relative to the same shared origin as other cards).
Offset _cornerAlignedOffset({required double angle, required Offset localCorner, required Offset targetPoint}) {
  final cosA = math.cos(angle);
  final sinA = math.sin(angle);
  final rotatedCorner = Offset(
    localCorner.dx * cosA - localCorner.dy * sinA,
    localCorner.dx * sinA + localCorner.dy * cosA,
  );
  return targetPoint - rotatedCorner;
}

/// Scene 3 ("FIRST PoW") of the open-store intro story: three tilted photo cards, the typed
/// intro copy, and the add/remove-theme button. Tapping the center photo opens a full-screen
/// detail view (the other two photos will get their own detail views later).
class FirstPowSceneBody extends StatefulWidget {
  const FirstPowSceneBody({
    super.key,
    required this.animation,
    required this.sceneDurationMs,
    required this.listing,
    required this.isAdded,
    required this.isApplied,
    required this.isCurrentScene,
    required this.onAdd,
    required this.onRemove,
  });

  final Animation<double> animation;
  final int sceneDurationMs;
  final CcosFeatureListing listing;
  final bool isAdded;
  final bool isApplied;
  // True only while this scene is the one visible - gates the center-card wiggle loop so it
  // doesn't keep animating while the user is looking at a different scene.
  final bool isCurrentScene;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  static const int baseDurationMs = 11000;
  static const int buttonPauseMs = 500;
  static const int buttonEntranceMs = 500;
  static const int _text1TypingStartMs = 2080;
  static const int _text1PauseMs = 650;

  static List<int> typingStartMs(List<String> lines) {
    final text2Start = _text1TypingStartMs + typewriterDurationMs(lines[0]) + _text1PauseMs;
    return [_text1TypingStartMs, text2Start];
  }

  static int ctaStartMs(List<String> lines) {
    final starts = typingStartMs(lines);
    return starts.last + typewriterDurationMs(lines.last) + buttonPauseMs;
  }

  static int navigationRevealStartMs(List<String> lines) {
    return ctaStartMs(lines) + (buttonEntranceMs ~/ 2);
  }

  @override
  State<FirstPowSceneBody> createState() => _FirstPowSceneBodyState();
}

class _FirstPowSceneBodyState extends State<FirstPowSceneBody> with TickerProviderStateMixin {
  static const Interval _cardsInterval = Interval(0.0, 0.0818, curve: Curves.easeOutCubic);
  static const int _buttonEntranceMs = FirstPowSceneBody.buttonEntranceMs;

  bool _hasInteractedWithCards = false;

  late final AnimationController _addedBadgeController = AnimationController(
    vsync: this,
    value: widget.isAdded ? 1 : 0,
  );

  static const int _wiggleBurstMs = 500;
  static const int _wigglePauseMs = 1500;
  static const int _wiggleLoopMs = _wiggleBurstMs + _wigglePauseMs;
  late final AnimationController _wiggleController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: _wiggleLoopMs),
  );

  @override
  void initState() {
    super.initState();
    if (widget.isCurrentScene) {
      _wiggleController.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant FirstPowSceneBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isCurrentScene != oldWidget.isCurrentScene) {
      if (widget.isCurrentScene && !_hasInteractedWithCards) {
        _wiggleController.repeat();
      } else {
        _wiggleController.stop();
      }
    }
    if (widget.isAdded == oldWidget.isAdded && widget.isApplied == oldWidget.isApplied) return;
    if (widget.isAdded) {
      _addedBadgeController.animateWith(
        SpringSimulation(const SpringDescription(mass: 1, stiffness: 280, damping: 14), 0, 1, 0),
      );
    } else {
      _addedBadgeController.value = 0;
    }
  }

  @override
  void dispose() {
    _addedBadgeController.dispose();
    _wiggleController.dispose();
    super.dispose();
  }

  static double _wiggleEnvelope(double loopT) {
    const burstFraction = _wiggleBurstMs / _wiggleLoopMs;
    if (loopT >= burstFraction) return 0.0;
    final burstLocal = loopT / burstFraction;
    return math.sin(((burstLocal * 2) % 1.0) * math.pi);
  }

  void _openDetail(BuildContext context, _FirstPowCardKind kind) {
    if (!_hasInteractedWithCards) {
      _hasInteractedWithCards = true;
      _wiggleController.stop();
    }
    final detail = _firstPowCardDetailForKind(kind);
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 320),
        reverseTransitionDuration: const Duration(milliseconds: 260),
        pageBuilder:
            (context, animation, secondaryAnimation) =>
                _FirstPowDetailScreen(detail: detail, onAdd: widget.onAdd, onRemove: widget.onRemove),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut), child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text1 = t.ccos.first_pow_scene.intro_line1;
    final text2 = t.ccos.first_pow_scene.intro_line2;
    final introHighlights = {
      t.ccos.first_pow_scene.intro_highlight_theme,
      t.ccos.first_pow_scene.intro_highlight_first_pow,
    };

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final idealCardWidth = width / 3 * 1.4;
        final idealCardHeight = idealCardWidth * 1.42;
        final arcLift = idealCardHeight * 0.07;
        final availableImageHeight = constraints.maxHeight * 0.5;
        final neededImageHeight = idealCardHeight + arcLift;
        final imageScale = neededImageHeight > availableImageHeight ? availableImageHeight / neededImageHeight : 1.0;
        final cardWidth = idealCardWidth * imageScale;
        final cardHeight = idealCardHeight * imageScale;
        const leftAngle = 10 * math.pi / 180;
        const rightAngle = -10 * math.pi / 180;
        final halfW = cardWidth / 2;
        final halfH = cardHeight / 2;
        final leftCardOffset = _cornerAlignedOffset(
          angle: leftAngle,
          localCorner: Offset(halfW, -halfH),
          targetPoint: Offset(-halfW, -halfH),
        );
        final rightCardOffset = _cornerAlignedOffset(
          angle: rightAngle,
          localCorner: Offset(-halfW, -halfH),
          targetPoint: Offset(halfW, -halfH),
        );
        final topExtra = cardHeight * 0.08 + 24;

        final bodyStyle = CoconutTypography.heading4_18_Bold.setColor(Colors.white).copyWith(height: 1.3);
        final highlightStyle = bodyStyle.copyWith(
          fontSize: (bodyStyle.fontSize ?? 18) * 1.4,
          fontWeight: FontWeight.w900,
          height: bodyStyle.height,
        );
        final strutStyle = StrutStyle(
          fontSize: highlightStyle.fontSize,
          height: bodyStyle.height,
          forceStrutHeight: true,
        );
        final text2Style = bodyStyle.copyWith(height: 1.16);
        final text2HighlightStyle = highlightStyle.copyWith(height: text2Style.height);
        final text2StrutStyle = StrutStyle(
          fontSize: text2HighlightStyle.fontSize,
          height: text2Style.height,
          forceStrutHeight: true,
        );

        return AnimatedBuilder(
          animation: Listenable.merge([widget.animation, _wiggleController]),
          builder: (context, child) {
            final value = widget.animation.value;
            final cardsProgress = _cardsInterval.transform(value);
            final wiggleEnvelope = _hasInteractedWithCards ? 0.0 : _wiggleEnvelope(_wiggleController.value);
            final wiggleRotation = wiggleEnvelope * 0.04;

            return Stack(
              clipBehavior: Clip.none,
              children: [
                SizedBox(
                  width: width,
                  height: cardHeight + topExtra,
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      Transform.translate(
                        offset: leftCardOffset,
                        child: _PolaroidCard(
                          imagePath: _creatorImagePath,
                          width: cardWidth,
                          height: cardHeight,
                          finalAngle: leftAngle,
                          entranceOffset: Offset(-cardWidth * 0.7, -24),
                          progress: cardsProgress,
                          heroTag: _creatorHeroTag,
                          onTap: () => _openDetail(context, _FirstPowCardKind.creator),
                        ),
                      ),
                      Transform.translate(
                        offset: rightCardOffset,
                        child: _PolaroidCard(
                          imagePath: _deliveryImagePath,
                          width: cardWidth,
                          height: cardHeight,
                          finalAngle: rightAngle,
                          entranceOffset: Offset(cardWidth * 0.7, -24),
                          progress: cardsProgress,
                          heroTag: _deliveryHeroTag,
                          onTap: () => _openDetail(context, _FirstPowCardKind.delivery),
                        ),
                      ),
                      _PolaroidCard(
                        imagePath: _featureImagePath,
                        width: cardWidth,
                        height: cardHeight,
                        finalAngle: 0,
                        entranceOffset: const Offset(0, -260),
                        progress: cardsProgress,
                        heroTag: _featureHeroTag,
                        onTap: () => _openDetail(context, _FirstPowCardKind.feature),
                        extraRotation: wiggleRotation,
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(top: cardHeight + topExtra + 44),
                  child: Builder(
                    builder: (context) {
                      final starts = FirstPowSceneBody.typingStartMs([text1, text2]);
                      final titleEntranceInterval = intervalFromMs(
                        starts[0] - 180,
                        starts[0],
                        widget.sceneDurationMs,
                        curve: Curves.easeOutCubic,
                      );
                      final entranceT = titleEntranceInterval.transform(value);
                      final dy = 20 * (1 - entranceT);

                      return Opacity(
                        opacity: entranceT,
                        child: Transform.translate(
                          offset: Offset(0, dy),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              RichText(
                                textAlign: TextAlign.left,
                                strutStyle: strutStyle,
                                text: typewriterSpan(
                                  source: text1,
                                  animation: widget.animation,
                                  interval: typewriterIntervalFromMs(text1, starts[0], widget.sceneDurationMs),
                                  baseStyle: bodyStyle,
                                  highlightStyle: highlightStyle,
                                  highlightPhrases: introHighlights,
                                ),
                              ),
                              const SizedBox(height: 22),
                              RichText(
                                textAlign: TextAlign.left,
                                strutStyle: text2StrutStyle,
                                text: typewriterSpan(
                                  source: text2,
                                  animation: widget.animation,
                                  interval: typewriterIntervalFromMs(text2, starts[1], widget.sceneDurationMs),
                                  baseStyle: text2Style,
                                  highlightStyle: text2HighlightStyle,
                                  highlightPhrases: const {},
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Builder(
                    builder: (context) {
                      final ctaStart = FirstPowSceneBody.ctaStartMs([text1, text2]);
                      final buttonEntranceInterval = intervalFromMs(
                        ctaStart,
                        ctaStart + _buttonEntranceMs,
                        widget.sceneDurationMs,
                        curve: Curves.linear,
                      );
                      final buttonT = Curves.elasticOut.transform(buttonEntranceInterval.transform(value));
                      final buttonOpacity = buttonEntranceInterval.transform(value).clamp(0.0, 1.0);
                      return Opacity(
                        opacity: buttonOpacity,
                        child: Transform.scale(
                          scale: buttonT.clamp(0.0, 1.4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AnimatedBuilder(
                                animation: _addedBadgeController,
                                builder: (context, child) {
                                  final progress = _addedBadgeController.value;
                                  if (progress <= 0.001) return const SizedBox.shrink();
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: Transform.scale(scale: progress, child: child),
                                  );
                                },
                                child: _AddedGlassBadge(
                                  label:
                                      widget.isApplied
                                          ? t.ccos.first_pow_scene.status_applied
                                          : t.ccos.first_pow_scene.status_added,
                                ),
                              ),
                              _AddThemeButton(isAdded: widget.isAdded, onAdd: widget.onAdd, onRemove: widget.onRemove),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _PolaroidCard extends StatelessWidget {
  const _PolaroidCard({
    required this.imagePath,
    required this.width,
    required this.height,
    required this.finalAngle,
    required this.entranceOffset,
    required this.progress,
    this.heroTag,
    this.onTap,
    this.extraRotation = 0,
  });

  final String imagePath;
  final double width;
  final double height;
  final double finalAngle;
  final Offset entranceOffset;
  final double progress;
  final Object? heroTag;
  final VoidCallback? onTap;
  final double extraRotation;

  @override
  Widget build(BuildContext context) {
    final offset = Offset.lerp(entranceOffset, Offset.zero, progress) ?? Offset.zero;
    final angle = finalAngle * progress;

    Widget image = Image.asset(imagePath, fit: BoxFit.cover, width: double.infinity);
    if (heroTag != null) {
      image = Hero(tag: heroTag!, child: image);
    }

    final card = Container(
      width: width,
      height: height,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 26),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      child: ClipRRect(borderRadius: BorderRadius.circular(2), child: image),
    );

    return Opacity(
      opacity: progress.clamp(0.0, 1.0),
      child: Transform.translate(
        offset: offset,
        child: Transform.rotate(
          angle: angle + extraRotation,
          child: onTap == null ? card : GestureDetector(onTap: onTap, child: card),
        ),
      ),
    );
  }
}

class _AddThemeButton extends StatefulWidget {
  const _AddThemeButton({required this.isAdded, required this.onAdd, required this.onRemove});

  final bool isAdded;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  @override
  State<_AddThemeButton> createState() => _AddThemeButtonState();
}

class _AddThemeButtonState extends State<_AddThemeButton> with SingleTickerProviderStateMixin {
  late final AnimationController _squashController = AnimationController(vsync: this, value: 1.0);

  void _handleTapDown([TapDownDetails? _]) {
    _squashController.stop();
    _squashController.animateTo(0.9, duration: const Duration(milliseconds: 100), curve: Curves.easeOut);
  }

  void _handleTapRelease([TapUpDetails? _]) {
    _squashController.animateWith(
      SpringSimulation(const SpringDescription(mass: 1, stiffness: 380, damping: 16), _squashController.value, 1.0, 0),
    );
  }

  @override
  void dispose() {
    _squashController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _squashController,
      builder: (context, child) {
        final squash = _squashController.value;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()..scale(1 + ((1 - squash) * 0.6), squash),
          child: child,
        );
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: widget.isAdded ? widget.onRemove : widget.onAdd,
          onTapDown: _handleTapDown,
          onTapUp: _handleTapRelease,
          onTapCancel: _handleTapRelease,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(color: _textPrimary, borderRadius: BorderRadius.circular(999)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Text(
                    widget.isAdded ? t.ccos.first_pow_scene.remove_button : t.ccos.first_pow_scene.add_button,
                    key: ValueKey(widget.isAdded),
                    style:
                        widget.isAdded
                            ? CoconutTypography.body3_12.setColor(_screenBackground)
                            : CoconutTypography.body3_12_Bold.setColor(_screenBackground),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(widget.isAdded ? Icons.remove_rounded : Icons.add_rounded, size: 18, color: _screenBackground),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AddedGlassBadge extends StatelessWidget {
  const _AddedGlassBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xB3FFFFFF), width: 1.2),
      ),
      child: LiquidGlassSurface(
        cornerRadius: 999,
        blurSigma: 12,
        distortion: 0.25,
        distortionWidth: 14,
        magnification: 1.08,
        tintColor: const Color(0x38FFFFFF),
        rimColor: Colors.white.withValues(alpha: 0.16),
        rimWidth: 5,
        rimOnTopBottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: Text(label, key: ValueKey(label), style: CoconutTypography.body3_12.setColor(_textPrimary)),
          ),
        ),
      ),
    );
  }
}

class _FirstPowDetailScreen extends StatefulWidget {
  const _FirstPowDetailScreen({required this.detail, required this.onAdd, required this.onRemove});

  final _FirstPowCardDetail detail;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  @override
  State<_FirstPowDetailScreen> createState() => _FirstPowDetailScreenState();
}

class _FirstPowDetailScreenState extends State<_FirstPowDetailScreen> with TickerProviderStateMixin {
  static const Duration _heroFlightDuration = Duration(milliseconds: 320);
  static const Duration _postFlightPause = Duration(milliseconds: 300);
  static const double _deliveryCardGap = 44;
  static const double _deliveryScrollEdgeFade = 34;

  static const int _defaultEntranceMs = 4150;
  static const int _creatorEntranceMs = 4700;
  static const int _deliveryEntranceMs = 5200;

  static Interval _buildInterval(int startMs, int endMs, int totalMs, {Curve curve = Curves.easeOutCubic}) {
    return Interval(startMs / totalMs, endMs / totalMs, curve: curve);
  }

  late _FirstPowCardDetail _detail = widget.detail;
  late final PageController _pageController = PageController(
    initialPage: _firstPowDetailOrder.indexOf(widget.detail.kind),
  );
  bool _hasPrecachedDetailImages = false;

  int get _totalEntranceMs => switch (_detail.kind) {
    _FirstPowCardKind.creator => _creatorEntranceMs,
    _FirstPowCardKind.delivery => _deliveryEntranceMs,
    _FirstPowCardKind.feature => _defaultEntranceMs,
  };

  Interval get _glassInterval => _buildInterval(0, 250, _totalEntranceMs, curve: Curves.easeOut);
  Interval get _backButtonInterval => _buildInterval(250, 700, _totalEntranceMs, curve: Curves.elasticOut);
  Interval get _labelSlideInterval => _buildInterval(700, 1400, _totalEntranceMs);
  Interval get _bodyGroup0Interval =>
      _detail.kind == _FirstPowCardKind.delivery
          ? _buildInterval(1550, 1980, _totalEntranceMs)
          : _buildInterval(1400, 1750, _totalEntranceMs);
  Interval get _stage2Interval => switch (_detail.kind) {
    _FirstPowCardKind.creator => _buildInterval(2450, 2780, _totalEntranceMs),
    _FirstPowCardKind.delivery => _buildInterval(2680, 3120, _totalEntranceMs),
    _FirstPowCardKind.feature => _buildInterval(2250, 2550, _totalEntranceMs),
  };
  Interval get _stage3Interval => switch (_detail.kind) {
    _FirstPowCardKind.creator => _buildInterval(3230, 3600, _totalEntranceMs),
    _FirstPowCardKind.delivery => _buildInterval(3820, 4280, _totalEntranceMs),
    _FirstPowCardKind.feature => _buildInterval(2950, 3300, _totalEntranceMs),
  };
  Interval get _stage4Interval => switch (_detail.kind) {
    _FirstPowCardKind.creator => _buildInterval(4020, _totalEntranceMs, _totalEntranceMs),
    _FirstPowCardKind.delivery => _buildInterval(4700, _totalEntranceMs, _totalEntranceMs),
    _FirstPowCardKind.feature => _buildInterval(3700, _totalEntranceMs, _totalEntranceMs),
  };

  late final AnimationController _entranceController = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: _totalEntranceMs),
  );

  static const Duration _addButtonDelay = Duration(seconds: 1);
  late final AnimationController _addButtonController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  );

  static const double _visibleLastCharFraction = 0.5;

  // Measured against the label's actual rendered glyph width so the crop stays correct
  // regardless of which panelLabel string or font ends up here.
  double get _labelCropWidth => _computeLabelCropWidth(_detail.panelLabel);

  static TextStyle _panelLabelStyle() {
    return CoconutTypography.heading1_32_Bold
        .setColor(Colors.white.withValues(alpha: 0.55))
        .copyWith(fontSize: 56, fontWeight: FontWeight.w900, letterSpacing: -2.8);
  }

  static double _measureTextWidth(String text) {
    final painter = TextPainter(text: TextSpan(text: text, style: _panelLabelStyle()), textDirection: TextDirection.ltr)
      ..layout();
    return painter.width;
  }

  static double _computeLabelCropWidth(String label) {
    final chars = label.characters;
    final lastCharWidth = _measureTextWidth(label) - _measureTextWidth(chars.take(chars.length - 1).toString());
    return lastCharWidth * (1 - _visibleLastCharFraction);
  }

  @override
  void initState() {
    super.initState();
    Future.delayed(_heroFlightDuration + _postFlightPause, () {
      if (!mounted) return;
      _entranceController.forward();
    });
    _entranceController.addStatusListener(_handleEntranceStatusForButton);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_hasPrecachedDetailImages) return;
    _hasPrecachedDetailImages = true;

    for (final path in [
      for (final kind in _firstPowDetailOrder) _firstPowCardDetailForKind(kind).imagePath,
      _previewTxCardImagePath,
      _previewWalletIconImagePath,
      _previewDownArrowImagePath,
      _previewUpArrowImagePath,
      _previewAddressBarImagePath,
    ]) {
      precacheImage(AssetImage(path), context);
    }
  }

  void _handleEntranceStatusForButton(AnimationStatus status) {
    if (status != AnimationStatus.completed || _detail.kind != _FirstPowCardKind.feature) return;
    Future.delayed(_addButtonDelay, () {
      if (!mounted || _detail.kind != _FirstPowCardKind.feature) return;
      _addButtonController.forward();
    });
  }

  void _handleDetailPageChanged(int index) {
    setState(() {
      _detail = _firstPowCardDetailForKind(_firstPowDetailOrder[index]);
    });
    _entranceController.duration = Duration(milliseconds: _totalEntranceMs);
    _entranceController.forward(from: 0);
    _addButtonController.reset();
  }

  @override
  void dispose() {
    _entranceController.removeStatusListener(_handleEntranceStatusForButton);
    _pageController.dispose();
    _entranceController.dispose();
    _addButtonController.dispose();
    super.dispose();
  }

  Widget _buildFeatureCta({required bool isAdded, required bool isApplied}) {
    return AnimatedBuilder(
      animation: _addButtonController,
      builder: (context, child) {
        final buttonT = Curves.elasticOut.transform(_addButtonController.value);
        final buttonOpacity = _addButtonController.value.clamp(0.0, 1.0);
        return Opacity(
          opacity: buttonOpacity,
          child: Transform.scale(scale: buttonT.clamp(0.0, 1.4), alignment: Alignment.centerRight, child: child),
        );
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isAdded)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _AddedGlassBadge(
                label: isApplied ? t.ccos.first_pow_scene.status_applied : t.ccos.first_pow_scene.status_added,
              ),
            ),
          _AddThemeButton(isAdded: isAdded, onAdd: widget.onAdd, onRemove: widget.onRemove),
        ],
      ),
    );
  }

  Widget _buildFeaturePreview(double progress) {
    return Flexible(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;
          final previewWidth = math.min(width, height * 1.04);

          return Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: previewWidth,
              height: previewWidth / 1.04,
              child: _FadeSlideIn(progress: progress, child: const _ThemePreviewCluster()),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDeliveryContent({required double group0T, required double stage2T, required double stage3T}) {
    return Expanded(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (bounds) {
              final fadeStop = (_deliveryScrollEdgeFade / bounds.height).clamp(0.0, 0.22);
              return LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: const [Color(0x00FFFFFF), Color(0xFFFFFFFF), Color(0xFFFFFFFF), Color(0x00FFFFFF)],
                stops: [0, fadeStop, 1 - fadeStop, 1],
              ).createShader(bounds);
            },
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Padding(
                  padding: const EdgeInsets.only(top: 58, bottom: 42),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _DeliveryStepCard(
                        progress: group0T,
                        iconPath: _deliveryProposeIconPath,
                        title: _deliveryProposeTitle,
                        body: _deliveryProposeBody,
                      ),
                      const SizedBox(height: _deliveryCardGap),
                      _DeliveryStepCard(
                        progress: stage2T,
                        iconPath: _deliveryReviewIconPath,
                        title: _deliveryReviewTitle,
                        body: _deliveryReviewBody,
                      ),
                      const SizedBox(height: _deliveryCardGap),
                      _DeliveryStepCard(
                        progress: stage3T,
                        iconPath: _deliveryIntroIconPath,
                        title: _deliveryIntroTitle,
                        body: _deliveryIntroBody,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final listing = CcosFeatureRegistrySource.featuredListing;
    final detail = _detail;
    final localizedFeatureTitle = listing.title;
    final localizedFeatureTags = [
      ...listing.tags,
      if (listing.priceType == CcosListingPriceType.free) t.ccos.first_pow_scene.feature_detail.tag_free,
    ];
    final localizedFeatureDescription = t.ccos.first_pow_scene.feature_detail.description;
    final localizedCreatorAuthor = listing.author;
    final localizedCreatorAuthorDescription = listing.authorBio;
    final topInset = MediaQuery.of(context).padding.top;
    final bottomInset = MediaQuery.of(context).padding.bottom + 12;

    // context.watch keeps the button/badge below reflecting live add/remove/apply taps made
    // from this screen or elsewhere, since this route was pushed on top of its parent.
    final preferenceProvider = context.watch<PreferenceProvider>();
    final availability = preferenceProvider.getCcosFeatureAvailability(listing.id);
    final isAdded = availability.isActivated;
    final isApplied =
        isAdded && listing.linkedVariant != null && preferenceProvider.themeVariant == listing.linkedVariant;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Hero(
            tag: widget.detail.heroTag,
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: _handleDetailPageChanged,
              itemCount: _firstPowDetailOrder.length,
              itemBuilder: (context, index) {
                final pageDetail = _firstPowCardDetailForKind(_firstPowDetailOrder[index]);
                return Image(image: AssetImage(pageDetail.imagePath), fit: BoxFit.cover);
              },
            ),
          ),
          AnimatedBuilder(
            animation: _entranceController,
            builder: (context, child) {
              final progress = _entranceController.value;
              final glassT = _glassInterval.transform(progress);
              final backButtonT = _backButtonInterval.transform(progress);
              final labelSlideT = _labelSlideInterval.transform(progress);
              final labelDx = -260 * (1 - labelSlideT);
              final group0T = _bodyGroup0Interval.transform(progress);
              final stage2T = _stage2Interval.transform(progress);
              final stage3T = _stage3Interval.transform(progress);
              final stage4T = _stage4Interval.transform(progress);

              return Opacity(
                opacity: glassT,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(14, topInset + 14, 14, 78 + bottomInset),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(32),
                      border: const Border(
                        left: BorderSide(color: Color(0x99FFFFFF), width: 1.2),
                        right: BorderSide(color: Color(0x99FFFFFF), width: 1.2),
                      ),
                    ),
                    child: LiquidGlassSurface(
                      cornerRadius: 32,
                      blurSigma: 2,
                      distortion: 0.16,
                      distortionWidth: 36,
                      magnification: 1.06,
                      tintColor: const Color(0x03FFFFFF),
                      rimColor: Colors.white.withValues(alpha: 0.12),
                      rimWidth: 2,
                      rimOnTopBottom: true,
                      child: SafeArea(
                        top: false,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 16, 0, 0),
                              child: Transform.scale(
                                scale: backButtonT,
                                child: Material(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  shape: const CircleBorder(),
                                  child: InkWell(
                                    customBorder: const CircleBorder(),
                                    onTap: () => Navigator.of(context).maybePop(),
                                    child: const Padding(
                                      padding: EdgeInsets.all(12),
                                      child: Icon(Icons.arrow_back_rounded, color: Colors.white, size: 24),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              top: 4,
                              right: -_labelCropWidth + labelDx,
                              child: IgnorePointer(
                                child: Opacity(
                                  opacity: labelSlideT * 0.8,
                                  child: Text(detail.panelLabel, style: _panelLabelStyle()),
                                ),
                              ),
                            ),
                            Positioned(
                              left: 20,
                              right: 20,
                              top: 108,
                              bottom: detail.kind == _FirstPowCardKind.feature ? 96 : 20,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (detail.kind == _FirstPowCardKind.feature) ...[
                                    _FadeSlideIn(
                                      progress: group0T,
                                      child: Text(
                                        localizedFeatureTitle,
                                        style: CoconutTypography.heading3_21_Bold.setColor(_textPrimary),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    _FadeSlideIn(
                                      progress: stage2T,
                                      child: Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [for (final tag in localizedFeatureTags) _GlassChip(label: tag)],
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    _FadeSlideIn(
                                      progress: stage3T,
                                      child: Text(
                                        localizedFeatureDescription,
                                        style: CoconutTypography.body2_14.setColor(_textPrimary),
                                      ),
                                    ),
                                    const SizedBox(height: 28),
                                    _buildFeaturePreview(stage4T),
                                  ] else if (detail.kind == _FirstPowCardKind.creator) ...[
                                    _FadeSlideIn(
                                      progress: group0T,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            localizedCreatorAuthor,
                                            style: CoconutTypography.heading3_21_Bold
                                                .setColor(_textPrimary)
                                                .copyWith(fontSize: 24),
                                          ),
                                          Text(
                                            localizedCreatorAuthorDescription,
                                            style: CoconutTypography.body3_12.setColor(_textPrimary),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    _DropletFadeIn(
                                      progress: stage2T,
                                      child: _GlassChip(label: t.ccos.first_pow_scene.creator_detail.story_label),
                                    ),
                                    const SizedBox(height: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: _FadeSlideIn(progress: stage3T, child: const _CreatorStoryBox()),
                                          ),
                                          const SizedBox(height: 12),
                                          _FadeSlideIn(
                                            progress: stage4T,
                                            child: _CreatorBeliefStatementBox(text: _creatorBeliefStatement),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ] else ...[
                                    _buildDeliveryContent(group0T: group0T, stage2T: stage2T, stage3T: stage3T),
                                  ],
                                ],
                              ),
                            ),
                            if (detail.kind == _FirstPowCardKind.feature)
                              Positioned(
                                right: 20,
                                bottom: 20,
                                child: _buildFeatureCta(isAdded: isAdded, isApplied: isApplied),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 16 + bottomInset,
            child: Center(
              child: _FirstPowDetailSegmentedIndicator(
                currentKind: detail.kind,
                onSelect: (kind) {
                  _pageController.animateToPage(
                    _firstPowDetailOrder.indexOf(kind),
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutCubic,
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FirstPowDetailSegmentedIndicator extends StatelessWidget {
  const _FirstPowDetailSegmentedIndicator({required this.currentKind, required this.onSelect});

  final _FirstPowCardKind currentKind;
  final ValueChanged<_FirstPowCardKind> onSelect;

  String _labelFor(_FirstPowCardKind kind) {
    return _firstPowCardDetailForKind(kind).panelLabel;
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.34), width: 1),
      ),
      child: LiquidGlassSurface(
        cornerRadius: 999,
        blurSigma: 14,
        distortion: 0.18,
        distortionWidth: 18,
        magnification: 1.04,
        tintColor: const Color(0x2BFFFFFF),
        rimColor: Colors.white.withValues(alpha: 0.12),
        rimWidth: 3,
        rimOnTopBottom: false,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final kind in _firstPowDetailOrder)
                _FirstPowDetailSegment(
                  label: _labelFor(kind),
                  selected: kind == currentKind,
                  onTap: () => onSelect(kind),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FirstPowDetailSegment extends StatelessWidget {
  const _FirstPowDetailSegment({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? Colors.white.withValues(alpha: 0.82) : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: CoconutTypography.caption_10_Bold.setColor(
              selected ? _textPrimary : Colors.white.withValues(alpha: 0.78),
            ),
          ),
        ),
      ),
    );
  }
}

class _FadeSlideIn extends StatelessWidget {
  const _FadeSlideIn({required this.progress, required this.child});

  final double progress;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = progress.clamp(0.0, 1.0);
    return Opacity(opacity: t, child: Transform.translate(offset: Offset(0, 12 * (1 - t)), child: child));
  }
}

class _GlassChip extends StatelessWidget {
  const _GlassChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x99FFFFFF)),
      ),
      child: LiquidGlassSurface(
        cornerRadius: 999,
        blurSigma: 8,
        distortion: 0.3,
        distortionWidth: 10,
        magnification: 1.06,
        tintColor: const Color(0x4DFFFFFF),
        rimColor: Colors.white.withValues(alpha: 0.16),
        rimWidth: 3,
        rimOnTopBottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Text(label, style: CoconutTypography.caption_10_Bold.setColor(CoconutColors.gray700)),
        ),
      ),
    );
  }
}

class _DropletFadeIn extends StatelessWidget {
  const _DropletFadeIn({required this.progress, required this.child});

  final double progress;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = progress.clamp(0.0, 1.0);
    final bounceT = Curves.bounceOut.transform(t);
    final dy = -22 * (1 - bounceT);
    final scale = 0.88 + (0.12 * Curves.easeOut.transform(t));
    return Opacity(
      opacity: Curves.easeOut.transform(t),
      child: Transform.translate(offset: Offset(0, dy), child: Transform.scale(scale: scale, child: child)),
    );
  }
}

class _CreatorStoryBox extends StatelessWidget {
  const _CreatorStoryBox();

  static const double _edgeFadeHeight = 28;

  @override
  Widget build(BuildContext context) {
    final quoteStyle = CoconutTypography.body3_12_Bold.setColor(_textPrimary.withValues(alpha: 0.92));
    final bodyStyle = CoconutTypography.body3_12
        .setColor(_textPrimary.withValues(alpha: 0.8))
        .copyWith(letterSpacing: -0.7, fontWeight: FontWeight.w400);

    return DecoratedBox(
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(16)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_creatorFeedbackQuote, style: quoteStyle),
                  const SizedBox(height: 12),
                  Text(_creatorFeedbackAttribution, style: quoteStyle),
                  const SizedBox(height: 22),
                  Text(_creatorStoryParagraph1, style: bodyStyle),
                  const SizedBox(height: 16),
                  Text(_creatorStoryParagraph2, style: bodyStyle),
                  const SizedBox(height: 16),
                  Text(_creatorStoryParagraph3, style: bodyStyle),
                ],
              ),
            ),
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: _StoryEdgeFade(height: _edgeFadeHeight, begin: Color(0xCCFFFFFF), end: Color(0x00FFFFFF)),
              ),
            ),
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: IgnorePointer(
                child: _StoryEdgeFade(height: _edgeFadeHeight, begin: Color(0x00FFFFFF), end: Color(0xCCFFFFFF)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoryEdgeFade extends StatelessWidget {
  const _StoryEdgeFade({required this.height, required this.begin, required this.end});

  final double height;
  final Color begin;
  final Color end;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [begin, end]),
        ),
      ),
    );
  }
}

class _CreatorBeliefStatementBox extends StatefulWidget {
  const _CreatorBeliefStatementBox({required this.text});

  final String text;

  @override
  State<_CreatorBeliefStatementBox> createState() => _CreatorBeliefStatementBoxState();
}

class _CreatorBeliefStatementBoxState extends State<_CreatorBeliefStatementBox> with SingleTickerProviderStateMixin {
  static final RegExp _hangulPattern = RegExp(r'[\u3131-\u318E\uAC00-\uD7A3]');

  late final AnimationController _glowController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat(reverse: true);

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
                child: Text(text, style: style),
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

class _DeliveryStepCard extends StatelessWidget {
  const _DeliveryStepCard({required this.progress, required this.iconPath, required this.title, required this.body});

  final double progress;
  final String iconPath;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final t = progress.clamp(0.0, 1.0);
    final boxT = Curves.easeOutCubic.transform(t);
    final iconT = Curves.elasticOut.transform(((t - 0.35) / 0.65).clamp(0.0, 1.0));

    return Opacity(
      opacity: boxT,
      child: Transform.translate(
        offset: Offset(0, 16 * (1 - boxT)),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(title, style: CoconutTypography.heading3_21_Bold.setColor(Colors.white)),
                    ),
                    const SizedBox(height: 2),
                    Text(body, style: CoconutTypography.body3_12.setColor(_textPrimary)),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 4,
              top: -30,
              child: Transform.scale(scale: iconT.clamp(0.0, 1.4), child: _DeliveryIconBadge(iconPath: iconPath)),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeliveryIconBadge extends StatelessWidget {
  const _DeliveryIconBadge({required this.iconPath});

  final String iconPath;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.26), width: 1),
      ),
      child: LiquidGlassSurface(
        cornerRadius: 999,
        blurSigma: 10,
        distortion: 0.25,
        distortionWidth: 14,
        magnification: 1.08,
        tintColor: Colors.transparent,
        rimColor: Colors.white.withValues(alpha: 0.1),
        rimWidth: 4,
        rimOnTopBottom: false,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: SizedBox.square(
            dimension: 22,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: 0.8,
                  top: 1.2,
                  child: SvgPicture.asset(
                    iconPath,
                    width: 22,
                    height: 22,
                    colorFilter: ColorFilter.mode(Colors.black.withValues(alpha: 0.26), BlendMode.srcIn),
                  ),
                ),
                SvgPicture.asset(
                  iconPath,
                  width: 22,
                  height: 22,
                  colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ThemePreviewCluster extends StatefulWidget {
  const _ThemePreviewCluster();

  @override
  State<_ThemePreviewCluster> createState() => _ThemePreviewClusterState();
}

class _ThemePreviewClusterState extends State<_ThemePreviewCluster> with TickerProviderStateMixin {
  bool _hasSettled = false;

  late final AnimationController _entranceController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..forward();

  late final AnimationController _floatController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 7000),
  )..repeat();

  static const List<_FloatingImageSpec> _images = [
    _FloatingImageSpec(
      path: _previewTxCardImagePath,
      alignment: Alignment(0.0, 0.1),
      width: 250,
      baseAngle: -0.035,
      phase: 0.21,
    ),
    _FloatingImageSpec(
      path: _previewAddressBarImagePath,
      alignment: Alignment(-0.22, 0.7),
      width: 254,
      baseAngle: 0.02,
      phase: 0.63,
    ),
    _FloatingImageSpec(
      path: _previewUpArrowImagePath,
      alignment: Alignment(0.84, 0.76),
      width: 78,
      baseAngle: -0.06,
      phase: 0.84,
    ),
    _FloatingImageSpec(
      path: _previewWalletIconImagePath,
      alignment: Alignment(0.64, -0.64),
      width: 88,
      baseAngle: 0.08,
      phase: 0.42,
    ),
    _FloatingImageSpec(
      path: _previewDownArrowImagePath,
      alignment: Alignment(-0.8, -0.56),
      width: 81,
      baseAngle: -0.09,
      phase: 0.0,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _entranceController.addStatusListener(_handleEntranceStatus);
  }

  void _handleEntranceStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || _hasSettled || !mounted) {
      return;
    }

    setState(() {
      _hasSettled = true;
    });
  }

  @override
  void dispose() {
    _entranceController.removeStatusListener(_handleEntranceStatus);
    _entranceController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: AspectRatio(
        aspectRatio: 1.04,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(24),
          ),
          child: AnimatedBuilder(
            animation: _hasSettled ? _floatController : Listenable.merge([_entranceController, _floatController]),
            builder: (context, child) {
              return Stack(
                children: [
                  for (var i = 0; i < _images.length; i++)
                    _buildFloatingImage(
                      _images[i],
                      i,
                      _hasSettled ? 1 : _entranceController.value,
                      _floatController.value,
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingImage(_FloatingImageSpec spec, int index, double entranceT, double floatT) {
    final bobWave = math.sin((floatT + spec.phase) * 2 * math.pi);
    final driftWave = math.sin((floatT + spec.phase) * 2 * math.pi * 2 + 1.3);
    const revealStart = 0.08;
    const revealStep = 0.12;
    const revealDuration = 0.16;
    final revealT =
        _hasSettled
            ? 1.0
            : Curves.easeOutCubic.transform(
              (((entranceT - (revealStart + (index * revealStep))) / revealDuration).clamp(0.0, 1.0)),
            );

    return Align(
      alignment: spec.alignment,
      child: Opacity(
        opacity: revealT,
        child: Transform.translate(
          offset: Offset(driftWave * 4, bobWave * 9 + ((1 - revealT) * 12)),
          child: Transform.scale(
            scale: 0.92 + (0.08 * revealT),
            child: Transform.rotate(
              angle: spec.baseAngle + (bobWave * 0.05),
              child: Image.asset(spec.path, width: spec.width),
            ),
          ),
        ),
      ),
    );
  }
}

class _FloatingImageSpec {
  const _FloatingImageSpec({
    required this.path,
    required this.alignment,
    required this.width,
    required this.baseAngle,
    required this.phase,
  });

  final String path;
  final Alignment alignment;
  final double width;
  final double baseAngle;
  final double phase;
}
