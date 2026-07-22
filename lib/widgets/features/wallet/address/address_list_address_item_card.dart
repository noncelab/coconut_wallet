import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:flutter/cupertino.dart';

class AddressItemCard extends StatelessWidget {
  final VoidCallback onPressed;

  final String address;
  final String derivationPath;
  final bool isUsed;
  final int? balanceInSats;
  final BitcoinUnit currentUnit;
  const AddressItemCard({
    super.key,
    required this.onPressed,
    required this.address,
    required this.derivationPath,
    required this.isUsed,
    required this.currentUnit,
    this.balanceInSats,
  });

  @override
  Widget build(BuildContext context) {
    var path = derivationPath.split('/');
    var index = path[path.length - 1];

    return CupertinoButton(
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      pressedOpacity: 0.8,
      child: Container(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), color: context.coconutColors.surfaceCard),
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
                color: context.coconutColors.surfaceDeep,
              ),
              child: Text(index, style: CoconutTypography.body3_12_Number.setColor(context.coconutColors.secondaryText)),
            ),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${address.substring(0, 10)}...${address.substring(address.length - 10, address.length)}',
                      style: CoconutTypography.body1_16_Number.setColor(context.coconutColors.primaryText),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      currentUnit.displayBitcoinAmount(balanceInSats, withUnit: true),
                      style: CoconutTypography.body2_14_Number.copyWith(
                        fontWeight: FontWeight.w500,
                        color: context.coconutColors.mutedText,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            CoconutLayout.spacing_200w,
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: context.coconutColors.infoChipBackground,
              ),
              child: Text(
                isUsed ? t.status_used : t.status_unused,
                style: CoconutTypography.caption_10.setColor(
                  isUsed ? context.coconutColors.textHighlight : context.coconutColors.secondaryText,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
