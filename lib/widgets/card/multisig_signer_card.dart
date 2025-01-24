import 'package:coconut_wallet/model/wallet/multisig_signer.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/utils/icons_util.dart';
import 'package:coconut_wallet/utils/text_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class MultisigSignerCard extends StatelessWidget {
  final int index;
  final MultisigSigner signer;
  final String masterFingerprint;
  const MultisigSignerCard({
    super.key,
    required this.index,
    required this.signer,
    required this.masterFingerprint,
  });

  @override
  Widget build(BuildContext context) {
    final isInnerWallet = signer.innerVaultId != null;
    final name = signer.name ?? '';
    final colorIndex = signer.colorIndex ?? 0;
    final iconIndex = signer.iconIndex ?? 0;
    final memo = signer.memo ?? '';
    return Container(
      color: Colors.transparent,
      child: Row(
        children: [
          // 왼쪽 인덱스 번호
          SizedBox(
            width: 24,
            child: Text(
              '${index + 1}',
              textAlign: TextAlign.center,
              style: Styles.body2.merge(
                TextStyle(
                  fontSize: 16,
                  fontFamily: CustomFonts.number.getFontFamily,
                ),
              ),
            ),
          ),

          const SizedBox(width: 12), // 간격

          // 카드 영역
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: MyColors.black,
                borderRadius: MyBorder.boxDecorationRadius,
                border: Border.all(color: MyColors.borderLightgrey),
              ),
              child: Row(
                children: [
                  // 아이콘
                  Container(
                      padding: EdgeInsets.all(isInnerWallet ? 8 : 10),
                      decoration: BoxDecoration(
                        color: isInnerWallet
                            ? BackgroundColorPalette[colorIndex]
                            : BackgroundColorPalette[8],
                        borderRadius: BorderRadius.circular(14.0),
                      ),
                      child: SvgPicture.asset(
                        isInnerWallet
                            ? CustomIcons.getPathByIndex(iconIndex)
                            : 'assets/svg/download.svg',
                        colorFilter: ColorFilter.mode(
                          isInnerWallet
                              ? ColorPalette[colorIndex]
                              : ColorPalette[8],
                          BlendMode.srcIn,
                        ),
                        width: isInnerWallet ? 20 : 15,
                      )),

                  const SizedBox(width: 12),

                  // 이름, 메모
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          TextUtils.ellipsisIfLonger(name),
                          style: Styles.body2,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Visibility(
                          visible: memo.isNotEmpty,
                          child: Text(
                            memo,
                            style: Styles.caption2,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // MFP 텍스트
                  Text(
                    masterFingerprint,
                    style: Styles.mfpH3,
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
