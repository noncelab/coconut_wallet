import 'package:coconut_design_system/coconut_design_system.dart';
// ignore: implementation_imports
import 'package:coconut_design_system/src/animation/_transition_animation.dart';
import 'package:flutter/material.dart';

extension WidgetAnimationExtensions on Widget {
  Widget fadeInAnimation({
    Key? key,
    Duration duration = const Duration(milliseconds: 220),
    Curve curve = Curves.easeOut,
    bool autoStart = true,
    VoidCallback? onCompleted,
  }) {
    return CoconutFadeInAnimation(
      key: key,
      duration: duration,
      curve: curve,
      autoStart: autoStart,
      onCompleted: onCompleted,
      child: this,
    );
  }

  Widget fadeOutAnimation({
    Key? key,
    Duration duration = const Duration(milliseconds: 220),
    Curve curve = Curves.easeIn,
    bool autoStart = true,
    VoidCallback? onCompleted,
  }) {
    return CoconutFadeOutAnimation(
      key: key,
      duration: duration,
      curve: curve,
      autoStart: autoStart,
      onCompleted: onCompleted,
      child: this,
    );
  }

  Widget bounceInAnimation({
    Key? key,
    Duration duration = const Duration(milliseconds: 420),
    double beginScale = 0.78,
    Curve curve = Curves.elasticOut,
    bool autoStart = true,
    VoidCallback? onCompleted,
  }) {
    return CoconutBounceInAnimation(
      key: key,
      duration: duration,
      beginScale: beginScale,
      curve: curve,
      autoStart: autoStart,
      onCompleted: onCompleted,
      child: this,
    );
  }

  Widget scaleInAnimation({
    Key? key,
    Duration duration = const Duration(milliseconds: 240),
    double beginScale = 0.92,
    Curve curve = Curves.easeOutCubic,
    bool autoStart = true,
    VoidCallback? onCompleted,
  }) {
    return CoconutScaleInAnimation(
      key: key,
      duration: duration,
      beginScale: beginScale,
      curve: curve,
      autoStart: autoStart,
      onCompleted: onCompleted,
      child: this,
    );
  }

  Widget scaleOutAnimation({
    Key? key,
    Duration duration = const Duration(milliseconds: 220),
    double endScale = 0.92,
    Curve curve = Curves.easeInCubic,
    bool autoStart = true,
    VoidCallback? onCompleted,
  }) {
    return CoconutScaleOutAnimation(
      key: key,
      duration: duration,
      endScale: endScale,
      curve: curve,
      autoStart: autoStart,
      onCompleted: onCompleted,
      child: this,
    );
  }

  Widget shakeAnimation({
    Key? key,
    int duration = 500,
    double shakeOffset = 3,
    double shakeAmount = 3,
    Axis direction = Axis.horizontal,
    Curve curve = Curves.linear,
    VoidCallback? onCompleted,
    bool autoStart = false,
  }) {
    return CoconutShakeAnimation(
      key: key,
      duration: duration,
      shakeOffset: shakeOffset,
      shakeAmount: shakeAmount,
      direction: direction,
      curve: curve,
      onCompleted: onCompleted,
      autoStart: autoStart,
      child: this,
    );
  }

  Widget slideDownAnimation({
    Key? key,
    Duration duration = const Duration(milliseconds: 280),
    Offset offset = const Offset(0, -24),
    Curve curve = Curves.easeOutCubic,
    bool autoStart = true,
    VoidCallback? onCompleted,
  }) {
    return CoconutSlideDownAnimation(
      key: key,
      duration: duration,
      offset: offset,
      curve: curve,
      autoStart: autoStart,
      onCompleted: onCompleted,
      child: this,
    );
  }

  Widget slideLeftAnimation({
    Key? key,
    Duration duration = const Duration(milliseconds: 280),
    Offset offset = const Offset(24, 0),
    Curve curve = Curves.easeOutCubic,
    bool autoStart = true,
    VoidCallback? onCompleted,
  }) {
    return CoconutSlideLeftAnimation(
      key: key,
      duration: duration,
      offset: offset,
      curve: curve,
      autoStart: autoStart,
      onCompleted: onCompleted,
      child: this,
    );
  }

  Widget slideRightAnimation({
    Key? key,
    Duration duration = const Duration(milliseconds: 280),
    Offset offset = const Offset(-24, 0),
    Curve curve = Curves.easeOutCubic,
    bool autoStart = true,
    VoidCallback? onCompleted,
  }) {
    return CoconutSlideRightAnimation(
      key: key,
      duration: duration,
      offset: offset,
      curve: curve,
      autoStart: autoStart,
      onCompleted: onCompleted,
      child: this,
    );
  }

