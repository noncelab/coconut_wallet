import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/constants/external_links.dart';
import 'package:coconut_wallet/services/model/response/recommended_fee.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:dio/dio.dart';

class FeeService {
  final Dio _dio = Dio();
  final String path =
      NetworkType.currentNetworkType == NetworkType.mainnet ? FEE_SERVICE_URL_MAINNET : FEE_SERVICE_URL_REGTEST;

  /// 멤풀 및 블록스트림 API에서 수수료 정보 수집
  Future<RecommendedFee?> getRecommendedFees() async {
    // 2번 시도
    final sources = [() => _getMempoolSpaceFees(), () => _getMempoolSpaceFees()];

    for (final source in sources) {
      try {
        return await source();
      } catch (e) {
        Logger.error('FeeService: getting recommended fees failed: $e');
        continue; // 다음 소스 시도
      }
    }
    return null;
  }

  /// mempool.space API
  Future<RecommendedFee> _getMempoolSpaceFees() async {
    final response = await _dio.get(
      path,
      options: Options(sendTimeout: const Duration(seconds: 5), receiveTimeout: const Duration(seconds: 8)),
    );

    return RecommendedFee(
      (response.data['fastestFee'] as num?)?.toInt(),
      (response.data['halfHourFee'] as num?)?.toInt(),
      (response.data['hourFee'] as num?)?.toInt(),
      (response.data['economyFee'] as num?)?.toInt(),
      (response.data['minimumFee'] as num?)?.toInt(),
    );
  }
}
