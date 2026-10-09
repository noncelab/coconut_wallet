import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_design_system/coconut_design_system.dart' show CoconutSegmentedControl;
import 'package:coconut_wallet/design_system/theme/coconut_theme_extension.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/home/home_configuration.dart';
import 'package:coconut_wallet/model/home/home_item.dart';
import 'package:coconut_wallet/model/home/home_item_definition.dart';
import 'package:coconut_wallet/model/home/home_item_ids.dart';
import 'package:coconut_wallet/model/home/home_preset.dart';
import 'package:coconut_wallet/model/home/shortcut_wallet_context.dart';
import 'package:coconut_wallet/screens/home/home_edit_screen.dart';
import 'package:coconut_wallet/services/feature/feature_registry.dart';
import 'package:coconut_wallet/providers/view_model/home/home_view_model.dart';
import 'package:coconut_wallet/repository/shared_preference/home_configuration_repository.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../mock/wallet_mock.dart';

class _SampleWidget extends HomeItemDefinition {
  final String name;

  _SampleWidget({super.id = 'sample_widget', this.name = 'Sample Widget', super.category = HomeItemCategory.wallets})
    : super(kind: HomeItemKind.widget, supportedSpans: const [HomeSpan.small]);

  @override
  String displayName() => name;

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

HomePresetApplied? _editResult;

Future<List<HomeConfiguration>> _open(
  WidgetTester tester,
  HomeConfiguration configuration, {
  List<int> walletIds = const [1, 2],
  List<HomeItemDefinition>? widgetDefinitions,
  List<HomePreset>? presets,
  bool likeApp = false,
  CoconutThemeVariant? variant,
}) async {
  tester.view.physicalSize = const Size(800, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  _editResult = null;
  SharedPreferences.setMockInitialValues({});
  final prefs = SharedPrefsRepository()..setSharedPreferencesForTest(await SharedPreferences.getInstance());
  final repository = HomeConfigurationRepository(prefs);
  await repository.save(configuration);
  final viewModel = HomeViewModel(
    repository: repository,
    wallets: () => [for (final id in walletIds) WalletMock.createSingleSigWalletItem(id: id)],
    onShortcutTap: (_, __) {},
    widgetDefinitions: widgetDefinitions ?? [_SampleWidget()],
    presets: presets,
  );
  final changes = <HomeConfiguration>[];
  viewModel.addListener(() => changes.add(viewModel.configuration));
  Widget opener(BuildContext context) => Scaffold(
    body: TextButton(
      onPressed: () async {
        _editResult = await Navigator.of(context).push<HomePresetApplied>(
          MaterialPageRoute(
            builder: (_) => ChangeNotifierProvider.value(value: viewModel, child: const HomeEditScreen()),
          ),
        );
      },
      child: const Text('open'),
    ),
  );
  await tester.pumpWidget(
    likeApp
        ? CupertinoApp(
          localizationsDelegates: const [
            DefaultMaterialLocalizations.delegate,
            DefaultWidgetsLocalizations.delegate,
            DefaultCupertinoLocalizations.delegate,
          ],
          builder: (context, child) => Theme(data: buildCoconutThemeData(variant: variant), child: child!),
          home: Builder(builder: opener),
        )
        : MaterialApp(theme: buildCoconutThemeData(variant: variant), home: Builder(builder: opener)),
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

  testWidgets('the presets tab previews a preset, applies it from the preview, and undo restores the home', (
    tester,
  ) async {
    final preset = HomePreset(
      id: 'p',
      name: () => 'Preset P',
      description: () => 'desc',
      definitionIds: ['sample_widget', _calculatorId],
    );
    final before = HomeConfiguration(
      items: [
        HomeItem(id: 'r', definitionId: _receiveId, kind: HomeItemKind.shortcut, order: 0, span: HomeSpan.shortcut),
      ],
    );
    final changes = await _open(tester, before, presets: [preset]);

    expect(find.text(t.home_presets.header), findsOneWidget);
    expect(find.text('Preset P'), findsOneWidget);
    expect(find.text('desc'), findsOneWidget);

    await tester.tapAt(tester.getTopLeft(find.byKey(const ValueKey('home-preset-card-p'))) + const Offset(24, 24));
    await _settle(tester);
    expect(find.byKey(const Key('home-preset-preview-scroll')), findsOneWidget);
    Navigator.of(tester.element(find.byKey(const Key('home-preset-preview-scroll')))).pop();
    await _settle(tester);

    await tester.tap(find.byKey(const ValueKey('home-preset-preview-p')));
    await _settle(tester);

    expect(find.byKey(const Key('home-preset-preview-scroll')), findsOneWidget);
    expect(changes, isEmpty);

    await tester.tap(find.byKey(const Key('home-preset-preview-apply')));
    await _settle(tester);

    expect(find.byKey(const Key('home-preset-preview-scroll')), findsNothing);
    expect(find.byType(HomeEditScreen), findsNothing);
    expect(changes.last.items.map((item) => item.definitionId), ['sample_widget', _calculatorId]);
    expect(_editResult!.previous.items.map((item) => item.definitionId), [_receiveId]);
    expect(_editResult!.preset.id, 'p');
  });

  testWidgets('in the app\'s CupertinoApp, applying a preset closes Edit Home without errors', (tester) async {
    final preset = HomePreset(
      id: 'p',
      name: () => 'Preset P',
      description: () => 'desc',
      definitionIds: [_calculatorId],
    );
    final changes = await _open(tester, HomeConfiguration(items: const []), presets: [preset], likeApp: true);

    await tester.tap(find.byKey(const ValueKey('home-preset-preview-p')));
    await _settle(tester);
    await tester.tap(find.byKey(const Key('home-preset-preview-apply')));
    await _settle(tester);

    expect(tester.takeException(), isNull);
    expect(find.byType(HomeEditScreen), findsNothing);
    expect(changes.last.items.map((item) => item.definitionId), [_calculatorId]);
    expect(_editResult!.previous.items, isEmpty);
  });

  testWidgets('the tab control container stands out from the home background in every theme', (tester) async {
    for (final variant in CoconutThemeVariant.values) {
      final colors = buildCoconutThemeData(variant: variant).extension<CoconutThemeExtension>()!.colors;
      await tester.pumpWidget(const SizedBox());
      await _open(tester, HomeConfiguration(items: const []), variant: variant);

      final control = tester.widget<CoconutSegmentedControl>(find.byType(CoconutSegmentedControl));
      expect(control.segmentedControlContainerColor, colors.homeSurface, reason: '$variant');
      expect(control.segmentedControlContainerColor, isNot(colors.homeBackground), reason: '$variant');
    }
  });

  testWidgets('add and remove buttons use the muted color in both tabs', (tester) async {
    final configuration = HomeConfiguration(
      items: [
        HomeItem(id: 'c', definitionId: _calculatorId, kind: HomeItemKind.shortcut, order: 0, span: HomeSpan.shortcut),
      ],
    );
    await _open(tester, configuration);
    final muted = tester.element(find.byType(HomeEditScreen)).coconutColors.mutedText;

    await tester.tap(find.text(t.home_edit.widgets));
    await _settle(tester);
    expect(
      tester
          .widget<Icon>(
            find.descendant(of: find.byKey(const ValueKey('home-edit-add-sample_widget')), matching: find.byType(Icon)),
          )
          .color,
      muted,
    );

    await tester.tap(find.text(t.home_edit.shortcuts));
    await _settle(tester);
    for (final key in ['home-edit-remove-$_calculatorId', 'home-edit-add-$_receiveId']) {
      expect(
        tester.widget<Icon>(find.descendant(of: find.byKey(ValueKey(key)), matching: find.byType(Icon))).color,
        muted,
        reason: key,
      );
    }
  });

  testWidgets('a background gradient sits under the tabs and the content starts below it', (tester) async {
    await _open(tester, HomeConfiguration(items: const []));

    for (final tab in [t.home_edit.presets, t.home_edit.widgets, t.home_edit.shortcuts]) {
      await tester.tap(find.text(tab));
      await _settle(tester);

      final fade = find.byKey(const Key('home-edit-top-fade'));
      expect(fade, findsOneWidget);
      expect(find.ancestor(of: fade, matching: find.byType(IgnorePointer)), findsWidgets);
      final decoration = tester.widget<DecoratedBox>(fade).decoration as BoxDecoration;
      expect((decoration.gradient! as LinearGradient).colors.last.a, 0);
      final firstScrollable = tester.getRect(find.byType(Scrollable).last);
      expect(tester.getRect(fade).top, firstScrollable.top);
    }
    final header = tester.getRect(find.text(t.home_edit.shortcuts_on_home));
    expect(header.top, greaterThanOrEqualTo(tester.getRect(find.byKey(const Key('home-edit-top-fade'))).bottom));
  });

  testWidgets('leaving the preview without applying changes nothing', (tester) async {
    addTearDown(() => expect(_editResult, isNull));
    final preset = HomePreset(
      id: 'p',
      name: () => 'Preset P',
      description: () => 'desc',
      definitionIds: [_calculatorId],
    );
    final changes = await _open(tester, HomeConfiguration(items: const []), presets: [preset]);

    await tester.tap(find.byKey(const ValueKey('home-preset-preview-p')));
    await _settle(tester);
    await Navigator.of(tester.element(find.byKey(const Key('home-preset-preview-scroll')))).maybePop();
    await _settle(tester);

    expect(changes, isEmpty);
    expect(find.text('Preset P'), findsOneWidget);
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

  testWidgets('the widgets tab groups widgets under their category in a fixed order', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await _open(
      tester,
      HomeConfiguration(items: const []),
      widgetDefinitions: [
        _SampleWidget(id: 'hodl_widget', name: 'Hodl Widget', category: HomeItemCategory.hodl),
        _SampleWidget(id: 'balance_widget', name: 'Balance Widget', category: HomeItemCategory.balance),
      ],
    );
    await tester.tap(find.text(t.home_edit.widgets));
    await _settle(tester);

    expect(find.byKey(const ValueKey('home-edit-category-balance')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-edit-category-hodl')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-edit-category-wallets')), findsNothing);
    expect(find.byKey(const ValueKey('home-edit-category-safety')), findsNothing);
    expect(
      tester.getTopLeft(find.text('Balance Widget')).dy,
      lessThan(tester.getTopLeft(find.byKey(const ValueKey('home-edit-category-hodl'))).dy),
    );
  });

  testWidgets('category chips list every category up front and show only the chosen one', (tester) async {
    await _open(
      tester,
      HomeConfiguration(items: const []),
      widgetDefinitions: [
        _SampleWidget(id: 'hodl_widget', name: 'Hodl Widget', category: HomeItemCategory.hodl),
        _SampleWidget(id: 'balance_widget', name: 'Balance Widget', category: HomeItemCategory.balance),
      ],
    );
    await tester.tap(find.text(t.home_edit.widgets));
    await _settle(tester);

    expect(find.byKey(const ValueKey('home-edit-chip-all')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-edit-chip-balance')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-edit-chip-hodl')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-edit-chip-wallets')), findsNothing);
    expect(tester.getTopLeft(find.byKey(const ValueKey('home-edit-chip-all'))).dx, 16);
    expect(
      tester.getRect(find.byKey(const ValueKey('home-edit-chip-all'))).bottom,
      lessThan(tester.getRect(find.byKey(const ValueKey('home-edit-category-balance'))).top),
    );

    await tester.tap(find.byKey(const ValueKey('home-edit-chip-hodl')));
    await _settle(tester);
    expect(find.text('Hodl Widget'), findsOneWidget);
    expect(find.text('Balance Widget'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('home-edit-chip-all')));
    await _settle(tester);
    expect(find.text('Hodl Widget'), findsOneWidget);
    expect(find.text('Balance Widget'), findsOneWidget);

    await tester.tap(find.text(t.home_edit.shortcuts));
    await _settle(tester);
    expect(find.byKey(const Key('home-edit-category-chips')), findsNothing);
  });

  testWidgets('the shortcuts tab puts a divider between rows in each section', (tester) async {
    await _open(tester, HomeConfiguration(items: const []));
    await tester.tap(find.text(t.home_edit.shortcuts));
    await _settle(tester);

    final rows = find.byWidgetPredicate(
      (widget) =>
          widget.key is ValueKey<String> &&
          (widget.key! as ValueKey<String>).value.startsWith('home-edit-shortcut-shortcut:'),
    );
    final rowCount = rows.evaluate().length;
    expect(rowCount, greaterThan(1));
    final dividers = find.byWidgetPredicate(
      (widget) =>
          widget.key is ValueKey<String> &&
          (widget.key! as ValueKey<String>).value.startsWith('home-edit-shortcut-divider-'),
    );
    expect(dividers.evaluate().length, rowCount - 1);
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
    final sheet = tester.widget<BottomSheet>(find.byType(BottomSheet).last);
    expect(sheet.shape, const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))));
    expect(sheet.clipBehavior, Clip.antiAlias);

    await tester.tap(find.byKey(const ValueKey('shortcut-configure-wallet-1')));
    await _settle(tester);
    await tester.tap(find.byKey(const Key('shortcut-configure-add')));
    await _settle(tester);

    expect(changes.single.shortcutWalletContext, const ShortcutWalletContext.wallet(1));
    expect(changes.single.items.single.definitionId, _receiveId);
  });

  testWidgets('with no wallets + still opens the configure sheet with only "ask every time"', (tester) async {
    final changes = await _open(tester, HomeConfiguration(items: const []), walletIds: const []);
    await tester.tap(find.text(t.home_edit.shortcuts));
    await _settle(tester);

    await tester.tap(find.byKey(ValueKey('home-edit-add-$_receiveId')));
    await _settle(tester);

    expect(find.text(t.home_edit.configure_shortcut), findsOneWidget);
    expect(find.byKey(const Key('shortcut-configure-ask')), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (w) => w.key is ValueKey && '${(w.key as ValueKey).value}'.startsWith('shortcut-configure-wallet-'),
      ),
      findsNothing,
    );
    await tester.tap(find.byKey(const Key('shortcut-configure-add')));
    await _settle(tester);
    expect(changes.single.shortcutWalletContext, const ShortcutWalletContext.askEveryTime());
    expect(changes.single.items.single.definitionId, _receiveId);
  });

