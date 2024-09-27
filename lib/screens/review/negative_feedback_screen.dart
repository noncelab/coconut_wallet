import 'package:coconut_wallet/services/app_review_service.dart';
import 'package:coconut_wallet/utils/uri_launcher.dart';
import 'package:coconut_wallet/widgets/appbar/custom_appbar.dart';
import 'package:flutter/material.dart';
import 'package:coconut_wallet/styles.dart';

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
      onPopInvoked: (didPop) {
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
                  "죄송합니다😭",
                  style:
                      Styles.h2.merge(const TextStyle(color: MyColors.white)),
                ),
                const SizedBox(
                  height: 20,
                ),
                const Text(
                  "불편한 점이나 개선사항을 저희에게 알려주세요!",
                  style: Styles.body1,
                ),
                const SizedBox(
                  height: 80,
                ),
                GestureDetector(
                  onTap: () => _runKakaoOpenChat(context),
                  child: Container(
                      width: MediaQuery.of(context).size.width * 0.5,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          color: MyColors.primary),
                      child: Text(
                        '1:1 메시지 보내기',
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
