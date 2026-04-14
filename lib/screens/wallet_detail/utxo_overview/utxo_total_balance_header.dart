import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/utils/utxo_amount_format_util.dart';
import 'package:flutter/material.dart';

class UtxoTotalBalanceHeader extends StatelessWidget {
  final int coinCount;
  final int totalSats;
  final BitcoinUnit currentUnit;
  final int dustThreshold;
  final VoidCallback? onBalanceTap;

  const UtxoTotalBalanceHeader({
    super.key,
    required this.coinCount,
    required this.totalSats,
    required this.currentUnit,
    required this.dustThreshold,
    this.onBalanceTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(t.utxo_list_screen.total_balance, style: CoconutTypography.body2_14_Bold.setColor(CoconutColors.gray400)),
        GestureDetector(
          onTap: onBalanceTap,
          behavior: HitTestBehavior.opaque,
          child: Text(
            '$coinCount coins • ${formatUtxoAmountForDisplay(totalSats, currentUnit, dustThreshold: dustThreshold)}',
            style: CoconutTypography.heading4_18_NumberBold.setColor(CoconutColors.white),
          ),
        ),
      ],
    );
  }
}
