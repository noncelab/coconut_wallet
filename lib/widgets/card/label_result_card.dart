import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class LabelResultCard extends StatelessWidget {
  final List<Object> steps;
  final bool showSkeleton;
  final List<Object>? stepResults;

  const LabelResultCard({super.key, required this.steps, this.showSkeleton = false, this.stepResults});

  String _formatStepResult(Object result) {
    final str = result.toString();
    return str.isEmpty ? '-' : str;
  }

  @override
  Widget build(BuildContext context) {
    final clampedTextScaler = TextScaler.linear(MediaQuery.textScalerOf(context).scale(1.0).clamp(1.0, 1.2));

    return Container(
      decoration: BoxDecoration(color: context.coconutColors.surface, borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.all(20),
      child: RichText(
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
                        Text(
                          stepText,
                          style: CoconutTypography.body2_14.setColor(context.coconutColors.secondaryText),
                          textScaler: clampedTextScaler,
                        ),
                        const Spacer(),
                        const SizedBox(width: 8),
                        if (showSkeleton) ...[
                          Shimmer.fromColors(
                            baseColor: context.coconutColors.surfaceSkeletonBase,
                            highlightColor: context.coconutColors.surfaceSkeletonHighlight,
                            child: Container(
                              width: MediaQuery.of(context).size.width * 0.35,
                              height: 19.6, // font 14의 140%
                              decoration: BoxDecoration(
                                color: context.coconutColors.surfaceSkeletonBase,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ] else if (stepResults != null && stepIndex < stepResults!.length) ...[
                          Text(
                            _formatStepResult(stepResults![stepIndex]),
                            textAlign: TextAlign.end,
                            style: CoconutTypography.body2_14.setColor(context.coconutColors.primaryText),
                            textScaler: clampedTextScaler,
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
