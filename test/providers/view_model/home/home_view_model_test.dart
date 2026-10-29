import 'package:coconut_wallet/services/home/home_presets.dart';
import 'package:coconut_wallet/model/home/home_configuration.dart';
import 'package:coconut_wallet/model/home/home_item.dart';
import 'package:coconut_wallet/model/home/home_item_definition.dart';
import 'package:coconut_wallet/model/home/home_item_ids.dart';
import 'package:coconut_wallet/model/home/home_preset.dart';
import 'package:coconut_wallet/model/home/shortcut_wallet_context.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/providers/view_model/home/home_view_model.dart';
import 'package:coconut_wallet/repository/shared_preference/home_configuration_repository.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:coconut_wallet/services/feature/feature_registry.dart';
import 'package:coconut_wallet/services/home/home_grid_layout.dart';
import 'package:coconut_wallet/services/home/builtin_home_widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../mock/wallet_mock.dart';

class _Widget extends HomeItemDefinition {
  _Widget({super.id = 'w', HomeSpan span = HomeSpan.small, List<HomeSpan>? spans})
    : super(kind: HomeItemKind.widget, supportedSpans: spans ?? [span], category: HomeItemCategory.wallets);

  @override
  Widget build(BuildContext context, HomeItem item) => const SizedBox();
}

HomeItem _shortcut(String id, String featureId, int order) => HomeItem(
  id: id,
  definitionId: HomeItemIds.shortcut(featureId),
  kind: HomeItemKind.shortcut,
  order: order,
  span: HomeSpan.shortcut,
);

