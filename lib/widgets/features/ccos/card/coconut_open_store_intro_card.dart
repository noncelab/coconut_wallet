import 'dart:math' as math;

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/ccos/open_store/coconut_open_store_content.dart';
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/widgets/common/buttons/shrink_tap_wrapper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class CoconutOpenStoreIntroCard extends StatefulWidget {
  const CoconutOpenStoreIntroCard({
    super.key,
    required this.intro,
    required this.onTap,
    this.onDismiss,
    this.showDismissButton = true,
    this.margin = EdgeInsets.zero,
  });

  final CcosOpenStoreIntro intro;
  final VoidCallback onTap;
  final VoidCallback? onDismiss;
  final bool showDismissButton;
  final EdgeInsets margin;

  @override
  State<CoconutOpenStoreIntroCard> createState() => _CoconutOpenStoreIntroCardState();
}

class _CoconutOpenStoreIntroCardState extends State<CoconutOpenStoreIntroCard> with SingleTickerProviderStateMixin {
  static const Color _primaryTextColor = Color(0xFFF5F7FF);
  static const Color _secondaryTextColor = Color(0xCCDAE3FF);
  static const Color _iconColor = Color(0xFFE9EEFF);
  static const Color _iconSecondaryColor = Color(0xB8D4DDFF);

