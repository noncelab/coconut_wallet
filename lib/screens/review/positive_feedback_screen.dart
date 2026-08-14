import 'package:coconut_wallet/ui/coconut/coconut_app_bar.dart';
import 'package:coconut_design_system/coconut_design_system.dart' hide CoconutAppBar;
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/services/app_review_service.dart';
import 'package:flutter/material.dart';

class PositiveFeedbackScreen extends StatelessWidget {
  const PositiveFeedbackScreen({super.key});

  Future<void> _startInAppReview(BuildContext context) async {
    AppReviewService.requestReview();
    await _stopGettingFeedback(context);
  }

  Future<void> _stopGettingFeedback(BuildContext context) async {
    final navigator = Navigator.of(context);
    final currentRoute = ModalRoute.of(context);

    navigator.pop();
    await currentRoute?.completed;

    if (navigator.mounted && navigator.canPop()) {
      navigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        appBar: CoconutAppBar.build(context: context, title: ''),
        backgroundColor: colors.background,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    t.positive_feedback_screen.text1,
                    style: CoconutTypography.heading2_28_NumberBold.copyWith(color: colors.primaryText),
                  ),
                  const SizedBox(height: 20),
                  FittedBox(
                    child: Text(
                      t.positive_feedback_screen.text2,
                      style: CoconutTypography.body1_16.setColor(colors.primaryText),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 80),
                  GestureDetector(
                    onTap: () => _startInAppReview(context),
                    child: Container(
                      width: MediaQuery.of(context).size.width * 0.5,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), color: colors.brandAccentBackground),
                      child: Text(
                        t.positive_feedback_screen.text3,
                        style: CoconutTypography.body2_14_Bold.setColor(colors.brandAccentForeground),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: () async => _stopGettingFeedback(context),
                    child: Container(
                      width: MediaQuery.of(context).size.width * 0.5,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: colors.buttonPrimaryBackground,
                      ),
                      child: Text(
                        t.positive_feedback_screen.text4,
                        style: CoconutTypography.body2_14_Bold.setColor(colors.buttonPrimaryForeground),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
