import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/extensions/string_extensions.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
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
    return Text(_displayAmount, style: widget.textStyle ?? CoconutTypography.heading1_32_NumberBold);
  }

  String get _displayAmount {
    final displayValue = _displayValue.toInt();
    if (!widget.currentUnit.isBtcUnit) {
      return widget.currentUnit.displayBitcoinAmount(displayValue);
    }

    final fractionDigits = _targetBtcFractionDigits;
    if (fractionDigits == 0) {
      return (displayValue ~/ 100000000).toString().toBtcDisplayString();
    }

    return UnitUtil.convertSatoshiToBitcoin(displayValue).toStringAsFixed(fractionDigits).toBtcDisplayString();
  }

  int get _targetBtcFractionDigits {
    final fixedAmount = UnitUtil.convertSatoshiToBitcoinString(widget.value.abs());
    final fraction = fixedAmount.split('.').last.replaceFirst(RegExp(r'0+$'), '');

    // 기존 BTC 표시 규칙은 소수부가 4자리를 넘으면 8자리 전체를 표시한다.
    return fraction.length > 4 ? 8 : fraction.length;
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
