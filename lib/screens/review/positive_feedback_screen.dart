import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/services/app_review_service.dart';
import 'package:flutter/material.dart';
import 'package:coconut_wallet/styles.dart';

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
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        appBar: CoconutAppBar.build(
          context: context,
          title: '',
        ),
        backgroundColor: CoconutColors.black,
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
                    style: Styles.h2.merge(const TextStyle(color: CoconutColors.white)),
                  ),
                  const SizedBox(
                    height: 20,
                  ),
                  FittedBox(
                    child: Text(
                      t.positive_feedback_screen.text2,
                      style: Styles.body1,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(
                    height: 80,
                  ),
                  GestureDetector(
                    onTap: () => _startInAppReview(context),
                    child: Container(
                        width: MediaQuery.of(context).size.width * 0.5,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14), color: CoconutColors.primary),
                        child: Text(
                          t.positive_feedback_screen.text3,
                          style: Styles.label.merge(const TextStyle(
                              color: MyColors.darkgrey, fontWeight: FontWeight.bold)),
                          textAlign: TextAlign.center,
                        )),
                  ),
                  const SizedBox(
                    height: 20,
                  ),
                  GestureDetector(
                    onTap: () => _stopGettingFeedback(context),
                    child: Container(
                        width: MediaQuery.of(context).size.width * 0.5,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            color: MyColors.transparentWhite_15),
                        child: Text(
                          t.positive_feedback_screen.text4,
                          style: Styles.label.merge(const TextStyle(
                              color: CoconutColors.white, fontWeight: FontWeight.bold)),
                          textAlign: TextAlign.center,
                        )),
                  ),
                  const SizedBox(
                    height: 40,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
