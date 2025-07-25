import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/services/app_review_service.dart';
import 'package:coconut_wallet/utils/uri_launcher.dart';
import 'package:flutter/material.dart';

class NegativeFeedbackScreen extends StatelessWidget {
  const NegativeFeedbackScreen({super.key});

  void _runKakaoOpenChat(BuildContext context) {
    launchURL('https://open.kakao.com/me/coconutwallet');
    AppReviewService.setHasReviewed();
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
                    t.negative_feedback_screen.text1,
                    style: CoconutTypography.heading2_28_NumberBold.setColor(CoconutColors.white),
                  ),
                  const SizedBox(
                    height: 20,
                  ),
                  FittedBox(
                    child: Text(
                      t.negative_feedback_screen.text2,
                      style: CoconutTypography.body1_16,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(
                    height: 80,
                  ),
                  GestureDetector(
                    onTap: () => _runKakaoOpenChat(context),
                    child: Container(
                        width: MediaQuery.of(context).size.width * 0.5,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14), color: CoconutColors.primary),
                        child: Text(
                          t.negative_feedback_screen.text3,
                          style: CoconutTypography.body2_14_Bold.setColor(CoconutColors.gray800),
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
                          color: CoconutColors.white.withOpacity(0.15),
                        ),
                        child: Text(
                          t.negative_feedback_screen.text4,
                          style: CoconutTypography.body2_14_Bold.setColor(CoconutColors.white),
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
