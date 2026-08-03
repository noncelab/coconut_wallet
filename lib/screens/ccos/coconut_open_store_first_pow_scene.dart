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
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/screens/ccos/coconut_open_store_text_effects.dart';
import 'package:coconut_wallet/widgets/common/effects/liquid_glass_surface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

const _whatImagePath = 'assets/images/ccos/what.png';
const _whyImagePath = 'assets/images/ccos/why.png';
const _deliveryImagePath = 'assets/images/ccos/delivery.png';
const _whatHeroTag = 'ccos-first-pow-what-image';
const _whoWhyHeroTag = 'ccos-first-pow-who-why-image';
const _deliveryHeroTag = 'ccos-first-pow-delivery-image';

// The "FEATURE" detail screen's floating preview cluster: five small UI-element cutouts
// (transaction card, wallet icon, arrows, address chip) that drift organically over the
// theme's hero photo to preview what the theme looks like in the app.
const _previewTxCardImagePath = 'assets/images/ccos/preview_transaction_card.png';
const _previewWalletIconImagePath = 'assets/images/ccos/preview_wallet_icon.png';
const _previewDownArrowImagePath = 'assets/images/ccos/preview_arrow_down.png';
const _previewUpArrowImagePath = 'assets/images/ccos/preview_arrow_up.png';
const _previewAddressBarImagePath = 'assets/images/ccos/preview_address_bar.png';

const _textPrimary = Color(0xFF10161C);
const _screenBackground = Color(0xFFCDD4D7);

// CREATOR screen only: the "story box" (box 1) content - a real piece of user feedback that
// motivated the theme, followed by the reasoning behind it. Kept as separate strings (rather
// than one block with embedded blank lines) so paragraph spacing can be tuned independently of
// within-paragraph line spacing.
const _creatorFeedbackQuote = '"코코넛은 밝고 따뜻한 과일인데,\n지갑은 어두운 느낌이라 조금 아쉬워요."';
const _creatorFeedbackAttribution = '- 빗짱님 피드백';
const _creatorStoryParagraph1 = '두 앱이 하나처럼 동작하는 코코넛 월렛과 볼트를\n구분하기 위해 의도적으로 코코넛 월렛은\n어두운 테마만 제공해 왔어요.';
const _creatorStoryParagraph2 =
    '하지만 오픈 스토어를 구상하며\n첫 사례는 \'누구나 새로운 기능을 제안하고\n함께 만들어가는 경험\'을 가장 잘 보여줄 수 있는\n기능이어야 한다고 생각했습니다.';
const _creatorStoryParagraph3 =
    '그래서 코코넛 과육 테마는\n단순히 새로운 색상을 추가한 것이 아니라,\n앞으로 오픈 스토어에서 다양한 아이디어가 어떻게 소개되고 사용자에게 전달될 수 있는지를 보여주는 첫 번째 예시가 되었습니다.';
// CREATOR screen only: box 2, the creator's own belief statement about why intent matters.
const _creatorBeliefStatement = '새로운 기능은 코드만이 아니라, 그것을 만든 사람의 생각과 이유도 함께 전달되어야 한다고 믿습니다.';

// DELIVERY screen only: the three-step "propose -> review -> introduce" flow, each with its
// own icon badge, title, and body copy.
const _deliveryProposeIconPath = 'assets/svg/brand/motifs/bulb.svg';
const _deliveryReviewIconPath = 'assets/svg/brand/motifs/shield-check.svg';
const _deliveryIntroIconPath = 'assets/svg/brand/motifs/users.svg';
const _deliveryProposeTitle = '제안';
const _deliveryProposeBody = '누구나 제작 의도를 담아 기능을 제안할 수 있어요\n무료로 나눌 수도, 지속한 가능한 방식으로 전달할 수도 있어요\n전달 방식은 제작자가 결정해요';
const _deliveryReviewTitle = '검토';
const _deliveryReviewBody = '코코넛 팀과 정책과 품질을 함께 논의해요\n피드백을 주고 받으며 안전한 경계 안에서 기존 UI/UX와 어울어져 개발자의 PoW가 실현되어가요';
const _deliveryIntroTitle = '소개';
const _deliveryIntroBody = '최종 승인된 PoW가 앱에 포함되어\n사용자와 만나요';