  Widget slideUpAnimation({
    Key? key,
    Duration duration = const Duration(milliseconds: 280),
    Offset offset = const Offset(0, 24),
    Curve curve = Curves.easeOutCubic,
    bool autoStart = true,
    VoidCallback? onCompleted,
  }) {
    return CoconutSlideUpAnimation(
      key: key,
      duration: duration,
      offset: offset,
      curve: curve,
      autoStart: autoStart,
      onCompleted: onCompleted,
      child: this,
    );
  }

  Widget transitionAnimation({
    Key? key,
    required Offset beginOffset,
    Offset endOffset = Offset.zero,
    required double beginOpacity,
    required double endOpacity,
    required double beginScale,
    required double endScale,
    required Curve curve,
    required Duration duration,
    Alignment alignment = Alignment.center,
    bool autoStart = true,
    VoidCallback? onCompleted,
  }) {
    return CoconutTransitionAnimation(
      key: key,
      beginOffset: beginOffset,
      endOffset: endOffset,
      beginOpacity: beginOpacity,
      endOpacity: endOpacity,
      beginScale: beginScale,
      endScale: endScale,
      curve: curve,
      duration: duration,
      alignment: alignment,
      autoStart: autoStart,
      onCompleted: onCompleted,
      child: this,
    );
  }

  Widget zoomInAnimation({
    Key? key,
    Duration duration = const Duration(milliseconds: 260),
    double beginScale = 0.72,
    Curve curve = Curves.easeOutBack,
    bool autoStart = true,
    VoidCallback? onCompleted,
  }) {
    return CoconutZoomInAnimation(
      key: key,
      duration: duration,
      beginScale: beginScale,
      curve: curve,
      autoStart: autoStart,
      onCompleted: onCompleted,
      child: this,
    );
  }

  Widget zoomOutAnimation({
    Key? key,
    Duration duration = const Duration(milliseconds: 220),
    double endScale = 0.64,
    Curve curve = Curves.easeInBack,
    bool autoStart = true,
    VoidCallback? onCompleted,
  }) {
    return CoconutZoomOutAnimation(
      key: key,
      duration: duration,
      endScale: endScale,
      curve: curve,
      autoStart: autoStart,
      onCompleted: onCompleted,
      child: this,
    );
  }

  Widget bounceOutAnimation({
    Key? key,
    Duration duration = const Duration(milliseconds: 280),
    double endScale = 0.7,
    Curve curve = Curves.easeInBack,
    bool autoStart = true,
    VoidCallback? onCompleted,
  }) {
    return CoconutBounceOutAnimation(
      key: key,
      duration: duration,
      endScale: endScale,
      curve: curve,
      autoStart: autoStart,
      onCompleted: onCompleted,
      child: this,
    );
  }
}

extension StringAnimationExtensions on String {
  Widget typewriterAnimation({
    Key? key,
    TextStyle? textStyle,
    TextAlign? textAlign,
    int? maxLines,
    TextOverflow? overflow,
    Duration duration = const Duration(milliseconds: 800),
    Curve curve = Curves.linear,
    bool autoStart = true,
    VoidCallback? onCompleted,
  }) {
    return CoconutTypewriterAnimation(
      key: key,
      text: this,
      textStyle: textStyle,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
      duration: duration,
      curve: curve,
      autoStart: autoStart,
      onCompleted: onCompleted,
    );
  }

  Widget characterFadeInAnimation({
    Key? key,
    TextStyle? textStyle,
    TextAlign? textAlign,
    int? maxLines,
    TextOverflow? overflow,
    Duration duration = const Duration(milliseconds: 1200),
    Curve curve = Curves.easeOut,
    bool autoStart = true,
    double fadePortion = 0.45,
    CoconutCharacterFadeSlideDirection slideDirection = CoconutCharacterFadeSlideDirection.none,
    double slideOffset = 8,
    VoidCallback? onCompleted,
  }) {
    return CoconutCharacterFadeInAnimation(
      key: key,
      text: this,
      textStyle: textStyle,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
      duration: duration,
      curve: curve,
      autoStart: autoStart,
      fadePortion: fadePortion,
      slideDirection: slideDirection,
      slideOffset: slideOffset,
      onCompleted: onCompleted,
    );
  }

  Widget characterFadeOutAnimation({
    Key? key,
    TextStyle? textStyle,
    TextAlign? textAlign,
    int? maxLines,
    TextOverflow? overflow,
    Duration duration = const Duration(milliseconds: 1200),
    Curve curve = Curves.easeIn,
    bool autoStart = true,
    double fadePortion = 0.45,
    CoconutCharacterFadeSlideDirection slideDirection = CoconutCharacterFadeSlideDirection.none,
    double slideOffset = 8,
    VoidCallback? onCompleted,
  }) {
    return CoconutCharacterFadeOutAnimation(
      key: key,
      text: this,
      textStyle: textStyle,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
      duration: duration,
      curve: curve,
      autoStart: autoStart,
      fadePortion: fadePortion,
      slideDirection: slideDirection,
      slideOffset: slideOffset,
      onCompleted: onCompleted,
    );
  }
}