  late final AnimationController _backgroundController = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 22),
  )..repeat();

  @override
  void dispose() {
    _backgroundController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(Sizes.size12);
    final shadowColor = context.coconutColors.shadowDefault;

    return Container(
      margin: widget.margin,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: [BoxShadow(color: shadowColor, blurRadius: 18, offset: const Offset(0, 8))],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: Stack(
          children: [
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _backgroundController,
                builder: (context, child) {
                  final t = _backgroundController.value;
                  final waveX = math.sin(t * math.pi * 2);
                  final waveY = math.cos(t * math.pi * 2);
                  final slowWave = math.sin((t * math.pi * 2) * 0.5);
                  final driftWave = math.cos((t * math.pi * 2) * 0.7);
                  return DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment(-1.05 + (waveX * 0.3), -1.1 + (waveY * 0.18)),
                        end: Alignment(1.02 + (slowWave * 0.2), 1.02 + (driftWave * 0.14)),
                        colors: const [
                          Color(0xFF0B1128),
                          Color(0xFF33205F),
                          Color(0xFF4A2E86),
                          Color(0xFF215E8C),
                          Color(0xFF2A9BB2),
                        ],
                        stops: const [0.0, 0.22, 0.48, 0.76, 1.0],
                      ),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _AnimatedGlowOrb(
                          progress: t,
                          alignment: Alignment(-0.9 + (waveX * 0.13), -0.88 + (waveY * 0.1)),
                          size: 168,
                          glowRadius: 0.92,
                          color: const Color(0x88616CFF),
                        ),
                        _AnimatedGlowOrb(
                          progress: t,
                          alignment: Alignment(0.86 + (waveY * 0.1), -0.64 + (slowWave * 0.12)),
                          size: 142,
                          glowRadius: 0.88,
                          color: const Color(0x6F7A4CFF),
                        ),
                        _AnimatedGlowOrb(
                          progress: t,
                          alignment: Alignment(0.4 + (waveX * 0.1), 1.0 + (waveY * 0.06)),
                          size: 206,
                          glowRadius: 1.0,
                          color: const Color(0x6648D1D4),
                        ),
                        _AnimatedGlowOrb(
                          progress: t + 0.18,
                          alignment: Alignment(-0.18 + (slowWave * 0.08), 0.1 + (waveX * 0.06)),
                          size: 92,
                          glowRadius: 0.84,
                          color: const Color(0x4CCBB8FF),
                        ),
                        IgnorePointer(
                          child: Transform.translate(
                            offset: Offset(waveX * 18, driftWave * 14),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: RadialGradient(
                                  center: Alignment(-0.15 + (slowWave * 0.34), -0.25 + (waveY * 0.22)),
                                  radius: 1.05,
                                  colors: const [Color(0x242D8DFF), Color(0x1831C9C6), Colors.transparent],
                                  stops: const [0.0, 0.34, 1.0],
                                ),
                              ),
                            ),
                          ),
                        ),
                        CustomPaint(painter: _NebulaTexturePainter(progress: t)),
                        CustomPaint(painter: _CosmicDustPainter(progress: t)),
                      ],
                    ),
                  );
                },
              ),
            ),
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0x16040816), Color(0x660A1022), Color(0x91111728)],
                    stops: [0.0, 0.45, 1.0],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(Sizes.size16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      SvgPicture.asset(
                        BrandIconPath.coconutPlanet,
                        width: Sizes.size18,
                        height: Sizes.size18,
                        colorFilter: const ColorFilter.mode(_iconColor, BlendMode.srcIn),
                      ),
                      CoconutLayout.spacing_200w,
                      Expanded(
                        child: Text(
                          widget.intro.title,
                          style: CoconutTypography.body2_14_Bold.setColor(_primaryTextColor),
                        ),
                      ),
                      if (widget.showDismissButton && widget.onDismiss != null) ...[
                        CoconutLayout.spacing_200w,
                        GestureDetector(
                          onTap: widget.onDismiss,
                          child: SvgPicture.asset(
                            CommonActionIconPath.close,
                            width: Sizes.size20,
                            height: Sizes.size20,
                            colorFilter: const ColorFilter.mode(_iconSecondaryColor, BlendMode.srcIn),
                          ),
                        ),
                      ],
                    ],
                  ),
                  CoconutLayout.spacing_300h,
                  Text(widget.intro.headline, style: CoconutTypography.body3_12_Bold.setColor(_primaryTextColor)),
                  CoconutLayout.spacing_100h,
                  Text(widget.intro.description, style: CoconutTypography.body3_12.setColor(_secondaryTextColor)),
                  CoconutLayout.spacing_200h,
                  Align(
                    alignment: Alignment.centerRight,
                    child: ShrinkTapWrapper(
                      onTap: widget.onTap,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.intro.ctaLabel,
                            style: CoconutTypography.caption_10_Bold.setColor(_primaryTextColor),
                          ),
                          CoconutLayout.spacing_300w,
                          SvgPicture.asset(
                            CommonNavigationIconPath.arrowRight,
                            width: Sizes.size10,
                            height: Sizes.size10,
                            colorFilter: const ColorFilter.mode(_iconColor, BlendMode.srcIn),
                          ),
                        ],
                      ),
                    ),
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

class _AnimatedGlowOrb extends StatelessWidget {
  const _AnimatedGlowOrb({
    required this.progress,
    required this.alignment,
    required this.size,
    required this.color,
    required this.glowRadius,
  });

  final double progress;
  final Alignment alignment;
  final double size;
  final Color color;
  final double glowRadius;

