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
import 'package:flutter/physics.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Scene 5 ("CONTRIBUTE") of the open-store intro story: a sparse, editorial text layout
/// inspired by the reference mock, followed by a single CTA once all lines have landed.
class ContributeSceneBody extends StatelessWidget {
  const ContributeSceneBody({super.key, required this.animation, required this.onStartPr});

  final Animation<double> animation;
  final VoidCallback onStartPr;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: height * 0.08),
            _ContributeTypeLine(
              animation: animation,
              entranceInterval: const Interval(0.0341, 0.0511, curve: Curves.easeOutCubic),
              typingInterval: const Interval(0.0511, 0.2500, curve: Curves.linear),
              text: t.ccos.contribute_scene.line1,
              textAlign: TextAlign.left,
              entryOffset: const Offset(-44, 22),
            ),
            const SizedBox(height: 34),
            _ContributeTypeLine(
              animation: animation,
              entranceInterval: const Interval(0.2614, 0.2784, curve: Curves.easeOutCubic),
              typingInterval: const Interval(0.2784, 0.4034, curve: Curves.linear),
              text: t.ccos.contribute_scene.line2,
              textAlign: TextAlign.left,
              entryOffset: const Offset(-40, 18),
            ),
            const SizedBox(height: 34),
            _ContributeTypeLine(
              animation: animation,
              entranceInterval: const Interval(0.4318, 0.4489, curve: Curves.easeOutCubic),
              typingInterval: const Interval(0.4489, 0.7045, curve: Curves.linear),
              text: t.ccos.contribute_scene.line3,
              highlightPhrases: {t.ccos.contribute_scene.highlight_new_feature},
              textAlign: TextAlign.left,
              entryOffset: const Offset(-52, 24),
            ),
            const SizedBox(height: 34),
            _ContributeTypeLine(
              animation: animation,
              entranceInterval: const Interval(0.7273, 0.7443, curve: Curves.easeOutCubic),
              typingInterval: const Interval(0.7443, 0.9205, curve: Curves.linear),
              text: t.ccos.contribute_scene.line4,
              highlightPhrases: {t.ccos.contribute_scene.highlight_bitcoin_standard},
              textAlign: TextAlign.left,
              entryOffset: const Offset(-48, 22),
            ),
            const Spacer(),
            Align(
              alignment: Alignment.centerRight,
              child: _ContributeCtaButton(animation: animation, onTap: onStartPr),
            ),
          ],
        );
      },
    );
  }
}

class _ContributeTypeLine extends StatelessWidget {
  const _ContributeTypeLine({
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

class _ContributeCtaButton extends StatefulWidget {
  const _ContributeCtaButton({required this.animation, required this.onTap});

  final Animation<double> animation;
  final VoidCallback onTap;

  @override
  State<_ContributeCtaButton> createState() => _ContributeCtaButtonState();
}

class _ContributeCtaButtonState extends State<_ContributeCtaButton> with SingleTickerProviderStateMixin {
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
      animation: Listenable.merge([widget.animation, _squashController]),
      builder: (context, child) {
        final entranceT = Curves.easeOutBack.transform(const Interval(0.9350, 1.0).transform(widget.animation.value));
        final squash = _squashController.value;
        final scaleY = squash * entranceT;
        final scaleX = (1 + ((1 - squash) * 0.6)) * entranceT;

        return Opacity(
          opacity: Curves.easeOut.transform(const Interval(0.9200, 0.9850).transform(widget.animation.value)),
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()..scale(scaleX, scaleY),
            child: child,
          ),
        );
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: widget.onTap,
          onTapDown: _handleTapDown,
          onTapUp: _handleTapRelease,
          onTapCancel: _handleTapRelease,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(color: const Color(0xFF10161C), borderRadius: BorderRadius.circular(999)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  t.ccos.contribute_scene.cta_start_first_pr,
                  style: CoconutTypography.body2_14_Bold.setColor(const Color(0xFFCDD4D7)),
                ),
                const SizedBox(width: 8),
                SvgPicture.asset(
                  BrandIconPath.arrowRightLg,
                  width: 20,
                  height: 20,
                  colorFilter: const ColorFilter.mode(Color(0xFFCDD4D7), BlendMode.srcIn),
                ),
              ],
            ),
          ),
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
