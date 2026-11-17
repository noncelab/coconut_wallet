import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/ccos/ccos_feature_registry.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/widgets/features/ccos/coconut_open_store_belief_box.dart';
import 'package:flutter/material.dart';

/// 기능 상세 CREATOR 장. 인용은 있을 때만, 마지막 한마디는 따옴표 상자
class CcosStoreCreatorStory extends StatelessWidget {
  const CcosStoreCreatorStory({super.key, required this.story});

  final CcosCreatorStory story;

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (story.quote case final quote?) ...[
          Column(
            key: const ValueKey('ccos-detail-quote'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(quote, style: CoconutTypography.body1_16_Bold.setColor(colors.primaryText)),
              if (story.quoteAttribution case final attribution?) ...[
                CoconutLayout.spacing_200h,
                Text(attribution, style: CoconutTypography.body3_12.setColor(colors.secondaryText)),
              ],
            ],
          ),
          CoconutLayout.spacing_600h,
        ],
        for (final paragraph in story.paragraphs) ...[
          Text(paragraph, style: CoconutTypography.body2_14.setColor(colors.secondaryTextStrong)),
          CoconutLayout.spacing_400h,
        ],
        CoconutLayout.spacing_200h,
        CoconutOpenStoreBeliefBox(text: story.belief, textAlign: TextAlign.center),
      ],
    );
  }
}
