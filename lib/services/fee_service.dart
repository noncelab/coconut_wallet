import 'package:coconut_wallet/services/model/response/recommended_fee.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:dio/dio.dart';

class FeeService {
  final Dio _dio = Dio();

  /// mempool.space API 사용
  Future<RecommendedFee> getRecommendedFees() async {
    try {
      final response = await _dio.get('https://mempool.space/api/v1/fees/recommended');

      return RecommendedFee(
        response.data['fastestFee'] ?? 20,
        response.data['halfHourFee'] ?? 10,
        response.data['hourFee'] ?? 5,
        response.data['economyFee'] ?? 1,
        response.data['minimumFee'] ?? 1,
      );
    } catch (e) {
      Logger.error('FeeService: Failed to get recommended fees: $e');
      // 폴백: 안전한 기본값
      return _getDefaultValues();
    }
  }

  /// 멤풀 및 블록스트림 API에서 수수료 정보 수집
  Future<RecommendedFee> getRecommendedFeesWithFallback() async {
    final sources = [
      () => _getMempoolSpaceFees(),
      () => _getBlockstreamFees(),
    ];

    for (final source in sources) {
      try {
        return await source().timeout(const Duration(seconds: 3));
      } catch (e) {
        Logger.error('FeeService: Source failed: $e');
        continue; // 다음 소스 시도
      }
    }

    Logger.log('FeeService: All sources failed, using default values');
    return _getDefaultValues();
  }

  /// 기본값 반환
  RecommendedFee _getDefaultValues() {
    return RecommendedFee(
      20, // fastestFee
      10, // halfHourFee
      5, // hourFee
      1, // economyFee
      1, // minimumFee
    );
  }

  /// mempool.space API
  Future<RecommendedFee> _getMempoolSpaceFees() async {
    final response = await _dio.get('https://mempool.space/api/v1/fees/recommended');
    return RecommendedFee(
      response.data['fastestFee'] ?? 20,
      response.data['halfHourFee'] ?? 10,
      response.data['hourFee'] ?? 5,
      response.data['economyFee'] ?? 1,
      response.data['minimumFee'] ?? 1,
    );
  }

  /// blockstream.info API
  Future<RecommendedFee> _getBlockstreamFees() async {
    final response = await _dio.get('https://blockstream.info/api/fee-estimates');

    // blockstream API 데이터 변환
    final Map<String, dynamic> estimates = response.data;

    return RecommendedFee(
      (estimates['1'] ?? 20).round(), // fastestFee (1 block)
      (estimates['3'] ?? 10).round(), // halfHourFee (3 blocks)
      (estimates['6'] ?? 5).round(), // hourFee (6 blocks)
      (estimates['10'] ?? 1).round(), // economyFee (10 blocks)
      1, // minimumFee
    );
  }
}
