import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/model/home/home_widget_settings.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/view_model/home/widget_configure_view_model.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../mock/wallet_mock.dart';

class _Preferences extends Fake with ChangeNotifier implements PreferenceProvider {
  @override
  FiatCode selectedFiat = FiatCode.KRW;
  bool fakeActive = false;
  int? fakeTotal;
  final List<String> calls = [];

  @override
  bool get isFakeBalanceActive => fakeActive;

  @override
  int? get fakeBalanceTotalAmount => fakeTotal;

  @override
  Future<void> toggleFakeBalanceActivation(bool isActive) async {
    calls.add('toggle:$isActive');
    fakeActive = isActive;
    if (!isActive) fakeTotal = null;
  }

  @override
  Future<void> distributeFakeBalance(
    List<WalletItemBase> wallets, {
    required bool isFakeBalanceActive,
    double? fakeBalanceTotalSats,
  }) async {
    calls.add('distribute:${fakeBalanceTotalSats!.toInt()}:${wallets.length}');
    fakeTotal = fakeBalanceTotalSats.toInt();
  }

  @override
  Future<void> setFakeBalanceTotalAmount(int balance) async {
    calls.add('total:$balance');
    fakeTotal = balance;
  }
}

void main() {
  late _Preferences preferences;
  final wallets = [
    WalletMock.createSingleSigWalletItem(id: 1),
    WalletMock.createSingleSigWalletItem(id: 2),
    WalletMock.createSingleSigWalletItem(id: 3),
  ];

  setUp(() => preferences = _Preferences());

  WidgetConfigureViewModel create(
    HomeWidgetSettingsSpec spec, {
    HomeWidgetSettings? initial,
    List<WalletItemBase>? list,
  }) =>
      WidgetConfigureViewModel(spec: spec, wallets: list ?? wallets, preferenceProvider: preferences, initial: initial);

  group('지갑', () {
    const spec = HomeWidgetSettingsSpec(wallets: true);

    test('새 위젯은 모든 지갑으로 시작하고 null로 저장한다', () {
      final viewModel = create(spec);
      expect(viewModel.isNew, isTrue);
      expect(viewModel.allWallets, isTrue);
      expect(viewModel.settings.walletIds, isNull);
    });

    test('개별 지갑을 고르면 모든 지갑이 풀리고, 모든 지갑을 고르면 개별 선택이 풀린다', () {
      final viewModel = create(spec);
      viewModel.toggleWallet(2);
      viewModel.toggleWallet(1);
      expect(viewModel.allWallets, isFalse);
      expect(viewModel.settings.walletIds, [1, 2]);
      viewModel.selectAllWallets();
      expect(viewModel.isWalletSelected(1), isFalse);
      expect(viewModel.settings.walletIds, isNull);
    });

    test('마지막 개별 지갑은 해제할 수 없다', () {
      final viewModel = create(spec);
      viewModel.toggleWallet(3);
      viewModel.toggleWallet(3);
      expect(viewModel.settings.walletIds, [3]);
    });

    test('저장된 지갑 중 없어진 지갑은 빼고, 모두 없으면 모든 지갑으로 연다', () {
      expect(create(spec, initial: const HomeWidgetSettings(walletIds: [2, 9])).settings.walletIds, [2]);
      expect(create(spec, initial: const HomeWidgetSettings(walletIds: [9])).allWallets, isTrue);
    });
  });

  group('통화', () {
    test('여러 통화 위젯은 앱 기본 통화를 먼저 두고 최대 개수만큼 고른 상태로 시작한다', () {
      preferences.selectedFiat = FiatCode.USD;
      final viewModel = create(
        const HomeWidgetSettingsSpec(currencies: HomeWidgetCurrencyMode.multiple, maxCurrencies: 3),
      );
      expect(viewModel.fiatOptions.first, FiatCode.USD);
      expect(viewModel.settings.fiats, [FiatCode.USD, FiatCode.KRW, FiatCode.JPY]);
      expect(viewModel.canSelectFiat(FiatCode.EUR), isFalse);
    });

    test('통화는 0개로 만들 수 없고, 고른 순서는 화면 순서를 따른다', () {
      final viewModel = create(
        const HomeWidgetSettingsSpec(currencies: HomeWidgetCurrencyMode.multiple, maxCurrencies: 4),
      );
      for (final fiat in [FiatCode.KRW, FiatCode.USD, FiatCode.JPY]) {
        viewModel.toggleFiat(fiat);
      }
      expect(viewModel.settings.fiats, [FiatCode.EUR]);
      viewModel.toggleFiat(FiatCode.EUR);
      expect(viewModel.settings.fiats, [FiatCode.EUR]);
      viewModel.toggleFiat(FiatCode.KRW);
      expect(viewModel.settings.fiats, [FiatCode.KRW, FiatCode.EUR]);
    });

    test('한 통화 위젯은 고르면 바뀐다', () {
      final viewModel = create(const HomeWidgetSettingsSpec(currencies: HomeWidgetCurrencyMode.single));
      expect(viewModel.settings.fiats, [FiatCode.KRW]);
      viewModel.toggleFiat(FiatCode.JPY);
      expect(viewModel.settings.fiats, [FiatCode.JPY]);
    });

    test('앱 기본 통화가 바뀌어도 저장된 선택은 그대로다', () {
      preferences.selectedFiat = FiatCode.EUR;
      final viewModel = create(
        const HomeWidgetSettingsSpec(currencies: HomeWidgetCurrencyMode.multiple, maxCurrencies: 4),
        initial: const HomeWidgetSettings(fiats: [FiatCode.KRW]),
      );
      expect(viewModel.defaultFiat, FiatCode.EUR);
      expect(viewModel.settings.fiats, [FiatCode.KRW]);
    });
  });

  test('기간은 1주로 시작하고 저장값을 불러온다', () {
    const spec = HomeWidgetSettingsSpec(period: true);
    expect(create(spec).settings.period, HomeWidgetPeriod.week);
    expect(
      create(spec, initial: const HomeWidgetSettings(period: HomeWidgetPeriod.month)).period,
      HomeWidgetPeriod.month,
    );
  });

  group('가짜 잔액', () {
    const spec = HomeWidgetSettingsSpec(wallets: true, fakeBalance: true);

    test('켜고 금액이 없으면 저장할 수 없다', () {
      final viewModel = create(spec);
      viewModel.setFakeBalanceActive(true);
      expect(viewModel.canSubmit, isFalse);
      viewModel.setFakeBalance(21000000 * 100000000 + 1);
      expect(viewModel.canSubmit, isFalse);
      viewModel.setFakeBalance(50000);
      expect(viewModel.canSubmit, isTrue);
    });

    test('켜면 기존 앱 설정에 금액을 나눠 저장하고 켠다', () async {
      final viewModel = create(spec);
      viewModel.setFakeBalanceActive(true);
      viewModel.setFakeBalance(50000);
      await viewModel.commitFakeBalance();
      expect(preferences.calls, ['distribute:50000:3', 'toggle:true']);
    });

    test('이미 켜져 있고 금액이 같으면 아무것도 바꾸지 않는다', () async {
      preferences
        ..fakeActive = true
        ..fakeTotal = 7000;
      final viewModel = create(spec);
      expect(viewModel.fakeBalanceActive, isTrue);
      expect(viewModel.fakeBalance, 7000);
      await viewModel.commitFakeBalance();
      expect(preferences.calls, isEmpty);
    });

    test('끄면 기존 앱 설정을 끈다', () async {
      preferences
        ..fakeActive = true
        ..fakeTotal = 7000;
      final viewModel = create(spec);
      viewModel.setFakeBalanceActive(false);
      await viewModel.commitFakeBalance();
      expect(preferences.calls, ['toggle:false']);
    });

    test('가짜 잔액이 없는 위젯은 앱 설정을 건드리지 않는다', () async {
      preferences.fakeActive = true;
      final viewModel = create(const HomeWidgetSettingsSpec(wallets: true));
      viewModel.setFakeBalanceActive(false);
      await viewModel.commitFakeBalance();
      expect(preferences.calls, isEmpty);
    });
  });

  test('설정값은 HomeItem.configuration으로 저장했다가 그대로 읽힌다', () {
    const settings = HomeWidgetSettings(
      walletIds: [1, 3],
      fiats: [FiatCode.USD, FiatCode.EUR],
      period: HomeWidgetPeriod.month,
    );
    expect(HomeWidgetSettings.fromConfiguration(settings.toConfiguration()), settings);
    expect(
      HomeWidgetSettings.fromConfiguration(const {
        'walletIds': [2],
      }).walletIds,
      [2],
    );
    expect(const HomeWidgetSettings().toConfiguration(), isEmpty);
  });

  test('only the periods the widget allows can be chosen, and a saved one outside them falls back', () {
    const fiatTrend = HomeWidgetSettingsSpec(period: true, periods: [HomeWidgetPeriod.week, HomeWidgetPeriod.month]);
    expect(
      create(fiatTrend, initial: const HomeWidgetSettings(period: HomeWidgetPeriod.year)).period,
      HomeWidgetPeriod.week,
    );
    const activity = HomeWidgetSettingsSpec(period: true);
    expect(activity.periods, HomeWidgetPeriod.widgetPeriods);
    expect(
      create(activity, initial: const HomeWidgetSettings(period: HomeWidgetPeriod.year)).period,
      HomeWidgetPeriod.year,
    );
  });

  test('wallet goals start from the saved targets, block a goal over the supply, and save only what changed', () async {
    final saved = <int, int?>{1: 100000000, 2: null, 3: 5000000};
    final writes = <(int, int?)>[];
    final viewModel = WidgetConfigureViewModel(
      spec: const HomeWidgetSettingsSpec(wallets: true, goals: true),
      wallets: wallets,
      preferenceProvider: preferences,
      initial: const HomeWidgetSettings(),
      targetOf: (id) => saved[id],
      saveTarget: (id, sats) async => writes.add((id, sats)),
    );
    expect(viewModel.targetOf(1), 100000000);
    viewModel.setTarget(2, 30000000);
    viewModel.setTarget(3, 0);
    viewModel.setTarget(1, 21000000 * 100000000 + 1);
    expect(viewModel.canSubmit, isFalse);
    viewModel.setTarget(1, 100000000);
    expect(viewModel.canSubmit, isTrue);
    await viewModel.commitTargets();
    expect(writes, [(2, 30000000), (3, null)]);
  });
}
