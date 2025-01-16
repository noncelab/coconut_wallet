import 'package:coconut_wallet/constants/app_info.dart';
import 'package:coconut_wallet/widgets/overlays/user_experience_survey_bottom_sheet.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/widgets/overlays/common_bottom_sheets.dart';
import 'package:flutter/cupertino.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:coconut_wallet/services/shared_prefs_service.dart';

class AppReviewService {
  static const int gapToRequestReview = 5; // 리뷰 요청 간격 (앱 실행 횟수)
  static final InAppReview _inAppReview = InAppReview.instance;

  static Future<void> requestReview() async {
    try {
      if (await _inAppReview.isAvailable()) {
        _inAppReview.requestReview();
      } else {
        _inAppReview.openStoreListing(appStoreId: APPSTORE_ID);
      }
    } catch (_) {
      _inAppReview.openStoreListing(appStoreId: APPSTORE_ID);
    } finally {
      setHasReviewed();
    }
  }

  /// ----------------- 리뷰 요청 관련 로직 -----------------

  /// 비트코인 전송을 완료한 적이 있는지 여부를 반환한다.
  static bool? _hasCompletedBitcoinTransfer() {
    final sharedPrefs = SharedPrefs();
    return sharedPrefs.sharedPrefs.getBool(SharedPrefs.kHaveSent);
  }

  static Future _setCompletedBitcoinTransfer() async {
    await SharedPrefs().sharedPrefs.setBool(SharedPrefs.kHaveSent, true);
  }

  /// 리뷰를 남긴 적이 있는지 여부를 반환한다.
  static bool? _hasReviewed() {
    final sharedPrefs = SharedPrefs();
    return sharedPrefs.sharedPrefs.getBool(SharedPrefs.kHaveReviewed);
  }

  static Future setHasReviewed() async {
    await SharedPrefs().sharedPrefs.setBool(SharedPrefs.kHaveReviewed, true);
  }

  /// 비트코인 전송 첫 성공 후 앱 실행 횟수를 반환한다.
  /// 리뷰를 남긴 후에는 기록하지 않으므로 언제나 정확한 값은 아님
  static int? _getAppRunningCountAfterRejectReview() {
    final sharedPrefs = SharedPrefs();
    return sharedPrefs.sharedPrefs
        .getInt(SharedPrefs.kAppRunCountAfterRejectReview);
  }

  /// 비트코인 전송을 완료한 적이 있고, 리뷰를 남긴 적이 없으면, 앱 실행 시 마다 count를 1씩 증가시켜 저장한다.
  static Future<void> _increaseAppRunningCountIfRejected() async {
    final sharedPrefs = SharedPrefs();
    if (_hasCompletedBitcoinTransfer() == true && _hasReviewed() != true) {
      final count = sharedPrefs.sharedPrefs
              .getInt(SharedPrefs.kAppRunCountAfterRejectReview) ??
          0;
      await sharedPrefs.sharedPrefs
          .setInt(SharedPrefs.kAppRunCountAfterRejectReview, count + 1);
    }
  }

  /// 앱 실행 후에 리뷰를 요청해도 되는 조건인지 여부를 반환한다.
  /// 리뷰 남기기를 거절한 후에 앱 실행 횟수가 gapToRequestReview의 배수인 경우
  static bool _canRequestReview() {
    bool? reviewBefore = _hasReviewed();
    if (reviewBefore == true) return false;

    final int? count = _getAppRunningCountAfterRejectReview();

    return count != null && count % gapToRequestReview == 0;
  }

  static Future<dynamic> _showReviewScreen(BuildContext context,
      {bool isFirst = false, AnimationController? animationController}) {
    return CommonBottomSheets.showBottomSheet_100(
        context: context,
        child: UserExperienceSurveyBottomSheet(
          isFirst: isFirst,
        ),
        enableDrag: false,
        backgroundColor: MyColors.nero,
        isDismissible: false,
        isScrollControlled: true,
        useSafeArea: false,
        animationController: animationController);
  }

  static Future<dynamic>? showReviewScreenIfFirstSending(BuildContext context,
      {AnimationController? animationController}) {
    if (_hasCompletedBitcoinTransfer() == true) return null;
    _setCompletedBitcoinTransfer();
    return _showReviewScreen(context,
        isFirst: true, animationController: animationController);
  }

  static void showReviewScreenIfEligible(BuildContext context,
      {AnimationController? animationController}) {
    if (_hasCompletedBitcoinTransfer() != true) return;

    if (_canRequestReview()) {
      _showReviewScreen(context, animationController: animationController);
    }
    _increaseAppRunningCountIfRejected();
  }
}
