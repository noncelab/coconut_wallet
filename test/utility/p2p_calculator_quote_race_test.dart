import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/providers/price_provider.dart';
import 'package:coconut_wallet/providers/view_model/utility/p2p_calculator_view_model.dart';
import 'package:coconut_wallet/services/coingecko_price_service.dart';
import 'package:coconut_wallet/services/web_socket_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../providers/price_provider_test.dart' show Harness, SocketBook;
import 'p2p_calculator_test.dart' show FakePreferenceProvider, FakeWalletProvider;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('switching from CHF to TWD needs no new CoinGecko request and shows the TWD quote', () async {
    final network = _Network();
    await HttpOverrides.runZoned(() async {
      final h = Harness();
      final prices = PriceProvider(
        h.connectivity,
        h.preference,
        webSocketFactory: SocketBook().create,
        coinGeckoFactory: CoinGeckoPriceService.new,
      );
      final calculator = P2PCalculatorViewModel(FakePreferenceProvider(), h.connectivity, prices, FakeWalletProvider());
      try {
        final allCoinGecko = [
          for (final fiat in FiatCode.values)
            if (!fiat.hasExchangeSource) fiat.vsCurrency,
        ].join(',');
        await calculator.setFiatCode(FiatCode.CHF);
        final quote = await network.requestFor(allCoinGecko);
        await calculator.setFiatCode(FiatCode.TWD);
        final currentQuote = Completer<void>();
        void onQuote() {
          if (calculator.btcPrice == 3000000 && !currentQuote.isCompleted) currentQuote.complete();
        }

        calculator.addListener(onQuote);
        quote.replyPrices({'chf': 70000, 'twd': 3000000});
        await currentQuote.future.timeout(const Duration(seconds: 2));
        calculator.removeListener(onQuote);
        calculator.setPremiumRate(0);
        expect((calculator.fiatCode, calculator.btcPrice), (FiatCode.TWD, 3000000));
        expect(calculator.calculateSatsFromFiat(100000), 33333);
        expect(network.requests.where((request) => request.currency == allCoinGecko), hasLength(1));
      } finally {
        calculator.dispose();
        prices.dispose();
        h.dispose();
      }
    }, createHttpClient: (_) => network);
  });

  testWidgets('superseded exchange fallback cannot replace the newer exchange quote', (tester) async {
    await _withExchange(tester, (h, calculator, network) async {
      final first = calculator.setFiatCode(FiatCode.USD);
      final usd = await network.requestFor('usd');
      final second = calculator.setFiatCode(FiatCode.JPY);
      final jpy = await network.requestFor('jpy');
      jpy.reply(9000000);
      await second;
      usd.reply(60000);
      await first;
      expect((calculator.fiatCode, calculator.btcPrice), (FiatCode.JPY, 9000000));
    });
  });

  testWidgets('a shared exchange quote arriving during fallback stays authoritative', (tester) async {
    await _withExchange(tester, (h, calculator, network) async {
      final selected = calculator.setFiatCode(FiatCode.USD);
      final usd = await network.requestFor('usd');
      h.prices.updatePriceForFiat(FiatCode.USD, BinanceResponse.fromJson({'c': '61000'}));
      await Future<void>.delayed(Duration.zero);
      expect(calculator.btcPrice, 61000);
      usd.reply(60000);
      await selected;
      expect(calculator.btcPrice, 61000);
    });
  });

  testWidgets('exchange fallback completing after dispose cannot mutate or notify', (tester) async {
    final network = _Network();
    await HttpOverrides.runZoned(() async {
      final h = Harness();
      try {
        await tester.runAsync(() async {
          final calculator = P2PCalculatorViewModel(
            FakePreferenceProvider(),
            h.connectivity,
            h.prices,
            FakeWalletProvider(),
          );
          final selected = calculator.setFiatCode(FiatCode.USD);
          final usd = await network.requestFor('usd');
          calculator.dispose();
          usd.reply(60000);
          await expectLater(selected, completes);
          expect(calculator.btcPrice, isNull);
        });
      } finally {
        h.dispose();
      }
    }, createHttpClient: (_) => network);
  });
}

Future<void> _withExchange(
  WidgetTester tester,
  Future<void> Function(Harness, P2PCalculatorViewModel, _Network) body,
) async {
  final network = _Network();
  await HttpOverrides.runZoned(() async {
    final h = Harness();
    P2PCalculatorViewModel? calculator;
    try {
      await tester.runAsync(() async {
        calculator = P2PCalculatorViewModel(FakePreferenceProvider(), h.connectivity, h.prices, FakeWalletProvider());
        await body(h, calculator!, network);
      });
    } finally {
      calculator?.dispose();
      h.dispose();
    }
  }, createHttpClient: (_) => network);
}

class _Network extends Fake implements HttpClient {
  final requests = <_Request>[];
  final _opened = <String, Completer<_Request>>{};
  @override
  Duration? connectionTimeout;
  @override
  Duration idleTimeout = Duration.zero;

  Future<_Request> requestFor(String currency) =>
      _opened.putIfAbsent(currency, Completer<_Request>.new).future.timeout(const Duration(seconds: 2));

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    // This fake intercepts every request; it never opens a real connection.
    if (!{'api.coingecko.com', 'api.binance.com', 'api.bitflyer.com', 'api.upbit.com'}.contains(url.host)) {
      throw StateError('Unexpected request host: ${url.host}');
    }
    final currency =
        url.queryParameters['vs_currencies'] ??
        (url.host == 'api.bitflyer.com'
            ? 'jpy'
            : url.host == 'api.upbit.com'
            ? 'krw'
            : url.queryParameters['symbol'] == 'BTCEUR'
            ? 'eur'
            : 'usd');
    final request = _Request(currency);
    requests.add(request);
    _opened.putIfAbsent(currency, Completer<_Request>.new).complete(request);
    return request;
  }
}

class _Request extends Fake implements HttpClientRequest {
  _Request(this.currency);
  final String currency;
  final _response = Completer<HttpClientResponse>();
  @override
  final HttpHeaders headers = _Headers();
  @override
  bool followRedirects = true;
  @override
  int maxRedirects = 5;
  @override
  bool persistentConnection = true;
  @override
  Future<HttpClientResponse> close() => _response.future;
  void replyPrices(Map<String, int> prices) => _response.complete(_Response(jsonEncode({'bitcoin': prices})));

  void reply(int quote) => _response.complete(
    _Response(
      jsonEncode(
        currency == 'usd' || currency == 'eur'
            ? {'price': '$quote'}
            : currency == 'jpy'
            ? {'ltp': quote}
            : currency == 'krw'
            ? [
              {'trade_price': quote},
            ]
            : {
              'bitcoin': {currency: quote},
            },
      ),
    ),
  );
}

class _Headers extends Fake implements HttpHeaders {
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}
  @override
  void forEach(void Function(String, List<String>) action) => action('content-type', ['application/json']);
}

class _Response extends Stream<List<int>> implements HttpClientResponse {
  _Response(this.body);
  final String body;
  @override
  final HttpHeaders headers = _Headers();
  @override
  int get statusCode => 200;
  @override
  bool get isRedirect => false;
  @override
  List<RedirectInfo> get redirects => const [];
  @override
  String get reasonPhrase => 'OK';
  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => Stream.value(utf8.encode(body)).listen(onData, onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
