import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/screens/wallet_detail/wallet_detail_screen.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:flutter/cupertino.dart';
import 'package:lottie/lottie.dart';

class WalletDetailHeader extends StatelessWidget {
  final int? balance;
  final Unit currentUnit;
  final String btcPriceInKrw;
  final int sendingAmount;
  final int receivingAmount;
  final void Function() onPressedUnitToggle;
  final void Function() onTapReceive;
  final void Function() onTapSend;

  const WalletDetailHeader({
    super.key,
    required this.balance,
    required this.currentUnit,
    required this.btcPriceInKrw,
    required this.sendingAmount,
    required this.receivingAmount,
    required this.onPressedUnitToggle,
    required this.onTapReceive,
    required this.onTapSend,
  });

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
        if (balance != null) onPressedUnitToggle();
      },
      child: Column(
        children: [
          _buildFiatPriceInfo(),
          _buildBtcBalance(),
        ],
      ),
    );
  }

  Widget _buildFiatPriceInfo() {
    return SizedBox(
      height: 20,
      child: Text(
        balance != null ? btcPriceInKrw : '-',
        style:
            CoconutTypography.body3_12_Number.setColor(CoconutColors.gray350),
      ),
    );
  }

  Widget _buildBtcBalance() {
    return SizedBox(
      height: 36,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            balance == null
                ? '-'
                : currentUnit == Unit.btc
                    ? satoshiToBitcoinString(balance!)
                    : addCommasToIntegerPart(balance!.toDouble()),
            style: CoconutTypography.heading1_32_NumberBold,
          ),
          const SizedBox(width: 4.0),
          Text(
            currentUnit == Unit.btc ? t.btc : t.sats,
            style: CoconutTypography.heading4_18_Number
                .setColor(CoconutColors.gray350),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingAmountStatus() {
    return Column(
      children: [
        _buildPendingAmountRow(
          sendingAmount != 0,
          'assets/lottie/arrow-up.json',
          sendingAmount != 0
              ? '${t.bitcoin_text(bitcoin: satoshiToBitcoinString(sendingAmount))} ${t.status_sending}'
              : '',
          CoconutColors.primary.withOpacity(0.2),
        ),
        _buildPendingAmountRow(
          receivingAmount != 0,
          'assets/lottie/arrow-down.json',
          receivingAmount != 0
              ? '${t.bitcoin_text(bitcoin: satoshiToBitcoinString(receivingAmount))} ${t.status_receiving}'
              : '',
          CoconutColors.cyan.withOpacity(0.2),
        ),
      ],
    );
  }

  Widget _buildPendingAmountRow(
      bool condition, String animationPath, String text, Color color) {
    if (!condition) return const SizedBox.shrink();

    return SizedBox(
      height: 20,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10.0),
              color: color,
            ),
            child: Lottie.asset(animationPath, width: 20, height: 20),
          ),
          CoconutLayout.spacing_200w,
          Text(
            text,
            style: CoconutTypography.body2_14_Number
                .setColor(CoconutColors.gray200),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        _buildActionButton(
            onTapReceive, t.receive, CoconutColors.white, CoconutColors.black),
        const SizedBox(width: 12.0),
        _buildActionButton(
            onTapSend, t.send, CoconutColors.primary, CoconutColors.black),
      ],
    );
  }

  Widget _buildActionButton(void Function() onTap, String label,
      Color backgroundColor, Color textColor) {
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
