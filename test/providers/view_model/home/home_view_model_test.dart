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

  HomeViewModel create({List<HomePreset>? presets}) => HomeViewModel(
    presets: presets,
    repository: repository,
    wallets: () => wallets,
    onShortcutTap: (_, __) {},
    widgetDefinitions: [
      _Widget(),
      _Widget(id: 'w_wide', span: HomeSpan.wide),
      _Widget(id: HomeItemIds.watchOnlyWalletStack, spans: [HomeSpan.small, HomeSpan.wide]),
    ],
  );

  group('loading', () {
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