enum _FirstPowCardKind { creator, feature, delivery }

class _FirstPowCardDetail {
  const _FirstPowCardDetail({
    required this.kind,
    required this.imagePath,
    required this.heroTag,
    required this.title,
    required this.panelLabel,
  });

  final _FirstPowCardKind kind;
  final String imagePath;
  final String heroTag;
  final String title;
  final String panelLabel;
}

const Map<_FirstPowCardKind, _FirstPowCardDetail> _firstPowCardDetails = {
  _FirstPowCardKind.creator: _FirstPowCardDetail(
    kind: _FirstPowCardKind.creator,
    imagePath: _whyImagePath,
    heroTag: _whoWhyHeroTag,
    title: 'WHO & WHY',
    panelLabel: 'CREATOR',
  ),
  _FirstPowCardKind.feature: _FirstPowCardDetail(
    kind: _FirstPowCardKind.feature,
    imagePath: _whatImagePath,
    heroTag: _whatHeroTag,
    title: 'WHAT',
    panelLabel: 'FEATURE',
  ),
  _FirstPowCardKind.delivery: _FirstPowCardDetail(
    kind: _FirstPowCardKind.delivery,
    imagePath: _deliveryImagePath,
    heroTag: _deliveryHeroTag,
    title: 'DELIVERY',
    panelLabel: 'DELIVERY',
  ),
};

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
    required this.listing,
    required this.isAdded,
    required this.isApplied,
    required this.isCurrentScene,
    required this.onAdd,
    required this.onRemove,
  });

  final Animation<double> animation;
  final CcosFeatureListing listing;
  final bool isAdded;
  // True when this listing's theme is not just unlocked but currently the active theme.
  final bool isApplied;
  // True only while this scene is the one actually visible in the story PageView. [animation]
  // is a single controller shared by all 5 scenes and gets restarted on every page change, so
  // without this the auto-open demo below could fire (and push a detail screen) while the user
  // is looking at a completely different scene.
  final bool isCurrentScene;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  @override
  State<FirstPowSceneBody> createState() => _FirstPowSceneBodyState();
}

class _FirstPowSceneBodyState extends State<FirstPowSceneBody> with TickerProviderStateMixin {
  // Three cards drop/rotate into place together.
  static const Interval _cardsInterval = Interval(0.0, 0.0818, curve: Curves.easeOutCubic);
  // 1s pause after the cards land, then the text settles in (~180ms) and types out as one
  // continuous reveal (~4.8s @ ~90ms/char across all 4 lines) - same typewriter treatment as
  // scenes 1 & 2. Line 1 is rendered as its own separately-styled block (see build()) so its
  // bigger/bold font can never collide with normal-sized text on the same line - the bug the
  // strut-height fix in scenes 1 & 2 guards against simply can't occur here.
  static const Interval _titleEntranceInterval = Interval(0.1727, 0.1891, curve: Curves.easeOutCubic);
  static const Interval _titleTypingInterval = Interval(0.1891, 0.6227, curve: Curves.linear);
  // 0.5s after the text finishes, the add-theme button pops in with an elastic overshoot.
  static const Interval _buttonEntranceInterval = Interval(0.6682, 0.7136, curve: Curves.linear);
  // After the scene is fully composed, the center card gives a subtle "tap me" hint by
  // briefly facing the viewer and enlarging before settling back.
  static const Interval _centerHintInterval = Interval(0.7409, 0.8045, curve: Curves.easeInOutCubic);

  static const String _line1Text = '코코넛 과육 테마';
  static const String _restText = '새로운 테마이자\n앞으로의 오픈 스토어를 상상할 수 있는\n첫 번째 PoW 입니다';
  static const String _combinedText = '$_line1Text\n$_restText';

  // Guards the auto-open "tap me" demo below so it only fires once per time the scene's
  // scripted intro actually plays through (not on every rebuild).
  bool _hasAutoOpened = false;

  // Jelly pop for the "추가됨" badge, played whenever isAdded flips true (a real interaction,
  // not part of the scripted intro timeline, so it gets its own spring rather than a curve).
  late final AnimationController _addedBadgeController = AnimationController(
    vsync: this,
    value: widget.isAdded ? 1 : 0,
  );

