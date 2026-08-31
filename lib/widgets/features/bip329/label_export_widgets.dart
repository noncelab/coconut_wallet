import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/widgets/common/animation/success_check_lottie.dart';
import 'package:coconut_wallet/widgets/features/bip329/label_result_card.dart';
import 'package:flutter/material.dart';

class LabelExportSuccessCard extends StatelessWidget {
  final Widget title;
  final List<Object> steps;
  final List<Object>? stepResults;

  const LabelExportSuccessCard({super.key, required this.title, required this.steps, this.stepResults});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        children: [
          SuccessCheckLottie(size: 48, color: context.coconutColors.success),
          CoconutLayout.spacing_1000h,
          title,
          const SizedBox(height: 43),
          LabelResultCard(steps: steps, showSkeleton: false, stepResults: stepResults),
        ],
      ),
    );
  }
}
