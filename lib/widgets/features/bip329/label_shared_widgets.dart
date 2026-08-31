import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/widgets/common/loading/loading_indicator.dart';
import 'package:coconut_wallet/widgets/features/bip329/label_result_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class LabelErrorCard extends StatelessWidget {
  final Widget title;

  const LabelErrorCard({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          SvgPicture.asset(
            CommonStateIconPath.circleWarning,
            colorFilter: ColorFilter.mode(context.coconutColors.danger, BlendMode.srcIn),
            height: 57.6,
            width: 57.6,
          ),
          CoconutLayout.spacing_1000h,
          title,
        ],
      ),
    );
  }
}

class LabelProgressCard extends StatelessWidget {
  final Widget title;
  final List<List<Object>> stepGroups;
  final Widget titleGap;

  const LabelProgressCard({
    super.key,
    required this.title,
    required this.stepGroups,
    this.titleGap = CoconutLayout.spacing_500h,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          const FullscreenLoadingIndicator(size: 48, strokeWidth: 4.6),
          CoconutLayout.spacing_1000h,
          title,
          titleGap,
          for (var i = 0; i < stepGroups.length; i++) ...[
            if (i > 0) CoconutLayout.spacing_300h,
            LabelResultCard(steps: stepGroups[i], showSkeleton: true),
          ],
        ],
      ),
    );
  }
}
