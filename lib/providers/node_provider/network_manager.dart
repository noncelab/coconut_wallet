import 'package:coconut_wallet/model/error/app_error.dart';
import 'package:coconut_wallet/services/model/response/block_timestamp.dart';
import 'package:coconut_wallet/services/model/response/recommended_fee.dart';
import 'package:coconut_wallet/services/network/node_client.dart';
import 'package:coconut_wallet/utils/result.dart';

/// NodeProvider의 네트워크 관련 기능을 담당하는 매니저 클래스
class NetworkManager {
  final NodeClient _nodeClient;

  NetworkManager(this._nodeClient);

  /// 네트워크 최소 수수료율을 조회합니다.
  Future<Result<int>> getNetworkMinimumFeeRate() async {
    try {
      final feeRate = await _nodeClient.getNetworkMinimumFeeRate();
      return Result.success(feeRate);
    } catch (e) {
      return Result.failure(e is AppError ? e : ErrorCodes.nodeUnknown);
    }
  }

  /// 최신 블록 정보를 조회합니다.
  Future<Result<BlockTimestamp>> getLatestBlock() async {
    try {
      final block = await _nodeClient.getLatestBlock();
      return Result.success(block);
    } catch (e) {
      return Result.failure(e is AppError ? e : ErrorCodes.nodeUnknown);
    }
  }

  /// 권장 수수료 정보를 조회합니다.
  Future<Result<RecommendedFee>> getRecommendedFees() async {
    try {
      final fees = await _nodeClient.getRecommendedFees();
      return Result.success(fees);
    } catch (e) {
      return Result.failure(e is AppError ? e : ErrorCodes.nodeUnknown);
    }
  }
}
