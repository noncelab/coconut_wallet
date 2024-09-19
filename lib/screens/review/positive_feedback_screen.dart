import 'package:coconut_wallet/services/app_review_service.dart';
import 'package:coconut_wallet/widgets/appbar/custom_appbar.dart';
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
      onPopInvoked: (didPop) {
        print(">>>> didPop: $didPop");
        if (!didPop) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        appBar: CustomAppBar.build(
            context: context,
            title: '',
            hasRightIcon: false,
            showTestnetLabel: false),
        backgroundColor: MyColors.black,
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  "감사합니다🥰",
                  style:
                      Styles.h2.merge(const TextStyle(color: MyColors.white)),
                ),
                const SizedBox(
                  height: 20,
                ),
                const Text(
                  "그렇다면 스토어에 리뷰를 남겨주시겠어요?",
                  style: Styles.body1,
                ),
                const SizedBox(
                  height: 80,
                ),
                GestureDetector(
                  onTap: () => _startInAppReview(context),
                  child: Container(
                      width: MediaQuery.of(context).size.width * 0.5,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          color: MyColors.primary),
                      child: Text(
                        '물론이죠',
                        style: Styles.label.merge(const TextStyle(
                            color: MyColors.darkgrey,
                            fontWeight: FontWeight.bold)),
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          color: MyColors.transparentWhite_15),
                      child: Text(
                        '다음에 할게요',
                        style: Styles.label.merge(const TextStyle(
                            color: MyColors.white,
                            fontWeight: FontWeight.bold)),
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
    );
  }
}
