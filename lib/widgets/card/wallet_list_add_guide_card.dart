import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:flutter/cupertino.dart';

class WalletListAddGuideCard extends StatefulWidget {
  final VoidCallback onPressed;

  const WalletListAddGuideCard({
    super.key,
    required this.onPressed,
  });

  @override
  State<WalletListAddGuideCard> createState() => _WalletListAddGuideCardState();
}

class _WalletListAddGuideCardState extends State<WalletListAddGuideCard> {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.maxFinite,
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16), color: MyColors.transparentWhite_12),
      margin: const EdgeInsets.symmetric(horizontal: CoconutLayout.defaultPadding),
      padding: const EdgeInsets.only(top: 26, bottom: 24, left: 26, right: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.wallet_list_add_guide_card.add_watch_only,
            style: Styles.title5,
          ),
          Text(
            t.wallet_list_add_guide_card.top_right_icon,
            style: Styles.label,
          ),
          const SizedBox(height: 16),
          CupertinoButton(
            onPressed: widget.onPressed,
            borderRadius: BorderRadius.circular(10),
            padding: EdgeInsets.zero,
            color: MyColors.primary,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 28,
                vertical: 12,
              ),
              child: Text(
                t.wallet_list_add_guide_card.btn_add,
                style: Styles.label.merge(
                  const TextStyle(
                    color: MyColors.black,
                    fontWeight: FontWeight.w700,
                    // fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
