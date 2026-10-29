import 'dart:async';

import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/providers/price_provider.dart';
import 'package:coconut_wallet/providers/view_model/utility/p2p_calculator_view_model.dart';
import 'package:coconut_wallet/services/coingecko_price_service.dart';
import 'package:coconut_wallet/services/web_socket_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../providers/price_provider_test.dart' show ScriptedConnectivity, ScriptedPreference, SocketBook;
import 'p2p_calculator_test.dart' show FakeWalletProvider;

void main() {
  testWidgets('calculator-only quote refreshes after 60 seconds and stops when the calculator closes', (tester) async {
    final h = _Harness();
    try {
      final calculator = h.calculator();
      unawaited(calculator.setFiatCode(FiatCode.CHF));
      await tester.pump();
      expect(h.dio.currencies, [_allCoinGecko]);
      h.dio.requests.last.reply({'chf': 70000});
      await tester.pump();
      expect(calculator.btcPrice, 70000);

      await tester.pump(const Duration(seconds: 59));
      expect(h.dio.requests, hasLength(1));
      await tester.pump(const Duration(seconds: 1));
      h.dio.requests.last.reply({'chf': 80000});
      await tester.pump();
      expect(calculator.btcPrice, 80000);
      calculator.setPremiumRate(0);
      expect(calculator.calculateSatsFromFiat(100000), 1250000);

      h.close(calculator);
      expect(h.prices.getBitcoinPriceForFiat(FiatCode.CHF), isNull);
      await tester.pump(const Duration(minutes: 10));
      expect(h.dio.requests, hasLength(2));
    } finally {
      h.dispose();
    }
  });

  testWidgets('first calculator quote failure retries with shared backoff without reselection', (tester) async {
    final h = _Harness();
    try {
      final calculator = h.calculator();
      unawaited(calculator.setFiatCode(FiatCode.CHF));
      await tester.pump();
      expect(h.dio.requests, hasLength(1));
      h.dio.requests.last.fail();
      await tester.pump();
      expect(calculator.isBtcPriceAvailable, isFalse);
      await tester.pump(const Duration(seconds: 119));
      expect(h.dio.requests, hasLength(1));
      await tester.pump(const Duration(seconds: 1));
      expect(h.dio.requests, hasLength(2));
      h.dio.requests.last.reply({'chf': 70000});
      await tester.pump();
      expect(calculator.isBtcPriceAvailable, isTrue);
      expect(calculator.btcPrice, 70000);
      await tester.pump(const Duration(seconds: 60));
      expect(h.dio.requests, hasLength(3));
    } finally {
      h.dispose();
    }
  });

  testWidgets('offline selection reconnects and background pause retains only current demand', (tester) async {
    final h = _Harness(online: false);
    try {
      final calculator = h.calculator();
      unawaited(calculator.setFiatCode(FiatCode.CHF));
      await tester.pump();
      expect(h.dio.requests, isEmpty);
      h.connectivity.setOnline(true);
      await tester.pump();
      expect(h.dio.currencies, [_allCoinGecko]);
      h.dio.requests.last.reply({'chf': 70000});
      await tester.pump();
      expect(calculator.btcPrice, 70000);

      h.connectivity.setOnline(false);
      expect(calculator.isBtcPriceAvailable, isFalse);
      await tester.pump(const Duration(minutes: 5));
      expect(h.dio.requests, hasLength(1));
      h.connectivity.setOnline(true);
      await tester.pump();
      h.dio.requests.last.reply({'chf': 80000});
      await tester.pump();
      expect(calculator.btcPrice, 80000);

      h.prices.pausePriceSources();
      unawaited(calculator.setFiatCode(FiatCode.TWD));
      h.connectivity.setOnline(false);
      h.connectivity.setOnline(true);
      await tester.pump(const Duration(minutes: 5));
      expect(h.dio.requests, hasLength(2));
      h.prices.resumePriceSources();
      await tester.pump();
      expect(h.dio.currencies.last, _allCoinGecko);
    } finally {
      h.dispose();
    }
  });

  testWidgets('calculator demand overlaps global and home demand on one polling schedule', (tester) async {
    final h = _Harness(fiat: FiatCode.CHF);
    try {
      final calculator = h.calculator();
      await tester.pump();
      h.dio.requests.last.reply({'chf': 70000, 'aed': 300000});
      await tester.pump();
      h.prices.setHomeWidgetFiats([FiatCode.AED, FiatCode.USD]);
      await tester.pump();
      expect(h.dio.requests, hasLength(1), reason: 'AED came with the same all-currency request');

      h.preference.select(FiatCode.KRW);
      await tester.pump();
      expect(calculator.btcPrice, 70000);
      unawaited(calculator.setFiatCode(FiatCode.AED));
      await tester.pump();
      expect(h.dio.requests, hasLength(1));
      expect(calculator.btcPrice, 300000);

      h.close(calculator);
      await tester.pump(const Duration(seconds: 60));
      expect(h.dio.requests, hasLength(2), reason: 'home keeps AED on the same polling schedule');
      h.dio.requests.last.reply({'aed': 310000});
      await tester.pump();
      expect(h.prices.getBitcoinPriceForFiat(FiatCode.AED), 310000);
      h.prices.setHomeWidgetFiats([]);
      await tester.pump(const Duration(minutes: 5));
      expect(h.dio.requests, hasLength(2));
      expect(h.prices.getBitcoinPriceForFiat(FiatCode.AED), isNull);
    } finally {
      h.dispose();
    }
  });

  testWidgets('closing one calculator keeps another calculator demand for the same currency', (tester) async {
    final h = _Harness();
    try {
      final first = h.calculator();
      final second = h.calculator();
      unawaited(first.setFiatCode(FiatCode.CHF));
      unawaited(second.setFiatCode(FiatCode.CHF));
      await tester.pump();
      expect(h.dio.requests, hasLength(1));
      h.close(first);
      h.dio.requests.last.reply({'chf': 70000});
      await tester.pump();
      expect(second.btcPrice, 70000);
      await tester.pump(const Duration(seconds: 60));
      expect(h.dio.requests, hasLength(2));
      h.close(second);
      await tester.pump(const Duration(minutes: 5));
      expect(h.dio.requests, hasLength(2));
    } finally {
      h.dispose();
    }
  });

  testWidgets('switching CoinGecko currencies reuses the pending all-currency quote', (tester) async {
    final h = _Harness();
    try {
      final calculator = h.calculator();
      unawaited(calculator.setFiatCode(FiatCode.CHF));
      await tester.pump();
      final pending = h.dio.requests.single;
      unawaited(calculator.setFiatCode(FiatCode.TWD));
      await tester.pump();
      expect(h.dio.requests, hasLength(1));

      pending.reply({'chf': 70000, 'twd': 3000000});
      await tester.pump();
      calculator.setPremiumRate(0);
      calculator.setInputAmount(100000);
      expect((calculator.fiatCode, calculator.btcPrice), (FiatCode.TWD, 3000000));
      expect(calculator.calculate(calculator.inputAmount!), 33333);
    } finally {
      h.dispose();
    }
  });

  testWidgets('closing a calculator drops its pending quote without notifying disposed listeners', (tester) async {
    final h = _Harness();
    try {
      final calculator = h.calculator();
      unawaited(calculator.setFiatCode(FiatCode.CHF));
      await tester.pump();
      expect(h.dio.requests, hasLength(1));
      final pending = h.dio.requests.last;
      h.close(calculator);
      pending.reply({'chf': 70000});
      await tester.pump(const Duration(minutes: 5));
      expect(h.prices.getBitcoinPriceForFiat(FiatCode.CHF), isNull);
      expect(h.dio.requests, hasLength(1));
      expect(tester.takeException(), isNull);
    } finally {
      h.dispose();
    }
  });

  testWidgets('the bill time is when the calculator price was received, not when the bill is made', (tester) async {
    final h = _Harness(fiat: FiatCode.CHF);
    try {
      final calculator = h.calculator();
      await tester.pump();
      h.dio.requests.last.reply({'chf': 70000});
      await tester.pump();
      final receivedAt = h.clock;

      h.clock = h.clock.add(const Duration(seconds: 30));
      expect(calculator.btcPriceAt, receivedAt);
      expect(h.prices.isPriceStale(FiatCode.CHF), isFalse);
      h.clock = h.clock.add(const Duration(seconds: 61));
      expect(h.prices.isPriceStale(FiatCode.CHF), isTrue);
    } finally {
      h.dispose();
    }
  });

  testWidgets('opening the calculator with a stale CoinGecko price asks for one at once', (tester) async {
    final h = _Harness(fiat: FiatCode.CHF);
    try {
      final first = h.calculator();
      await tester.pump();
      h.dio.requests.last.reply({'chf': 70000});
      await tester.pump();
      h.close(first);

      h.prices.setHomeWidgetFiats([FiatCode.CHF]);
      h.clock = h.clock.add(const Duration(seconds: 91));
      final second = h.calculator();
      await tester.pump();
      expect(h.dio.requests, hasLength(2), reason: 'did not wait for the next 60s tick');
      expect(second.btcPrice, 70000, reason: 'keeps the last price until the new one arrives');

      h.dio.requests.last.reply({'chf': 71000});
      await tester.pump();
      expect((second.btcPrice, second.btcPriceAt), (71000, h.clock));
    } finally {
      h.dispose();
    }
  });

  testWidgets('a stale exchange price is replaced by a REST quote, and only a newer shared quote replaces that', (
    tester,
  ) async {
    final h = _Harness();
    try {
      h.restPrices[FiatCode.USD] = 60000;
      final calculator = h.calculator();
      await calculator.setFiatCode(FiatCode.USD);
      expect(calculator.btcPrice, 60000);
      final restAt = calculator.btcPriceAt!;

      h.clock = restAt.subtract(const Duration(minutes: 5));
      h.prices.updatePriceForFiat(FiatCode.USD, BinanceResponse.fromJson({'c': '59000'}));
      expect(calculator.btcPrice, 60000, reason: 'an older shared quote does not replace the REST quote');

      h.clock = restAt.add(const Duration(seconds: 1));
      h.prices.updatePriceForFiat(FiatCode.USD, BinanceResponse.fromJson({'c': '61000'}));
      expect((calculator.btcPrice, calculator.btcPriceAt), (61000, h.clock));
    } finally {
      h.dispose();
    }
  });

  testWidgets('selectFiat resets input and premium only when the currency changes', (tester) async {
    final h = _Harness(fiat: FiatCode.CHF);
    try {
      final calculator = h.calculator();
      calculator.setPremiumRate(3);
      calculator.setInputAmount(100000);

      expect(calculator.selectFiat(FiatCode.CHF), isFalse);
      expect((calculator.inputAmount, calculator.premiumRate), (100000, 3.0));

      expect(calculator.selectFiat(FiatCode.AED), isTrue);
      await tester.pump();
      expect((calculator.fiatCode, calculator.inputAmount, calculator.premiumRate), (FiatCode.AED, null, 1.0));
    } finally {
      h.dispose();
    }
  });

  testWidgets('selecting the same currency preserves quote input and premium without restarting polling', (
    tester,
  ) async {
    final h = _Harness(fiat: FiatCode.CHF);
    try {
      final calculator = h.calculator();
      await tester.pump();
      h.dio.requests.last.reply({'chf': 70000});
      await tester.pump();
      calculator.setPremiumRate(3);
      calculator.setInputAmount(100000);
      await calculator.setFiatCode(FiatCode.CHF);
      await tester.pump();
      expect((calculator.btcPrice, calculator.inputAmount, calculator.premiumRate), (70000, 100000, 3.0));
      expect(h.dio.requests, hasLength(1));
    } finally {
      h.dispose();
    }
  });
}

