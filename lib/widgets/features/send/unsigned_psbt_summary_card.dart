import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/core/transaction/unsigned_psbt_summary.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:flutter/material.dart';

/// 미서명 PSBT의 요약(보낼 금액/수신 주소/수수료/총비용)을 카드 형태로 표시하는 공용 위젯.
/// BitBox02, Trezor 서명 화면에서 공통으로 사용한다.
class UnsignedPsbtSummaryCard extends StatelessWidget {
  final UnsignedPsbtSummary? summary;
  final BitcoinUnit currentUnit;
  final String title;
  final String sendLabel;
  final String toLabel;
  final String feeLabel;
  final String totalCostLabel;

  const UnsignedPsbtSummaryCard({
    super.key,
    required this.summary,
    required this.currentUnit,
    required this.title,
    required this.sendLabel,
    required this.toLabel,
    required this.feeLabel,
    required this.totalCostLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4.0),
          child: Text(
            title,
            style: CoconutTypography.body2_14_Bold.setColor(context.coconutColors.primaryText),
            textAlign: TextAlign.left,
          ),
        ),
        CoconutLayout.spacing_300h,
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: context.coconutColors.surface,
            borderRadius: BorderRadius.circular(CoconutStyles.radius_200),
          ),
          child: Column(
            children: [
              if (summary != null) ...[
                _buildDetailRow(context, sendLabel, currentUnit.displayBitcoinAmount(summary!.amount, withUnit: true)),
                CoconutLayout.spacing_300h,
                if (summary!.recipientAddresses.isNotEmpty)
                  _buildDetailRow(context, toLabel, summary!.recipientAddresses.join('\n')),
                CoconutLayout.spacing_300h,
                _buildDetailRow(context, feeLabel, currentUnit.displayBitcoinAmount(summary!.fee, withUnit: true)),
                CoconutLayout.spacing_300h,
                _buildDetailRow(
                  context,
                  totalCostLabel,
                  currentUnit.displayBitcoinAmount(summary!.totalCost, withUnit: true),
                ),
              ] else ...[
                _buildDetailRow(
                  context,
                  sendLabel,
                  currentUnit.isPrefixSymbol ? '${currentUnit.symbol} --' : '-- ${currentUnit.symbol}',
                ),
                _buildDetailRow(
                  context,
                  feeLabel,
                  currentUnit.isPrefixSymbol ? '${currentUnit.symbol} --' : '-- ${currentUnit.symbol}',
                ),
              ],
            ],
          ),
        ),
        CoconutLayout.spacing_300h,
      ],
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(label, style: CoconutTypography.body3_12.setColor(context.coconutColors.secondaryText)),
        ),
        Expanded(
          child: Text(
            value,
            style: CoconutTypography.body3_12_NumberBold.setColor(context.coconutColors.primaryText),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}
