import 'package:coconut_wallet/model/enums.dart';
import 'package:coconut_wallet/screens/send/send_fee_selection_screen.dart';
import 'package:flutter/cupertino.dart';

class FeeSelectionScreen extends StatefulWidget {
  final List<FeeInfoWithLevel> feeInfos;
  final Future<int> Function(int satsPerVb) onCustomSelected;
  final TransactionFeeLevel? selectedFeeLevel; // null인 경우 직접 입력한 경우
  final int? estimatedFeeOfCustomFeeRate; // feeRate을 직접 입력한 경우의 예상 수수료
  final bool isRecommendedFeeFetchSuccess;

  const FeeSelectionScreen(
      {super.key,
      required this.feeInfos,
      required this.onCustomSelected,
      this.selectedFeeLevel,
      this.estimatedFeeOfCustomFeeRate,
      this.isRecommendedFeeFetchSuccess = true});

  @override
  State<FeeSelectionScreen> createState() => _FeeSelectionScreenState();
}

class _FeeSelectionScreenState extends State<FeeSelectionScreen> {
  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}
