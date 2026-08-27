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
    return Container(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        children: [
          SvgPicture.asset(
            'assets/svg/circle-check.svg',
            colorFilter: ColorFilter.mode(context.coconutColors.textHighlight, BlendMode.srcIn),
            height: 48,
            width: 48,
          ),
          CoconutLayout.spacing_1000h,
          title,
          const SizedBox(height: 43),
          ExportLabelInstructionToolTip(steps: steps, showSkeleton: false, stepResults: stepResults),
        ],
      ),
    );
  }
}

class ExportLabelErrorCard extends StatelessWidget {
  final Widget title;

  const ExportLabelErrorCard({super.key, required this.title});

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
          CoconutLayout.spacing_1000h,
          title,
        ],
      ),
    );
  }
}

class ExportLabelProgressCard extends StatelessWidget {
  final Widget title;
  final List<Object> topSteps;
  final List<Object> bottomSteps;

  const ExportLabelProgressCard({super.key, required this.title, required this.topSteps, required this.bottomSteps});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: Transform.scale(
              scale: 0.8,
              child: CircularProgressIndicator(color: context.coconutColors.loadingIndicatorColor, strokeWidth: 3),
            ),
          ),
          CoconutLayout.spacing_1000h,
          title,
          const SizedBox(height: 43),
          ExportLabelInstructionToolTip(steps: topSteps, showSkeleton: true),
          CoconutLayout.spacing_300h,
          ExportLabelInstructionToolTip(steps: bottomSteps, showSkeleton: true),
        ],
      ),
    );
  }
}

class ExportLabelInstructionToolTip extends StatelessWidget {
  final List<Object> steps;
  final bool showSkeleton;
  final List<Object>? stepResults;

  const ExportLabelInstructionToolTip({super.key, required this.steps, this.showSkeleton = false, this.stepResults});

  String _formatStepResult(Object? result) {
    if (result == null) return '-';
    final str = result.toString();
    return str.isNotEmpty ? str : '-';
  }

  @override
  Widget build(BuildContext context) {
    final clampedTextScaler = TextScaler.linear(MediaQuery.textScalerOf(context).scale(1.0).clamp(1.0, 1.2));

    return CoconutToolTip(
      backgroundColor: context.coconutColors.surface,
      borderColor: context.coconutColors.surface,
      icon: const SizedBox.shrink(),
      tooltipType: CoconutTooltipType.fixed,
      richText: RichText(
        text: TextSpan(
          children:
              steps.asMap().entries.map((e) {
                final stepIndex = e.key;
                final stepText = e.value.toString();

                return WidgetSpan(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: stepIndex < steps.length - 1 ? 12.0 : 0.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            stepText,
                            style: CoconutTypography.body2_14.setColor(context.coconutColors.secondaryText),
                            textScaler: clampedTextScaler,
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
                        ] else if (stepResults != null && stepIndex < stepResults!.length) ...[
                          const SizedBox(width: 8),
                          ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.35),
                            child: Text(
                              _formatStepResult(stepResults![stepIndex]),
                              textAlign: TextAlign.end,
                              style: CoconutTypography.body2_14.setColor(context.coconutColors.primaryText),
                              textScaler: clampedTextScaler,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }).toList(),
        ),
      ),
    );
  }
}
