import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/wallet/multisig_signer.dart';
import 'package:coconut_wallet/utils/colors_util.dart';
import 'package:coconut_wallet/utils/icons_util.dart';
import 'package:coconut_wallet/utils/text_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class MultisigSignerCard extends StatelessWidget {
  final int index;
  final MultisigSigner signer;
  final String masterFingerprint;
  final String derivationPath;
  const MultisigSignerCard({
    super.key,
    required this.index,
    required this.signer,
    required this.masterFingerprint,
    required this.derivationPath,
  });

  @override
  Widget build(BuildContext context) {
    final isInnerWallet = signer.innerVaultId != null;
    final name = signer.name ?? '';
    final memo = signer.memo ?? '';
    final useMemoInsteadOfName = name.isEmpty && memo.isNotEmpty;
    final String? finalName = name.isNotEmpty ? name : (useMemoInsteadOfName ? memo : null);
    // icon
    final colorIndex = signer.colorIndex ?? 0;
    final iconIndex = signer.iconIndex ?? 0;

    String? importSourceIconPath;
    if (!isInnerWallet && signer.signerSource?.isNotEmpty == true) {
      final WalletImportSource? walletImportSource = WalletImportSourceExtension.fromString(signer.signerSource!);
      if (walletImportSource != null) {
        importSourceIconPath = walletImportSource.externalWalletIconPath;
      }
    }

    final finalIconPath =
        isInnerWallet ? CustomIcons.getPathByIndex(iconIndex) : (importSourceIconPath ?? 'assets/svg/puzzle-piece.svg');
    final Color finalIconColor =
        isInnerWallet
            ? ColorUtil.getColor(colorIndex).color
            : (importSourceIconPath != null ? CoconutColors.white : CoconutColors.gray600);

    return Container(
      color: Colors.transparent,
      child: Row(
        children: [
          // 왼쪽 인덱스 번호
          SizedBox(
            width: 24,
            child: Text('${index + 1}', textAlign: TextAlign.center, style: CoconutTypography.body1_16_NumberBold),
          ),
          CoconutLayout.spacing_200w,
          // 카드 영역
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: CoconutColors.black,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE9E9E9)),
              ),
              child: Row(
                children: [
                  // 아이콘
                  Container(
                    padding: const EdgeInsets.all(Sizes.size10),
                    decoration: BoxDecoration(
                      color: isInnerWallet ? ColorUtil.getColor(8).backgroundColor : CoconutColors.gray800,
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    child: SvgPicture.asset(
                      finalIconPath,
                      colorFilter: ColorFilter.mode(finalIconColor, BlendMode.srcIn),
                      width: isInnerWallet ? 18 : 15,
                    ),
                  ),
                  CoconutLayout.spacing_300w,

                  // 이름, 메모
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          finalName != null ? TextUtils.ellipsisIfLonger(finalName) : t.wallet_info_screen.no_info,
                          style: CoconutTypography.body2_14.setColor(
                            finalName != null ? CoconutColors.white : CoconutColors.gray500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Visibility(
                          visible: !useMemoInsteadOfName && memo.isNotEmpty,
                          child: Text(
                            memo,
                            style: CoconutTypography.body3_12.setColor(CoconutColors.gray500),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // MFP, Derivation Path
                  Column(
                    children: [
                      Text(masterFingerprint, style: CoconutTypography.body2_14_Number.setColor(CoconutColors.white)),
                      CoconutLayout.spacing_50h,
                      Text(derivationPath, style: CoconutTypography.body3_12.setColor(CoconutColors.gray500)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
