import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/price_provider.dart';
import 'package:coconut_wallet/providers/view_model/home/home_widgets_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/services/historical_bitcoin_price_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late _Prices prices;
  late _History history;
  late HomeWidgetsViewModel viewModel;

  setUp(() {
    prices = _Prices();
    history = _History();
    viewModel = HomeWidgetsViewModel(
      walletProvider: _Wallets(),
      preferenceProvider: _Preferences(),
      priceProvider: prices,
      targetSatsOf: (_) => null,
      historicalPriceService: history,
    );
  });

  tearDown(() => viewModel.dispose());

  testWidgets('a failed CoinGecko currency retries only when a new CoinGecko price arrives', (tester) async {
    prices.set(FiatCode.CHF, 70000);
    history.failNext(FiatCode.CHF);
    viewModel.priceChange24h(FiatCode.CHF);
    await tester.pump();
    expect(history.calls[FiatCode.CHF], 1);

    await tester.pump(const Duration(minutes: 30));
    viewModel.priceChange24h(FiatCode.CHF);
    await tester.pump();
    expect(history.calls[FiatCode.CHF], 1, reason: 'no CoinGecko success yet, so no retry');

    prices.set(FiatCode.USD, 60000);
    viewModel.priceChange24h(FiatCode.CHF);
    await tester.pump();
    expect(history.calls[FiatCode.CHF], 1, reason: 'an exchange price says nothing about CoinGecko');

    prices.set(FiatCode.CHF, 70100);
    viewModel.priceChange24h(FiatCode.CHF);
    await tester.pump();
    expect(history.calls[FiatCode.CHF], 2);
    expect(viewModel.priceChange24h(FiatCode.CHF), isNotNull);
  });

  testWidgets('a failed CoinGecko currency retries when the same price arrives again', (tester) async {
    prices.set(FiatCode.CHF, 70000);
    history.failNext(FiatCode.CHF);
    viewModel.priceChange24h(FiatCode.CHF);
    await tester.pump();
    expect(history.calls[FiatCode.CHF], 1);

    prices.set(FiatCode.CHF, 70000);
    viewModel.priceChange24h(FiatCode.CHF);
    await tester.pump();
    expect(history.calls[FiatCode.CHF], 2);
    expect(viewModel.priceChange24h(FiatCode.CHF), isNotNull);
  });

  testWidgets('a failed exchange currency retries after 1, then 2 minutes', (tester) async {
    prices.set(FiatCode.USD, 60000);
    history
      ..failNext(FiatCode.USD)
      ..failNext(FiatCode.USD);
    viewModel.priceChange24h(FiatCode.USD);
    await tester.pump();
    expect(history.calls[FiatCode.USD], 1);

    await tester.pump(const Duration(seconds: 59));
    viewModel.priceChange24h(FiatCode.USD);
    await tester.pump();
    expect(history.calls[FiatCode.USD], 1);
    await tester.pump(const Duration(seconds: 1));
    viewModel.priceChange24h(FiatCode.USD);
    await tester.pump();
    expect(history.calls[FiatCode.USD], 2);

    await tester.pump(const Duration(seconds: 119));
    viewModel.priceChange24h(FiatCode.USD);
    await tester.pump();
    expect(history.calls[FiatCode.USD], 2);
    await tester.pump(const Duration(seconds: 1));
    viewModel.priceChange24h(FiatCode.USD);
    await tester.pump();
    expect(history.calls[FiatCode.USD], 3);
    expect(viewModel.priceChange24h(FiatCode.USD), isNotNull);
  });
}

class _History extends Fake implements HistoricalBitcoinPriceService {
  final calls = <FiatCode, int>{};
  final _failures = <FiatCode, int>{};

  void failNext(FiatCode fiat) => _failures[fiat] = (_failures[fiat] ?? 0) + 1;

  @override
  Future<List<double>?> fetchDailyCloses(FiatCode fiatCode) async {
    calls[fiatCode] = (calls[fiatCode] ?? 0) + 1;
    final remaining = _failures[fiatCode] ?? 0;
    if (remaining > 0) {
      _failures[fiatCode] = remaining - 1;
      throw StateError('429');
    }
    return List.filled(31, 65000);
  }
}

class _Prices extends Fake with ChangeNotifier implements PriceProvider {
  final _prices = <FiatCode, int>{};
  final _receivedAt = <FiatCode, DateTime>{};
  var _clock = DateTime(2026);

  void set(FiatCode fiat, int price) {
    _prices[fiat] = price;
    _clock = _clock.add(const Duration(minutes: 1));
    _receivedAt[fiat] = _clock;
    notifyListeners();
  }

  @override
  int? getBitcoinPriceForFiat(FiatCode fiatCode) => _prices[fiatCode];

  @override
  DateTime? priceReceivedAt(FiatCode fiatCode) => _receivedAt[fiatCode];
}

class _Wallets extends Fake implements WalletProvider {
  @override
  final ValueNotifier<WalletLoadState> walletLoadStateNotifier = ValueNotifier(WalletLoadState.loadCompleted);

  @override
  final ValueNotifier<List<WalletItemBase>> walletItemListNotifier = ValueNotifier(const []);
}

class _Preferences extends Fake with ChangeNotifier implements PreferenceProvider {}
