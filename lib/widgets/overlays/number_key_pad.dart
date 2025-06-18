import 'package:coconut_wallet/enums/currency_enums.dart';
import 'package:coconut_wallet/widgets/button/key_button.dart';
import 'package:flutter/material.dart';

class NumberKeyPad extends StatelessWidget {
  final BitcoinUnit currentUnit;
  final ValueChanged<String> onKeyTap;
  const NumberKeyPad({
    super.key,
    required this.currentUnit,
    required this.onKeyTap,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      childAspectRatio: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        '1',
        '2',
        '3',
        '4',
        '5',
        '6',
        '7',
        '8',
        '9',
        if (currentUnit == BitcoinUnit.btc) '.' else ' ',
        '0',
        '<',
      ].map((key) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: KeyButton(
            keyValue: key,
            onKeyTap: onKeyTap,
          ),
        );
      }).toList(),
    );
  }
}
