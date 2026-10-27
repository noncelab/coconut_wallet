import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/widgets/features/wallet/taproot/role_description_card.dart';
import 'package:flutter/material.dart';

/// 탭루트 상속 지갑의 서명 방식(0: 부모 키, 1: 자식 키) 선택.
class TaprootSpendTypeSegmentedControl extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onPressed;

  const TaprootSpendTypeSegmentedControl({super.key, required this.selectedIndex, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    return CoconutSegmentedControl(
      selectedColor: colors.segmentedControlSelected,
      segmentedControlContainerColor: colors.segmentedControlBackground,
      selectedTextColor: colors.segmentedControlSelectedText,
      unselectedTextColor: colors.segmentedControlUnselectedText,
      isSelected: [selectedIndex == 0, selectedIndex == 1],
      onPressed: onPressed,
      children: [
        _label(
          context,
          t.wallet_signer_section.segmented_control.parent_key,
          selectedIndex == 0
              ? t.wallet_signer_section.segmented_control.currently_using
              : t.wallet_signer_section.segmented_control.default_path,
          selectedIndex == 0,
        ),
        _label(
          context,
          t.wallet_signer_section.segmented_control.child_key,
          selectedIndex == 1
              ? t.wallet_signer_section.segmented_control.currently_using
              : t.wallet_signer_section.segmented_control.inheritance_path,
          selectedIndex == 1,
        ),
      ],
    );
  }

  Widget _label(BuildContext context, String title, String subTitle, bool isSelected) {
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
}

/// 선택한 서명 방식에서 내 역할(서명자·공동 서명자·상속자)을 설명하는 카드.
class TaprootRoleDescriptionCard extends StatelessWidget {
  final bool isParent;
  final bool hasSingleParent;

  const TaprootRoleDescriptionCard({super.key, required this.isParent, required this.hasSingleParent});

  @override
  Widget build(BuildContext context) {
    final theme = isParent ? RoleDescriptionTheme.cosigner : RoleDescriptionTheme.heir;
    final description =
        !isParent
            ? t.taproot.role_description_card.child_description
            : hasSingleParent
            ? t.taproot.role_description_card.single_parent_description
            : t.taproot.role_description_card.multi_parent_description;
    return RoleDescriptionCard(
      description: description,
      themeColor: theme.themeColor,
      backgroundColor: theme.backgroundColor,
      highlightPattern: theme.highlightPattern,
    );
  }
}
