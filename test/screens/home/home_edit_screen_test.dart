import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/home/home_configuration.dart';
import 'package:coconut_wallet/model/home/home_item.dart';
import 'package:coconut_wallet/model/home/home_item_definition.dart';
import 'package:coconut_wallet/model/home/home_item_ids.dart';
import 'package:coconut_wallet/model/home/shortcut_wallet_context.dart';
import 'package:coconut_wallet/screens/home/home_edit_screen.dart';
import 'package:coconut_wallet/services/feature/feature_registry.dart';
import 'package:coconut_wallet/providers/view_model/home/home_view_model.dart';
import 'package:coconut_wallet/repository/shared_preference/home_configuration_repository.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../mock/wallet_mock.dart';

class _SampleWidget extends HomeItemDefinition {
  _SampleWidget()
    : super(id: 'sample_widget', kind: HomeItemKind.widget, supportedSpans: const [HomeSpan.small], category: 't');

  @override
  String displayName() => 'Sample Widget';

  @override
  Widget build(BuildContext context, HomeItem item) => const ColoredBox(color: Colors.grey);
}

final _calculatorId = HomeItemIds.shortcut(FeatureIds.calculator);
final _receiveId = HomeItemIds.shortcut(FeatureIds.receive);

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<List<HomeConfiguration>> _open(
  WidgetTester tester,
  HomeConfiguration configuration, {
  List<int> walletIds = const [1, 2],
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = SharedPrefsRepository()..setSharedPreferencesForTest(await SharedPreferences.getInstance());
  final repository = HomeConfigurationRepository(prefs);
  await repository.save(configuration);
  final viewModel = HomeViewModel(
    repository: repository,
    wallets: () => [for (final id in walletIds) WalletMock.createSingleSigWalletItem(id: id)],
    onShortcutTap: (_, __) {},
    widgetDefinitions: [_SampleWidget()],
  );
  final changes = <HomeConfiguration>[];
  viewModel.addListener(() => changes.add(viewModel.configuration));
  await tester.pumpWidget(
    MaterialApp(
      theme: buildCoconutThemeData(),
      home: Builder(
        builder:
            (context) => Scaffold(
              body: TextButton(
                onPressed:
                    () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ChangeNotifierProvider.value(value: viewModel, child: const HomeEditScreen()),
                      ),
                    ),
                child: const Text('open'),
              ),
            ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await _settle(tester);
  return changes;
}

void main() {
  testWidgets('shows the title and three tabs with presets selected first', (tester) async {
    await _open(tester, HomeConfiguration(items: const []));

    expect(find.text(t.home_edit.title), findsOneWidget);
    expect(find.text(t.home_edit.presets), findsOneWidget);
    expect(find.text(t.home_edit.widgets), findsOneWidget);
    expect(find.text(t.home_edit.shortcuts), findsOneWidget);
    expect(find.byKey(const ValueKey('home-edit-tab-presets')), findsOneWidget);
  });

  testWidgets('the widgets tab lists registered widgets and adds one to home', (tester) async {
    final changes = await _open(tester, HomeConfiguration(items: const []));
    await tester.tap(find.text(t.home_edit.widgets));
    await _settle(tester);

    expect(find.text('Sample Widget'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('home-edit-add-sample_widget')));
    await _settle(tester);

    expect(changes.single.items.single.definitionId, 'sample_widget');
    expect(changes.single.items.single.span, HomeSpan.small);
    expect(find.byKey(const ValueKey('home-edit-remove-sample_widget')), findsOneWidget);
  });

  testWidgets('the shortcuts tab removes a shortcut that is on home', (tester) async {
    final configuration = HomeConfiguration(
      items: [
        HomeItem(id: 'c', definitionId: _calculatorId, kind: HomeItemKind.shortcut, order: 0, span: HomeSpan.shortcut),
      ],
    );
    final changes = await _open(tester, configuration);
    await tester.tap(find.text(t.home_edit.shortcuts));
    await _settle(tester);

    await tester.tap(find.byKey(ValueKey('home-edit-remove-$_calculatorId')));
    await _settle(tester);

    expect(changes.single.items, isEmpty);
    expect(find.byKey(ValueKey('home-edit-add-$_calculatorId')), findsOneWidget);
  });

  testWidgets('the shortcuts tab adds an available shortcut', (tester) async {
    final changes = await _open(tester, HomeConfiguration(items: const []));
    await tester.tap(find.text(t.home_edit.shortcuts));
    await _settle(tester);

    await tester.scrollUntilVisible(find.byKey(ValueKey('home-edit-add-$_calculatorId')), 100);
    await tester.tap(find.byKey(ValueKey('home-edit-add-$_calculatorId')));
    await _settle(tester);

    expect(changes.single.items.single.definitionId, _calculatorId);
    expect(changes.single.items.single.kind, HomeItemKind.shortcut);
  });

  testWidgets('a 2×2 widget takes half the content width', (tester) async {
    await _open(tester, HomeConfiguration(items: const []));
    await tester.tap(find.text(t.home_edit.widgets));
    await _settle(tester);

    final screenWidth = tester.getSize(find.byType(HomeEditScreen)).width;
    final itemWidth = tester.getSize(find.byKey(const ValueKey('home-edit-widget-sample_widget'))).width;
    expect(itemWidth, (screenWidth - 32 - 16) / 2);
  });

  testWidgets('with two or more wallets adding a wallet shortcut asks for the shared wallet first', (tester) async {
    final changes = await _open(tester, HomeConfiguration(items: const []));
    await tester.tap(find.text(t.home_edit.shortcuts));
    await _settle(tester);

    await tester.tap(find.byKey(ValueKey('home-edit-add-$_receiveId')));
    await _settle(tester);
    expect(find.text(t.home_edit.configure_shortcut), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('shortcut-configure-wallet-1')));
    await _settle(tester);
    await tester.tap(find.byKey(const Key('shortcut-configure-add')));
    await _settle(tester);

    expect(changes.single.shortcutWalletContext, const ShortcutWalletContext.wallet(1));
    expect(changes.single.items.single.definitionId, _receiveId);
  });

  testWidgets('with no wallets a wallet shortcut is added at once and asks every time', (tester) async {
    final changes = await _open(tester, HomeConfiguration(items: const []), walletIds: const []);
    await tester.tap(find.text(t.home_edit.shortcuts));
    await _settle(tester);

    await tester.tap(find.byKey(ValueKey('home-edit-add-$_receiveId')));
    await _settle(tester);

    expect(find.text(t.home_edit.configure_shortcut), findsNothing);
    expect(changes.single.shortcutWalletContext, const ShortcutWalletContext.askEveryTime());
    expect(changes.single.items.single.definitionId, _receiveId);
  });

  testWidgets('with one wallet a wallet shortcut is added at once and uses that wallet', (tester) async {
    final changes = await _open(tester, HomeConfiguration(items: const []), walletIds: const [7]);
    await tester.tap(find.text(t.home_edit.shortcuts));
    await _settle(tester);

    await tester.tap(find.byKey(ValueKey('home-edit-add-$_receiveId')));
    await _settle(tester);

    expect(find.text(t.home_edit.configure_shortcut), findsNothing);
    expect(changes.single.shortcutWalletContext, const ShortcutWalletContext.wallet(7));
  });

  testWidgets('closing the configure sheet adds nothing', (tester) async {
    final changes = await _open(tester, HomeConfiguration(items: const []));
    await tester.tap(find.text(t.home_edit.shortcuts));
    await _settle(tester);

    await tester.tap(find.byKey(ValueKey('home-edit-add-$_receiveId')));
    await _settle(tester);
    await tester.tapAt(const Offset(10, 10));
    await _settle(tester);

    expect(changes, isEmpty);
  });

  testWidgets('done closes the screen', (tester) async {
    await _open(tester, HomeConfiguration(items: const []));

    await tester.tap(find.byKey(const Key('home-edit-done')));
    await _settle(tester);

    expect(find.byType(HomeEditScreen), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });
}
