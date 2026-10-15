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

class _AnimatedBalanceState extends State<AnimatedBalance> with SingleTickerProviderStateMixin {
  late AnimationController _balanceAnimController;
  late Animation<double> _balanceAnimation;
  double _displayValue = 0.0;

  @override
  Widget build(BuildContext context) {
    return Text(
      widget.currentUnit.displayBitcoinAmount(_displayValue.toInt()),
      style: widget.textStyle ?? CoconutTypography.heading1_32_NumberBold,
    );
  }

  @override
  void didUpdateWidget(covariant AnimatedBalance oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      _initializeAnimation();
    }
  }

  @override
  void dispose() {
    _balanceAnimController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _balanceAnimController = AnimationController(duration: Duration(milliseconds: widget.duration), vsync: this);

    _initializeAnimation();
  }

  void _initializeAnimation() {
    double startBalance = widget.prevValue.toDouble();
    double endBalance = widget.value.toDouble();

    _balanceAnimation = Tween<double>(
      begin: startBalance,
      end: endBalance,
    ).animate(CurvedAnimation(parent: _balanceAnimController, curve: Curves.easeOutCubic))..addListener(() {
      setState(() {
        _displayValue = _balanceAnimation.value;
      });
    });

    if (startBalance != endBalance) {
      _balanceAnimController.forward(from: 0.0); // 애니메이션의 진행도를 처음부터 다시 시작하기 위함(부드럽게)
    } else {
      _displayValue = endBalance;
    }
  }
}
