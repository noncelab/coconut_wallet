import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/ccos/ccos_feature_registry.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/providers/view_model/ccos/ccos_store_view_model.dart';
import 'package:coconut_wallet/screens/ccos/store/widgets/ccos_store_action_button.dart';
import 'package:coconut_wallet/screens/ccos/store/widgets/ccos_store_category_label.dart';
import 'package:coconut_wallet/screens/ccos/store/widgets/ccos_store_feature_icon.dart';
import 'package:coconut_wallet/screens/ccos/store/widgets/ccos_store_feature_thumbnail.dart';
import 'package:flutter/material.dart';
import 'package:coconut_wallet/screens/ccos/store/widgets/ccos_store_scope.dart';

/// 스토어의 기능 카드. 한 줄 소개, 썸네일, 이름, 작성자, 상태
class CcosStoreFeatureCard extends StatelessWidget {
  const CcosStoreFeatureCard({
    super.key,
    required this.listing,
    required this.state,
    required this.onTap,
    required this.onAdd,
  });

  final CcosFeatureListing listing;
  final CcosStoreItemState state;
  final VoidCallback onTap;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    return Semantics(
      button: true,
      container: true,
      child: GestureDetector(
        key: ValueKey('ccos-store-card-${listing.id}'),
        onTap: onTap,
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(color: CcosStoreScope.cardColor, borderRadius: BorderRadius.circular(20)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(listing.category.label, style: CoconutTypography.body3_12_Bold.setColor(colors.secondaryText)),
                    CoconutLayout.spacing_100h,
                    Text(listing.subtitle, style: CoconutTypography.heading4_18_Bold.setColor(colors.primaryText)),
                  ],
                ),
              ),
              CcosStoreFeatureThumbnail(listing: listing),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CcosStoreFeatureIcon(iconPath: listing.iconPath, size: 40, onSurface: true),
                    CoconutLayout.spacing_300w,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(listing.title, style: CoconutTypography.body2_14_Bold.setColor(colors.primaryText)),
                          Text(listing.author, style: CoconutTypography.body3_12.setColor(colors.secondaryText)),
                        ],
                      ),
                    ),
                    CcosStoreActionButton(state: state, onAdd: onAdd, onSurface: true),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
