import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:flutter/cupertino.dart';

class WalletAdditionGuideCard extends StatefulWidget {
  final VoidCallback onPressed;

  const WalletAdditionGuideCard({
    super.key,
    required this.onPressed,
  });

  @override
  State<WalletAdditionGuideCard> createState() => _WalletAdditionGuideCardState();
}

class _WalletAdditionGuideCardState extends State<WalletAdditionGuideCard> {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.maxFinite,
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(CoconutStyles.radius_400),
          color: CoconutColors.gray800),
      margin: const EdgeInsets.symmetric(horizontal: CoconutLayout.defaultPadding),
      padding: const EdgeInsets.only(top: 26, bottom: 24, left: 26, right: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.wallet_list_add_guide_card.add_watch_only,
            style: CoconutTypography.heading3_21_Bold,
          ),
          Text(
            t.wallet_list_add_guide_card.top_right_icon,
            style: CoconutTypography.body2_14.setColor(CoconutColors.gray400),
          ),
          CoconutLayout.spacing_300h,
          CoconutButton(
            // todo: width 지정 필요 없도록 cds 수정 필요
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
            width: 132,
            onPressed: widget.onPressed,
            text: t.wallet_list_add_guide_card.btn_add,
            backgroundColor: CoconutColors.primary,
            foregroundColor: CoconutColors.black,
            pressedTextColor: CoconutColors.black,
          ),
        ],
      ),
    );
  }
}
