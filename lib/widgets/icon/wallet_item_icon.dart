import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/utils/colors_util.dart';
import 'package:coconut_wallet/utils/icons_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class WalletItemIcon extends StatelessWidget {
  final WalletImportSource walletImportSource;
  final int colorIndex;
  final int iconIndex;

  const WalletItemIcon({
    super.key,
    required this.walletImportSource,
    this.colorIndex = 0,
    this.iconIndex = 0,
  });

  @override
  Widget build(BuildContext context) {
    var isExternalWallet = walletImportSource != WalletImportSource.coconutVault;
    return Container(
      padding: const EdgeInsets.all(10),
      constraints: const BoxConstraints(
        // zpub일 경우에 아이콘 사이즈가 작게 나오기 때문에 minimum 설정
        minHeight: 44,
        minWidth: 44,
      ),
      decoration: BoxDecoration(
        color: isExternalWallet
            ? CoconutColors.gray700
            : ColorUtil.getColor(colorIndex).backgroundColor,
        borderRadius: BorderRadius.circular(16.0),
      ),
      child: isExternalWallet
          ? SvgPicture.asset(
              WalletImportSourceExtension.getExternalWalletIconPath(walletImportSource),
              colorFilter: const ColorFilter.mode(
                Colors.black,
                BlendMode.srcIn,
              ),
            )
          : SvgPicture.asset(
              CustomIcons.getPathByIndex(iconIndex),
              colorFilter: ColorFilter.mode(
                ColorUtil.getColor(colorIndex).color,
                BlendMode.srcIn,
              ),
              width: 20.0,
            ),
    );
  }
}
