import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_lib/coconut_lib.dart';
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
  const MultisigSignerCard({super.key, required this.index, required this.signer, required this.masterFingerprint});

  @override
  Widget build(BuildContext context) {
    final isInnerWallet = signer.innerVaultId != null;
    final name = signer.name ?? '';
    final colorIndex = signer.colorIndex ?? 0;
    final iconIndex = signer.iconIndex ?? 0;
    final memo = signer.memo ?? '';
    final derivationPath =
        signer.derivationPath ?? 'm/48’/${NetworkType.currentNetworkType == NetworkType.mainnet ? '0' : '1'}’/0’/2’';
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
                      color: isInnerWallet ? ColorUtil.getColor(8).backgroundColor : const Color(0xFFE7E7E7),
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    child: SvgPicture.asset(
                      isInnerWallet ? CustomIcons.getPathByIndex(iconIndex) : 'assets/svg/download.svg',
                      colorFilter: ColorFilter.mode(
                        isInnerWallet ? ColorUtil.getColor(colorIndex).color : CoconutColors.white, // index 8 is gray
                        BlendMode.srcIn,
                      ),
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
                          TextUtils.ellipsisIfLonger(name),
                          style: CoconutTypography.body2_14.setColor(CoconutColors.white),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Visibility(
                          visible: memo.isNotEmpty,
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
