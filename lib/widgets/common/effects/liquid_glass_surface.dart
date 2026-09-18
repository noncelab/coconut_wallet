import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// A backdrop-refraction "liquid glass" surface: blurs, tints, and lightly bends whatever is
/// behind [child] near the shape's rounded edges, with an optional soft rim-light glow.
///
/// Backed by `shaders/liquid_glass.frag`, a FragmentShader that only runs on Impeller. On
/// unsupported backends (or before the shader finishes loading) this degrades to a plain
/// tinted blur - no refraction/rim-glow, but never a hard failure or a flash of unstyled glass.
class LiquidGlassSurface extends StatefulWidget {
  const LiquidGlassSurface({
    super.key,
    required this.child,
    required this.cornerRadius,
    required this.blurSigma,
    this.distortion = 0.2,
    this.distortionWidth = 20,
    this.magnification = 1.05,
    this.tintColor = const Color(0x33FFFFFF),
    this.rimColor = Colors.transparent,
    this.rimWidth = 0,
    this.rimOnLeftRight = true,
    this.rimOnTopBottom = true,
  });

  final Widget child;
  final double cornerRadius;
  final double blurSigma;
  final double distortion;
  final double distortionWidth;
  final double magnification;
  final Color tintColor;
  final Color rimColor;
  final double rimWidth;
  // Which sides of the shape carry the rim glow; both true (the default) gives a uniform rim
  // all the way around, blended smoothly through the rounded corners either way.
  final bool rimOnLeftRight;
  final bool rimOnTopBottom;

  @override
  State<LiquidGlassSurface> createState() => _LiquidGlassSurfaceState();
}

class _LiquidGlassSurfaceState extends State<LiquidGlassSurface> {
  static const String _assetKey = 'shaders/liquid_glass.frag';
  static Future<ui.FragmentProgram>? _programFuture;

  static Future<ui.FragmentProgram> _loadProgram() {
    return _programFuture ??= ui.FragmentProgram.fromAsset(_assetKey);
  }

  ui.FragmentShader? _shader;

  @override
  void initState() {
    super.initState();
    _loadProgram().then(
      (program) {
        if (!mounted) return;
        setState(() => _shader = program.fragmentShader());
      },
      onError: (Object _) {
        // Leave _shader null - this instance permanently falls back to a plain tinted blur.
      },
    );
  }

  @override
  void dispose() {
    _shader?.dispose();
    super.dispose();
  }

  bool get _useShader => _shader != null && ui.ImageFilter.isShaderFilterSupported;

  @override
  Widget build(BuildContext context) {
    // TileMode.clamp (the default) is a known source of a visible seam/line artifact through
    // blurred content on Impeller (iOS/Android/macOS) - decal avoids it.
    final blur = ui.ImageFilter.blur(sigmaX: widget.blurSigma, sigmaY: widget.blurSigma, tileMode: TileMode.decal);

    if (!_useShader) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(widget.cornerRadius),
        child: BackdropFilter(
          filter: blur,
          child: Stack(
            fit: StackFit.passthrough,
            children: [Positioned.fill(child: ColoredBox(color: widget.tintColor)), widget.child],
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.cornerRadius),
      // Blur and the refraction/tint/rim shader each get their own BackdropFilter pass rather
      // than being merged into one ImageFilter.compose - composing them into a single filter
      // produced a visible seam down the filtered region's own center on Impeller.
      child: BackdropFilter(filter: blur, child: BackdropFilter(filter: _shaderFilter(context), child: widget.child)),
    );
  }

  ui.ImageFilter _shaderFilter(BuildContext context) {
    final shader = _shader!;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    // Indices 0-1 (uSize, a vec2) are engine-owned - overwritten with the real filtered
    // surface size at render time - so uniform setting starts at index 2.
    shader
      ..setFloat(2, widget.cornerRadius * dpr)
      ..setFloat(3, widget.distortion)
      ..setFloat(4, widget.distortionWidth * dpr)
      ..setFloat(5, widget.magnification)
      ..setFloat(6, widget.tintColor.r)
      ..setFloat(7, widget.tintColor.g)
      ..setFloat(8, widget.tintColor.b)
      ..setFloat(9, widget.tintColor.a)
      ..setFloat(10, widget.rimColor.r)
      ..setFloat(11, widget.rimColor.g)
      ..setFloat(12, widget.rimColor.b)
      ..setFloat(13, widget.rimColor.a)
      ..setFloat(14, widget.rimWidth * dpr)
      ..setFloat(15, widget.rimOnLeftRight ? 1.0 : 0.0)
      ..setFloat(16, widget.rimOnTopBottom ? 1.0 : 0.0);
    return ui.ImageFilter.shader(shader);
  }
}