  @override
  Widget build(BuildContext context) {
    final pulse = 0.96 + (math.sin(progress * math.pi * 2) * 0.045);
    final innerCoreSize = size * 0.22;
    return Align(
      alignment: alignment,
      child: Transform.scale(
        scale: pulse,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [color, color.withValues(alpha: 0.08), color.withValues(alpha: 0.03), Colors.transparent],
                  stops: [0.0, glowRadius * 0.24, glowRadius * 0.5, 1.0],
                ),
              ),
            ),
            Container(
              width: innerCoreSize,
              height: innerCoreSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Colors.white.withValues(alpha: 0.28), color.withValues(alpha: 0.35), Colors.transparent],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CosmicDustPainter extends CustomPainter {
  const _CosmicDustPainter({required this.progress});

  final double progress;

  static const List<_CosmicPoint> _points = [
    _CosmicPoint(Offset(0.08, 0.14), 1.0, 0.08),
    _CosmicPoint(Offset(0.33, 0.18), 1.2, 0.07, isTwinkling: true, twinkleSpeed: 1.2, twinklePhase: 0.2),
    _CosmicPoint(Offset(0.56, 0.12), 1.0, 0.06),
    _CosmicPoint(Offset(0.74, 0.18), 1.4, 0.08, isTwinkling: true, twinkleSpeed: 0.9, twinklePhase: 1.6),
    _CosmicPoint(Offset(0.25, 0.54), 1.4, 0.08),
    _CosmicPoint(Offset(0.48, 0.74), 2.6, 0.12, isTwinkling: true, twinkleSpeed: 0.7, twinklePhase: 2.4),
    _CosmicPoint(Offset(0.68, 0.66), 1.5, 0.08),
    _CosmicPoint(Offset(0.9, 0.74), 1.1, 0.06),
    _CosmicPoint(Offset(0.68, 0.3), 3.6, 0.06, tint: Color(0x28A6B8FF)),
    _CosmicPoint(
      Offset(0.22, 0.2),
      3.0,
      0.05,
      tint: Color(0x22FFB7EA),
      isTwinkling: true,
      twinkleSpeed: 1.05,
      twinklePhase: 0.8,
    ),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final starPaint = Paint()..style = PaintingStyle.fill;
    final glowPaint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < _points.length; i++) {
      final point = _points[i];
      final pulse = 0.22 + ((math.sin((progress * math.pi * 2) + (i * 0.8)) + 1) * 0.12);
      final twinkle =
          point.isTwinkling
              ? 0.06 + ((math.sin((progress * math.pi * 2 * point.twinkleSpeed) + point.twinklePhase) + 1) * 0.16)
              : 0.0;
      final center = Offset(point.position.dx * size.width, point.position.dy * size.height);

      if (point.glowAlpha > 0) {
        glowPaint
          ..color = (point.tint ?? Colors.white).withValues(alpha: (point.glowAlpha + pulse + twinkle) * 0.42)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, point.radius * 2.2);
        canvas.drawCircle(center, point.radius * 1.3, glowPaint);
      }

      starPaint
        ..color = (point.tint ?? Colors.white).withValues(alpha: 0.26 + pulse + twinkle)
        ..maskFilter = null;
      canvas.drawCircle(center, point.radius, starPaint);

      if (point.isTwinkling) {
        final sparklePaint =
            Paint()
              ..color = Colors.white.withValues(alpha: 0.06 + twinkle)
              ..strokeWidth = 0.7
              ..strokeCap = StrokeCap.round
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.4);
        canvas.drawLine(
          Offset(center.dx - (point.radius * 1.4), center.dy),
          Offset(center.dx + (point.radius * 1.4), center.dy),
          sparklePaint,
        );
        canvas.drawLine(
          Offset(center.dx, center.dy - (point.radius * 1.4)),
          Offset(center.dx, center.dy + (point.radius * 1.4)),
          sparklePaint,
        );
      }
    }

    final streakPaint =
        Paint()
          ..shader = const LinearGradient(
            colors: [Colors.transparent, Color(0xAAFFFFFF), Colors.transparent],
          ).createShader(Rect.fromLTWH(size.width * 0.52, size.height * 0.16, size.width * 0.24, size.height * 0.24))
          ..strokeWidth = 1.2
          ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(size.width * 0.56, size.height * 0.29),
      Offset(size.width * 0.7, size.height * 0.17),
      streakPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _CosmicDustPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _CosmicPoint {
  const _CosmicPoint(
    this.position,
    this.radius,
    this.glowAlpha, {
    this.tint,
    this.isTwinkling = false,
    this.twinkleSpeed = 1,
    this.twinklePhase = 0,
  });

  final Offset position;
  final double radius;
  final double glowAlpha;
  final Color? tint;
  final bool isTwinkling;
  final double twinkleSpeed;
  final double twinklePhase;
}

