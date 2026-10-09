import 'package:coconut_wallet/model/feature/feature_item.dart';
import 'package:coconut_wallet/providers/view_model/home/all_features_view_model.dart';
import 'package:coconut_wallet/services/feature/feature_registry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final registry = FeatureRegistry([
    FeatureItem(id: 'send', label: () => '보내기', category: FeatureCategory.transactions),
    FeatureItem(id: 'wallets', label: () => '내 지갑', category: FeatureCategory.wallet),
    FeatureItem(id: 'glossary', label: () => '용어집', category: FeatureCategory.tools),
    FeatureItem(id: 'settings', label: () => '앱 설정', category: FeatureCategory.settings),
    FeatureItem(id: 'settings.fiat', label: () => '통화', keywords: ['통화', 'KRW'], parentId: 'settings'),
    FeatureItem(id: 'store', label: () => '추가 기능', source: FeatureSource.ccos),
  ]);

  test('without a query, features are grouped in category order and added features come last', () {
    final viewModel = AllFeaturesViewModel(registry: registry);
    expect(viewModel.isSearching, isFalse);
    expect(viewModel.sections.map((section) => section.$1), [
      FeatureCategory.wallet,
      FeatureCategory.transactions,
      FeatureCategory.tools,
      FeatureCategory.settings,
      null,
    ]);
    expect(
      viewModel.sections.expand((section) => section.$2).map((entry) => entry.item.id),
      isNot(contains('settings.fiat')),
    );
  });

  test('unavailable features are hidden from both the list and the results', () {
    final viewModel = AllFeaturesViewModel(registry: registry, isAvailable: (feature) => feature.id != 'glossary');
    expect(viewModel.sections.map((section) => section.$1), isNot(contains(FeatureCategory.tools)));
    viewModel.search('용어');
    expect(viewModel.results, isEmpty);
  });

  test('a query finds a sub feature through its top feature and keeps the path', () {
    final viewModel = AllFeaturesViewModel(registry: registry);
    var notified = 0;
    viewModel.addListener(() => notified++);
    viewModel.search('krw');
    expect(notified, 1);
    expect(viewModel.isSearching, isTrue);
    final result = viewModel.results.single;
    expect(result.item.id, 'settings');
    expect(result.path, ['앱 설정', '통화']);

    viewModel.search('보내');
    expect(viewModel.results.single.path, isEmpty);
  });

  test('every built-in top feature has a category except the open store, which leads the added features', () {
    for (final feature in FeatureRegistry.builtin().topLevel.where((item) => item.source == FeatureSource.builtin)) {
      expect(feature.category == null, feature.id == FeatureIds.openStore, reason: feature.id);
    }
    final sections = AllFeaturesViewModel(registry: FeatureRegistry.builtin()).sections;
    expect(sections.last.$1, isNull);
    expect(sections.last.$2.first.item.id, FeatureIds.openStore);
  });

  test('wallet features follow the All Features order', () {
    final viewModel = AllFeaturesViewModel(registry: FeatureRegistry.builtin());
    final wallet = viewModel.sections.firstWhere((section) => section.$1 == FeatureCategory.wallet).$2;
    expect(wallet.map((entry) => entry.item.id), [
      FeatureIds.myWallets,
      FeatureIds.walletDetail,
      FeatureIds.addresses,
      FeatureIds.walletAddWatchOnly,
      FeatureIds.walletAddHot,
    ]);
  });

  test('recently opened features come first, count a sub-feature as its parent, and are saved', () {
    final saved = <List<String>>[];
    final viewModel = AllFeaturesViewModel(
      registry: registry,
      isAvailable: (feature) => feature.id != 'glossary',
      recentIds: const ['wallets', 'glossary', 'unknown'],
      saveRecentIds: saved.add,
    );
    expect(viewModel.recent.map((feature) => feature.id), ['wallets']);

    viewModel.recordLaunch(registry.byId('send')!);
    viewModel.recordLaunch(registry.byId('settings.fiat')!);
    viewModel.recordLaunch(registry.byId('wallets')!);

    expect(viewModel.recent.map((feature) => feature.id), ['wallets', 'settings', 'send']);
    expect(saved.last.take(3), ['wallets', 'settings', 'send']);
  });

  test('at most four recent features are shown', () {
    final viewModel = AllFeaturesViewModel(
      registry: registry,
      recentIds: const ['send', 'wallets', 'glossary', 'settings', 'store'],
    );
    expect(viewModel.recent, hasLength(AllFeaturesViewModel.recentLimit));
  });

  test('an extra feature appears in the list and can be restored from recent IDs', () {
    final fakeBalance = FeatureItem(
      id: AllFeaturesViewModel.fakeBalanceRecentId,
      label: () => 'Fake Balance',
      category: FeatureCategory.settings,
    );
    final viewModel = AllFeaturesViewModel(
      registry: registry,
      recentIds: const [AllFeaturesViewModel.fakeBalanceRecentId, 'send'],
      extraFeature: fakeBalance,
    );

    expect(
      viewModel.sections
          .firstWhere((section) => section.$1 == FeatureCategory.settings)
          .$2
          .map((entry) => entry.item.id),
      contains(AllFeaturesViewModel.fakeBalanceRecentId),
    );
    expect(viewModel.recent.map((feature) => feature.id), [AllFeaturesViewModel.fakeBalanceRecentId, 'send']);
  });
}
