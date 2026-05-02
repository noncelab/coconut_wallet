import 'package:coconut_wallet/enums/transaction_enums.dart';
import 'package:coconut_wallet/model/send/fee_info.dart';
import 'package:coconut_wallet/services/fee_service.dart';
import 'package:coconut_wallet/utils/text_field_filter_util.dart';
import 'package:flutter/foundation.dart';

enum RecommendedFeeFetchStatus { fetching, succeed, failed }

mixin FeeRateMixin on ChangeNotifier {
  RecommendedFeeFetchStatus _recommendedFeeFetchStatus = RecommendedFeeFetchStatus.fetching;
  RecommendedFeeFetchStatus get recommendedFeeFetchStatus => _recommendedFeeFetchStatus;

  List<FeeInfoWithLevel> feeInfos = [
    FeeInfoWithLevel(level: TransactionFeeLevel.fastest),
    FeeInfoWithLevel(level: TransactionFeeLevel.halfhour),
    FeeInfoWithLevel(level: TransactionFeeLevel.hour),
  ];

  double? _minimumFeeRate;
  double? get minimumFeeRate => _minimumFeeRate;

  Future<bool> fetchRecommendedFees({
    required String currentFeeRateText,
    required void Function(String) onDefaultFeeRateSet,
  }) async {
    if (_recommendedFeeFetchStatus == RecommendedFeeFetchStatus.fetching && feeInfos[0].satsPerVb != null) return true;

    _recommendedFeeFetchStatus = RecommendedFeeFetchStatus.fetching;
    notifyListeners();

    final recommendedFees = await FeeService().getRecommendedFees();

    if (recommendedFees == null) {
      _recommendedFeeFetchStatus = RecommendedFeeFetchStatus.failed;
      notifyListeners();
      return false;
    }

    feeInfos[0].satsPerVb = recommendedFees.fastestFee;
    feeInfos[1].satsPerVb = recommendedFees.halfHourFee;
    feeInfos[2].satsPerVb = recommendedFees.hourFee;
    _minimumFeeRate = recommendedFees.halfHourFee;

    if (currentFeeRateText.isEmpty && recommendedFees.halfHourFee != null) {
      onDefaultFeeRateSet(recommendedFees.halfHourFee.toString());
    }

    _recommendedFeeFetchStatus = RecommendedFeeFetchStatus.succeed;
    notifyListeners();
    return true;
  }

  // 숫자 입력값인데 0 또는 0.1 미만이어서 보정을 했는지를 반환, '-'일 때는 false
  bool handleFeeRateChanged(String text, void Function(String) updateText) {
    if (text == "-") return false;
    String formattedText = filterNumericInput(text, integerPlaces: 8, decimalPlaces: 2);
    double? parsedFeeRate = double.tryParse(formattedText);

    if ((formattedText != '0' && formattedText != '0.' && formattedText != '0.0') &&
        (parsedFeeRate != null && parsedFeeRate < 0.1)) {
      updateText('0.');
      return true;
    }
    updateText(formattedText);
    return false;
  }

  String removeTrailingDotInFeeRateText(String text) {
    if (text.endsWith('.')) {
      return text.substring(0, text.length - 1);
    }
    return text;
  }
}