final _allCoinGecko = {
  for (final fiat in FiatCode.values)
    if (!fiat.hasExchangeSource) fiat.vsCurrency,
};

class _Harness {
  _Harness({bool online = true, FiatCode fiat = FiatCode.KRW})
    : connectivity = ScriptedConnectivity(online: online),
      preference = _Preference(fiat) {
    prices = PriceProvider(
      connectivity,
      preference,
      webSocketFactory: SocketBook().create,
      coinGeckoFactory: () => CoinGeckoPriceService(dio: dio),
      now: () => clock,
    );
  }

  DateTime clock = DateTime(2026, 10, 29, 12);

  final ScriptedConnectivity connectivity;
  final _Preference preference;
  final _QuoteDio dio = _QuoteDio();
  final _calculators = <P2PCalculatorViewModel>[];
  final restPrices = <FiatCode, int>{};
  late final PriceProvider prices;

  P2PCalculatorViewModel calculator() {
    final calculator = P2PCalculatorViewModel(
      preference,
      connectivity,
      prices,
      FakeWalletProvider(),
      restPriceFetcher: (fiat) async => restPrices[fiat],
    );
    _calculators.add(calculator);
    return calculator;
  }

  void close(P2PCalculatorViewModel calculator) {
    _calculators.remove(calculator);
    calculator.dispose();
  }

