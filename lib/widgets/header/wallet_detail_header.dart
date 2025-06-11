import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/enums/currency_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/wallet/balance.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:coconut_wallet/widgets/animated_balance.dart';
import 'package:coconut_wallet/widgets/contents/fiat_price.dart';
import 'package:flutter/cupertino.dart';
import 'package:lottie/lottie.dart';

class WalletDetailHeader extends StatefulWidget {
  final AnimatedBalanceData animatedBalanceData;
  final BitcoinUnit currentUnit;
  final String btcPriceInKrw;
  final int sendingAmount;
  final int receivingAmount;
  final void Function() onPressedUnitToggle;
  final void Function() onTapReceive;
  final void Function() onTapSend;

  const WalletDetailHeader({
    super.key,
    required this.animatedBalanceData,
    required this.currentUnit,
    required this.btcPriceInKrw,
    required this.sendingAmount,
    required this.receivingAmount,
    required this.onPressedUnitToggle,
    required this.onTapReceive,
    required this.onTapSend,
  });

  @override
  State<WalletDetailHeader> createState() => _WalletDetailHeaderState();
}

class _WalletDetailHeaderState extends State<WalletDetailHeader> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CoconutLayout.spacing_800h,
          _buildBalanceInfo(),
          CoconutLayout.spacing_200h,
          _buildPendingAmountStatus(),
          CoconutLayout.spacing_500h,
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildBalanceInfo() {
    return GestureDetector(
      onTap: () {
        widget.onPressedUnitToggle();
      },
      child: Column(
        children: [
          FiatPrice(satoshiAmount: widget.animatedBalanceData.current),
          _buildBtcBalance(),
        ],
      ),
    );
  }

  Widget _buildBtcBalance() {
    return SizedBox(
      height: 36,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBalance(
            prevValue: widget.animatedBalanceData.previous,
            value: widget.animatedBalanceData.current,
            isBtcUnit: widget.currentUnit == BitcoinUnit.btc,
          ),
          const SizedBox(width: 4.0),
          Text(
            widget.currentUnit == BitcoinUnit.btc ? t.btc : t.sats,
            style: CoconutTypography.heading4_18_Number.setColor(CoconutColors.gray350),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingAmountStatus() {
    String getUnitText() => widget.currentUnit == BitcoinUnit.btc ? t.btc : t.sats;
    String getSendingAmountText() {
      if (widget.sendingAmount == 0) return '';
      return '${widget.currentUnit == BitcoinUnit.btc ? satoshiToBitcoinString(widget.sendingAmount) : addCommasToIntegerPart(widget.sendingAmount.toDouble())} ${getUnitText()} ${t.status_sending}';
    }

    String getReceivingAmountText() {
      if (widget.receivingAmount == 0) return '';
      return '${widget.currentUnit == BitcoinUnit.btc ? satoshiToBitcoinString(widget.receivingAmount) : addCommasToIntegerPart(widget.receivingAmount.toDouble())} ${getUnitText()} ${t.status_receiving}';
    }

    return Column(
      children: [
        _buildPendingAmountRow(
          widget.sendingAmount != 0,
          'assets/lottie/arrow-up.json',
          getSendingAmountText(),
          CoconutColors.primary.withOpacity(0.2),
        ),
        CoconutLayout.spacing_100h,
        _buildPendingAmountRow(
          widget.receivingAmount != 0,
          'assets/lottie/arrow-down.json',
          getReceivingAmountText(),
          CoconutColors.cyan.withOpacity(0.2),
        ),
      ],
    );
  }

  Widget _buildPendingAmountRow(bool condition, String animationPath, String text, Color color) {
    if (!condition) return const SizedBox.shrink();

    return SizedBox(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10.0),
              color: color,
            ),
            child: Lottie.asset(animationPath, width: 12, height: 12),
          ),
          CoconutLayout.spacing_200w,
          Text(
            text,
            style: CoconutTypography.body2_14_Number.setColor(CoconutColors.gray200),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        _buildActionButton(
            widget.onTapReceive, t.receive, CoconutColors.white, CoconutColors.black),
        const SizedBox(width: 12.0),
        _buildActionButton(widget.onTapSend, t.send, CoconutColors.primary, CoconutColors.black),
      ],
    );
  }

  Widget _buildActionButton(
      void Function() onTap, String label, Color backgroundColor, Color textColor) {
    return Expanded(
      child: CoconutButton(
        onPressed: onTap,
        backgroundColor: backgroundColor,
        buttonType: CoconutButtonType.filled,
        text: label,
        foregroundColor: textColor,
      ),
    );
  }
}
