import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/model/app/wallet/multisig_signer.dart';
import 'package:coconut_wallet/model/app/wallet/multisig_wallet_list_item.dart';
import 'package:coconut_wallet/model/app/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/utils/colors_util.dart';
import 'package:coconut_wallet/utils/icons_util.dart';
import 'package:coconut_wallet/widgets/button/tooltip_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class WalletInfoItemCard extends StatelessWidget {
  final WalletListItemBase walletItem;
  final VoidCallback onTooltipClicked;
  final GlobalKey tooltipKey;

  const WalletInfoItemCard({
    super.key,
    required this.walletItem,
    required this.onTooltipClicked,
    required this.tooltipKey,
  });

  @override
  Widget build(BuildContext context) {
    List<MultisigSigner>? signers;
    bool isMultisig = false;
    late int colorIndex;
    late int iconIndex;
    late String rightText;
    late String tooltipText;

    if (walletItem is MultisigWalletListItem) {
      /// 멀티 시그
      MultisigWalletListItem multiWallet = walletItem as MultisigWalletListItem;
      signers = multiWallet.signers;
      colorIndex = multiWallet.colorIndex;
      iconIndex = multiWallet.iconIndex;
      rightText = '';
      tooltipText =
          '${multiWallet.requiredSignatureCount}/${multiWallet.signers.length}';
      isMultisig = true;
    } else {
      /// 싱글 시그
      final singlesigWallet = walletItem.walletBase as SingleSignatureWallet;
      colorIndex = walletItem.colorIndex;
      iconIndex = walletItem.iconIndex;
      rightText = singlesigWallet.keyStore.masterFingerprint;
      tooltipText = '지갑 ID';
    }

    return Container(
      decoration: isMultisig
          ? BoxDecoration(
              color: MyColors.black,
              borderRadius: MyBorder.boxDecorationRadius,
              gradient: BoxDecorations.getMultisigLinearGradient(
                  CustomColorHelper.getGradientColors(signers!)),
            )
          : null,
      child: Container(
        margin: isMultisig ? const EdgeInsets.all(2) : const EdgeInsets.all(0),
        padding:
            isMultisig ? const EdgeInsets.all(20) : const EdgeInsets.all(24),
        decoration: isMultisig
            ? BoxDecoration(
                color: MyColors.black,
                borderRadius: BorderRadius.circular(
                    26), // defaultRadius로 통일하면 border 넓이가 균일해보이지 않음
              )
            : BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: MyColors.borderLightgrey, width: 1),
              ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 아이콘
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: BackgroundColorPalette[colorIndex],
                borderRadius: BorderRadius.circular(18),
              ),
              child: SvgPicture.asset(
                CustomIcons.getPathByIndex(iconIndex),
                colorFilter: ColorFilter.mode(
                  ColorPalette[colorIndex],
                  BlendMode.srcIn,
                ),
                width: 24.0,
              ),
            ),
            const SizedBox(width: 8.0),
            // 이름
            Expanded(
              child: Text(
                walletItem.name,
                style: Styles.h3,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(
              width: 8,
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (rightText.isNotEmpty)
                  Text(
                    rightText,
                    style: Styles.h3.merge(TextStyle(
                        fontFamily: CustomFonts.number.getFontFamily)),
                  ),
                TooltipButton(
                  isSelected: false,
                  text: tooltipText,
                  isLeft: true,
                  iconKey: tooltipKey,
                  containerMargin: EdgeInsets.zero,
                  containerPadding: EdgeInsets.zero,
                  iconPadding: const EdgeInsets.only(left: 10),
                  onTap: () {},
                  onTapDown: (details) {
                    onTooltipClicked();
                  },
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