  @override
  void initState() {
    super.initState();
    widget.animation.addListener(_handleAutoOpenTick);
  }

  @override
  void didUpdateWidget(covariant FirstPowSceneBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animation != widget.animation) {
      oldWidget.animation.removeListener(_handleAutoOpenTick);
      widget.animation.addListener(_handleAutoOpenTick);
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
    widget.animation.removeListener(_handleAutoOpenTick);
    _addedBadgeController.dispose();
    super.dispose();
  }

  // The cards being tappable isn't obvious on their own, so once the scene finishes playing
  // out (the "tap me" wiggle included), it automatically opens the center card's detail view
  // once - a live demo of what tapping does, instead of a hint the user might miss.
  void _handleAutoOpenTick() {
    if (!widget.isCurrentScene) return;
    final value = widget.animation.value;
    if (value < 0.02 && _hasAutoOpened) {
      _hasAutoOpened = false;
      return;
    }
    if (_hasAutoOpened || value < _centerHintInterval.end) return;
    _hasAutoOpened = true;
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      _openDetail(context, _FirstPowCardKind.feature);
    });
  }

  void _openDetail(BuildContext context, _FirstPowCardKind kind) {
    final detail = _firstPowCardDetails[kind]!;
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        // Target size: 1/3 of screen width, enlarged by 120% (i.e. 2.2x that third). On shorter
        // screens this is scaled down just enough to fit the space budgeted for the image
        // cluster, so it never overflows - the formula above is the ceiling, not a fixed value.
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
        // Solve each side card's position so its near-top corner lands exactly on the center
        // card's opposite top corner (left card's top-right meets center's top-left, and
        // mirrored on the right), rather than an eyeballed overlap amount.
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
        // Line 1 is its own separately-styled, separately-rendered block (see below) rather than
        // a highlighted run mixed into a longer line, so there's no line-box that could suddenly
        // grow once typing reaches it - the failure mode the strut fix in scenes 1 & 2 addresses
        // simply doesn't apply to this layout.
        final line1Style = bodyStyle.copyWith(fontSize: (bodyStyle.fontSize ?? 18) * 1.4, fontWeight: FontWeight.w900);
        final line1Length = _line1Text.characters.length;

        return AnimatedBuilder(
          animation: widget.animation,
          builder: (context, child) {
            final value = widget.animation.value;
            final cardsProgress = _cardsInterval.transform(value);
            final centerHintT = _centerHintInterval.transform(value);

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
                      // Not a flat stack: each side card is positioned so its near-top corner
                      // meets the center card's opposite top corner, as if fanned out from a
                      // pivot somewhere above the screen.
                      Transform.translate(
                        offset: leftCardOffset,
                        child: _PolaroidCard(
                          imagePath: _whyImagePath,
                          width: cardWidth,
                          height: cardHeight,
                          finalAngle: leftAngle,
                          entranceOffset: Offset(-cardWidth * 0.7, -24),
                          progress: cardsProgress,
                          heroTag: _whoWhyHeroTag,
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
                        imagePath: _whatImagePath,
                        width: cardWidth,
                        height: cardHeight,
                        finalAngle: 0,
                        entranceOffset: const Offset(0, -260),
                        progress: cardsProgress,
                        heroTag: _whatHeroTag,
                        onTap: () => _openDetail(context, _FirstPowCardKind.feature),
                        facingRotation: -0.08 * math.sin(centerHintT * math.pi),
                        scaleBoost: 1 + (0.14 * math.sin(centerHintT * math.pi)),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(top: cardHeight + topExtra + 56),
                  child: Builder(
                    builder: (context) {
                      final entranceT = _titleEntranceInterval.transform(value);
                      final dy = 20 * (1 - entranceT);
                      // One continuous typewriter reveal across all 4 lines, split into two
                      // widgets purely for rendering (separate style + the extra 28px gap) -
                      // typing progress and position never desync since both read off the same
                      // combined revealed string.
                      final fullVisible = typewriterText(_combinedText, widget.animation, _titleTypingInterval);
                      final visibleChars = fullVisible.characters;
                      final line1Visible = visibleChars.take(line1Length).toString();
                      final restVisible =
                          visibleChars.length > line1Length + 1 ? visibleChars.skip(line1Length + 1).toString() : '';

                      return Opacity(
                        opacity: entranceT,
                        child: Transform.translate(
                          offset: Offset(0, dy),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(line1Visible, style: line1Style),
                              const SizedBox(height: 28),
                              Text(restVisible, style: bodyStyle),
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
                      final buttonT = Curves.elasticOut.transform(_buttonEntranceInterval.transform(value));
                      final buttonOpacity = _buttonEntranceInterval.transform(value).clamp(0.0, 1.0);
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
                                  final t = _addedBadgeController.value;
                                  if (t <= 0.001) return const SizedBox.shrink();
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: Transform.scale(scale: t, child: child),
                                  );
                                },
                                child: _AddedGlassBadge(label: widget.isApplied ? '적용됨' : '추가됨'),
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
    this.facingRotation = 0,
    this.scaleBoost = 1,
  });

  final String imagePath;
  final double width;
  final double height;
  final double finalAngle;
  final Offset entranceOffset;
  final double progress;
  final Object? heroTag;
  final VoidCallback? onTap;
  final double facingRotation;
  final double scaleBoost;

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
        child: Transform.scale(
          scale: scaleBoost,
          child: Transform(
            alignment: Alignment.center,
            transform:
                Matrix4.identity()
                  ..setEntry(3, 2, 0.0012)
                  ..rotateY(facingRotation),
            child: Transform.rotate(
              angle: angle,
              child: onTap == null ? card : GestureDetector(onTap: onTap, child: card),
            ),
          ),
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
  // Jelly press feedback, same squash-and-spring technique used for the scene-overview rows.
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
                    widget.isAdded ? '제거하기' : '테마 화면에 추가하기',
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

// A frosted glass "추가됨" pill, matching the app's established liquid-glass styling.
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

// Full-screen detail view opened by tapping the center ("WHAT") photo. Only this one photo's
// detail view is implemented for now; the other two will get their own custom treatment later.
class _FirstPowDetailScreen extends StatefulWidget {
  const _FirstPowDetailScreen({required this.detail, required this.onAdd, required this.onRemove});

  final _FirstPowCardDetail detail;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  @override
  State<_FirstPowDetailScreen> createState() => _FirstPowDetailScreenState();
}

class _FirstPowDetailScreenState extends State<_FirstPowDetailScreen> with TickerProviderStateMixin {
  // Step 1 (image expands to fullscreen) is the Hero flight driven by the push route's own
  // transitionDuration; everything else here only starts 0.3s after that flight lands.
  static const Duration _heroFlightDuration = Duration(milliseconds: 320);
  static const Duration _postFlightPause = Duration(milliseconds: 300);

  // All three detail kinds reveal their content one block at a time with a deliberate pause
  // between each (like the BUILD scene's title -> pause -> description pacing), so 2200ms
  // isn't enough room - everything below is defined in absolute milliseconds against this
  // total, then divided down to the 0..1 fractions Interval needs.
  static const int _totalEntranceMs = 4150;

  // Step 2: the glass panel fades in.
  static const Interval _glassInterval = Interval(0, 250 / _totalEntranceMs, curve: Curves.easeOut);
  // Step 3: the back button pops in like an elastic/jelly object.
  static const Interval _backButtonInterval = Interval(
    250 / _totalEntranceMs,
    700 / _totalEntranceMs,
    curve: Curves.elasticOut,
  );
  // Step 4: the label slides in slowly from the right - long enough to actually register.
  static const Interval _labelSlideInterval = Interval(
    700 / _totalEntranceMs,
    1400 / _totalEntranceMs,
    curve: Curves.easeOutCubic,
  );
  // Step 5: title (FEATURE/CREATOR) or the first step card (DELIVERY).
  static const Interval _bodyGroup0Interval = Interval(
    1400 / _totalEntranceMs,
    1750 / _totalEntranceMs,
    curve: Curves.easeOutCubic,
  );
  // Every kind's content reveals one block at a time, fully finishing and then pausing
  // (500ms/400ms/400ms) before the next starts, so every block has time to register instead of
  // the whole chain reading as one instantaneous flicker.
  // FEATURE: tags / description / image. CREATOR: "Creator Story" tag / story box / belief box.
  // DELIVERY: review step card / intro step card (propose uses _bodyGroup0Interval above).
  static const Interval _stage2Interval = Interval(2250 / 4150, 2550 / 4150, curve: Curves.easeOutCubic);
  static const Interval _stage3Interval = Interval(2950 / 4150, 3300 / 4150, curve: Curves.easeOutCubic);
  static const Interval _stage4Interval = Interval(3700 / 4150, 1.0, curve: Curves.easeOutCubic);

  late final AnimationController _entranceController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: _totalEntranceMs),
  );

  // The "테마 화면에 추가하기" button (FEATURE screen only) pops in 1s after the rest of the
  // content - including the floating preview images - has fully entered.
  static const Duration _addButtonDelay = Duration(seconds: 1);
  late final AnimationController _addButtonController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  );

  // How much of the label's final character should still peek past the panel's edge once it
  // settles - the rest of that character (and everything before it that's pushed further
  // right) is cropped away by the panel's own clip.
  static const double _visibleLastCharFraction = 0.5;

  // Measured against the label's actual rendered glyph width (not a fixed guess), so the crop
  // stays correct regardless of which panelLabel string or font ends up here.
  late final double _labelCropWidth = _computeLabelCropWidth(widget.detail.panelLabel);

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
    if (widget.detail.kind == _FirstPowCardKind.feature) {
      _entranceController.addStatusListener(_handleEntranceStatusForButton);
    }
  }

  void _handleEntranceStatusForButton(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    Future.delayed(_addButtonDelay, () {
      if (!mounted) return;
      _addButtonController.forward();
    });
  }

  @override
  void dispose() {
    _entranceController.removeStatusListener(_handleEntranceStatusForButton);
    _entranceController.dispose();
    _addButtonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const listing = CcosFeatureRegistrySource.featuredListing;
    final detail = widget.detail;
    // The glass panel must not creep into the status bar; the fullscreen image behind it can.
    final topInset = MediaQuery.of(context).padding.top;
    final bottomInset = MediaQuery.of(context).padding.bottom + 12;

    // Reactive to PreferenceProvider so the button/badge below reflect live add/remove/apply
    // taps made from this screen (or elsewhere) without needing this route to be rebuilt by
    // its parent - this screen was pushed on top of it, so it watches independently.
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
          Hero(tag: detail.heroTag, child: Image(image: AssetImage(detail.imagePath), fit: BoxFit.cover)),
          AnimatedBuilder(
            animation: _entranceController,
            builder: (context, child) {
              final t = _entranceController.value;
              final glassT = _glassInterval.transform(t);
              final backButtonT = _backButtonInterval.transform(t);
              final labelSlideT = _labelSlideInterval.transform(t);
              // Starts pushed further past the right edge (off-screen) and slides left toward
              // its resting, slightly-cropped position - not the reverse.
              final labelDx = -260 * (1 - labelSlideT);
              final group0T = _bodyGroup0Interval.transform(t);
              final stage2T = _stage2Interval.transform(t);
              final stage3T = _stage3Interval.transform(t);
              final stage4T = _stage4Interval.transform(t);

              return Opacity(
                opacity: glassT,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(14, topInset + 14, 14, 14),
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
                      // Top inset already reserved by the padding above.
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
                              bottom: 20,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (detail.kind == _FirstPowCardKind.feature) ...[
                                    _FadeSlideIn(
                                      progress: group0T,
                                      child: Text(
                                        '코코넛 과육 테마',
                                        style: CoconutTypography.heading3_21_Bold.setColor(_textPrimary),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    // Strictly sequential: tags don't start until the title
                                    // above has fully finished fading in, and so on down the
                                    // chain - each _FadeSlideIn's interval only begins where
                                    // the previous one ends (see the interval definitions).
                                    _FadeSlideIn(
                                      progress: stage2T,
                                      child: Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [for (final tag in listing.tags) _GlassChip(label: tag)],
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    _FadeSlideIn(
                                      progress: stage3T,
                                      child: Text(
                                        listing.description,
                                        style: CoconutTypography.body2_14.setColor(_textPrimary),
                                      ),
                                    ),
                                    const SizedBox(height: 28),
                                    _FadeSlideIn(progress: stage4T, child: const _ThemePreviewCluster()),
                                  ] else if (detail.kind == _FirstPowCardKind.creator) ...[
                                    _FadeSlideIn(
                                      progress: group0T,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            listing.author,
                                            style: CoconutTypography.heading3_21_Bold
                                                .setColor(_textPrimary)
                                                .copyWith(fontSize: 24),
                                          ),
                                          Text(
                                            listing.authorDescription,
                                            style: CoconutTypography.body3_12.setColor(_textPrimary),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    // "물방울" entrance: falls from just above and settles with
                                    // a bounce, rather than the plain fade/slide used elsewhere.
                                    _DropletFadeIn(progress: stage2T, child: const _GlassChip(label: 'Creator Story')),
                                    const SizedBox(height: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Box 1: fills whatever space is left above box 2 and
                                          // scrolls internally if the story text runs taller
                                          // than that - box 2 below always stays fully visible.
                                          Expanded(
                                            child: _FadeSlideIn(progress: stage3T, child: const _CreatorStoryBox()),
                                          ),
                                          const SizedBox(height: 12),
                                          _FadeSlideIn(
                                            progress: stage4T,
                                            child: const _CreatorGlassTextBox(
                                              text: _creatorBeliefStatement,
                                              bold: true,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ] else ...[
                                    // DELIVERY: three identical-design step cards (propose ->
                                    // review -> introduce), each fully finishing and pausing
                                    // before the next appears - spaced far enough apart to
                                    // register clearly, unlike FEATURE/CREATOR's tighter chain.
                                    Expanded(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Container(),
                                          _DeliveryStepCard(
                                            progress: group0T,
                                            iconPath: _deliveryProposeIconPath,
                                            title: _deliveryProposeTitle,
                                            body: _deliveryProposeBody,
                                          ),
                                          _DeliveryStepCard(
                                            progress: stage2T,
                                            iconPath: _deliveryReviewIconPath,
                                            title: _deliveryReviewTitle,
                                            body: _deliveryReviewBody,
                                          ),
                                          _DeliveryStepCard(
                                            progress: stage3T,
                                            iconPath: _deliveryIntroIconPath,
                                            title: _deliveryIntroTitle,
                                            body: _deliveryIntroBody,
                                          ),
                                          Container(),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
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
          if (detail.kind == _FirstPowCardKind.feature)
            Positioned(
              left: 0,
              right: 16,
              bottom: 28 + bottomInset,
              child: Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 20),
                  child: AnimatedBuilder(
                    animation: _addButtonController,
                    builder: (context, child) {
                      final buttonT = Curves.elasticOut.transform(_addButtonController.value);
                      final buttonOpacity = _addButtonController.value.clamp(0.0, 1.0);
                      return Opacity(
                        opacity: buttonOpacity,
                        child: Transform.scale(
                          scale: buttonT.clamp(0.0, 1.4),
                          alignment: Alignment.centerRight,
                          child: child,
                        ),
                      );
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isAdded)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: _AddedGlassBadge(label: isApplied ? '적용됨' : '추가됨'),
                          ),
                        _AddThemeButton(isAdded: isAdded, onAdd: widget.onAdd, onRemove: widget.onRemove),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// Fades and slides a body block up into place, driven by an externally-computed 0..1 progress
// (already curved) so several of these can cascade top-to-bottom off one shared controller.
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

// A small liquid-glass chip for the "what" screen's tag pills, matching the panel's own
// frosted treatment rather than a flat outlined pill.
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

// CREATOR screen only: the "Creator Story" tag's entrance - falls from just above and settles
// with a bounce, reading as a droplet landing rather than the plain fade/slide used elsewhere.
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

// CREATOR screen only: box 1, the scrollable "story" card - a real piece of user feedback
// (bold, with attribution) followed by the reasoning paragraphs behind the theme. Scrolls
// internally rather than growing the box, since box 2 below it must always stay fully visible.
class _CreatorStoryBox extends StatelessWidget {
  const _CreatorStoryBox();

  static const double _edgeFadeHeight = 28;

  @override
  Widget build(BuildContext context) {
    final quoteStyle = CoconutTypography.body3_12_Bold.setColor(_textPrimary.withValues(alpha: 0.92));
    final bodyStyle = CoconutTypography.body3_12.setColor(_textPrimary.withValues(alpha: 0.8));

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

// CREATOR screen only: box 2 - a short, always-fully-visible statement in its own frosted card,
// matching box 1's styling (same white/50%-opacity fill, same 16-radius corners).
class _CreatorGlassTextBox extends StatelessWidget {
  const _CreatorGlassTextBox({required this.text, this.bold = false});

  final String text;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final style = (bold ? CoconutTypography.body2_14_Bold : CoconutTypography.body2_14).setColor(
      _textPrimary.withValues(alpha: 0.92),
    );
    return DecoratedBox(
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(16)),
      child: Padding(padding: const EdgeInsets.all(18), child: Text(text, style: style)),
    );
  }
}

// DELIVERY screen only: one step of the propose -> review -> introduce flow. The box itself
// fades/slides in first; the icon badge overlapping its top-left corner pops in a beat later
// with an elastic overshoot, reading as "the card arrives, then the icon lands on top of it".
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
              left: 0,
              top: -30,
              child: Transform.scale(scale: iconT.clamp(0.0, 1.4), child: _DeliveryIconBadge(iconPath: iconPath)),
            ),
          ],
        ),
      ),
    );
  }
}

// DELIVERY screen only: the circular frosted-glass icon badge that overlaps each step card's
// top-left corner, matching the app's established liquid-glass styling.
class _DeliveryIconBadge extends StatelessWidget {
  const _DeliveryIconBadge({required this.iconPath});

  final String iconPath;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 1.2),
      ),
      child: LiquidGlassSurface(
        cornerRadius: 999,
        blurSigma: 10,
        distortion: 0.25,
        distortionWidth: 14,
        magnification: 1.08,
        tintColor: const Color(0x33FFFFFF),
        rimColor: Colors.white.withValues(alpha: 0.1),
        rimWidth: 4,
        rimOnTopBottom: false,
        child: Padding(padding: const EdgeInsets.all(14), child: SvgPicture.asset(iconPath, width: 22, height: 22)),
      ),
    );
  }
}

// The FEATURE screen's floating preview: five small UI-element cutouts (transaction card,
// wallet icon, arrows, address chip) drifting organically over the theme's hero photo, giving a
// glance of what the theme looks like in the app rather than a single static screenshot.
class _ThemePreviewCluster extends StatefulWidget {
  const _ThemePreviewCluster();

  @override
  State<_ThemePreviewCluster> createState() => _ThemePreviewClusterState();
}

class _ThemePreviewClusterState extends State<_ThemePreviewCluster> with SingleTickerProviderStateMixin {
  late final AnimationController _floatController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 7000),
  )..repeat();

  // Each image's resting position (fraction of the cluster box), size, resting tilt, and its
  // own phase in the shared drift cycle - offset phases keep the five images from ever bobbing
  // in unison, which is what reads as "organic" rather than mechanical.
  // Painted in list order (later = on top), so the tx card sits first/behind and the two
  // corner badges (wallet icon, down arrow) paint after it to stay visible over its corners.
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
  void dispose() {
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
            animation: _floatController,
            builder: (context, child) {
              return Stack(children: [for (final spec in _images) _buildFloatingImage(spec, _floatController.value)]);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingImage(_FloatingImageSpec spec, double t) {
    // Both waves complete a whole number of cycles over one repeat lap (1 and 2 respectively),
    // so their value at t=1 exactly matches t=0 - no jump at the loop seam.
    final bobWave = math.sin((t + spec.phase) * 2 * math.pi);
    final driftWave = math.sin((t + spec.phase) * 2 * math.pi * 2 + 1.3);
    return Align(
      alignment: spec.alignment,
      child: Transform.translate(
        offset: Offset(driftWave * 4, bobWave * 9),
        child: Transform.rotate(
          angle: spec.baseAngle + (bobWave * 0.05),
          child: Image.asset(spec.path, width: spec.width),
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
  // 0..1 offset into the shared drift cycle, so each image bobs out of phase with the others.
  final double phase;
}
