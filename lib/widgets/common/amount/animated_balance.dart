import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:flutter/material.dart';

class AnimatedBalance extends StatefulWidget {
  final int prevValue;
  final int value;
  final int duration;
  final BitcoinUnit currentUnit;
  final TextStyle? textStyle;

  const AnimatedBalance({
    super.key,
    required this.prevValue,
    required this.value,
    required this.currentUnit,
    this.duration = 1000,
    this.textStyle,
  });

  @override
  State<AnimatedBalance> createState() => _AnimatedBalanceState();
}

class _AnimatedBalanceState extends State<AnimatedBalance> {
  late int _visibleTarget = widget.prevValue;

  @override
  Widget build(BuildContext context) {
    final route = ModalRoute.of(context);
    final returnAnimation = route?.secondaryAnimation;
    if (returnAnimation == null) return _buildAmount(context, visible: true);
    return AnimatedBuilder(
      animation: returnAnimation,
      builder: (context, child) => _buildAmount(context, visible: route!.isCurrent && returnAnimation.isDismissed),
    );
  }

  Widget _buildAmount(BuildContext context, {required bool visible}) {
    // 서명 화면 뒤에서 새 잔액 애니메이션이 끝나지 않도록 복귀할 때 목표값을 갱신한다.
    if (visible && TickerMode.of(context)) _visibleTarget = widget.value;
    final reduceMotion = MediaQuery.disableAnimationsOf(context) || MediaQuery.accessibleNavigationOf(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: widget.prevValue.toDouble(), end: _visibleTarget.toDouble()),
      duration: reduceMotion ? Duration.zero : Duration(milliseconds: widget.duration),
      curve: Curves.easeOutCubic,
      builder:
          (context, amount, child) => Text(
            // 전환 중에는 소수 자릿수를 고정해 숫자가 잘리거나 폭이 매 프레임 바뀌지 않게 한다.
            widget.currentUnit.displayBitcoinAmount(
              amount.toInt(),
              forceEightDecimals: amount.toInt() != _visibleTarget,
            ),
            style: widget.textStyle ?? CoconutTypography.heading1_32_NumberBold,
          ),
    );
  }
}
