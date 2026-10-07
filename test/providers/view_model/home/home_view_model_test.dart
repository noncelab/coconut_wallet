import 'package:coconut_wallet/model/home/home_configuration.dart';
import 'package:coconut_wallet/model/home/home_item.dart';
import 'package:coconut_wallet/model/home/home_item_definition.dart';
import 'package:coconut_wallet/model/home/home_item_ids.dart';
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
  _Widget() : super(id: 'w', kind: HomeItemKind.widget, supportedSpans: const [HomeSpan.small], category: 't');

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

  HomeViewModel create() => HomeViewModel(
    repository: repository,
    wallets: () => wallets,
    onShortcutTap: (_, __) {},
    widgetDefinitions: [_Widget()],
  );

  group('loading', () {
    test('with nothing saved the default configuration is used and saved', () {
      final viewModel = create();

      final ids = viewModel.configuration.items.map((item) => item.definitionId);
      expect(ids, [HomeItemIds.watchOnlyWalletStack, HomeItemIds.shortcut(FeatureIds.calculator)]);
      expect(repository.load(), viewModel.configuration);
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

      expect(ids, contains(HomeItemIds.watchOnlyWalletStack));
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

    test('adding a shortcut with a wallet context changes the shared wallet', () async {
      await repository.save(HomeConfiguration(items: const []));
      final viewModel = create();

      viewModel.addItem(
        viewModel.registry.byId(HomeItemIds.shortcut(FeatureIds.receive))!,
        walletContext: const ShortcutWalletContext.wallet(3),
      );

      expect(viewModel.shortcutWalletContext, const ShortcutWalletContext.wallet(3));
      expect(viewModel.hasWalletShortcutsOnHome, isTrue);
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

  test('a wallet feature with no wallets goes to add wallet first', () {
    final viewModel = create();

    expect(viewModel.shouldAddWalletBeforeLaunch(viewModel.features.byId(FeatureIds.receive)!), isTrue);
    expect(viewModel.shouldAddWalletBeforeLaunch(viewModel.features.byId(FeatureIds.calculator)!), isFalse);

    wallets = [WalletMock.createSingleSigWalletItem(id: 1)];
    expect(viewModel.shouldAddWalletBeforeLaunch(viewModel.features.byId(FeatureIds.receive)!), isFalse);
  });
}
