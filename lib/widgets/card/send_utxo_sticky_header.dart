import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/enums/currency_enums.dart';
import 'package:coconut_wallet/enums/transaction_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/view_model/send/send_utxo_selection_view_model.dart';
import 'package:coconut_wallet/screens/send/send_utxo_selection_screen.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:coconut_wallet/widgets/button/custom_underlined_button.dart';
import 'package:coconut_wallet/widgets/contents/fiat_price.dart';
import 'package:flutter/material.dart';

class SendUtxoStickyHeader extends StatelessWidget {
  final ErrorState? errorState;
  final RecommendedFeeFetchStatus recommendedFeeFetchStatus;
  final TransactionFeeLevel? selectedLevel;
  final VoidCallback onTapFeeButton;
  final VoidCallback onPressedUnitToggle;
  final BitcoinUnit currentUnit;
  final bool isMaxMode;
  final bool customFeeSelected;
  final int sendAmount;
  final int? estimatedFee;
  final int? satsPerVb;
  final int? change;

  const SendUtxoStickyHeader({
    super.key,
    required this.errorState,
    required this.recommendedFeeFetchStatus,
    this.selectedLevel = TransactionFeeLevel.halfhour,
    required this.onTapFeeButton,
    required this.isMaxMode,
    required this.customFeeSelected,
    required this.sendAmount,
    required this.estimatedFee,
    required this.satsPerVb,
    required this.change,
    required this.currentUnit,
    required this.onPressedUnitToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildAmountRow(context),
        _divider(),
        _buildFeeRow(),
        _divider(),
        _buildChangeRow(),
      ],
    );
  }

  Widget _buildAmountRow(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t.send_amount, style: CoconutTypography.body2_14_Bold),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (isMaxMode) _buildMaxBadge(),
              _buildAmountText(context),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMaxBadge() {
    return Container(
      padding: const EdgeInsets.only(bottom: 2),
      margin: const EdgeInsets.only(right: 4, bottom: 16),
      height: 24,
      width: 34,
      decoration: BoxDecoration(
        color: CoconutColors.gray700,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Text(t.max, style: CoconutTypography.caption_10),
      ),
    );
  }

  Widget _buildAmountText(BuildContext context) {
    return GestureDetector(
      onTap: onPressedUnitToggle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
              currentUnit == BitcoinUnit.btc
                  ? "${satoshiToBitcoinString(sendAmount).normalizeToFullCharacters()} ${t.btc}"
                  : "${addCommasToIntegerPart(sendAmount.toDouble())} ${t.sats}",
              style: CoconutTypography.body2_14_Number),
          FiatPrice(
            satoshiAmount: sendAmount,
            textStyle: CoconutTypography.body3_12_Number,
            textColor: CoconutColors.gray500,
          ),
        ],
      ),
    );
  }

  Widget _buildFeeRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.fee, style: CoconutTypography.body2_14_Bold),
            _buildModifyButton(),
          ],
        ),
        Expanded(child: _buildFeeInfo()),
      ],
    );
  }

  Widget _buildModifyButton() {
    return CustomUnderlinedButton(
      text: t.modify,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      isEnable: recommendedFeeFetchStatus != RecommendedFeeFetchStatus.fetching,
      onTap: onTapFeeButton,
    );
  }

  Widget _buildFeeInfo() {
    if (recommendedFeeFetchStatus == RecommendedFeeFetchStatus.failed && !customFeeSelected) {
      return _buildPlaceholderFee();
    } else if (recommendedFeeFetchStatus == RecommendedFeeFetchStatus.succeed ||
        customFeeSelected) {
      return _buildEstimatedFee();
    } else {
      return _buildLoadingIndicator();
    }
  }

  String get unitText => currentUnit == BitcoinUnit.btc ? t.btc : t.sats;
  String get feeText => estimatedFee != null
      ? currentUnit == BitcoinUnit.btc
          ? satoshiToBitcoinString(estimatedFee!)
          : addCommasToIntegerPart(estimatedFee!.toDouble())
      : '0';
  String get changeText => change != null
      ? currentUnit == BitcoinUnit.btc
          ? satoshiToBitcoinString(change!)
          : addCommasToIntegerPart(change!.toDouble())
      : '-';

  Widget _buildEstimatedFee() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          "$feeText $unitText",
          style: CoconutTypography.body2_14_Number,
        ),
        if (satsPerVb != null && !customFeeSelected)
          Text(
              '${selectedLevel?.expectedTime ?? ''} ($satsPerVb ${satsPerVb == 1 ? 'sat' : 'sats'}/vb)',
              style: CoconutTypography.body3_12_Number.setColor(CoconutColors.gray500)),
      ],
    );
  }

  Widget _buildLoadingIndicator() {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        SizedBox(
          width: 15,
          height: 15,
          child: CircularProgressIndicator(
            color: CoconutColors.white,
            strokeWidth: 2,
          ),
        ),
      ],
    );
  }

  Widget _buildPlaceholderFee() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text('- $unitText',
            style: CoconutTypography.body2_14_Number.setColor(CoconutColors.gray400)),
      ],
    );
  }

  Widget _buildChangeRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t.change,
          style: CoconutTypography.body2_14_Bold.setColor(
            change != null
                ? (change! >= 0 ? CoconutColors.white : CoconutColors.hotPink)
                : CoconutColors.gray400,
          ),
        ),
        Expanded(
          child: Text(
            "$changeText $unitText",
            textAlign: TextAlign.end,
            style: CoconutTypography.body2_14_Number.setColor(
              change != null
                  ? (change! >= 0 ? CoconutColors.white : CoconutColors.hotPink)
                  : CoconutColors.gray400,
            ),
          ),
        ),
      ],
    );
  }

  Widget _divider({EdgeInsets padding = const EdgeInsets.symmetric(vertical: 12)}) => Container(
        padding: padding,
        child: const Divider(
          height: 1,
          color: CoconutColors.gray700,
        ),
      );
}