  void dispose() {
    for (final calculator in _calculators) {
      calculator.dispose();
    }
    prices.dispose();
    connectivity.dispose();
    preference.dispose();
  }
}

class _Preference extends ScriptedPreference {
  _Preference(super.selectedFiat);

  @override
  BitcoinUnit get currentUnit => BitcoinUnit.sats;
}

class _QuoteDio extends Fake implements Dio {
  final requests = <_QuoteRequest>[];
  List<Set<String>> get currencies => requests.map((request) => request.currencies).toList();

  @override
  Future<Response<T>> get<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) async {
    expectSync(path, 'https://api.coingecko.com/api/v3/simple/price');
    final request = _QuoteRequest((queryParameters!['vs_currencies'] as String).split(',').toSet());
    requests.add(request);
    return Response<T>(requestOptions: RequestOptions(), data: await request.result.future as T, statusCode: 200);
  }
}

class _QuoteRequest {
  _QuoteRequest(this.currencies);
  final Set<String> currencies;
  final result = Completer<Map<String, dynamic>>();

  void reply(Map<String, num> prices) => result.complete({'bitcoin': prices});

  void fail() => result.completeError(
    DioException.badResponse(
      statusCode: 429,
      requestOptions: RequestOptions(),
      response: Response(requestOptions: RequestOptions(), statusCode: 429),
    ),
  );
}
