import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:shimmer/shimmer.dart';

class ImportLabelSuccessCard extends StatelessWidget {
  final String title;
  final Widget? child;

  const ImportLabelSuccessCard({super.key, required this.title, this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          SvgPicture.asset(
            'assets/svg/circle-check.svg',
            colorFilter: ColorFilter.mode(context.coconutColors.textHighlight, BlendMode.srcIn),
            height: 48,
            width: 48,
          ),
          CoconutLayout.spacing_200h,
          Text(
            title,
            style: CoconutTypography.body1_16_Bold.setColor(context.coconutColors.primaryText),
            textAlign: TextAlign.center,
          ),
          CoconutLayout.spacing_200h,
          CoconutLayout.spacing_600h,
          if (child != null) child!,
        ],
      ),
    );
  }
}

class ImportLabelErrorCard extends StatelessWidget {
  final String title;
  final String description;
  final String? errorMessage;
  final List<String>? steps;

  const ImportLabelErrorCard({
    super.key,
    required this.title,
    required this.description,
    this.errorMessage,
    this.steps,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          SvgPicture.asset(
            'assets/svg/circle-warning.svg',
            colorFilter: ColorFilter.mode(context.coconutColors.danger, BlendMode.srcIn),
            height: 48,
            width: 48,
          ),
          CoconutLayout.spacing_200h,
          Text(title, style: CoconutTypography.body1_16_Bold.setColor(context.coconutColors.danger)),
          CoconutLayout.spacing_400h,
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            decoration: BoxDecoration(
              color: context.coconutColors.surface,
              borderRadius: BorderRadius.circular(CoconutStyles.radius_200),
            ),
            child: Text(
              description,
              style: CoconutTypography.body1_16.setColor(context.coconutColors.primaryText),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

class ImportLabelProgressCard extends StatelessWidget {
  final Widget title;
  final List<Object> steps;
  final bool showSkeleton;

  const ImportLabelProgressCard({super.key, required this.title, required this.steps, this.showSkeleton = false});

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
          ImportLabelInstructionToolTip(steps: steps, showSkeleton: showSkeleton),
        ],
      ),
    );
  }
}

class ImportLabelInstructionToolTip extends StatelessWidget {
  final List<Object> steps;
  final String? notice;
  final bool showSkeleton;

  const ImportLabelInstructionToolTip({super.key, required this.steps, this.notice, this.showSkeleton = false});

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
            if (notice != null) ...[
              TextSpan(
                text: notice,
                style: TextStyle(color: context.coconutColors.primaryText, fontWeight: FontWeight.bold),
              ),
              const TextSpan(text: '\n\n'),
            ],
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
