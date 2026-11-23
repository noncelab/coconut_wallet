import 'dart:async';

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

/// 일별 종가는 UTC 날짜로 마감된다. 앱을 켜 둔 채 UTC 자정(한국 오전 9시)을 넘기면 새로 마감된 종가를 다시 받아야 한다.
void main() {
  const usd = FiatCode.USD;
  late DateTime clock;
  late _History history;
  late HomeWidgetsViewModel viewModel;

  // 한국 11/11 08:30. 마지막으로 마감된 날은 11/9(종가 90,000).
  final beforeUtcMidnight = DateTime.utc(2026, 11, 10, 23, 30);
  // 한국 11/11 09:30. 11/10이 95,000으로 마감됐다.
  final afterUtcMidnight = DateTime.utc(2026, 11, 11, 0, 30);
  final closedNov9 = [...List.filled(30, 80000.0), 90000.0];
  final closedNov10 = [...List.filled(29, 80000.0), 90000.0, 95000.0];

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  setUp(() {
    clock = beforeUtcMidnight;
    history = _History(closedNov9);
    viewModel = HomeWidgetsViewModel(
      walletProvider: _Wallets(),
      preferenceProvider: _Preferences(),
      priceProvider: _Prices({usd: 100000}),
      targetSatsOf: (_) => null,
      historicalPriceService: history,
      now: () => clock,
    );
  });

  tearDown(() => viewModel.dispose());

  test('a new UTC day fetches the closes again, so the 24h change and chart use the day that just closed', () async {
    viewModel.priceChange24h(usd);
    await settle();
    expect(viewModel.priceChange24h(usd), closeTo(100000 / 90000 - 1, 1e-9));

    clock = afterUtcMidnight;
    history.closes = closedNov10;
    viewModel.priceChange24h(usd);
    await settle();

    expect(history.calls, 2);
    expect(viewModel.priceChange24h(usd), closeTo(100000 / 95000 - 1, 1e-9));
    expect(viewModel.dailyPrices(usd, days: 3), [90000, 95000, 100000]);
  });

  test('while the new closes load, the old closes stay on screen instead of a loading state', () async {
    viewModel.priceChange24h(usd);
    await settle();
    expect(viewModel.isDailyClosesLoading(usd), isFalse);

    clock = afterUtcMidnight;
    history
      ..closes = closedNov10
      ..gate = Completer<void>();
    expect(viewModel.isDailyClosesLoading(usd), isFalse);
    expect(viewModel.dailyPrices(usd, days: 3), [80000, 90000, 100000]);

    history.gate!.complete();
    await settle();
    expect(viewModel.isDailyClosesLoading(usd), isFalse);
    expect(viewModel.dailyPrices(usd, days: 3), [90000, 95000, 100000]);
  });

  test('local midnight before the UTC day changes does not fetch again', () async {
    clock = DateTime.utc(2026, 11, 10, 14, 30); // 한국 11/10 23:30
    viewModel.priceChange24h(usd);
    await settle();
    clock = DateTime.utc(2026, 11, 10, 15, 30); // 한국 11/11 00:30, UTC로는 아직 11/10
    viewModel.priceChange24h(usd);
    await settle();

    expect(history.calls, 1);
  });

  test('a failed fetch on the new day keeps the old closes and waits for the next UTC day', () async {
    viewModel.priceChange24h(usd);
    await settle();

    clock = afterUtcMidnight;
    history.fail = true;
    for (var i = 0; i < 3; i++) {
      viewModel.priceChange24h(usd);
      await settle();
    }

    expect(history.calls, 2);
    expect(viewModel.priceChange24h(usd), closeTo(100000 / 90000 - 1, 1e-9));
    expect(viewModel.isDailyClosesLoading(usd), isFalse);
  });
}

class _History extends Fake implements HistoricalBitcoinPriceService {
  _History(this.closes);

  List<double> closes;
  int calls = 0;
  bool fail = false;
  Completer<void>? gate;

  @override
  Future<List<double>?> fetchDailyCloses(FiatCode fiatCode) async {
    calls++;
    await gate?.future;
    if (fail) throw StateError('network unavailable');
    return List.of(closes);
  }
}

class _Prices extends Fake with ChangeNotifier implements PriceProvider {
  _Prices(this.prices);

  final Map<FiatCode, int> prices;

  @override
  int? getBitcoinPriceForFiat(FiatCode fiatCode) => prices[fiatCode];
}

class _Wallets extends Fake implements WalletProvider {
  @override
  final ValueNotifier<WalletLoadState> walletLoadStateNotifier = ValueNotifier(WalletLoadState.loadCompleted);

  @override
  final ValueNotifier<List<WalletItemBase>> walletItemListNotifier = ValueNotifier(const []);
}

class _Preferences extends Fake with ChangeNotifier implements PreferenceProvider {}
