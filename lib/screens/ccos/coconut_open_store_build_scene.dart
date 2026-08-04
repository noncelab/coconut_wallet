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
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/screens/ccos/coconut_open_store_text_effects.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

// Deep, deliberately dark end of the coconut2 glow gradient below. Previously matched the
// screen's flat background color (0xFFCDD4D7), but that's nearly as light as the white it was
// paired with, so the wandering glow barely registered - a much darker tone gives it real
// contrast to glow against.
const _glowLightColor = Color.fromARGB(255, 161, 172, 177);
const _glowDarkColor = Color.fromARGB(255, 120, 120, 187);

/// Scene 2 ("BUILD") of the open-store intro story: the coconut hero icon crossfade,
/// its orbiting feature labels, and the typed title/description.
class BuildSceneBody extends StatelessWidget {
  const BuildSceneBody({super.key, required this.animation, required this.title, required this.description});

  final Animation<double> animation;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        final titleStyle = CoconutTypography.heading3_21_Bold.setColor(Colors.white).copyWith(height: 1.24);
        final titleHighlightStyle = titleStyle.copyWith(
          fontSize: (titleStyle.fontSize ?? 21) * 1.4,
          fontWeight: FontWeight.w900,
        );
        // Reserve the line's height up front for the bigger highlighted run, so '누구나' doesn't
        // shift the instant typing reaches the highlighted '비트코인' - the line box would
        // otherwise only grow once a highlighted character actually appears.
        final titleStrutStyle = StrutStyle(
          fontSize: titleHighlightStyle.fontSize,
          height: titleStyle.height,
          forceStrutHeight: true,
        );
        final descriptionStyle = CoconutTypography.heading4_18_Bold.setColor(Colors.white).copyWith(height: 1.16);
        final descriptionHighlightStyle = descriptionStyle.copyWith(
          fontSize: (descriptionStyle.fontSize ?? 18) * 1.4,
          fontWeight: FontWeight.w900,
        );
        // Same fix as the title: '여러분의 PoW' shares its line with plain '가', so reserve
        // that line's height for the bigger highlighted run up front.
        final descriptionStrutStyle = StrutStyle(
          fontSize: descriptionHighlightStyle.fontSize,
          height: descriptionStyle.height,
          forceStrutHeight: true,
        );
        // Hero + orbit labels finish by ~5.23s, then hold for a 1s pause before the title starts typing.
        // The title block quickly settles into place (~180ms), then every remaining character
        // pops in one at a time at full opacity, so it reads as a clean typewriter effect
        // instead of fading/sliding in while characters are still being added.
        const titleEntranceInterval = Interval(0.5694, 0.5828, curve: Curves.easeOutCubic);
        const titleTypingInterval = Interval(0.5828, 0.7037, curve: Curves.linear);
        // Title finishes at ~8.03s; description starts 0.5s later, then settles in (~180ms)
        // before typing out one character at a time, same as the title.
        const descriptionEntranceInterval = Interval(0.7410, 0.7545, curve: Curves.easeOutCubic);
        const descriptionTypingInterval = Interval(0.7545, 0.9649, curve: Curves.linear);

