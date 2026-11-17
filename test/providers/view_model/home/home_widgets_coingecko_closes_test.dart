// CoinGecko 문서(coins/{id}/market_chart): "The last completed UTC day (00:00) is available after 00:35 UTC the next day"
// → UTC 자정부터 00:35까지는 방금 마감된 날의 종가(오늘 00:00 점)가 아직 응답에 없다.
// 실제 HistoricalBitcoinPriceService(응답 해석)와 실제 HomeWidgetsViewModel로, 그 사이에 종가를 받으면 어떻게 되는지 본다.
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/price_provider.dart';
import 'package:coconut_wallet/providers/view_model/home/home_widgets_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/services/historical_bitcoin_price_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

const _day = Duration(days: 1);
int availabilityMinutes = 35;

/// 날짜별 종가(UTC). 11/15는 90,000, 11/16은 95,000, 나머지는 80,000.
double _closeOf(DateTime utcDay) {
  if (utcDay == DateTime.utc(2026, 11, 15)) return 90000;
  if (utcDay == DateTime.utc(2026, 11, 16)) return 95000;
  return 80000;
}

/// CoinGecko market_chart(days=100) 모양: UTC 자정 점 100개(각 점은 직전 날의 종가) + 지금 시각의 마지막 점.
/// 문서대로 00:35 UTC 전에는 오늘 00:00 점(어제 종가)이 아직 없다.
Map<String, dynamic> _marketChart(DateTime nowUtc) {
  final today = DateTime.utc(nowUtc.year, nowUtc.month, nowUtc.day);
  final lastCompletedIsAvailable = nowUtc.difference(today) >= Duration(minutes: availabilityMinutes);
  final lastMidnight = lastCompletedIsAvailable ? today : today.subtract(_day);
  return {
    'prices': [
      for (var i = 99; i >= 0; i--)
        [
          lastMidnight.subtract(_day * i).millisecondsSinceEpoch,
          _closeOf(lastMidnight.subtract(_day * i).subtract(_day)),
        ],
      [nowUtc.millisecondsSinceEpoch, 100000.0],
    ],
  };
}

class _ChartDio extends Fake implements Dio {
  _ChartDio(this._now);

  final DateTime Function() _now;
  final requests = <({String path, Map<String, dynamic>? query, DateTime at})>[];

  @override
  Future<Response<T>> get<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) async {
    requests.add((path: path, query: queryParameters, at: _now()));
    return Response<T>(requestOptions: RequestOptions(), data: _marketChart(_now()) as T, statusCode: 200);
  }
}

class _Prices extends Fake with ChangeNotifier implements PriceProvider {
  final prices = <FiatCode, int>{FiatCode.THB: 100000};
  DateTime receivedAt = DateTime.utc(2026, 11, 16, 23);

  /// CoinGecko 새 시세가 들어온 것처럼 알린다(60초 주기).
  void tick(DateTime at) {
    receivedAt = at;
    notifyListeners();
  }

  @override
  int? getBitcoinPriceForFiat(FiatCode fiatCode) => prices[fiatCode];

  @override
  DateTime? priceReceivedAt(FiatCode fiatCode) => prices.containsKey(fiatCode) ? receivedAt : null;
}

class _Wallets extends Fake implements WalletProvider {
  @override
  final ValueNotifier<WalletLoadState> walletLoadStateNotifier = ValueNotifier(WalletLoadState.loadCompleted);

  @override
  final ValueNotifier<List<WalletItemBase>> walletItemListNotifier = ValueNotifier(const []);
}

class _Preferences extends Fake with ChangeNotifier implements PreferenceProvider {}

