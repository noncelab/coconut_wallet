import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/extensions/widget_animation_extensions.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/view_model/wallet_detail/wallet_info_view_model.dart';
import 'package:coconut_wallet/widgets/common/buttons/shrink_animation_button.dart';
import 'package:coconut_wallet/widgets/features/wallet/signer/multisig_signer_card.dart';
import 'package:coconut_wallet/widgets/features/wallet/taproot/role_description_card.dart';
import 'package:coconut_wallet/widgets/features/wallet/taproot/taproot_setup_summary_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

class WalletSignerSection extends StatefulWidget {
  final WalletType walletType;

  const WalletSignerSection({super.key, required this.walletType});

  @override
  State<WalletSignerSection> createState() => _WalletSignerSectionState();
}

class _WalletSignerSectionState extends State<WalletSignerSection> {
  final GlobalKey _taprootSegmentedControlKey = GlobalKey();
  bool _isExpanded = false;
  bool _isClosing = false;
  int _expansionCycle = 0;

  Future<void> _toggleAccordion() async {
    if (_isClosing) return;
    if (!_isExpanded) {
      setState(() {
        _expansionCycle++;
        _isExpanded = true;
      });
      return;
    }

    setState(() => _isClosing = true);
    await Future<void>.delayed(const Duration(milliseconds: 180));
    if (!mounted) return;
    setState(() => _isExpanded = false);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    setState(() => _isClosing = false);
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<WalletInfoViewModel>();

    if (widget.walletType == WalletType.multiSignature) {
      return _buildAccordion(context, [
        for (var index = 0; index < viewModel.multisigTotalSignerCount; index++)
          Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              index == 0 ? 8 : 0,
              16,
              index == viewModel.multisigTotalSignerCount - 1 ? 32 : 8,
            ),
            child: MultisigSignerCard(
              index: index,
              signer: viewModel.getSigner(index),
              masterFingerprint: viewModel.getSignerMasterFingerprint(index),
              derivationPath: viewModel.getSignerBsms(index).derivationPath,
            ),
          ),
      ]);
    }

    if (widget.walletType == WalletType.taproot) {
      final effectiveIndex = viewModel.taprootSpendTypeIndex;

      return _buildAccordion(context, [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 16, 0),
          child: Text(
            t.wallet_signer_section.title,
            style: CoconutTypography.body3_12_Bold.setColor(context.coconutColors.primaryText),
          ),
        ),
        CoconutLayout.spacing_100h,
        if (viewModel.canSpendBothPaths) ...[
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 4),
            child: CoconutSegmentedControl(
              key: _taprootSegmentedControlKey,
              selectedColor: context.coconutColors.segmentedControlSelected,
              segmentedControlContainerColor: context.coconutColors.segmentedControlBackground,
              selectedTextColor: context.coconutColors.segmentedControlSelectedText,
              unselectedTextColor: context.coconutColors.segmentedControlUnselectedText,
              isSelected: [effectiveIndex == 0, effectiveIndex == 1],
              onPressed: (index) {
                viewModel.updateTaprootSpendType(index);
              },
              children: [
                _buildSegmentLabel(
                  context,
                  t.wallet_signer_section.segmented_control.parent_key,
                  effectiveIndex == 0
                      ? t.wallet_signer_section.segmented_control.currently_using
                      : t.wallet_signer_section.segmented_control.default_path,
                  effectiveIndex == 0,
                ),
                _buildSegmentLabel(
                  context,
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
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _buildRoleDescriptionCard(effectiveIndex, viewModel),
        ),
        Divider(color: context.coconutColors.divider, height: 40, indent: 16, endIndent: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TaprootSetupSummaryCard(
            itemList: viewModel.getTaprootParticipants(effectiveIndex),
            taprootSetupSummaryCardType: TaprootSetupSummaryCardType.column,
          ),
        ),
        Divider(color: context.coconutColors.divider, height: 40, indent: 16, endIndent: 16),
      ]);
    }

    return CoconutLayout.spacing_800h;
  }

  Widget _buildAccordion(BuildContext context, List<Widget> contentChildren) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: Semantics(
            button: true,
            expanded: _isExpanded,
            child: ShrinkAnimationButton(
              onPressed: _toggleAccordion,
              isActive: !_isClosing,
              pressedColor: Colors.transparent,
              pressedOverlayColor: Colors.transparent,
              pressedOverlayOpacity: 0,
              defaultColor: context.coconutColors.background,
              disabledColor: context.coconutColors.background,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    AnimatedRotation(
                      turns: _isExpanded ? -0.25 : 0.25,
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                      child: SvgPicture.asset(
                        CommonNavigationIconPath.arrowRight,
                        width: 6,
                        height: 10,
                        colorFilter: ColorFilter.mode(context.coconutColors.iconSecondary, BlendMode.srcIn),
                      ),
                    ),
                    CoconutLayout.spacing_200w,
                    Text(
                      _isExpanded ? t.wallet_signer_section.collapse : t.wallet_signer_section.view_details,
                      style: CoconutTypography.body3_12_Bold.setColor(context.coconutColors.secondaryTextStrong),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: _isExpanded ? 1 : 0),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          builder: (context, heightFactor, _) {
            return ClipRect(
              child: Align(
                alignment: Alignment.topCenter,
                heightFactor: heightFactor,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var index = 0; index < contentChildren.length; index++)
                      _isClosing
                          ? contentChildren[index].transitionAnimation(
                            key: ValueKey('wallet-signer-close-$_expansionCycle-$index'),
                            beginOffset: Offset.zero,
                            endOffset: const Offset(0, -8),
                            beginOpacity: 1,
                            endOpacity: 0,
                            beginScale: 1,
                            endScale: 1,
                            duration: const Duration(milliseconds: 250),
                            delay: Duration(milliseconds: (contentChildren.length - index - 1) * 20),
                            curve: Curves.easeInCubic,
                          )
                          : contentChildren[index].slideDownAnimation(
                            key: ValueKey('wallet-signer-open-$_expansionCycle-$index'),
                            duration: const Duration(milliseconds: 350),
                            delay: Duration(milliseconds: 80 + index * 40),
                            offset: const Offset(0, -8),
                            curve: Curves.easeOutCubic,
                          ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSegmentLabel(BuildContext context, String title, String subTitle, bool isSelected) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title),
        Text(
          subTitle,
          style: CoconutTypography.caption_10.setColor(
            isSelected
                ? context.coconutColors.segmentedControlSelectedText.withValues(alpha: 0.7)
                : context.coconutColors.primaryText.withValues(alpha: 0.2),
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