void main() {
  late HomeConfigurationRepository repository;
  late List<WalletItemBase> wallets;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = SharedPrefsRepository()..setSharedPreferencesForTest(await SharedPreferences.getInstance());
    repository = HomeConfigurationRepository(prefs);
    wallets = [];
  });

  HomeViewModel create({
    List<HomePreset>? presets,
    List<HomeItemDefinition>? widgetDefinitions,
    bool legacyFakeBalanceActive = false,
    bool legacyBalanceHidden = false,
  }) => HomeViewModel(
    presets: presets,
    repository: repository,
    wallets: () => wallets,
    onShortcutTap: (_, __) {},
    legacyFakeBalanceActive: legacyFakeBalanceActive,
    legacyBalanceHidden: legacyBalanceHidden,
    widgetDefinitions:
        widgetDefinitions ??
        [
          _Widget(),
          _Widget(id: 'w_wide', span: HomeSpan.wide),
          _Widget(id: HomeItemIds.watchOnlyWalletStack, spans: [HomeSpan.small, HomeSpan.wide]),
        ],
  );

  test('expanded edits persist their grid count and undo restores canonical positions', () async {
    await repository.save(
      HomeConfiguration(
        items: [
          const HomeItem(id: 'a', definitionId: 'w', kind: HomeItemKind.widget, order: 0, span: HomeSpan.small),
          _shortcut('b', FeatureIds.calculator, 1),
        ],
      ),
    );
    final viewModel = create(
      widgetDefinitions: [
        _Widget(spans: [HomeSpan.small, HomeSpan.wide]),
      ],
    );
    addTearDown(viewModel.dispose);
    final original = viewModel.configuration;
    final stored = repository.load();
    for (final columns in [6, 8, 4, 6, 4]) {
      HomeGridLayout(viewModel.configuration).reflow(columns);
      expect(repository.load(), stored);
    }
    viewModel.moveToCell('b', const HomeGridPosition(5, 3), columns: 6);
    expect(viewModel.configuration.columns, 6);
    expect(repository.load(), viewModel.configuration);
    expect(HomeGridLayout(repository.load()!).positionOf('b'), const HomeGridPosition(5, 3));
    final reloaded = create(
      widgetDefinitions: [
        _Widget(spans: [HomeSpan.small, HomeSpan.wide]),
      ],
    );
    expect(reloaded.configuration, viewModel.configuration);
    reloaded.dispose();
    viewModel.undoArrangement();
    expect(viewModel.configuration, original);
    viewModel.insertBefore('b', 'a', columns: 8);
    expect(viewModel.configuration.columns, 8);
    viewModel.undoArrangement();
    expect(viewModel.configuration, original);
    viewModel.resizeItem('a', HomeSpan.wide, columns: 6);
    expect(viewModel.configuration.columns, 6);
    expect(viewModel.configuration.items.firstWhere((item) => item.id == 'a').span, HomeSpan.wide);
    expect(repository.load(), viewModel.configuration);
    viewModel.updateItemConfiguration('a', {'label': 'expanded'});
    viewModel.updateShortcutWalletContext(const ShortcutWalletContext.wallet(7));
    expect(viewModel.configuration.columns, 6);
    viewModel.removeItem('b');
    expect(repository.load()!.columns, 6);
  });

  for (final (columns, positions, rows) in [
    (6, [(0, 0), (4, 0), (0, 2), (2, 2), (4, 2), (5, 2), (4, 3), (5, 3), (0, 4)], 6),
    (8, [(0, 0), (4, 0), (6, 0), (0, 2), (2, 2), (3, 2), (2, 3), (3, 3), (4, 2)], 4),
    (10, [(0, 0), (4, 0), (6, 0), (8, 0), (0, 2), (1, 2), (0, 3), (1, 3), (2, 2)], 4),
  ]) {
    test('real default preset preserves its shortcut block in $columns-column projection', () {
      final viewModel = create(widgetDefinitions: builtinHomeWidgets());
      addTearDown(viewModel.dispose);
      final canonical = viewModel.configuration;
      final preset = builtinHomePresets().firstWhere((preset) => preset.id == defaultPresetId);
      final projected = HomeGridLayout(HomeGridLayout(canonical).reflow(columns));
      expect(canonical.items.map((item) => item.definitionId), preset.definitionIds);
      expect(projected.rows, rows);
      final occupied = <(int, int)>{};
      for (final (index, definitionId) in preset.definitionIds.indexed) {
        final item = canonical.items.singleWhere((item) => item.definitionId == definitionId);
        final position = projected.positionOf(item.id)!;
        expect(position, HomeGridPosition(positions[index].$1, positions[index].$2), reason: definitionId);
        for (var y = position.row; y < position.row + item.span.height; y++) {
          for (var x = position.column; x < position.column + item.span.width; x++) {
            expect(occupied.add((x, y)), isTrue, reason: 'overlap at ($x, $y)');
          }
        }
        expect(projected.configuration.items.singleWhere((other) => other.id == item.id).span, item.span);
      }
      expect(projected.configuration.items.length, canonical.items.length);
      expect(HomeGridLayout(canonical).reflow(4), canonical);
      expect(repository.load(), canonical);
      expect(viewModel.configuration, canonical);
    });
  }

  for (final (columns, left, top) in [(6, 4, 2), (4, 2, 4)]) {
    test('saved eight-column default edits keep the shortcut rectangle when projected to $columns columns', () {
      final viewModel = create(widgetDefinitions: builtinHomeWidgets());
      addTearDown(viewModel.dispose);
      final price = viewModel.configuration.items.singleWhere(
        (item) => item.definitionId == HomeItemIds.fiatPriceTrend,
      );
      viewModel.moveToCell(price.id, const HomeGridPosition(6, 0), columns: 8);
      final saved = repository.load()!;
      final reloaded = create(widgetDefinitions: builtinHomeWidgets());
      addTearDown(reloaded.dispose);
      expect(reloaded.configuration, saved);
      expect(saved.columns, 8);
      final shortcutIds = [FeatureIds.receive, FeatureIds.send, FeatureIds.utxoOrganizer, FeatureIds.hodlInsights];
      for (final (index, featureId) in shortcutIds.indexed) {
        final shortcut = saved.items.singleWhere((item) => item.definitionId == HomeItemIds.shortcut(featureId));
        expect(shortcut.position, HomeGridPosition(2 + index % 2, 2 + index ~/ 2));
      }
      final projected = HomeGridLayout(HomeGridLayout(reloaded.configuration).reflow(columns));
      for (final (index, featureId) in shortcutIds.indexed) {
        final shortcut = saved.items.singleWhere((item) => item.definitionId == HomeItemIds.shortcut(featureId));
        expect(
          projected.positionOf(shortcut.id),
          HomeGridPosition(left + index % 2, top + index ~/ 2),
          reason: featureId,
        );
      }
      for (final viewportColumns in [4, 8, 6, 10, 6]) {
        HomeGridLayout(reloaded.configuration).reflow(viewportColumns);
        expect(repository.load(), saved);
        expect(reloaded.configuration, saved);
      }
      expect(HomeGridLayout(reloaded.configuration).reflow(columns), projected.configuration);
    });
  }

  group('loading', () {
    test('legacy hidden balance selects the hide balances preset on first load', () {
      final viewModel = create(widgetDefinitions: builtinHomeWidgets(), legacyBalanceHidden: true);
      final preset = builtinHomePresets().firstWhere((preset) => preset.id == 'hide_balances');

      expect(viewModel.currentPresetId, 'hide_balances');
      expect(viewModel.configuration.items.map((item) => item.definitionId), preset.definitionIds);
      expect(repository.load(), viewModel.configuration);
    });

    test('legacy fake balance takes precedence over hidden balance on first load', () {
      final viewModel = create(
        widgetDefinitions: builtinHomeWidgets(),
        legacyFakeBalanceActive: true,
        legacyBalanceHidden: true,
      );
      final preset = builtinHomePresets().firstWhere((preset) => preset.id == defaultPresetId);

      expect(viewModel.currentPresetId, defaultPresetId);
      expect(viewModel.configuration.items.map((item) => item.definitionId), preset.definitionIds);
    });

    test('legacy settings do not replace an existing customized home', () async {
      await repository.save(HomeConfiguration(items: [_shortcut('custom', FeatureIds.receive, 0)]));

      final viewModel = create(widgetDefinitions: builtinHomeWidgets(), legacyBalanceHidden: true);

      expect(viewModel.configuration.items.map((item) => item.id), ['custom']);
      expect(viewModel.currentPresetId, isNull);
    });

    test('on first install the default preset is applied and saved', () {
      final viewModel = create();
      final preset = builtinHomePresets().firstWhere((preset) => preset.id == defaultPresetId);

      final ids = viewModel.configuration.items.map((item) => item.definitionId);
      expect(ids, [
        for (final id in preset.definitionIds)
          if (viewModel.registry.byId(id) != null) id,
      ]);
      expect(ids, contains(HomeItemIds.shortcut(FeatureIds.receive)));
      expect(viewModel.configuration.items.every((item) => item.position != null), isTrue);
      expect(repository.load(), viewModel.configuration);
    });

    test('on first install with one wallet, the preset shortcuts use that wallet', () {
      wallets = [WalletMock.createSingleSigWalletItem(id: 3)];

      expect(create().shortcutWalletContext, const ShortcutWalletContext.wallet(3));
    });

    test('with no preset items registered, the fallback configuration is used', () {
      final viewModel = create(presets: const []);

      final ids = viewModel.configuration.items.map((item) => item.definitionId);
      expect(ids, [HomeItemIds.watchOnlyWalletStack, HomeItemIds.shortcut(FeatureIds.calculator)]);
    });

    test('a saved configuration with old dummy widgets is replaced by the default', () async {
      await repository.save(
        HomeConfiguration(
          items: const [
            HomeItem(id: 'd', definitionId: 'dummy_widget', kind: HomeItemKind.widget, order: 0, span: HomeSpan.small),
          ],
        ),
      );

      final ids = create().configuration.items.map((item) => item.definitionId);

      expect(ids, contains(HomeItemIds.shortcut(FeatureIds.receive)));
      expect(ids, isNot(contains('dummy_widget')));
    });

    test('shortcuts that are no longer candidates are removed, others kept', () async {
      await repository.save(
        HomeConfiguration(items: [_shortcut('a', FeatureIds.receive, 0), _shortcut('b', FeatureIds.walletDetail, 1)]),
      );

      final ids = create().configuration.items.map((item) => item.id);

      expect(ids, ['a']);
      expect(repository.load()!.items.map((item) => item.id), ['a']);
    });

    test('widgets whose definition is not registered yet are kept', () async {
      await repository.save(
        HomeConfiguration(
          items: const [
            HomeItem(id: 'f', definitionId: 'future_widget', kind: HomeItemKind.widget, order: 0, span: HomeSpan.small),
          ],
        ),
      );

      expect(create().configuration.items.map((item) => item.id), ['f']);
    });
  });

  group('editing', () {
    test('adding and removing a definition updates and saves the home', () async {
      await repository.save(HomeConfiguration(items: const []));
      final viewModel = create();
      final definition = viewModel.registry.byId('w')!;
      var notified = 0;
      viewModel.addListener(() => notified++);

      viewModel.addItem(definition);
      expect(viewModel.isOnHome(definition), isTrue);
      expect(repository.load()!.items.single.definitionId, 'w');

      viewModel.removeDefinition(definition);
      expect(viewModel.isOnHome(definition), isFalse);
      expect(repository.load()!.items, isEmpty);
      expect(notified, 2);
    });

    test('the same kind of widget in another size is a separate widget, one of each', () async {
      await repository.save(HomeConfiguration(items: const []));
      final viewModel = create();
      final small = viewModel.registry.byId('w')!;
      final wide = viewModel.registry.byId('w_wide')!;

      viewModel.addItem(small);
      viewModel.addItem(wide);

      expect(viewModel.isOnHome(small), isTrue);
      expect(viewModel.isOnHome(wide), isTrue);
      expect(viewModel.configuration.items.map((item) => item.span), [HomeSpan.small, HomeSpan.wide]);
    });

    test('adding a shortcut with a wallet context changes the shared wallet', () async {
      await repository.save(HomeConfiguration(items: const []));
      final viewModel = create();

      viewModel.addItem(
        viewModel.registry.byId(HomeItemIds.shortcut(FeatureIds.receive))!,
        walletContext: const ShortcutWalletContext.wallet(3),
      );

      expect(viewModel.shortcutWalletContext, const ShortcutWalletContext.wallet(3));
    });
  });

  group('shared shortcut wallet without asking (requirements 16.2)', () {
    test('no wallets → ask every time', () {
      expect(create().walletContextWithoutAsking(), const ShortcutWalletContext.askEveryTime());
    });

    test('one wallet → that wallet', () {
      wallets = [WalletMock.createSingleSigWalletItem(id: 5)];

      expect(create().walletContextWithoutAsking(), const ShortcutWalletContext.wallet(5));
    });

    test('two or more wallets → must ask', () {
      wallets = [WalletMock.createSingleSigWalletItem(id: 1), WalletMock.createSingleSigWalletItem(id: 2)];

      expect(create().walletContextWithoutAsking(), isNull);
    });
  });

  group('presets', () {
    test('default preset preview and apply remain tidy after a saved eight-column edit', () {
      wallets = [WalletMock.createSingleSigWalletItem(id: 7)];
      final viewModel = create(widgetDefinitions: builtinHomeWidgets());
      addTearDown(viewModel.dispose);
      final preset = builtinHomePresets().firstWhere((preset) => preset.id == defaultPresetId);
      final recent = viewModel.configuration.items.singleWhere(
        (item) => item.definitionId == HomeItemIds.recentTransactions,
      );
      viewModel.moveToCell(recent.id, const HomeGridPosition(4, 8), columns: 8);
      final previous = viewModel.configuration;
      expect(previous.columns, 8);
      expect(repository.load(), previous);
      expect(previous.shortcutWalletContext, const ShortcutWalletContext.wallet(7));

      final preview = viewModel.previewOf(preset);
      void expectTidy(HomeConfiguration configuration) {
        final projected = HomeGridLayout(HomeGridLayout(configuration).reflow(8));
        expect(projected.rows, 4);
        expect(configuration.columns, 4);
        final positions = {
          for (final item in projected.positionedConfiguration.items) item.definitionId: item.position,
        };
        expect(positions[HomeItemIds.allWalletStack], const HomeGridPosition(0, 2));
        expect(positions[HomeItemIds.shortcut(FeatureIds.utxoOrganizer)], const HomeGridPosition(2, 3));
        expect(positions[HomeItemIds.recentTransactions], const HomeGridPosition(4, 2));
        expect(configuration.shortcutWalletContext, previous.shortcutWalletContext);
      }

      expectTidy(preview);
      expect(repository.load(), previous);
      expect(viewModel.configuration, previous);

      final undo = viewModel.applyPreset(preset);
      expect(undo, previous);
      expectTidy(viewModel.configuration);
      expect(viewModel.configuration, preview);
      expect(repository.load(), preview);
      viewModel.restore(undo);
      expect(viewModel.configuration, previous);
      expect(repository.load(), previous);
      expect(viewModel.configuration.shortcutWalletContext, const ShortcutWalletContext.wallet(7));
    });

    final preset = HomePreset(
      id: 'p',
      name: () => 'p',
      description: () => 'p',
      definitionIds: ['w_wide', 'not_registered', HomeItemIds.shortcut(FeatureIds.receive), 'w'],
    );

    test('applying replaces the home in order, skips unknown items, and can be undone', () async {
      await repository.save(HomeConfiguration(items: [_shortcut('a', FeatureIds.calculator, 0)]));
      final viewModel = create(presets: [preset]);
      final before = viewModel.configuration;

      final previous = viewModel.applyPreset(preset);

      expect(viewModel.currentPresetId, 'p');

      expect(previous, before);
      expect(viewModel.configuration.items.map((item) => item.definitionId), [
        'w_wide',
        HomeItemIds.shortcut(FeatureIds.receive),
        'w',
      ]);
      expect(viewModel.configuration.items.every((item) => item.position != null), isTrue);
      expect(repository.load(), viewModel.configuration);

      viewModel.restore(previous);
      expect(viewModel.configuration.items.map((item) => item.id), ['a']);
      expect(viewModel.currentPresetId, isNull);
    });

    test('shortcuts after a 2×2 widget fill the 2×2 space to its right', () async {
      await repository.save(HomeConfiguration(items: const []));
      final shortcuts = [FeatureIds.receive, FeatureIds.send, FeatureIds.calculator, FeatureIds.glossary];
      final filling = HomePreset(
        id: 'f',
        name: () => 'f',
        description: () => 'f',
        definitionIds: ['w', for (final id in shortcuts) HomeItemIds.shortcut(id), 'w_wide'],
      );
      final viewModel = create(presets: [filling]);

      final positions = {for (final item in viewModel.previewOf(filling).items) item.definitionId: item.position};

      expect(positions['w'], const HomeGridPosition(0, 0));
      expect(
        [for (final id in shortcuts) positions[HomeItemIds.shortcut(id)]],
        const [HomeGridPosition(2, 0), HomeGridPosition(3, 0), HomeGridPosition(2, 1), HomeGridPosition(3, 1)],
      );
      expect(positions['w_wide'], const HomeGridPosition(0, 2));
    });

    test('shrinking the first widget and growing it back keeps shortcuts beside the 2×2 widget below', () async {
      await repository.save(HomeConfiguration(items: const []));
      final shortcuts = [FeatureIds.receive, FeatureIds.send, FeatureIds.calculator, FeatureIds.glossary];
      final filling = HomePreset(
        id: 'f',
        name: () => 'f',
        description: () => 'f',
        spans: const {HomeItemIds.watchOnlyWalletStack: HomeSpan.wide},
        definitionIds: [
          HomeItemIds.watchOnlyWalletStack,
          'w',
          for (final id in shortcuts) HomeItemIds.shortcut(id),
          'w_wide',
        ],
      );
      final viewModel = create(presets: [filling]);
      viewModel.applyPreset(filling);
      Map<String, HomeGridPosition?> positions() => {
        for (final item in viewModel.configuration.items) item.definitionId: item.position,
      };
      final applied = positions();
      final stackId = viewModel.configuration.items.first.id;

      viewModel.resizeItem(stackId, HomeSpan.small);
      viewModel.resizeItem(stackId, HomeSpan.wide);

      expect(positions(), applied);
      expect(applied[HomeItemIds.shortcut(FeatureIds.receive)], const HomeGridPosition(2, 2));
      expect(applied['w_wide'], const HomeGridPosition(0, 4));
    });

    test('with one wallet, a preset with wallet shortcuts uses that wallet', () async {
      wallets = [WalletMock.createSingleSigWalletItem(id: 4)];
      await repository.save(HomeConfiguration(items: const []));
      final viewModel = create(presets: [preset]);

      viewModel.applyPreset(preset);

      expect(viewModel.shortcutWalletContext, const ShortcutWalletContext.wallet(4));
    });
  });

  group('no wallets', () {
    test('wallet shortcuts are dimmed and the add wallet hint shows until it is closed', () async {
      await repository.save(HomeConfiguration(items: const []));
      final walletList = ValueNotifier<List<WalletItemBase>>(const []);
      var saved = 0;
      final viewModel = HomeViewModel(
        repository: repository,
        wallets: () => walletList.value,
        onShortcutTap: (_, __) {},
        walletListChanges: walletList,
        onAddWalletHintDismissed: () => saved++,
      );
      addTearDown(viewModel.dispose);

      expect(viewModel.noWallets.value, isTrue);
      expect(viewModel.showsAddWalletHint, isTrue);

      viewModel.dismissAddWalletHint();
      expect(viewModel.showsAddWalletHint, isFalse);
      expect(saved, 1);

      viewModel.remindAddWallet();
      expect(viewModel.showsAddWalletHint, isTrue);
      expect(viewModel.addWalletHintNudges, 1);

      walletList.value = [WalletMock.createSingleSigWalletItem(id: 1)];
      expect(viewModel.noWallets.value, isFalse);
      expect(viewModel.showsAddWalletHint, isFalse);
    });

    test('the All Features hint waits for the add wallet hint and goes away for good once dismissed', () async {
      await repository.save(HomeConfiguration(items: const []));
      final walletList = ValueNotifier<List<WalletItemBase>>(const []);
      var saved = 0;
      final viewModel = HomeViewModel(
        repository: repository,
        wallets: () => walletList.value,
        onShortcutTap: (_, __) {},
        walletListChanges: walletList,
        onAllFeaturesHintDismissed: () => saved++,
      );
      addTearDown(viewModel.dispose);

      expect(viewModel.showsAddWalletHint, isTrue);
      expect(viewModel.showsAllFeaturesHint, isFalse);

      walletList.value = [WalletMock.createSingleSigWalletItem(id: 1)];
      expect(viewModel.showsAllFeaturesHint, isTrue);

      viewModel.dismissAllFeaturesHint();
      viewModel.dismissAllFeaturesHint();
      expect(viewModel.showsAllFeaturesHint, isFalse);
      expect(saved, 1);
    });

    test('a hint closed before stays closed on the next launch', () async {
      await repository.save(HomeConfiguration(items: const []));
      final viewModel = HomeViewModel(
        repository: repository,
        wallets: () => const [],
        onShortcutTap: (_, __) {},
        addWalletHintDismissed: true,
      );
      addTearDown(viewModel.dispose);

      expect(viewModel.showsAddWalletHint, isFalse);
    });
  });

  test('addable shortcuts leave out those on home and those not available now', () async {
    await repository.save(HomeConfiguration(items: [_shortcut('a', FeatureIds.receive, 0)]));
    final viewModel = HomeViewModel(
      repository: repository,
      wallets: () => wallets,
      onShortcutTap: (_, __) {},
      widgetDefinitions: [_Widget()],
      isFeatureAvailable: (feature) => feature.id != FeatureIds.glossary,
    );

    final ids = viewModel.addableShortcutDefinitions.map((definition) => definition.feature.id);

    expect(ids, isNot(contains(FeatureIds.receive)));
    expect(ids, isNot(contains(FeatureIds.glossary)));
    expect(ids, containsAll([FeatureIds.send, FeatureIds.mnemonicWordList, FeatureIds.myWallets]));
  });

  test('a wallet feature with no wallets goes to add wallet first', () {
    final viewModel = create();

    expect(viewModel.shouldAddWalletBeforeLaunch(viewModel.features.byId(FeatureIds.receive)!), isTrue);
    expect(viewModel.shouldAddWalletBeforeLaunch(viewModel.features.byId(FeatureIds.calculator)!), isFalse);

    wallets = [WalletMock.createSingleSigWalletItem(id: 1)];
    expect(viewModel.shouldAddWalletBeforeLaunch(viewModel.features.byId(FeatureIds.receive)!), isFalse);
  });

  group('arrangement undo', () {
    Future<HomeViewModel> editableHome() async {
      await repository.save(
        HomeConfiguration(
          items: [
            for (final (index, id) in ['a', 'b', 'c'].indexed)
              HomeItem(
                id: id,
                definitionId: 'widget-$id',
                kind: HomeItemKind.widget,
                order: index,
                span: HomeSpan.small,
              ),
          ],
        ),
      );
      final viewModel = create(
        widgetDefinitions: [
          for (final id in ['a', 'b', 'c']) _Widget(id: 'widget-$id', spans: [HomeSpan.small, HomeSpan.wide]),
        ],
      );
      addTearDown(viewModel.dispose);
      return viewModel;
    }

    test('finishing editing keeps a saved move and its explicit undo available', () async {
      final viewModel = await editableHome();
      final before = viewModel.configuration;
      expect(viewModel.canUndoArrangement, isFalse);
      viewModel.startArranging();
      viewModel.insertBefore('c', 'a');
      final moved = viewModel.configuration;
      expect(moved, isNot(before));
      expect(repository.load(), moved);

      viewModel.finishArranging();
      expect(viewModel.isArranging, isFalse);
      expect(viewModel.configuration, moved);
      expect(repository.load(), moved);
      expect(viewModel.canUndoArrangement, isTrue);

      viewModel.startArranging();
      viewModel.undoArrangement();
      expect(viewModel.configuration, before);
      expect(repository.load(), before);
      expect(viewModel.isArranging, isTrue);
      expect(viewModel.canUndoArrangement, isFalse);
    });

    test('undo restores only the latest completed move and persists it', () async {
      final viewModel = await editableHome();
      viewModel.insertBefore('c', 'a');
      final afterFirstDrop = viewModel.configuration;
      viewModel.moveToCell('a', const HomeGridPosition(2, 2));
      expect(viewModel.configuration, isNot(afterFirstDrop));
      expect(viewModel.canUndoArrangement, isTrue);

      viewModel.undoArrangement();
      expect(viewModel.configuration, afterFirstDrop);
      expect(repository.load(), afterFirstDrop);
      expect(viewModel.canUndoArrangement, isFalse);
      viewModel.undoArrangement();
      expect(viewModel.configuration, afterFirstDrop);
      expect(repository.load(), afterFirstDrop);
    });

    test('dropping back in the same cell does not erase the preceding move undo', () async {
      final viewModel = await editableHome();
      final before = viewModel.configuration;
      viewModel.insertBefore('c', 'a');
      final moved = viewModel.configuration;
      final currentCell = HomeGridLayout(moved).positionOf('c')!;
      viewModel.moveToCell('c', currentCell);
      viewModel.insertBefore('c', 'c');
      expect(viewModel.configuration, moved);
      expect(viewModel.canUndoArrangement, isTrue);

      viewModel.undoArrangement();
      expect(viewModel.configuration, before);
      expect(repository.load(), before);
    });

    for (final savedColumns in [4, 6, 8]) {
      test('projected no-op edits preserve canonical gaps and prior undo from $savedColumns columns', () async {
        final viewModel = await editableHome();
        final before = viewModel.configuration;
        viewModel.moveToCell('c', const HomeGridPosition(0, 8), columns: savedColumns);
        final moved = viewModel.configuration;
        final prefs = await SharedPreferences.getInstance();
        final stored = prefs.getString(HomeConfigurationRepository.key);
        var notifications = 0;
        viewModel.addListener(() => notifications++);
        for (final columns in [4, 6, 8, 10]) {
          final projected = HomeGridLayout(HomeGridLayout(moved).reflow(columns));
          viewModel.moveToCell('c', projected.positionOf('c')!, columns: columns);
          viewModel.moveToCell('c', const HomeGridPosition(-1, 0), columns: columns);
          viewModel.moveToCell('missing', const HomeGridPosition(0, 0), columns: columns);
          viewModel.insertBefore('c', 'c', columns: columns);
          viewModel.insertBefore('c', 'missing', columns: columns);
          viewModel.insertBefore('missing', 'c', columns: columns);
          expect(viewModel.configuration, moved);
          expect(prefs.getString(HomeConfigurationRepository.key), stored);
          expect(viewModel.canUndoArrangement, isTrue);
          expect(notifications, 0);
        }
        viewModel.undoArrangement();
        expect(viewModel.configuration, before);
        expect(repository.load(), before);
      });
    }

    final mutations = <String, void Function(HomeViewModel)>{
      'remove': (model) => model.removeItem('a'),
      'resize': (model) => model.resizeItem('a', HomeSpan.wide),
      'add': (model) => model.addItem(model.registry.byId('widget-a')!),
      'settings': (model) => model.updateItemConfiguration('a', {'unit': 'sats'}),
      'wallet context': (model) => model.updateShortcutWalletContext(const ShortcutWalletContext.wallet(9)),
      'preset':
          (model) => model.applyPreset(
            HomePreset(id: 'single', name: () => 'Single', description: () => '', definitionIds: ['widget-a']),
          ),
      'restore': (model) => model.restore(HomeConfiguration(items: const [])),
    };
    for (final mutation in mutations.entries) {
      test('${mutation.key} invalidates arrangement undo so later changes cannot be overwritten', () async {
        final viewModel = await editableHome();
        viewModel.insertBefore('c', 'a');
        expect(viewModel.canUndoArrangement, isTrue);
        mutation.value(viewModel);
        final updated = viewModel.configuration;

        expect(viewModel.canUndoArrangement, isFalse);
        viewModel.undoArrangement();
        expect(viewModel.configuration, updated);
        expect(repository.load(), updated);
      });
    }
  });

  group('resizing a widget', () {
    HomeItem widget(String id, String definitionId, int order, HomeGridPosition position) => HomeItem(
      id: id,
      definitionId: definitionId,
      kind: HomeItemKind.widget,
      order: order,
      span: HomeSpan.small,
      position: position,
    );

    Future<HomeViewModel> homeWith(List<HomeItem> items) async {
      await repository.save(HomeConfiguration(items: items));
      return create();
    }

    Map<String, HomeGridPosition?> positions(HomeViewModel viewModel) => {
      for (final item in viewModel.configuration.items) item.id: item.position,
    };

    test('growing the second 2×2 keeps four visible shortcuts together before the following 4×2', () async {
      final shortcuts = [FeatureIds.receive, FeatureIds.send, FeatureIds.calculator, FeatureIds.glossary];
      final viewModel = await homeWith([
        widget('first', 'w', 0, const HomeGridPosition(0, 0)),
        widget('stack', HomeItemIds.watchOnlyWalletStack, 1, const HomeGridPosition(2, 0)),
        for (var index = 0; index < 3; index++)
          _shortcut('shortcut-$index', shortcuts[index], index + 2).copyWith(position: HomeGridPosition(index, 2)),
        widget('wide', 'w_wide', 5, const HomeGridPosition(0, 3)).copyWith(span: HomeSpan.wide),
        _shortcut('shortcut-3', shortcuts[3], 6).copyWith(position: const HomeGridPosition(3, 2)),
      ]);

      final before = HomeGridLayout(viewModel.configuration);
      expect(before.positionOf('first'), const HomeGridPosition(0, 0));
      expect(before.positionOf('stack'), const HomeGridPosition(2, 0));
      for (var index = 0; index < 4; index++) {
        expect(before.positionOf('shortcut-$index'), HomeGridPosition(index, 2));
      }
      expect(before.positionOf('wide'), const HomeGridPosition(0, 3));

      viewModel.resizeItem('stack', HomeSpan.wide);

      final layout = HomeGridLayout(viewModel.configuration);
      expect(layout.positionOf('first'), const HomeGridPosition(0, 0));
      expect(layout.positionOf('stack'), const HomeGridPosition(0, 2));
      for (var index = 0; index < 4; index++) {
        expect(layout.positionOf('shortcut-$index'), HomeGridPosition(index, 4));
      }
      expect(layout.positionOf('wide'), const HomeGridPosition(0, 5));
      expect(viewModel.configuration.items.map((item) => item.id), [
        'first',
        'stack',
        'shortcut-0',
        'shortcut-1',
        'shortcut-2',
        'shortcut-3',
        'wide',
      ]);
    });

    test('growing keeps the order, leaves items before it alone and flows the rest after it', () async {
      final viewModel = await homeWith([
        widget('a', 'w', 0, const HomeGridPosition(0, 0)),
        widget('stack', HomeItemIds.watchOnlyWalletStack, 1, const HomeGridPosition(2, 0)),
        _shortcut('c', FeatureIds.receive, 2).copyWith(position: const HomeGridPosition(0, 2)),
      ]);

      viewModel.resizeItem('stack', HomeSpan.wide);

      final items = viewModel.configuration.items;
      expect(items.map((item) => item.id), ['a', 'stack', 'c']);
      expect(items[1].span, HomeSpan.wide);
      expect(positions(viewModel)['a'], const HomeGridPosition(0, 0));
      expect(positions(viewModel)['stack'], const HomeGridPosition(0, 2));
      expect(positions(viewModel)['c'], const HomeGridPosition(0, 4));
    });

    test('shrinking pulls the items after it up into the space it leaves', () async {
      final viewModel = await homeWith([
        widget(
          'stack',
          HomeItemIds.watchOnlyWalletStack,
          0,
          const HomeGridPosition(0, 0),
        ).copyWith(span: HomeSpan.wide),
        widget('b', 'w', 1, const HomeGridPosition(0, 2)),
        _shortcut('c', FeatureIds.receive, 2).copyWith(position: const HomeGridPosition(2, 2)),
      ]);

      viewModel.resizeItem('stack', HomeSpan.small);

      expect(viewModel.configuration.items.first.span, HomeSpan.small);
      expect(positions(viewModel)['stack'], const HomeGridPosition(0, 0));
      expect(positions(viewModel)['b'], const HomeGridPosition(2, 0));
      expect(positions(viewModel)['c'], const HomeGridPosition(0, 2));
    });

    test('growing then shrinking follows the same rule both ways and leaves earlier items alone', () async {
      final viewModel = await homeWith([
        widget('a', 'w', 0, const HomeGridPosition(0, 0)),
        widget('stack', HomeItemIds.watchOnlyWalletStack, 1, const HomeGridPosition(2, 0)),
        _shortcut('c', FeatureIds.receive, 2).copyWith(position: const HomeGridPosition(0, 2)),
      ]);

      viewModel.resizeItem('stack', HomeSpan.wide);
      viewModel.resizeItem('stack', HomeSpan.small);

      expect(positions(viewModel)['a'], const HomeGridPosition(0, 0));
      expect(positions(viewModel)['stack'], const HomeGridPosition(2, 0));
      expect(positions(viewModel)['c'], const HomeGridPosition(0, 2));
    });

    test('a size the widget does not support is ignored', () async {
      final viewModel = await homeWith([widget('a', 'w', 0, const HomeGridPosition(0, 0))]);
      final before = viewModel.configuration;
      viewModel.resizeItem('a', HomeSpan.wide);
      expect(viewModel.configuration, before);
    });
  });
}