  testWidgets('with one wallet + still opens the configure sheet', (tester) async {
    final changes = await _open(tester, HomeConfiguration(items: const []), walletIds: const [7]);
    await tester.tap(find.text(t.home_edit.shortcuts));
    await _settle(tester);

    await tester.tap(find.byKey(ValueKey('home-edit-add-$_receiveId')));
    await _settle(tester);

    expect(find.text(t.home_edit.configure_shortcut), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('shortcut-configure-wallet-7')));
    await _settle(tester);
    await tester.tap(find.byKey(const Key('shortcut-configure-add')));
    await _settle(tester);
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

  testWidgets('there is no done button; changes apply right away and back closes the screen', (tester) async {
    final changes = await _open(tester, HomeConfiguration(items: const []));

    expect(find.byKey(const Key('home-edit-done')), findsNothing);
    expect(find.text(t.done), findsNothing);

    await tester.tap(find.text(t.home_edit.widgets));
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('home-edit-add-sample_widget')));
    await _settle(tester);
    expect(changes.single.items.single.definitionId, 'sample_widget');

    await Navigator.of(tester.element(find.byType(HomeEditScreen))).maybePop();
    await _settle(tester);
    expect(find.byType(HomeEditScreen), findsNothing);
    expect(_editResult, isNull);
  });
}
