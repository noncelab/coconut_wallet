import 'dart:convert';

import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/constants/shared_pref_keys.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/home/home_configuration.dart';
import 'package:coconut_wallet/model/home/home_item.dart';
import 'package:coconut_wallet/model/home/home_item_ids.dart';
import 'package:coconut_wallet/model/wallet/balance.dart';
import 'package:coconut_wallet/providers/auth_provider.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/preferences/block_explorer_provider.dart';
import 'package:coconut_wallet/providers/preferences/electrum_server_provider.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/price_provider.dart';
import 'package:coconut_wallet/providers/view_model/home/home_view_model.dart';
import 'package:coconut_wallet/providers/view_model/home/home_widgets_view_model.dart';
import 'package:coconut_wallet/repository/realm/wallet_preferences_repository.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/repository/shared_preference/home_configuration_repository.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:coconut_wallet/screens/home/home_screen.dart';
import 'package:coconut_wallet/screens/home/wallet_add/wallet_add_dialog.dart';
import 'package:coconut_wallet/screens/home/wallet_add/wallet_add_screen.dart';
import 'package:coconut_wallet/services/analytics_service.dart';
import 'package:coconut_wallet/services/historical_bitcoin_price_service.dart';
import 'package:coconut_wallet/services/home/builtin_home_widgets.dart';
import 'package:coconut_wallet/widgets/features/home/home_items_view.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/balance_widget_views.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/home_widget_parts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../mock/wallet_mock.dart';
import '../../services/safety/safety_fakes.dart';

class _WalletPreferences extends Fake implements WalletPreferencesRepository {
  @override
  bool hasWalletPreferences() => false;
  @override
  List<int> getWalletOrder() => [];
  @override
  List<int> getFavoriteWalletIds() => [];
  @override
  List<int> getExcludedWalletIds() => [];
}

class _Node extends SafetyNodeFake {
  @override
  bool get hasConnectionError => false;
  @override
  bool get isInitializing => false;
}

class _Connectivity extends SafetyConnectivityFake {
  @override
  bool get isVpnActive => false;
}

class _Prices extends Fake with ChangeNotifier implements PriceProvider {
  @override
  void setHomeWidgetFiats(Iterable<FiatCode> fiats) {}

  final bool available;
  _Prices({this.available = true});
  @override
  int? getBitcoinPriceForFiat(FiatCode fiatCode) => available ? 100000000 : null;
}

class _History extends Fake implements HistoricalBitcoinPriceService {
  @override
  Future<List<double>?> fetchDailyCloses(FiatCode fiatCode) async => List.filled(31, 90000000);
}

Future<PreferenceProvider> _preferences(Map<String, Object> stored) async {
  SharedPreferences.setMockInitialValues({
    SharedPrefKeys.kLanguage: 'ko',
    SharedPrefKeys.kNumberFormatPreset: 'dotDecimal',
    SharedPrefKeys.kAllFeaturesHintDismissed: true,
    ...stored,
  });
  await SharedPrefsRepository().init();
  final electrum = ElectrumServerProvider();
  final explorer = BlockExplorerProvider();
  final preferences = PreferenceProvider(_WalletPreferences(), electrum, explorer);
  addTearDown(() {
    preferences.dispose();
    electrum.dispose();
    explorer.dispose();
    LocaleSettings.setLocaleSync(AppLocale.ko);
  });
  return preferences;
}

SafetyWalletsFake _wallets({bool empty = false}) {
  final wallets = SafetyWalletsFake(empty ? [] : [WalletMock.createSingleSigWalletItem(id: 1)])
    ..balances[1] = Balance(20000000, 0);
  addTearDown(wallets.dispose);
  return wallets;
}

HomeItem _item(String definitionId, {HomeSpan span = HomeSpan.small, Map<String, Object?> configuration = const {}}) =>
    HomeItem(
      id: 'configured-widget',
      definitionId: definitionId,
      kind: HomeItemKind.widget,
      order: 0,
      span: span,
      configuration: configuration,
    );

