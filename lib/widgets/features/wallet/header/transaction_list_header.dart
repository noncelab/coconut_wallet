import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/wallet/balance.dart';
import 'package:coconut_wallet/widgets/common/amount/animated_balance.dart';
import 'package:coconut_wallet/widgets/common/amount/bitcoin_amount_unit.dart';
import 'package:coconut_wallet/widgets/common/amount/fiat_price.dart';
import 'package:coconut_wallet/widgets/features/wallet/amount/wallet_balance_sync_shimmer.dart';
import 'package:flutter/cupertino.dart';
import 'package:coconut_wallet/widgets/features/transaction/icon/pending_transaction_lottie_icon.dart';

class TransactionListHeader extends StatefulWidget {
  final AnimatedBalanceData animatedBalanceData;
  final BitcoinUnit currentUnit;
  final String fiatPrice;
  final int sendingAmount;
  final int receivingAmount;
  final bool isRefreshing;
  final void Function() onPressedUnitToggle;
  final double collapseProgress;

  const TransactionListHeader({
    super.key,
    required this.animatedBalanceData,
    required this.currentUnit,
    required this.fiatPrice,
    required this.sendingAmount,
    required this.receivingAmount,
    required this.isRefreshing,
    required this.onPressedUnitToggle,
    this.collapseProgress = 0,
  });

  @override
  State<TransactionListHeader> createState() => _TransactionListHeaderState();
}

class _TransactionListHeaderState extends State<TransactionListHeader> {
  @override
  Widget build(BuildContext context) {
    final progress = widget.collapseProgress.clamp(0.0, 1.0);
    return ColoredBox(
      color: context.coconutColors.background,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16 + 40 * progress),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildBalanceInfo(context),
            SizedBox(height: 4 * (1 - progress)),
            ClipRect(
              child: Align(
                heightFactor: 1 - progress,
                child: Opacity(opacity: 1 - progress, child: _buildPendingAmountStatus(context)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceInfo(BuildContext context) {
    return GestureDetector(
      onTap: () {
        widget.onPressedUnitToggle();
      },
      child: Column(
        children: [
          FiatPrice(
            satoshiAmount: widget.animatedBalanceData.current,
            textStyle: TextStyle.lerp(
              CoconutTypography.body2_14_Number,
              CoconutTypography.body3_12_Number,
              widget.collapseProgress,
            ),
          ),
          _buildBtcBalance(context),
        ],
      ),
    );
  }

  Widget _buildBtcBalance(BuildContext context) {
    final unitStyle = TextStyle.lerp(
      CoconutTypography.heading4_18_Number,
      CoconutTypography.body2_14_Number,
      widget.collapseProgress,
    )!.setColor(context.coconutColors.primaryText);
    final amountStyle = TextStyle.lerp(
      CoconutTypography.heading2_28_NumberBold,
      CoconutTypography.body1_16_NumberBold.merge(const TextStyle(fontSize: 18)),
      widget.collapseProgress,
    )!.setColor(context.coconutColors.primaryText);
    return WalletBalanceSyncShimmer(
      isRefreshing: widget.isRefreshing,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: BitcoinAmountUnit(
          currentUnit: widget.currentUnit,
          unitStyle: unitStyle,
          child: AnimatedBalance(
            prevValue: widget.animatedBalanceData.previous,
            value: widget.animatedBalanceData.current,
            currentUnit: widget.currentUnit,
            textStyle: amountStyle,
          ),
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
