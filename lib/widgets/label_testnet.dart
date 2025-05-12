import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:flutter/cupertino.dart';

import '../styles.dart';

class TestnetLabelWidget extends StatelessWidget {
  const TestnetLabelWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: Sizes.size10, left: Sizes.size4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        color: MyColors.cyanblue,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 3,
      ),
      child: Text(
        t.testnet,
        style: Styles.label.merge(
          const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: CoconutColors.white,
          ),
        ),
      ),
    );
  }
}
