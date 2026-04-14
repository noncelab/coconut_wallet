import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:flutter/material.dart';

class SendOutputDetailRow extends StatelessWidget {
  final String label;
  final String address;
  final int amountSats;
  final bool isChange;
  final BitcoinUnit currentUnit;

  const SendOutputDetailRow({
    super.key,
    required this.label,
    required this.address,
    required this.amountSats,
    required this.isChange,
    required this.currentUnit,
  });

  @override
  Widget build(BuildContext context) {
    final amountText = currentUnit.displayBitcoinAmount(amountSats, withUnit: true);
    final valueColor = isChange ? CoconutColors.cyan : CoconutColors.white;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(label, style: CoconutTypography.body2_14.setColor(CoconutColors.gray400)),
        ),
        CoconutLayout.spacing_1000w,
        Expanded(
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.0)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const SizedBox(height: 4),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: address),
                      TextSpan(
                        text: ' | ',
                        style: CoconutTypography.body3_12_NumberBold.copyWith(color: CoconutColors.gray700),
                      ),
                      TextSpan(text: amountText),
                    ],
                  ),
                  textAlign: TextAlign.right,
                  style: CoconutTypography.body3_12_NumberBold.copyWith(color: valueColor),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
