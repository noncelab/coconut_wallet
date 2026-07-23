import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/model/price/historical_bitcoin_prices.dart';
import 'package:dio/dio.dart';

class HistoricalBitcoinPriceService {
  static const int _requiredClosedCandleCount = 30;

  final Dio _dio;

  HistoricalBitcoinPriceService({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 5),
              receiveTimeout: const Duration(seconds: 5),
            ),
          );

  Future<HistoricalBitcoinPrices?> fetch(FiatCode fiatCode) {
    return switch (fiatCode) {
      FiatCode.KRW => _fetchUpbitPrices(),
      FiatCode.USD => _fetchBinancePrices('BTCUSDT'),
      FiatCode.EUR => _fetchBinancePrices('BTCEUR'),
      FiatCode.JPY => Future.value(null),
    };
  }

  Future<HistoricalBitcoinPrices> _fetchUpbitPrices() async {
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
    return _toHistoricalPrices(
      closedPrices.map((candle) => candle.close).toList(),
    );
  }

  Future<HistoricalBitcoinPrices> _fetchBinancePrices(String symbol) async {
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

    return _toHistoricalPrices(closedPrices);
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
