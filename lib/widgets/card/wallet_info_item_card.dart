import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/wallet/multisig_signer.dart';
import 'package:coconut_wallet/model/wallet/multisig_wallet_list_item.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/screens/wallet_detail/wallet_info_edit_bottom_sheet.dart';
import 'package:coconut_wallet/utils/colors_util.dart';
import 'package:coconut_wallet/widgets/button/tooltip_button.dart';
import 'package:coconut_wallet/widgets/icon/wallet_icon.dart';
import 'package:flutter/material.dart';

import 'dart:math' as math;

import 'package:flutter_svg/svg.dart';

class WalletInfoItemCard extends StatefulWidget {
  final int id;
  final WalletListItemBase walletItem;
  final VoidCallback onTooltipClicked;
  final GlobalKey tooltipKey;
  final Function(String) onNameChanged;

  const WalletInfoItemCard({
    super.key,
    required this.id,
    required this.walletItem,
    required this.onTooltipClicked,
    required this.tooltipKey,
    required this.onNameChanged,
  });

  @override
  State<WalletInfoItemCard> createState() => _WalletInfoItemCardState();
}

class _WalletInfoItemCardState extends State<WalletInfoItemCard> {
  List<MultisigSigner>? signers;
  bool isMultisig = false;
  late int colorIndex;
  late int iconIndex;
  late String rightText;
  late String tooltipText;
  late String nameText;
  late WalletListItemBase walletItem;
  WalletImportSource? walletImportSource;

  bool isItemTapped = false; // ui (edit 아이콘)

  @override
  void initState() {
    super.initState();
    walletItem = widget.walletItem;
    if (walletItem is MultisigWalletListItem) {
      /// 멀티 시그
      MultisigWalletListItem multiWallet = walletItem as MultisigWalletListItem;
      signers = multiWallet.signers;
      colorIndex = multiWallet.colorIndex;
      iconIndex = multiWallet.iconIndex;
      rightText = '';
      tooltipText = '${multiWallet.requiredSignatureCount}/${multiWallet.signers.length}';
      isMultisig = true;
    } else {
      /// 싱글 시그
      final singlesigWallet = walletItem.walletBase as SingleSignatureWallet;
      colorIndex = widget.walletItem.colorIndex;
      iconIndex = widget.walletItem.iconIndex;
      rightText = singlesigWallet.keyStore.masterFingerprint;
      tooltipText = t.wallet_id;
      walletImportSource = widget.walletItem.walletImportSource;
    }
    nameText = walletItem.name;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24), // defaultRadius로 통일하면 border 넓이가 균일해보이지 않음
        border: isMultisig ? null : Border.all(color: CoconutColors.gray700, width: 1),
        gradient:
            isMultisig
                ? LinearGradient(
                  colors: ColorUtil.getGradientColors(signers!),
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  transform: const GradientRotation(math.pi / 10),
                )
                : null,
      ),
      child: Container(
        margin: isMultisig ? const EdgeInsets.all(2) : null, // 멀티시그의 경우 border 대신
        padding: const EdgeInsets.all(20),
        decoration:
            isMultisig
                ? BoxDecoration(
                  color: CoconutColors.black,
                  borderRadius: BorderRadius.circular(22), // defaultRadius로 통일하면 border 넓이가 균일해보이지 않음
                )
                : null,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 아이콘
            // TODO: 만약 멀티시그의 외부지갑도 지원하게 된다면 이 부분 수정해야합니다.
            Expanded(
              child: GestureDetector(
                onTapDown: (details) {
                  setState(() {
                    isItemTapped = true;
                  });
                },
                onTapCancel: () {
                  setState(() {
                    isItemTapped = false;
                  });
                },
                onTap: () {
                  setState(() {
                    isItemTapped = false;
                  });
                  _onTap(context, walletImportSource);
                },
                child: Row(
                  children: [
                    _buildIcon(),

                    CoconutLayout.spacing_200w,
                    // 이름
                    Expanded(
                      child: Text(
                        nameText,
                        style: CoconutTypography.heading4_18_Bold.setColor(CoconutColors.white),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            CoconutLayout.spacing_200w,
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (rightText.isNotEmpty)
                  LayoutBuilder(
                    builder: (context, constraints) {
                      return ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 120),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(
                            rightText.replaceAllMapped(RegExp(r'[a-z]+'), (match) => match.group(0)!.toUpperCase()),
                            style: CoconutTypography.heading4_18_NumberBold.setColor(CoconutColors.white),
                          ),
                        ),
                      );
                    },
                  ),
                LayoutBuilder(
                  builder: (context, constraints) {
                    return ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 120),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: TooltipButton(
                          isSelected: false,
                          text: tooltipText,
                          isLeft: true,
                          iconKey: widget.tooltipKey,
                          containerMargin: EdgeInsets.zero,
                          containerPadding: EdgeInsets.zero,
                          iconMargin: const EdgeInsets.only(left: 4),
                          onTap: () {
                            widget.onTooltipClicked();
                          },
                          onTapDown: (details) {
                            widget.onTooltipClicked();
                          },
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _onTap(BuildContext context, WalletImportSource? walletImportSource) {
    if (walletImportSource == null || walletImportSource == WalletImportSource.coconutVault) {
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => WalletInfoEditBottomSheet(id: widget.id, walletImportSource: walletImportSource),
    ).then((result) {
      if (result != null) {
        var ellipsisName = result.length > 10 ? '${result.substring(0, 7)}...' : result;
        setState(() {
          nameText = ellipsisName;
        });
        widget.onNameChanged(ellipsisName);
      }
    });
  }

  Widget _buildIcon() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        WalletIcon(
          walletImportSource: walletImportSource ?? WalletImportSource.coconutVault,
          colorIndex: colorIndex,
          iconIndex: iconIndex,
        ),
        if (walletImportSource != null && walletImportSource != WalletImportSource.coconutVault)
          Positioned(
            right: -3,
            bottom: -3,
            child: Container(
              padding: const EdgeInsets.all(4.3),
              decoration: BoxDecoration(
                color: isItemTapped ? CoconutColors.gray750 : CoconutColors.gray800,
                shape: BoxShape.circle,
                boxShadow: const [
                  BoxShadow(color: CoconutColors.gray900, offset: Offset(2, 2), blurRadius: 10, spreadRadius: 0),
                ],
              ),
              child: Container(
                padding: const EdgeInsets.all(1),
                decoration: BoxDecoration(
                  color: isItemTapped ? CoconutColors.gray750 : CoconutColors.gray800,
                  shape: BoxShape.circle,
                ),
                child: SvgPicture.asset(
                  'assets/svg/edit-outlined.svg',
                  width: 10,
                  colorFilter: const ColorFilter.mode(CoconutColors.gray400, BlendMode.srcIn),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
