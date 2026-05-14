import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/services/app_review_service.dart';
import 'package:flutter/material.dart';

class PositiveFeedbackScreen extends StatelessWidget {
  const PositiveFeedbackScreen({super.key});

  void _startInAppReview(BuildContext context) {
    AppReviewService.requestReview();
    _stopGettingFeedback(context);
  }

  void _stopGettingFeedback(BuildContext context) {
    Navigator.pop(context);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final typography = context.coconutTypography;

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
            padding: EdgeInsets.symmetric(horizontal: context.coconutSpacing.md),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    t.positive_feedback_screen.text1,
                    style: typography.title.copyWith(
                      color: colors.primaryText,
                      fontFamily: 'SpaceGrotesk',
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 20),
                  FittedBox(
                    child: Text(
                      t.positive_feedback_screen.text2,
                      style: typography.body.copyWith(color: colors.primaryText),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 80),
                  GestureDetector(
                    onTap: () => _startInAppReview(context),
                    child: Container(
                      width: MediaQuery.of(context).size.width * 0.5,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), color: colors.primary),
                      child: Text(
                        t.positive_feedback_screen.text3,
                        style: typography.caption.copyWith(
                          color: colors.background,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: () => _stopGettingFeedback(context),
                    child: Container(
                      width: MediaQuery.of(context).size.width * 0.5,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), color: colors.surface),
                      child: Text(
                        t.positive_feedback_screen.text4,
                        style: typography.caption.copyWith(
                          color: colors.primaryText,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
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
