import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/providers/app_state_model.dart';
import 'package:coconut_wallet/services/recommend_fee_service.dart';

Future<RecommendedFee?> fetchRecommendedFees(AppStateModel model) async {
  try {
    RecommendedFee recommendedFee = await RecommendFeeService.getRecommendFee();

    /// 포우 월렛은 수수료를 너무 낮게 보내서 1시간 이상 트랜잭션이 펜딩되는 것을 막는 방향으로 구현하자고 결정되었습니다.
    /// 따라서 트랜잭션 전송 시점에, 네트워크 상 최소 수수료 값 미만으로는 수수료를 설정할 수 없게 해야 합니다.
    Result<int, CoconutError>? minimumFeeResult =
        await model.getMinimumNetworkFeeRate();
    if (minimumFeeResult != null &&
        minimumFeeResult.isSuccess &&
        minimumFeeResult.value != null) {
      return RecommendedFee(
          recommendedFee.fastestFee,
          recommendedFee.halfHourFee,
          recommendedFee.hourFee,
          recommendedFee.economyFee,
          minimumFeeResult.value!);
    }

    //RecommendedFee recommendedFee = RecommendedFee(20, 19, 12, 3, 3);
    return recommendedFee;
  } catch (e) {
    return null;
  }
}
