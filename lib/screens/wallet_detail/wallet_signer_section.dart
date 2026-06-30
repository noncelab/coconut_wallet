import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/view_model/wallet_detail/wallet_info_view_model.dart';
import 'package:coconut_wallet/widgets/card/multisig_signer_card.dart';
import 'package:coconut_wallet/widgets/card/role_description_card.dart';
import 'package:coconut_wallet/widgets/card/taproot_setup_summary_card.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class WalletSignerSection extends StatelessWidget {
  final WalletType walletType;

  const WalletSignerSection({super.key, required this.walletType});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<WalletInfoViewModel>();

    if (walletType == WalletType.multiSignature) {
      return Container(
        margin: const EdgeInsets.only(top: 8, bottom: 32),
        child: ListView.separated(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: viewModel.multisigTotalSignerCount,
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            return MultisigSignerCard(
              index: index,
              signer: viewModel.getSigner(index),
              masterFingerprint: viewModel.getSignerMasterFingerprint(index),
              derivationPath: viewModel.getSignerBsms(index).derivationPath,
            );
          },
        ),
      );
    }

    if (walletType == WalletType.taproot) {
      final effectiveIndex = viewModel.taprootSpendTypeIndex;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Text(
              t.wallet_signer_section.title,
              style: CoconutTypography.body3_12_Bold.setColor(CoconutColors.white),
            ),
          ),
          CoconutLayout.spacing_200h,
          if (viewModel.canSpendBothPaths) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: CoconutSegmentedControl(
                isSelected: [effectiveIndex == 0, effectiveIndex == 1],
                onPressed: (index) {
                  viewModel.updateTaprootSpendType(index);
                },
                children: [
                  _buildSegmentLabel(
                    t.wallet_signer_section.segmented_control.parent_key,
                    effectiveIndex == 0
                        ? t.wallet_signer_section.segmented_control.currently_using
                        : t.wallet_signer_section.segmented_control.default_path,
                    effectiveIndex == 0,
                  ),
                  _buildSegmentLabel(
                    t.wallet_signer_section.segmented_control.child_key,
                    effectiveIndex == 1
                        ? t.wallet_signer_section.segmented_control.currently_using
                        : t.wallet_signer_section.segmented_control.inheritance_path,
                    effectiveIndex == 1,
                  ),
                ],
              ),
            ),
          ],
          CoconutLayout.spacing_100h,
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildRoleDescriptionCard(effectiveIndex, viewModel),
          ),
          const Divider(color: CoconutColors.gray800, height: 40, indent: 16, endIndent: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TaprootSetupSummaryCard(
              itemList: viewModel.getTaprootParticipants(effectiveIndex),
              taprootSetupSummaryCardType: TaprootSetupSummaryCardType.column,
            ),
          ),
          const Divider(color: CoconutColors.gray800, height: 40, indent: 16, endIndent: 16),
        ],
      );
    }

    return CoconutLayout.spacing_800h;
  }

  Widget _buildSegmentLabel(String title, String subTitle, bool isSelected) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title),
        Text(
          subTitle,
          style: CoconutTypography.caption_10.setColor(
            isSelected ? CoconutColors.gray400 : CoconutColors.gray400.withOpacity(0.5),
          ),
        ),
      ],
    );
  }

  Widget _buildRoleDescriptionCard(int index, WalletInfoViewModel viewModel) {
    final isParent = index == 0;
    final theme = isParent ? RoleDescriptionTheme.cosigner : RoleDescriptionTheme.heir;
    String description;
    if (isParent) {
      description =
          viewModel.hasSingleTaprootParent
              ? t.taproot.role_description_card.single_parent_description
              : t.taproot.role_description_card.multi_parent_description;
    } else {
      description = t.taproot.role_description_card.child_description;
    }
    return RoleDescriptionCard(
      description: description,
      themeColor: theme.themeColor,
      backgroundColor: theme.backgroundColor,
      highlightPattern: theme.highlightPattern,
    );
  }
}
