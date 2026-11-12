import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/constants/lottie_path.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/utils/vibration_util.dart';
import 'package:coconut_wallet/widgets/common/amount/fiat_price.dart';
import 'package:coconut_wallet/widgets/common/buttons/fixed_bottom_button.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

/// A payment arrived while the receive screen was open: the send flow's "Transaction Sent" screen
/// with "Received" and the amount where that screen has its memo. An on-chain payment says it's
/// waiting for its confirmation. Confirm closes it.
class ReceiveCompleteScreen extends StatefulWidget {
  const ReceiveCompleteScreen({super.key, required this.amountSats, required this.unit, this.isUnconfirmed = false});

  final int amountSats;
  final BitcoinUnit unit;
  final bool isUnconfirmed;

  @override
  State<ReceiveCompleteScreen> createState() => _ReceiveCompleteScreenState();
}

class _ReceiveCompleteScreenState extends State<ReceiveCompleteScreen> with SingleTickerProviderStateMixin {
  /// Where the broadcast screen's check stops swinging and starts drawing the tick.
  static const _checkStart = 22 / 60;

  late final AnimationController _lottie = AnimationController(vsync: this, value: _checkStart);

  @override
  void initState() {
    super.initState();
    vibrateLight();
  }

  @override
  void dispose() {
    _lottie.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final height = MediaQuery.sizeOf(context).height;
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: colors.background,
        body: SafeArea(
          child: Stack(
            children: [
              SizedBox(
                width: double.infinity,
                child: Column(
                  children: [
                    SizedBox(height: height * 0.3),
                    Lottie.asset(
                      TransactionLottiePath.checkSpinning,
                      controller: _lottie,
                      width: 70,
                      height: 70,
                      repeat: false,
                      onLoaded: (composition) {
                        _lottie.duration = composition.duration;
                        _lottie.forward(from: _checkStart);
                      },
                    ),
                    CoconutLayout.spacing_400h,
                    Text(
                      t.ark.receive.received_title,
                      style: CoconutTypography.heading4_18_Bold.setColor(colors.primaryText),
                    ),
                    CoconutLayout.spacing_400h,
                    _buildAmount(context),
                    if (widget.isUnconfirmed) ...[
                      CoconutLayout.spacing_300h,
                      Text(
                        t.ark.receive.waiting_confirmation,
                        style: CoconutTypography.body3_12.setColor(colors.secondaryText),
                      ),
                    ],
                  ],
                ),
              ),
              FixedBottomButton(
                showSurroundings: false,
                isVisibleAboveKeyboard: false,
                onButtonClicked: () => Navigator.pop(context),
                text: t.confirm,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The amount as the transaction detail screen shows a receipt: signed, in the receiving colour,
  /// with its fiat value.
  Widget _buildAmount(BuildContext context) {
    final color = context.coconutColors.receivingColor;
    final unit = widget.unit;
    final boldStyle = CoconutTypography.heading2_28_NumberBold.copyWith(fontSize: 24, color: color);
    final unitStyle = CoconutTypography.heading4_18_NumberBold.copyWith(color: color);
    final amount = unit.displayBitcoinAmount(widget.amountSats);
    return Column(
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children:
                unit.isPrefixSymbol
                    ? [
                      Text('+', style: boldStyle),
                      Text(unit.symbol, style: unitStyle),
                      CoconutLayout.spacing_50w,
                      Text(amount, style: boldStyle),
                    ]
                    : [
                      Text('+$amount', style: boldStyle),
                      CoconutLayout.spacing_50w,
                      Text(unit.symbol, style: unitStyle),
                    ],
          ),
        ),
        CoconutLayout.spacing_100h,
        FiatPrice(
          satoshiAmount: widget.amountSats,
          textStyle: CoconutTypography.body2_14_Number.setColor(color.withValues(alpha: 0.7)),
        ),
      ],
    );
  }
}
