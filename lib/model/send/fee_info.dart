import 'package:coconut_wallet/enums/transaction_enums.dart';

class FeeInfoWithLevel extends FeeInfo {
  final TransactionFeeLevel level;

  FeeInfoWithLevel({
    required this.level,
    super.estimatedFee,
    super.fiatValue,
    super.satsPerVb,
    super.failedEstimation, // 현재 활용 안함
    super.isEstimating, // 현재 활용 안함
  });
}

class FeeInfo {
  int? estimatedFee;
  int? fiatValue;
  double? satsPerVb;
  bool failedEstimation;
  bool isEstimating;

  FeeInfo(
      {this.estimatedFee,
      this.fiatValue,
      this.satsPerVb,
      this.failedEstimation = false,
      this.isEstimating = false});
}
