import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/home/home_configuration.dart';
import 'package:coconut_wallet/model/home/home_item.dart';
import 'package:coconut_wallet/model/home/home_item_ids.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/view_model/home/home_view_model.dart';
import 'package:coconut_wallet/repository/shared_preference/home_configuration_repository.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:coconut_wallet/screens/home/home_fake_balance_search.dart';
import 'package:coconut_wallet/services/home/builtin_home_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Preferences extends Fake with ChangeNotifier implements PreferenceProvider {
  bool active = false;
  int? total;

  @override
  FiatCode get selectedFiat => FiatCode.KRW;

  @override
  bool get isFakeBalanceActive => active;

  @override
  int? get fakeBalanceTotalAmount => total;

  @override
  Future<void> setFakeBalanceTotalAmount(int balance) async => total = balance;

  @override
  Future<void> toggleFakeBalanceActivation(bool isActive) async => active = isActive;
}

Future<(HomeViewModel, _Preferences)> _pump(WidgetTester tester, {required bool hasBalanceWidget}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = SharedPrefsRepository();
  await prefs.init();
  final repository = HomeConfigurationRepository(prefs);
  await repository.save(
    HomeConfiguration(
      items: [
        if (hasBalanceWidget)
          const HomeItem(
            id: 'balance',
            definitionId: HomeItemIds.bitcoinBalanceTrend,
            kind: HomeItemKind.widget,
            order: 0,
            span: HomeSpan.wide,
          ),
      ],
    ),
  );
  final viewModel = HomeViewModel(
    repository: repository,
    wallets: () => [],
    onShortcutTap: (_, __) {},
    widgetDefinitions: builtinHomeWidgets(),
  );
  final preferences = _Preferences();
  await tester.pumpWidget(
    ChangeNotifierProvider<PreferenceProvider>.value(
      value: preferences,
      child: MaterialApp(
        theme: buildCoconutThemeData(),
        home: Builder(
          builder:
              (context) => Scaffold(
                body: TextButton(
                  onPressed: () => openFakeBalanceFromSearch(context, viewModel),
                  child: const Text('Open fake balance'),
                ),
              ),
        ),
      ),
    ),
  );
  addTearDown(viewModel.dispose);
  return (viewModel, preferences);
}

void main() {
  testWidgets('with a balance widget, search opens the shared fake balance setting directly', (tester) async {
    await _pump(tester, hasBalanceWidget: true);

    await tester.tap(find.text('Open fake balance'));
    await tester.pumpAndSettle();

    expect(find.text(t.wallet_home_screen.edit.fake_balance.fake_balance_setting), findsOneWidget);
    expect(find.text(t.wallet_home_screen.edit.fake_balance.fake_balance_display), findsOneWidget);
    expect(find.text(t.home_edit.fake_balance_description), findsOneWidget);
    expect(find.text(t.home_edit.balance_display), findsNothing);
    expect(find.byKey(const Key('widget-configure-fake-balance')), findsOneWidget);
  });

  testWidgets('with no balance widget, search saves fake balance without adding a widget', (tester) async {
    final (viewModel, preferences) = await _pump(tester, hasBalanceWidget: false);

    await tester.tap(find.text('Open fake balance'));
    await tester.pumpAndSettle();
    expect(find.text(t.wallet_home_screen.edit.fake_balance.fake_balance_setting), findsOneWidget);
    expect(find.text(t.home_edit.fake_balance_description), findsOneWidget);
    expect(find.byKey(const Key('widget-configure-fake-balance')), findsOneWidget);
    expect(viewModel.configuration.items, isEmpty);

    await tester.tap(find.byKey(const Key('widget-configure-fake-balance')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('widget-configure-fake-balance-input')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('widget-configure-fake-balance-input')), '1');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('widget-configure-submit')));
    await tester.pumpAndSettle();

    expect(preferences.active, isTrue);
    expect(preferences.total, 100000000);
    expect(viewModel.configuration.items, isEmpty);
  });
}
