import 'package:flutter/widgets.dart';

/// 진행 중을 나타내는 은은한 빛. [builder]는 0~1 세기를 받아 그림. 움직임 줄이기면 중간 세기로 멈춤
class ArkGlow extends StatefulWidget {
  const ArkGlow({super.key, required this.builder});

  final Widget Function(BuildContext context, double strength) builder;

  @override
  State<ArkGlow> createState() => _ArkGlowState();
}

class _ArkGlowState extends State<ArkGlow> with SingleTickerProviderStateMixin {
  late final AnimationController _glow = AnimationController(vsync: this, duration: const Duration(milliseconds: 1300));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context) || MediaQuery.accessibleNavigationOf(context)) {
      _glow.value = 0.5;
    } else if (!_glow.isAnimating) {
      _glow.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _glow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _glow,
    builder: (context, _) => widget.builder(context, Curves.easeInOut.transform(_glow.value)),
  );
}
