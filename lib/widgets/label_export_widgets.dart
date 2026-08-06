import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:shimmer/shimmer.dart';

class ExportLabelSuccessCard extends StatelessWidget {
  final Widget title;
  final List<Object> steps;
  final List<Object>? stepResults;

  const ExportLabelSuccessCard({super.key, required this.title, required this.steps, this.stepResults});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SvgPicture.asset(
          'assets/svg/circle-check.svg',
          colorFilter: ColorFilter.mode(context.coconutColors.textHighlight, BlendMode.srcIn),
          height: 48,
          width: 48,
        ),
        CoconutLayout.spacing_200h,
        title,
        CoconutLayout.spacing_400h,
        _ExportLabelInstructionToolTip(steps: steps, showSkeleton: false, stepResults: stepResults),
      ],
    );
  }
}

class ExportLabelErrorCard extends StatelessWidget {
  final Widget title;

  const ExportLabelErrorCard({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SvgPicture.asset(
          'assets/svg/circle-warning.svg',
          colorFilter: ColorFilter.mode(context.coconutColors.danger, BlendMode.srcIn),
          height: 48,
          width: 48,
        ),
        CoconutLayout.spacing_200h,
        title,
      ],
    );
  }
}

class ExportLabelProgressCard extends StatelessWidget {
  final Widget title;
  final List<Object> steps;

  const ExportLabelProgressCard({super.key, required this.title, required this.steps});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(color: context.coconutColors.loadingIndicatorColor, strokeWidth: 3),
          ),
          CoconutLayout.spacing_400h,
          title,
          CoconutLayout.spacing_400h,
          _ExportLabelInstructionToolTip(steps: steps, showSkeleton: true),
        ],
      ),
    );
  }
}

class _ExportLabelInstructionToolTip extends StatelessWidget {
  final List<Object> steps;
  final bool showSkeleton;
  final List<Object>? stepResults;

  const _ExportLabelInstructionToolTip({required this.steps, this.showSkeleton = false, this.stepResults});

  @override
  Widget build(BuildContext context) {
    return CoconutToolTip(
      backgroundColor: context.coconutColors.surface,
      borderColor: context.coconutColors.surface,
      icon: const SizedBox.shrink(),
      tooltipType: CoconutTooltipType.fixed,
      richText: RichText(
        text: TextSpan(
          style: CoconutTypography.body2_14,
          children: [
            ...steps.asMap().entries.map((e) {
              final stepText = e.value as String;

              return WidgetSpan(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        stepText,
                        style: CoconutTypography.body2_14.setColor(context.coconutColors.secondaryText),
                      ),
                    ),
                    if (showSkeleton) ...[
                      const SizedBox(width: 8),
                      Shimmer.fromColors(
                        baseColor: context.coconutColors.surfaceSkeletonBase,
                        highlightColor: context.coconutColors.surfaceSkeletonHighlight,
                        child: Container(
                          width: 60,
                          height: 14,
                          decoration: BoxDecoration(
                            color: context.coconutColors.surfaceSkeletonBase,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ],
                    if (!showSkeleton && stepResults != null && e.key < stepResults!.length) ...[
                      const SizedBox(width: 8),
                      Text(
                        stepResults![e.key].toString(),
                        style: CoconutTypography.body2_14.setColor(context.coconutColors.primaryText),
                      ),
                    ],
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
