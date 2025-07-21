import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/model/error/app_error.dart';
import 'package:coconut_wallet/services/model/response/block_header.dart';
import 'package:coconut_wallet/services/model/response/block_timestamp.dart';
import 'package:coconut_wallet/services/model/response/recommended_fee.dart';
import 'package:coconut_wallet/services/electrum_service.dart';
import 'package:coconut_wallet/utils/result.dart';

/// NodeProvider의 네트워크 관련 기능을 담당하는 서비스 클래스
/// ElectrumService의 네트워크 관련 기능을 직접 구현합니다.
class NetworkService {
  final ElectrumService _electrumService;

  NetworkService(this._electrumService);

  /// 네트워크 최소 수수료율을 조회합니다.
  Future<Result<double>> getNetworkMinimumFeeRate() async {
    try {
      final feeHistogram = await _electrumService.getMempoolFeeHistogram();
      if (feeHistogram.isEmpty) {
        return Result.success(0.1);
      }

      num minimumFeeRate = feeHistogram.last.first;
      feeHistogram.map((feeInfo) => feeInfo.first).forEach((feeRate) {
        if (minimumFeeRate > feeRate) {
          minimumFeeRate = feeRate;
        }
      });

      return Result.success(minimumFeeRate.toDouble());
    } catch (e) {
      return Result.failure(e is AppError ? e : ErrorCodes.nodeUnknown);
    }
  }

  /// 최신 블록 정보를 조회합니다.
  Future<Result<BlockTimestamp>> getLatestBlock() async {
    try {
      var result = await _electrumService.getCurrentBlock();
      var blockHeader = BlockHeader.parse(result.height, result.hex);
      return Result.success(BlockTimestamp(
        blockHeader.height,
        DateTime.fromMillisecondsSinceEpoch(blockHeader.timestamp * 1000, isUtc: true),
      ));
    } catch (e) {
      return Result.failure(e is AppError ? e : ErrorCodes.nodeUnknown);
    }
  }

  /// 권장 수수료 정보를 조회합니다.
  Future<Result<RecommendedFee>> getRecommendedFees() async {
    try {
      // 1. mempool.get_fee_histogram 호출
      //    결과는 [[fee, vsize], [fee, vsize], ...] 형태이며 fee 단위는 sat/vB.
      final dynamic histogramResult = await _electrumService.getMempoolFeeHistogram();
      List<List<dynamic>> histogram = [];
      if (histogramResult is List) {
        for (var entry in histogramResult) {
          if (entry is List && entry.length >= 2) {
            histogram.add(entry);
          }
        }
      }

      // 2. blockchain.estimatefee를 여러 블록 목표로 호출하여 fee rate (BTC/kB)를 가져옴
      //    여기서는 아래와 같이 확인 목표를 정합니다.
      const int fastestTarget = 1; // 빠른 확인 (예: 1블록 이내)
      const int halfHourTarget = 3; // 30분 내 확인 (3블록)
      const int hourTarget = 6; // 1시간 내 확인 (6블록)
      const int economyTarget = 10; // 경제적 확인 (10블록)

      // 각 목표에 대해 fee 추정값 호출 (BTC/kB 단위)
      final dynamic feeFastRaw = await _electrumService.estimateFee(fastestTarget);
      final dynamic feeHalfHourRaw = await _electrumService.estimateFee(halfHourTarget);
      final dynamic feeHourRaw = await _electrumService.estimateFee(hourTarget);
      final dynamic feeEconomyRaw = await _electrumService.estimateFee(economyTarget);

      // 반환값이 -1이면 충분한 정보가 없다는 뜻이므로 0으로 처리 (추후 대체)
      double feeFast = (feeFastRaw is int ? feeFastRaw.toDouble() : feeFastRaw) as double;
      double feeHalfHour =
          (feeHalfHourRaw is int ? feeHalfHourRaw.toDouble() : feeHalfHourRaw) as double;
      double feeHour = (feeHourRaw is int ? feeHourRaw.toDouble() : feeHourRaw) as double;
      double feeEconomy =
          (feeEconomyRaw is int ? feeEconomyRaw.toDouble() : feeEconomyRaw) as double;
      feeFast = feeFast > 0 ? feeFast : 0;
      feeHalfHour = feeHalfHour > 0 ? feeHalfHour : 0;
      feeHour = feeHour > 0 ? feeHour : 0;
      feeEconomy = feeEconomy > 0 ? feeEconomy : 0;

      // 3. BTC/kB 단위를 sat/vB로 변환
      int fastestFee = feeFast > 0 ? _convertFeeToSatPerVByte(feeFast) : 0;
      int halfHourFee = feeHalfHour > 0 ? _convertFeeToSatPerVByte(feeHalfHour) : 0;
      int hourFee = feeHour > 0 ? _convertFeeToSatPerVByte(feeHour) : 0;
      int economyFee = feeEconomy > 0 ? _convertFeeToSatPerVByte(feeEconomy) : 0;

      // 4. 최소 수수료 (minimumFee)는 mempool 내에서 지불되고 있는 가장 낮은 fee rate (sat/vB)
      // 소수점 지원을 위해 double로 처리
      double minimumFee = 0.1;
      // histogram이 존재하면 마지막 요소의 fee를 최소 수수료로 설정
      minimumFee = histogram.isNotEmpty ? (histogram.last[0] as num).toDouble() : 0.1;

      // 최소 수수료의 반올림 값을 미리 계산
      final int minimumFeeRounded = minimumFee.round() == 0 ? 1 : minimumFee.round();

      // 수수료가 0인 경우 최소 수수료나 기본값 1로 대체하는 함수
      int getValidFee(int fee) => fee > 0 ? fee : minimumFeeRounded;

      // 각 수수료 레벨에 대해 유효한 값 설정
      fastestFee = getValidFee(fastestFee);
      halfHourFee = getValidFee(halfHourFee);
      hourFee = getValidFee(hourFee);
      economyFee = getValidFee(economyFee);

      return Result.success(
          RecommendedFee(fastestFee, halfHourFee, hourFee, economyFee, minimumFee));
    } catch (e) {
      return Result.failure(e is AppError ? e : ErrorCodes.nodeUnknown);
    }
  }

  /// blockchain.estimatefee가 반환하는 BTC/kB 단위를 sat/vB 단위로 변환합니다.
  int _convertFeeToSatPerVByte(double feeBtcPerKb) {
    // 1 BTC = 1e8 sat, 1 kB = 1000 vB → 변환 계수는 1e8/1000 = 100000
    return (feeBtcPerKb * 100000).round();
  }

  /// 트랜잭션을 브로드캐스트합니다.
  Future<Result<String>> broadcast(Transaction signedTx) async {
    try {
      final txHash = await _electrumService.broadcast(signedTx.serialize());

      return Result.success(txHash);
    } catch (e) {
      return Result.failure(ErrorCodes.broadcastErrorWithMessage(e.toString()));
    }
  }

  /// 특정 트랜잭션을 조회합니다.
  Future<Result<String>> getTransaction(String txHash) async {
    try {
      final tx = await _electrumService.getTransaction(txHash);
      return Result.success(tx);
    } catch (e) {
      return Result.failure(e is AppError ? e : ErrorCodes.nodeUnknown);
    }
  }
}
