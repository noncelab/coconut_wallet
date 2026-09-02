import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/widgets/card/label_result_card.dart';
import 'package:coconut_wallet/widgets/loading_indicator/loading_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

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
          SvgPicture.asset(
            'assets/svg/circle-check.svg',
            colorFilter: ColorFilter.mode(context.coconutColors.textHighlight, BlendMode.srcIn),
            height: 48,
            width: 48,
          ),
          CoconutLayout.spacing_1000h,
          title,
          const SizedBox(height: 43),
          LabelResultCard(steps: steps, showSkeleton: false, stepResults: stepResults),
        ],
      ),
    );
  }
}

class LabelExportErrorCard extends StatelessWidget {
  final Widget title;

  const LabelExportErrorCard({super.key, required this.title});

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

class LabelExportProgressCard extends StatelessWidget {
  final Widget title;
  final List<Object> topSteps;
  final List<Object> bottomSteps;

  const LabelExportProgressCard({super.key, required this.title, required this.topSteps, required this.bottomSteps});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          const CircularLoadingSpinner(),
          CoconutLayout.spacing_1000h,
          title,
          const SizedBox(height: 43),
          LabelResultCard(steps: topSteps, showSkeleton: true),
          CoconutLayout.spacing_300h,
          LabelResultCard(steps: bottomSteps, showSkeleton: true),
        ],
      ),
    );
  }
}