Future<PreferenceProvider> _pumpHome(
  WidgetTester tester, {
  Map<String, Object> stored = const {},
  bool empty = false,
  List<HomeItem> items = const [],
}) async {
  tester.view.physicalSize = const Size(412, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final preferences = await _preferences(stored);
  await HomeConfigurationRepository(SharedPrefsRepository()).save(HomeConfiguration(items: items));
  final node = _Node();
  final connectivity = _Connectivity();
  final prices = _Prices();
  addTearDown(node.dispose);
  addTearDown(connectivity.dispose);
  addTearDown(prices.dispose);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<WalletProvider>.value(value: _wallets(empty: empty)),
        ChangeNotifierProvider<PreferenceProvider>.value(value: preferences),
        ChangeNotifierProvider<PriceProvider>.value(value: prices),
        ChangeNotifierProvider<NodeProvider>.value(value: node),
        ChangeNotifierProvider<ConnectivityProvider>.value(value: connectivity),
        ChangeNotifierProvider<AuthProvider>.value(value: SafetyAuthFake()),
        Provider<AnalyticsService>.value(value: SafetyAnalyticsFake()),
      ],
      child: MaterialApp(theme: buildCoconutThemeData(), home: const HomeScreen()),
    ),
  );
  node.sync.add(NodeSyncState.completed);
  await tester.pump();
  return preferences;
}