        return Stack(
          children: [
            Align(
              alignment: Alignment.center,
              child: SizedBox(
                width: constraints.maxWidth,
                height: height * 0.56,
                child: _BuildHero(animation: animation),
              ),
            ),
            Positioned(
              top: height * 0.07,
              left: 0,
              right: 90,
              child: AnimatedBuilder(
                animation: animation,
                builder: (context, child) {
                  final entranceT = titleEntranceInterval.transform(animation.value);
                  final dx = -56 * (1 - entranceT);
                  final dy = 26 * (1 - entranceT);
                  final scale = 0.9 + (0.16 * entranceT);
                  final settleScale = scale > 1.0 ? 1.0 + ((scale - 1.0) * 0.35) : scale;

                  return Opacity(
                    opacity: entranceT,
                    child: Transform.translate(
                      offset: Offset(dx, dy),
                      child: Transform.scale(
                        scale: settleScale,
                        alignment: Alignment.centerLeft,
                        child: RichText(
                          textAlign: TextAlign.left,
                          strutStyle: titleStrutStyle,
                          text: typewriterSpan(
                            source: title,
                            animation: animation,
                            interval: titleTypingInterval,
                            baseStyle: titleStyle,
                            highlightStyle: titleHighlightStyle,
                            highlightPhrases: {t.ccos.build_scene.highlight_bitcoin_builder},
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Positioned(
              top: height * 0.72,
              left: 84,
              right: 0,
              child: AnimatedBuilder(
                animation: animation,
                builder: (context, child) {
                  final entranceT = descriptionEntranceInterval.transform(animation.value);
                  final dx = 58 * (1 - entranceT);
                  final dy = 30 * (1 - entranceT);
                  final scale = 0.9 + (0.16 * entranceT);
                  final settleScale = scale > 1.0 ? 1.0 + ((scale - 1.0) * 0.35) : scale;

                  return Opacity(
                    opacity: entranceT,
                    child: Transform.translate(
                      offset: Offset(dx, dy),
                      child: Transform.scale(
                        scale: settleScale,
                        alignment: Alignment.centerRight,
                        child: RichText(
                          textAlign: TextAlign.right,
                          strutStyle: descriptionStrutStyle,
                          text: typewriterSpan(
                            source: description,
                            animation: animation,
                            interval: descriptionTypingInterval,
                            baseStyle: descriptionStyle,
                            highlightStyle: descriptionHighlightStyle,
                            highlightPhrases: {t.ccos.build_scene.highlight_pow},
                          ),
                        ),
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
  }
}

class _BuildHero extends StatefulWidget {
  const _BuildHero({required this.animation});

  final Animation<double> animation;

  @override
  State<_BuildHero> createState() => _BuildHeroState();
}

class _BuildHeroState extends State<_BuildHero> with TickerProviderStateMixin {
  // coconutCore: tiny dot -> 45% of screen width, ease-out, then fixed size.
  static const Interval _coconut0GrowInterval = Interval(0.0, 0.0672, curve: Curves.easeOut);
  // Slow, fully-overlapping crossfade (coconutCore fades out while coconutOrbit fades in at the same time)
  // so the swap reads as a smooth dissolve rather than a blink. ~3.6s, slowed further per feedback.
  static const Interval _heroCrossfadeInterval = Interval(0.0709, 0.3396, curve: Curves.easeInOut);
  // Both coconutCore and coconutOrbit stay plain white through the crossfade above. Only once coconutOrbit
  // is fully visible does it slowly dissolve into the glow-colored version (~1.4s), after which
  // the wandering glow shimmer is the steady-state look.
  static const Interval _glowRevealInterval = Interval(0.3396, 0.6441, curve: Curves.easeInOut);

  late final AnimationController _glowController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat(reverse: true);

  // Drives a slow, continuously rotating angular (sweep) gradient between white and the
  // screen background color, so different parts of coconut2 mysteriously fade in and out
  // as the gradient sweeps around it, rather than a simple opacity pulse.
  late final AnimationController _sweepController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 7000),
  )..repeat();

  @override
  void dispose() {
    _glowController.dispose();
    _sweepController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 58% of screen width
    final heroSize = MediaQuery.of(context).size.width * 0.58;

    return AnimatedBuilder(
      animation: Listenable.merge([widget.animation, _glowController, _sweepController]),
      builder: (context, child) {
        final introValue = widget.animation.value;
        final coconut0Scale = _coconut0GrowInterval.transform(introValue).clamp(0.0, 1.0);
        final crossfadeProgress = _heroCrossfadeInterval.transform(introValue);
        final coconut0Opacity = 1 - crossfadeProgress;
        final coconut2Opacity = crossfadeProgress;
        final glowRevealProgress = _glowRevealInterval.transform(introValue);
        final glowProgress = Curves.easeInOut.transform(_glowController.value);
        final coconut2LoopScale = Tween<double>(begin: 0.988, end: 1.026).transform(glowProgress);
        final glowHaloOpacity = Tween<double>(begin: 0.08, end: 0.22).transform(glowProgress) * glowRevealProgress;
        final flowT = _sweepController.value;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Center(
              child: Transform.translate(
                offset: const Offset(0, -20),
                child: SizedBox(
                  width: heroSize,
                  height: heroSize,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      IgnorePointer(
                        child: Opacity(
                          opacity: glowHaloOpacity,
                          child: Container(
                            width: heroSize * 0.95,
                            height: heroSize * 0.95,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [Color(0x55AEEBFF), Color(0x44D5C6FF), Colors.transparent],
                                stops: [0.0, 0.52, 1.0],
                              ),
                            ),
                          ),
                        ),
                      ),
                      Transform.scale(
                        scale: coconut2LoopScale,
                        child: Opacity(
                          opacity: coconut2Opacity,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Plain white throughout the crossfade above, and still white right
                              // after coconutOrbit is fully visible - the glow hasn't "started" yet.
                              Opacity(
                                opacity: 1 - glowRevealProgress,
                                child: SvgPicture.asset(
                                  BrandIconPath.coconutOrbit,
                                  width: heroSize,
                                  height: heroSize,
                                  colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                                ),
                              ),
                              // Slowly dissolves in once fully visible; once fully opaque, the
                              // ongoing wandering shimmer (driven by flowT) is the steady glow.
                              Opacity(
                                opacity: glowRevealProgress,
                                child: ShaderMask(
                                  shaderCallback: (bounds) => _milkyWayShader(bounds, flowT),
                                  blendMode: BlendMode.srcIn,
                                  child: SvgPicture.asset(
                                    BrandIconPath.coconutOrbit,
                                    width: heroSize,
                                    height: heroSize,
                                    colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Opacity(
                        opacity: coconut0Opacity.clamp(0.0, 1.0),
                        child: Transform.scale(
                          scale: coconut0Scale,
                          child: SvgPicture.asset(
                            BrandIconPath.coconutCore,
                            width: heroSize,
                            height: heroSize,
                            colorFilter: const ColorFilter.mode(Color(0xF6FFFFFF), BlendMode.srcIn),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Orbit labels only start flying in once coconutOrbit's slow crossfade has fully settled (~0.2625).
            _BuildOrbitLabel(
              label: t.ccos.build_scene.orbit.widget,
              alignment: const Alignment(-0.32, -0.12),
              animation: widget.animation,
              pulseAnimation: _glowController,
              interval: const Interval(0.3433, 0.3993, curve: Curves.easeOutCubic),
              fontSize: 19,
              color: const Color(0xFFE3F0E6),
              pulsePhase: 0.44,
              startDirection: _OrbitStartDirection.left,
              bendSign: 1,
            ),
            _BuildOrbitLabel(
              label: t.ccos.build_scene.orbit.theme,
              alignment: const Alignment(-0.58, -0.62),
              animation: widget.animation,
              pulseAnimation: _glowController,
              interval: const Interval(0.3567, 0.4239, curve: Curves.easeOutCubic),
              fontSize: 14,
              color: const Color.fromARGB(217, 251, 238, 223),
              pulsePhase: 0.10,
              startDirection: _OrbitStartDirection.topLeft,
              bendSign: -1,
            ),
            _BuildOrbitLabel(
              label: t.ccos.build_scene.orbit.analysis,
              alignment: const Alignment(0.72, -0.03),
              animation: widget.animation,
              pulseAnimation: _glowController,
              interval: const Interval(0.3701, 0.4299, curve: Curves.easeOutCubic),
              fontSize: 12,
              color: const Color(0xFFD4E7FF),
              pulsePhase: 0.56,
              startDirection: _OrbitStartDirection.right,
              bendSign: -1,
            ),
            _BuildOrbitLabel(
              label: t.ccos.build_scene.orbit.tool,
              alignment: const Alignment(0.62, -0.52),
              animation: widget.animation,
              pulseAnimation: _glowController,
              interval: const Interval(0.3866, 0.4500, curve: Curves.easeOutCubic),
              fontSize: 16,
              color: const Color(0xFFDCEFEA),
              pulsePhase: 0.28,
              startDirection: _OrbitStartDirection.topRight,
              bendSign: 1,
            ),
            _BuildOrbitLabel(
              label: t.ccos.build_scene.orbit.layer2,
              alignment: const Alignment(-0.72, 0.24),
              animation: widget.animation,
              pulseAnimation: _glowController,
              interval: const Interval(0.4030, 0.4739, curve: Curves.easeOutCubic),
              fontSize: 17,
              color: const Color(0xFFD9DFF5),
              pulsePhase: 0.68,
              startDirection: _OrbitStartDirection.bottomLeft,
              bendSign: 1,
            ),
            _BuildOrbitLabel(
              label: t.ccos.build_scene.orbit.backup,
              alignment: const Alignment(0.34, 0.26),
              animation: widget.animation,
              pulseAnimation: _glowController,
              interval: const Interval(0.4201, 0.4948, curve: Curves.easeOutCubic),
              fontSize: 17,
              color: const Color(0xFFDCE4F4),
              pulsePhase: 0.88,
              startDirection: _OrbitStartDirection.bottomRight,
              bendSign: -1,
            ),
          ],
        );
      },
    );
  }

  // A soft glow wanders around the icon in a gentle figure-eight loop (integer frequency
  // ratio so it repeats with no seam) instead of sweeping in one straight direction or
  // spinning around a fixed pivot - and a single smooth radial falloff (no tiling/mirroring,
  // which is what caused the banding/"pixelated" look) keeps the transition soft everywhere.
  Shader _milkyWayShader(Rect bounds, double t) {
    final angle = t * 2 * math.pi;
    final wanderX = math.sin(angle) * 0.4;
    final wanderY = math.sin(angle * 2) * 0.3;
    return RadialGradient(
      center: Alignment(wanderX, wanderY),
      radius: 0.95,
      colors: const [_glowLightColor, _glowDarkColor],
    ).createShader(bounds);
  }
}

enum _OrbitStartDirection { topLeft, topRight, left, right, bottomLeft, bottomRight }

class _BuildOrbitLabel extends StatelessWidget {
  const _BuildOrbitLabel({
    required this.label,
    required this.alignment,
    required this.animation,
    required this.pulseAnimation,
    required this.interval,
    required this.fontSize,
    required this.color,
    required this.pulsePhase,
    required this.startDirection,
    required this.bendSign,
  });

  final String label;
  final Alignment alignment;
  final Animation<double> animation;
  final Animation<double> pulseAnimation;
  final Interval interval;
  final double fontSize;
  final Color color;
  final double pulsePhase;
  final _OrbitStartDirection startDirection;
  final double bendSign;

  static Offset _quadraticBezier(Offset p0, Offset p1, Offset p2, double t) {
    final u = 1 - t;
    return Offset(u * u * p0.dx + 2 * u * t * p1.dx + t * t * p2.dx, u * u * p0.dy + 2 * u * t * p1.dy + t * t * p2.dy);
  }

  Offset _startOffset(Size screenSize) {
    final diagX = screenSize.width * 0.62;
    final diagY = screenSize.height * 0.42;
    final sideX = screenSize.width * 0.72;
    switch (startDirection) {
      case _OrbitStartDirection.topLeft:
        return Offset(-diagX, -diagY);
      case _OrbitStartDirection.topRight:
        return Offset(diagX, -diagY);
      case _OrbitStartDirection.left:
        return Offset(-sideX, 10);
      case _OrbitStartDirection.right:
        return Offset(sideX, -8);
      case _OrbitStartDirection.bottomLeft:
        return Offset(-diagX, diagY);
      case _OrbitStartDirection.bottomRight:
        return Offset(diagX, diagY);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final startOffset = _startOffset(screenSize);
    final bendMagnitude = screenSize.shortestSide * 0.16;
    final direction = -startOffset;
    final directionLength = direction.distance;
    final perpUnit = directionLength == 0 ? Offset.zero : Offset(-direction.dy, direction.dx) / directionLength;
    final control = Offset.lerp(startOffset, Offset.zero, 0.5)! + perpUnit * bendMagnitude * bendSign;

    return Align(
      alignment: alignment,
      child: AnimatedBuilder(
        animation: Listenable.merge([animation, pulseAnimation]),
        builder: (context, child) {
          final curved = Curves.easeOutCubic.transform(interval.transform(animation.value));
          final slideOffset = _quadraticBezier(startOffset, control, Offset.zero, curved);
          final entryScale = Tween<double>(begin: 0.92, end: 1).transform(curved);
          final pulse = math.sin((pulseAnimation.value + pulsePhase) * math.pi * 2);
          final scale = entryScale * (1 + (pulse * 0.02));

          return Opacity(
            opacity: curved,
            child: Transform.translate(
              offset: slideOffset,
              child: Transform.scale(
                scale: scale,
                child: Text(
                  label,
                  style: CoconutTypography.heading4_18_Bold
                      .setColor(color)
                      .copyWith(
                        fontSize: fontSize,
                        letterSpacing: -0.2,
                      ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
