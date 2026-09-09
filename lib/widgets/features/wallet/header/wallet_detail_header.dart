import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/wallet/balance.dart';
import 'package:coconut_wallet/widgets/common/amount/animated_balance.dart';
import 'package:coconut_wallet/widgets/common/amount/bitcoin_amount_unit.dart';
import 'package:coconut_wallet/widgets/common/amount/fiat_price.dart';
import 'package:flutter/cupertino.dart';
import 'package:coconut_wallet/widgets/features/transaction/icon/pending_transaction_lottie_icon.dart';

class WalletDetailHeader extends StatefulWidget {
  final AnimatedBalanceData animatedBalanceData;
  final BitcoinUnit currentUnit;
  final String fiatPrice;
  final int sendingAmount;
  final int receivingAmount;
  final void Function() onPressedUnitToggle;

  const WalletDetailHeader({
    super.key,
    required this.animatedBalanceData,
    required this.currentUnit,
    required this.fiatPrice,
    required this.sendingAmount,
    required this.receivingAmount,
    required this.onPressedUnitToggle,
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
          _buildBalanceInfo(context),
          CoconutLayout.spacing_500h,
          _buildPendingAmountStatus(context),
        ],
      ),
    );
  }

  Widget _buildBalanceInfo(BuildContext context) {
    return GestureDetector(
      onTap: () {
        widget.onPressedUnitToggle();
      },
      child: Column(
        children: [FiatPrice(satoshiAmount: widget.animatedBalanceData.current), _buildBtcBalance(context)],
      ),
    );
  }

  Widget _buildBtcBalance(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: BitcoinAmountUnit(
        currentUnit: widget.currentUnit,
        unitStyle: CoconutTypography.heading4_18_Number.setColor(context.coconutColors.primaryText),
        child: AnimatedBalance(
          prevValue: widget.animatedBalanceData.previous,
          value: widget.animatedBalanceData.current,
          currentUnit: widget.currentUnit,
          textStyle: CoconutTypography.heading2_28_NumberBold.setColor(context.coconutColors.primaryText),
        ),
      ),
    );
  }

  Widget _buildPendingAmountStatus(BuildContext context) {
    String getSendingAmountText() =>
        '${widget.currentUnit.displayBitcoinAmount(widget.sendingAmount, shouldCheckZero: true, withUnit: true)} ${t.status_sending}';
    String getReceivingAmountText() =>
        '${widget.currentUnit.displayBitcoinAmount(widget.receivingAmount, shouldCheckZero: true, withUnit: true)} ${t.status_receiving}';

    return Column(
      children: [
        _buildPendingAmountRow(widget.sendingAmount != 0, false, getSendingAmountText()),
        if (widget.sendingAmount != 0 && widget.receivingAmount != 0) CoconutLayout.spacing_100h,
        _buildPendingAmountRow(widget.receivingAmount != 0, true, getReceivingAmountText()),
      ],
    );
  }

  Widget _buildPendingAmountRow(bool condition, bool isIncoming, String text) {
    if (!condition) return const SizedBox.shrink();

    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          PendingTransactionLottieIcon(isIncoming: isIncoming, size: 12, padding: const EdgeInsets.all(4)),
          CoconutLayout.spacing_200w,
          Text(text, style: CoconutTypography.body2_14_Number.setColor(context.coconutColors.secondaryText)),
        ],
      ),
    );
  }
}