class _NebulaTexturePainter extends CustomPainter {
  const _NebulaTexturePainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final drift = math.sin(progress * math.pi * 2) * 0.024;
    final shimmer = (math.sin((progress * math.pi * 2 * 1.15) + 0.6) + 1) * 0.5;

    final topNebulaPaint =
        Paint()
          ..blendMode = BlendMode.screen
          ..shader = RadialGradient(
            center: Alignment(-0.42 + drift, -0.24),
            radius: 0.92,
            colors: [
              const Color(0x1200F0FF).withValues(alpha: 0.07 + (shimmer * 0.05)),
              const Color(0x1400A2FF).withValues(alpha: 0.08 + (shimmer * 0.05)),
              const Color(0x0A3D1A72).withValues(alpha: 0.03 + (shimmer * 0.025)),
              Colors.transparent,
            ],
            stops: const [0.0, 0.28, 0.62, 1.0],
          ).createShader(Offset.zero & size);

    final topNebulaPath =
        Path()
          ..moveTo(size.width * 0.02, size.height * 0.18)
          ..cubicTo(
            size.width * 0.16,
            size.height * 0.06,
            size.width * 0.4,
            size.height * 0.3,
            size.width * 0.58,
            size.height * 0.14,
          )
          ..cubicTo(
            size.width * 0.8,
            size.height * -0.01,
            size.width * 0.96,
            size.height * 0.18,
            size.width * 0.98,
            size.height * 0.34,
          )
          ..cubicTo(
            size.width * 0.76,
            size.height * 0.3,
            size.width * 0.56,
            size.height * 0.42,
            size.width * 0.28,
            size.height * 0.34,
          )
          ..cubicTo(
            size.width * 0.12,
            size.height * 0.3,
            size.width * 0.04,
            size.height * 0.26,
            size.width * 0.02,
            size.height * 0.18,
          )
          ..close();
    canvas.drawPath(topNebulaPath, topNebulaPaint);

    final bottomNebulaPaint =
        Paint()
          ..blendMode = BlendMode.screen
          ..shader = RadialGradient(
            center: Alignment(0.56 - drift, 0.68),
            radius: 0.78,
            colors: [
              const Color(0x10A9FFF6).withValues(alpha: 0.06 + (shimmer * 0.04)),
              const Color(0x0EA779FF).withValues(alpha: 0.05 + (shimmer * 0.035)),
              const Color(0x08312B55).withValues(alpha: 0.025 + (shimmer * 0.015)),
              Colors.transparent,
            ],
            stops: const [0.0, 0.26, 0.56, 1.0],
          ).createShader(Offset.zero & size);

    final bottomNebulaPath =
        Path()
          ..moveTo(size.width * 0.34, size.height * 0.78)
          ..cubicTo(
            size.width * 0.48,
            size.height * 0.58,
            size.width * 0.7,
            size.height * 0.56,
            size.width * 0.88,
            size.height * 0.68,
          )
          ..cubicTo(
            size.width * 0.94,
            size.height * 0.76,
            size.width * 0.9,
            size.height * 0.88,
            size.width * 0.78,
            size.height * 0.92,
          )
          ..cubicTo(
            size.width * 0.62,
            size.height * 0.95,
            size.width * 0.42,
            size.height * 0.9,
            size.width * 0.34,
            size.height * 0.78,
          )
          ..close();
    canvas.drawPath(bottomNebulaPath, bottomNebulaPaint);

    final shimmerPaint =
        Paint()
          ..color = Colors.white.withValues(alpha: 0.03 + (shimmer * 0.05))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);
    canvas.drawCircle(
      Offset(size.width * (0.76 + (drift * 0.28)), size.height * 0.28),
      11 + (shimmer * 5),
      shimmerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _NebulaTexturePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