void main() {
  setUp(() => availabilityMinutes = 35);
  const thb = FiatCode.THB;
  late DateTime clock;
  late _ChartDio dio;
  late _Prices prices;
  late HomeWidgetsViewModel viewModel;

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  void create() {
    dio = _ChartDio(() => clock);
    prices = _Prices();
    viewModel = HomeWidgetsViewModel(
      walletProvider: _Wallets(),
      preferenceProvider: _Preferences(),
      priceProvider: prices,
      targetSatsOf: (_) => null,
      historicalPriceService: HistoricalBitcoinPriceService(dio: dio, now: () => clock),
      now: () => clock,
    );
    addTearDown(viewModel.dispose);
  }

  /// 위젯이 다시 그려질 때처럼 값을 읽고, 시작된 요청이 끝나기를 기다린다.
  Future<double?> readChange(DateTime at) async {
    clock = at;
    prices.tick(at);
    viewModel.priceChange24h(thb);
    await settle();
    return viewModel.priceChange24h(thb);
  }

  const vsNov15 = 100000 / 90000 - 1; // 그저께 종가 대비
  const vsNov16 = 100000 / 95000 - 1; // 어제 종가 대비

  test('요청 모양: CoinGecko 통화의 종가는 market_chart를 vs_currency·days=100으로 묻는다', () async {
    clock = DateTime.utc(2026, 11, 16, 12);
    create();
    await readChange(clock);

    expect(dio.requests.single.path, 'https://api.coingecko.com/api/v3/coins/bitcoin/market_chart');
    expect(dio.requests.single.query, {'vs_currency': 'thb', 'days': 100});
    expect(viewModel.dailyPrices(thb, days: 3), [80000, 90000, 100000]);
  });

  test('앱을 켜 둔 채 UTC 자정을 넘기면, 00:40 뒤에는 어제(11/16) 종가 대비로 보여 준다', () async {
    clock = DateTime.utc(2026, 11, 16, 23, 30);
    create();
    final before = await readChange(clock);
    expect(before, closeTo(vsNov15, 1e-9), reason: '11/16 23:30에는 마지막으로 마감된 날이 11/15');

    for (final at in [
      DateTime.utc(2026, 11, 17, 0, 1), // 자정 직후: 00:40 전이라 받아 둔 종가를 그대로 쓴다
      DateTime.utc(2026, 11, 17, 0, 36), // 새 종가가 올라온 뒤
      DateTime.utc(2026, 11, 17, 1, 0),
      DateTime.utc(2026, 11, 17, 12, 0),
      DateTime.utc(2026, 11, 17, 23, 59),
    ]) {
      await readChange(at);
    }

    final afterNoon = await readChange(DateTime.utc(2026, 11, 17, 12, 0));
    expect(afterNoon, closeTo(vsNov16, 1e-9), reason: '11/17 낮에는 어제(11/16) 종가 95,000 대비여야 한다');
    expect(viewModel.dailyPrices(thb, days: 3), [90000, 95000, 100000]);
  });

  test('UTC 00:00~00:40 사이에 앱을 켜도, 00:40 뒤에는 어제(11/16) 종가 대비로 보여 준다', () async {
    clock = DateTime.utc(2026, 11, 17, 0, 10);
    create();
    final atStart = await readChange(clock);
    expect(atStart, closeTo(vsNov15, 1e-9), reason: '00:40 전에는 받아 둔 종가를 유지한다');
    final afterNoon = await readChange(DateTime.utc(2026, 11, 17, 12, 0));

    expect(afterNoon, closeTo(vsNov16, 1e-9), reason: '11/17 낮에는 어제(11/16) 종가 95,000 대비여야 한다');
  });

  test('00:36에는 캐시를 유지하고 00:40에 최신 종가를 받는다', () async {
    clock = DateTime.utc(2026, 11, 17, 0, 10);
    create();
    await readChange(clock);
    final at36 = await readChange(DateTime.utc(2026, 11, 17, 0, 36));
    expect(at36, closeTo(vsNov15, 1e-9));
    expect(dio.requests, hasLength(1));
    final at40 = await readChange(DateTime.utc(2026, 11, 17, 0, 40));
    expect(at40, closeTo(vsNov16, 1e-9));
    expect(dio.requests, hasLength(2));
  });

  test('서버가 00:45에야 최신 종가를 주어도 00:40의 낡은 응답을 하루 동안 고정하지 않는다', () async {
    availabilityMinutes = 45;
    clock = DateTime.utc(2026, 11, 16, 23, 30);
    create();
    expect(await readChange(clock), closeTo(vsNov15, 1e-9));
    expect(await readChange(DateTime.utc(2026, 11, 17, 0, 40)), closeTo(vsNov15, 1e-9));
    final actual = await readChange(DateTime.utc(2026, 11, 17, 0, 46));
    expect(actual, closeTo(vsNov16, 1e-9));
  });

  test('대조: UTC 00:40에 앱을 켜면 어제 종가 대비다', () async {
    clock = DateTime.utc(2026, 11, 17, 0, 40);
    create();
    final change = await readChange(clock);

    expect(change, closeTo(vsNov16, 1e-9));
    expect(viewModel.dailyPrices(thb, days: 3), [90000, 95000, 100000]);
  });
}
