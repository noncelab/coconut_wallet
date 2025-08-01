import 'package:coconut_wallet/model/error/app_error.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/services/fee_service.dart';
import 'package:coconut_wallet/services/model/response/recommended_fee.dart';
import 'package:coconut_wallet/utils/result.dart';

Future<RecommendedFee> getRecommendedFees(NodeProvider nodeProvider) async {
  final nodeProviderResult = await nodeProvider.getRecommendedFees().timeout(
    const Duration(seconds: 10), // 타임아웃 초
    onTimeout: () {
      return Result.failure(
          const AppError('NodeProvider', 'TimeoutException: Isolate response timeout'));
    },
  );

  if (nodeProviderResult.isSuccess) {
    return nodeProviderResult.value;
  }

  return await FeeService().getRecommendedFees();
}
