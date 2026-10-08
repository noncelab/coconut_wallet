import 'package:coconut_wallet/services/historical_bitcoin_price_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('bitFlyer daily candles', () {
    const day = 86400000;
    final now = DateTime.utc(2026, 10, 8, 3);
    final todayStart = DateTime.utc(2026, 10, 8).millisecondsSinceEpoch;

    test('keeps only closed days, oldest first, using the close price', () {
      final candles = [
        [todayStart, 13179110, 13179110, 13137033, 13158962, 5.6],
        [todayStart - day, 13560491, 13576210, 13104907, 13180118, 313.3],
        [todayStart - 2 * day, 13565424, 13693673, 13477009, 13561041, 195.9],
      ];

      expect(HistoricalBitcoinPriceService.closedDailyClosesFromBitflyer(candles, now), [13561041, 13180118]);
    });

    test('keeps at most the latest 32 closed days', () {
      final candles = [
        for (var i = 1; i <= 40; i++) [todayStart - i * day, 0, 0, 0, i, 0],
      ];

      final closes = HistoricalBitcoinPriceService.closedDailyClosesFromBitflyer(candles, now);

      expect(closes, hasLength(32));
      expect(closes.first, 32);
      expect(closes.last, 1);
    });

    test('ignores malformed rows', () {
      final candles = [
        'x',
        [todayStart - day],
        [todayStart - day, 1, 2, 3, null],
        [todayStart - 2 * day, 1, 2, 3, 7],
      ];

      expect(HistoricalBitcoinPriceService.closedDailyClosesFromBitflyer(candles, now), [7]);
    });
  });
}