Future<(PreferenceProvider, HomeWidgetsViewModel)> _pumpWidget(
  WidgetTester tester,
  HomeItem item, {
  bool hidden = false,
  bool fake = false,
  bool pricesAvailable = true,
}) async {
  final preferences = await _preferences({
    SharedPrefKeys.kIsFiatBalanceHidden: hidden,
    if (fake) SharedPrefKeys.kFakeBalanceTotal: 50000000,
    if (fake) SharedPrefKeys.kFakeBalanceMap: jsonEncode({'1': 50000000}),
  });
  final prices = _Prices(available: pricesAvailable);
  final data = HomeWidgetsViewModel(
    walletProvider: _wallets(),
    preferenceProvider: preferences,
    priceProvider: prices,
    targetSatsOf: (_) => null,
    historicalPriceService: _History(),
    now: () => DateTime(2026, 10, 21),
  );
  addTearDown(prices.dispose);
  final definition = builtinHomeWidgets().firstWhere((definition) => definition.id == item.definitionId);
  await tester.pumpWidget(
    ChangeNotifierProvider(
      create: (_) => data,
      child: MaterialApp(
        theme: buildCoconutThemeData(),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: item.span == HomeSpan.wide ? 328 : 156,
              height: 156,
              child: Builder(builder: (context) => definition.build(context, item)),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return (preferences, data);
}

void main() {
  for (final empty in [false, true]) {
    for (final option in HomeAddWalletOption.values) {
      testWidgets('stored add-wallet ${option.name} controls icon and entry (empty: $empty)', (tester) async {
        await _pumpHome(tester, empty: empty, stored: {SharedPrefKeys.kHomeAddWalletOption: option.name});
        final button = find.byKey(const Key('home-add-wallet-button'));
        if (option == HomeAddWalletOption.hidden) {
          expect(button, findsNothing);
          expect(find.byKey(const Key('add-wallet-hint')), findsNothing);
        } else {
          final expectedIcon = switch (option) {
            HomeAddWalletOption.all => FeatureWalletIconPath.walletAddDefault,
            HomeAddWalletOption.watchOnly => FeatureWalletIconPath.walletEyes,
            _ => FeatureWalletIconPath.walletAddHot,
          };
          final icon = tester.widget<SvgPicture>(find.descendant(of: button, matching: find.byType(SvgPicture)));
          expect((icon.bytesLoader as SvgAssetLoader).assetName, expectedIcon);
          await tester.tap(button);
          await tester.pumpAndSettle();
          if (option == HomeAddWalletOption.all && empty) {
            expect(find.byType(WalletAddScreen), findsOneWidget);
          } else {
            expect(tester.widget<WalletAddDialog>(find.byType(WalletAddDialog)).mode, switch (option) {
              HomeAddWalletOption.all => WalletAddDialogMode.walletType,
              HomeAddWalletOption.watchOnly => WalletAddDialogMode.watchOnlySource,
              _ => WalletAddDialogMode.hotWalletAction,
            });
          }
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }

  testWidgets('missing preferences keep the default entry and visible fiat balance', (tester) async {
    final preferences = await _pumpHome(tester, items: [_item(HomeItemIds.bitcoinBalanceTrend, span: HomeSpan.wide)]);
    expect(preferences.homeAddWalletOption, HomeAddWalletOption.all);
    expect(preferences.isFiatBalanceHidden, isFalse);
    expect(tester.widget<Text>(find.byKey(const Key('balance-change-fiat'))).data!.isNotEmpty, isTrue);
    await tester.tap(find.byKey(const Key('home-add-wallet-button')));
    await tester.pumpAndSettle();
    expect(tester.widget<WalletAddDialog>(find.byType(WalletAddDialog)).mode, WalletAddDialogMode.walletType);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('mounted home follows saved preference changes without replacing its configuration', (tester) async {
    final preferences = await _pumpHome(
      tester,
      empty: true,
      items: [_item(HomeItemIds.bitcoinBalanceTrend, span: HomeSpan.wide)],
    );
    final viewModel = tester.element(find.byType(HomeItemsView)).read<HomeViewModel>();
    final configuration = viewModel.configuration;
    for (final option in [HomeAddWalletOption.hidden, HomeAddWalletOption.hotWallet, HomeAddWalletOption.watchOnly]) {
      await preferences.changeIsFiatBalanceHidden(option != HomeAddWalletOption.watchOnly);
      await preferences.changeHomeAddWalletOption(option);
      await tester.pump();
      final button = find.byKey(const Key('home-add-wallet-button'));
      expect(button, option == HomeAddWalletOption.hidden ? findsNothing : findsOneWidget);
      expect(viewModel.showsAddWalletHint, option != HomeAddWalletOption.hidden);
      final fiat = tester.widget<Text>(find.byKey(const Key('balance-change-fiat'))).data!;
      expect(fiat.isEmpty, option != HomeAddWalletOption.watchOnly);
      expect(viewModel.configuration, configuration);
      expect(HomeConfigurationRepository(SharedPrefsRepository()).load(), configuration);
      expect(SharedPrefsRepository().getString(SharedPrefKeys.kHomeAddWalletOption), option.name);
    }
    await tester.tap(find.byKey(const Key('home-add-wallet-button')));
    await tester.pumpAndSettle();
    expect(tester.widget<WalletAddDialog>(find.byType(WalletAddDialog)).mode, WalletAddDialogMode.watchOnlySource);
    await tester.pumpWidget(const SizedBox());
    await preferences.changeHomeAddWalletOption(HomeAddWalletOption.all);
    expect(tester.takeException(), isNull);
  });

  for (final hidden in [false, true]) {
    for (final fake in [false, true]) {
      testWidgets('saved balance widget survives hidden-balance upgrade (fiat hidden: $hidden, fake: $fake)', (
        tester,
      ) async {
        await _pumpHome(
          tester,
          stored: {
            SharedPrefKeys.kIsBalanceHidden: true,
            SharedPrefKeys.kIsFiatBalanceHidden: hidden,
            if (fake) SharedPrefKeys.kFakeBalanceTotal: 50000000,
            if (fake) SharedPrefKeys.kFakeBalanceMap: jsonEncode({'1': 50000000}),
          },
          items: [_item(HomeItemIds.bitcoinBalanceTrend, span: HomeSpan.wide)],
        );
        final viewModel = tester.element(find.byType(HomeItemsView)).read<HomeViewModel>();
        expect(viewModel.configuration.items.single.id, 'configured-widget');
        expect(tester.widget<Text>(find.byKey(const Key('balance-change-fiat'))).data!.isEmpty, hidden);
        final data = tester.element(find.byType(HomeItemsView)).read<HomeWidgetsViewModel>();
        expect(data.isFakeBalance, fake);
        expect(data.totalBalance() == (fake ? 50000000 : 20000000), isTrue);
        expect(SharedPrefsRepository().getBool(SharedPrefKeys.kIsBalanceHidden), isTrue);
        await tester.pumpWidget(const SizedBox());
      });

      for (final balanceHidden in [false, true]) {
        test(
          'first new-home load retains preferences with fiat hidden=$hidden, fake=$fake, balance hidden=$balanceHidden',
          () async {
            final preferences = await _preferences({
              SharedPrefKeys.kIsBalanceHidden: balanceHidden,
              SharedPrefKeys.kIsFiatBalanceHidden: hidden,
              SharedPrefKeys.kHomeAddWalletOption: HomeAddWalletOption.watchOnly.name,
              if (fake) SharedPrefKeys.kFakeBalanceTotal: 50000000,
            });
            final viewModel = HomeViewModel(
              repository: HomeConfigurationRepository(SharedPrefsRepository()),
              wallets: () => [],
              onShortcutTap: (_, __) {},
              preferenceProvider: preferences,
              legacyBalanceHidden: preferences.isBalanceHidden,
              legacyFakeBalanceActive: preferences.isFakeBalanceActive,
            );
            addTearDown(viewModel.dispose);
            expect(viewModel.currentPresetId, balanceHidden && !fake ? 'hide_balances' : 'default');
            expect(preferences.isFiatBalanceHidden, hidden);
            expect(preferences.homeAddWalletOption, HomeAddWalletOption.watchOnly);
            expect(SharedPrefsRepository().getBool(SharedPrefKeys.kIsFiatBalanceHidden), hidden);
            expect(
              SharedPrefsRepository().getString(SharedPrefKeys.kHomeAddWalletOption),
              HomeAddWalletOption.watchOnly.name,
            );
          },
        );
      }
    }
  }

  for (final fake in [false, true]) {
    for (final span in [HomeSpan.small, HomeSpan.wide]) {
      testWidgets('balance trend obeys both fiat modes with live updates (fake: $fake, span: $span)', (tester) async {
        final (preferences, data) = await _pumpWidget(
          tester,
          _item(
            HomeItemIds.bitcoinBalanceTrend,
            span: span,
            configuration: const {
              'walletIds': [1],
              'period': 'month',
            },
          ),
          hidden: true,
          fake: fake,
        );
        final fiat = formatHomeFiat(data.fiatValueOf(data.totalBalance(), data.fiat), data.fiat);
        expect(find.text(fiat).evaluate().isEmpty, isTrue, reason: 'Hidden fiat must not enter the widget tree');
        final balance = tester.widget<HomeAmountText>(find.byType(HomeAmountText)).amount;
        expect(balance.number, data.unit.displayBitcoinAmount(data.totalBalance()));
        await preferences.changeIsFiatBalanceHidden(false);
        await tester.pump();
        expect(find.text(fiat).evaluate().length, 1);
        await preferences.changeIsFiatBalanceHidden(true);
        await tester.pump();
        expect(find.text(fiat).evaluate().isEmpty, isTrue);
        expect(tester.widget<HomeAmountText>(find.byType(HomeAmountText)).amount.number, balance.number);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    }

    testWidgets('configured multi-fiat balances obey hiding without losing currencies (fake: $fake)', (tester) async {
      final item = _item(
        HomeItemIds.bitcoinBalanceByFiat,
        configuration: const {
          'walletIds': [1],
          'fiats': ['USD', 'EUR'],
        },
      );
      final (preferences, _) = await _pumpWidget(tester, item, hidden: true, fake: fake);
      expect(tester.widget<BitcoinBalanceByFiatView>(find.byType(BitcoinBalanceByFiatView)).rows, isEmpty);
      await preferences.changeIsFiatBalanceHidden(false);
      await tester.pump();
      final rows = tester.widget<BitcoinBalanceByFiatView>(find.byType(BitcoinBalanceByFiatView)).rows;
      expect(rows.map((row) => row.fiat), [FiatCode.USD, FiatCode.EUR]);
      expect(rows.every((row) => row.amountText.isNotEmpty), isTrue);
      await preferences.changeIsFiatBalanceHidden(true);
      await tester.pump();
      expect(tester.widget<BitcoinBalanceByFiatView>(find.byType(BitcoinBalanceByFiatView)).rows, isEmpty);
      await tester.pumpWidget(const SizedBox());
    });
  }

  for (final id in [HomeItemIds.bitcoinBalanceTrend, HomeItemIds.bitcoinBalanceByFiat]) {
    testWidgets('hidden fiat does not delay $id waiting for an unused price', (tester) async {
      await _pumpWidget(tester, _item(id), hidden: true, pricesAvailable: false);
      expect(find.byType(HomeWidgetSkeleton), findsNothing);
      expect(find.byType(HomeAmountText), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  }

  for (final id in [HomeItemIds.fiatPriceTrend, HomeItemIds.fiatValues]) {
    testWidgets('fiat hiding keeps public market prices visible in $id', (tester) async {
      final (preferences, _) = await _pumpWidget(
        tester,
        _item(
          id,
          configuration: const {
            'fiats': ['USD'],
          },
        ),
        hidden: true,
      );
      final before = tester.widgetList<Text>(find.byType(Text)).map((text) => text.data).toList();
      expect(before.any((text) => text != null && RegExp(r'\d').hasMatch(text)), isTrue);
      await preferences.changeIsFiatBalanceHidden(false);
      await tester.pump();
      expect(tester.widgetList<Text>(find.byType(Text)).map((text) => text.data), before);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
