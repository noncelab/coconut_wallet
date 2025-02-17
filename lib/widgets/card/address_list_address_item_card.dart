import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:flutter/cupertino.dart';

class AddressItemCard extends StatelessWidget {
  final VoidCallback onPressed;

  final String address;
  final String derivationPath;
  final bool isUsed;
  final int? balanceInSats;
  const AddressItemCard(
      {super.key,
      required this.onPressed,
      required this.address,
      required this.derivationPath,
      required this.isUsed,
      this.balanceInSats});

  @override
  Widget build(BuildContext context) {
    var path = derivationPath.split('/');
    var index = path[path.length - 1];

    return CupertinoButton(
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: MyBorder.defaultRadius,
          color: MyColors.transparentWhite_15,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        margin: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: MyColors.transparentBlack_50),
                child: Text(index, style: Styles.caption)),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${address.substring(0, 10)}...${address.substring(address.length - 10, address.length)}',
                  style: Styles.body1Number,
                ),
                const SizedBox(height: 4),
                Text(
                    balanceInSats == null
                        ? ''
                        : '${satoshiToBitcoinString(balanceInSats!)} BTC',
                    style: Styles.label.merge(TextStyle(
                        fontFamily: CustomFonts.number.getFontFamily,
                        fontWeight: FontWeight.normal,
                        color: MyColors.transparentWhite_50)))
              ],
            ),
            const Spacer(),
            CoconutChip(
              color: CoconutColors.white.withOpacity(0.15),
              borderWidth: 0,
              child: Text(
                isUsed ? t.status_used : t.status_unused,
                style: CoconutTypography.caption_10.copyWith(
                  color:
                      isUsed ? MyColors.primary : MyColors.transparentWhite_70,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
