import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/model/price/historical_bitcoin_prices.dart';
import 'package:dio/dio.dart';

class HistoricalBitcoinPriceService {
  static const int _requiredClosedCandleCount = 30;

  final Dio _dio;

  HistoricalBitcoinPriceService({Dio? dio})
    : _dio =
          dio ??
          Dio(BaseOptions(connectTimeout: const Duration(seconds: 5), receiveTimeout: const Duration(seconds: 5)));

  Future<HistoricalBitcoinPrices?> fetch(FiatCode fiatCode) {
    return switch (fiatCode) {
      FiatCode.KRW => _fetchUpbitPrices(),
      FiatCode.USD => _fetchBinancePrices('BTCUSDT'),
      FiatCode.EUR => _fetchBinancePrices('BTCEUR'),
      FiatCode.JPY => _fetchBitflyerDailyCloses().then(_toHistoricalPrices),
    };
  }

  /// 마감된 일봉 종가 목록. 오래된 날부터 어제까지.
  Future<List<double>?> fetchDailyCloses(FiatCode fiatCode) {
    return switch (fiatCode) {
      FiatCode.KRW => _fetchUpbitDailyCloses(),
      FiatCode.USD => _fetchBinanceDailyCloses('BTCUSDT'),
      FiatCode.EUR => _fetchBinanceDailyCloses('BTCEUR'),
      FiatCode.JPY => _fetchBitflyerDailyCloses(),
    };
  }

  // bitFlyer 공개 API에는 일봉이 없어, bitFlyer 웹 차트가 쓰는 비공식 주소를 쓴다. 바뀌면 실패하고 값 없음으로 처리된다.
  Future<List<double>> _fetchBitflyerDailyCloses() async {
    final now = DateTime.now().toUtc();
    final response = await _dio.get<List<dynamic>>(
      'https://lightchart.bitflyer.com/api/ohlc',
      queryParameters: {
        'symbol': 'BTC_JPY',
        'period': 'd',
        'before': DateTime.utc(now.year, now.month, now.day).millisecondsSinceEpoch,
        'type': 'full',
        'grouping': 1,
      },
    );
    return closedDailyClosesFromBitflyer(response.data ?? const [], now);
  }

  /// bitFlyer 일봉 응답([시작 ms, 시가, 고가, 저가, 종가, …], 최신순)에서 마감된 날의 종가만 오래된 날부터
  static List<double> closedDailyClosesFromBitflyer(List<dynamic> candles, DateTime now) {
    final nowMilliseconds = now.toUtc().millisecondsSinceEpoch;
    final closed = <({int start, double close})>[];
    for (final candle in candles) {
      if (candle is! List || candle.length < 5) continue;
      final start = (candle[0] as num?)?.toInt();
      final close = (candle[4] as num?)?.toDouble();
      if (start == null || close == null) continue;
      if (start + const Duration(days: 1).inMilliseconds > nowMilliseconds) continue;
      closed.add((start: start, close: close));
    }
    closed.sort((a, b) => a.start.compareTo(b.start));
    return [for (final candle in closed.skip(closed.length > 32 ? closed.length - 32 : 0)) candle.close];
  }

  Future<HistoricalBitcoinPrices> _fetchUpbitPrices() async => _toHistoricalPrices(await _fetchUpbitDailyCloses());

  Future<List<double>> _fetchUpbitDailyCloses() async {
    final response = await _dio.get<List<dynamic>>(
      'https://api.upbit.com/v1/candles/days',
      queryParameters: {'market': 'KRW-BTC', 'count': 32},
    );
    final candles = response.data ?? const [];
    final now = DateTime.now().toUtc();
    final closedPrices = <({DateTime start, double close})>[];

    for (final candle in candles.whereType<Map<String, dynamic>>()) {
      final candleStartText = candle['candle_date_time_utc'] as String?;
      final close = (candle['trade_price'] as num?)?.toDouble();
      if (candleStartText == null || close == null) continue;

      final candleStart = DateTime.parse('${candleStartText}Z');
      if (candleStart.add(const Duration(days: 1)).isAfter(now)) continue;
      closedPrices.add((start: candleStart, close: close));
    }

    closedPrices.sort((a, b) => a.start.compareTo(b.start));
    return closedPrices.map((candle) => candle.close).toList();
  }

  Future<HistoricalBitcoinPrices> _fetchBinancePrices(String symbol) async =>
      _toHistoricalPrices(await _fetchBinanceDailyCloses(symbol));

  Future<List<double>> _fetchBinanceDailyCloses(String symbol) async {
    final response = await _dio.get<List<dynamic>>(
      'https://api.binance.com/api/v3/klines',
      queryParameters: {'symbol': symbol, 'interval': '1d', 'limit': 32},
    );
    final nowMilliseconds = DateTime.now().toUtc().millisecondsSinceEpoch;
    final closedPrices = <double>[];

    for (final candle in response.data ?? const []) {
      if (candle is! List || candle.length <= 6) continue;
      final closeTime = candle[6] as int?;
      final close = double.tryParse(candle[4].toString());
      if (closeTime == null || close == null || closeTime >= nowMilliseconds) {
        continue;
      }
      closedPrices.add(close);
    }

    return closedPrices;
  }

  HistoricalBitcoinPrices _toHistoricalPrices(List<double> closedPrices) {
    if (closedPrices.length < _requiredClosedCandleCount) {
      throw StateError(
        'Not enough closed daily candles: '
        '${closedPrices.length}/$_requiredClosedCandleCount',
      );
    }

    return HistoricalBitcoinPrices(
      previousDayClose: closedPrices.last,
      sevenDaysAgoClose: closedPrices[closedPrices.length - 7],
      thirtyDaysAgoClose: closedPrices[closedPrices.length - 30],
    );
  }
}
