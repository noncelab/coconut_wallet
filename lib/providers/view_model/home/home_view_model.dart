import 'package:coconut_wallet/model/feature/feature_item.dart';
import 'package:coconut_wallet/model/home/home_configuration.dart';
import 'package:coconut_wallet/model/home/home_item.dart';
import 'package:coconut_wallet/model/home/home_item_definition.dart';
import 'package:coconut_wallet/model/home/home_item_ids.dart';
import 'package:coconut_wallet/model/home/shortcut_wallet_context.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/repository/shared_preference/home_configuration_repository.dart';
import 'package:coconut_wallet/services/feature/feature_registry.dart';
import 'package:coconut_wallet/services/home/home_grid_layout.dart';
import 'package:coconut_wallet/services/home/home_item_registry.dart';
import 'package:coconut_wallet/services/home/watch_only_wallet_stack_definition.dart';
import 'package:flutter/foundation.dart';

class HomeViewModel extends ChangeNotifier {
  static const _legacyDummyWidgetId = 'dummy_widget';

  final HomeConfigurationRepository _repository;
  final List<WalletItemBase> Function() _wallets;
  final FeatureRegistry features;
  late final HomeItemRegistry registry;
  late HomeConfiguration _configuration;

  HomeViewModel({
    required HomeConfigurationRepository repository,
    required List<WalletItemBase> Function() wallets,
    required ShortcutTap onShortcutTap,
    FeatureRegistry? features,
    List<HomeItemDefinition>? widgetDefinitions,
  }) : _repository = repository,
       _wallets = wallets,
       features = features ?? FeatureRegistry.builtin() {
    registry = HomeItemRegistry();
    for (final definition in widgetDefinitions ?? [WatchOnlyWalletStackDefinition()]) {
      registry.register(definition);
    }
    registry.registerShortcuts(this.features, onTap: onShortcutTap);
    _configuration = _load();
  }

  HomeConfiguration get configuration => _configuration;

  ShortcutWalletContext get shortcutWalletContext => _configuration.shortcutWalletContext;

  static HomeConfiguration defaultConfiguration() {
    return HomeConfiguration(
      items: [
        const HomeItem(
          id: 'watch-only-wallet-stack',
          definitionId: HomeItemIds.watchOnlyWalletStack,
          kind: HomeItemKind.widget,
          order: 0,
          span: HomeSpan.small,
        ),
        HomeItem(
          id: 'shortcut-calculator',
          definitionId: HomeItemIds.shortcut(FeatureIds.calculator),
          kind: HomeItemKind.shortcut,
          order: 1,
          span: HomeSpan.shortcut,
        ),
      ],
    );
  }

  HomeConfiguration _load() {
    final saved = _repository.load();
    final usable = saved == null || saved.items.any((item) => item.definitionId == _legacyDummyWidgetId) ? null : saved;
    final cleaned = usable == null ? defaultConfiguration() : _withoutUnregisteredShortcuts(usable);
    final positioned = HomeGridLayout(cleaned.normalize(registry.byId)).positionedConfiguration;
    if (positioned != saved) _repository.save(positioned);
    return positioned;
  }

  HomeConfiguration _withoutUnregisteredShortcuts(HomeConfiguration configuration) {
    var result = configuration;
    for (final item in configuration.items) {
      if (item.kind == HomeItemKind.shortcut && registry.byId(item.definitionId) == null) {
        result = result.removeItem(item.id);
      }
    }
    return result;
  }

  HomeConfiguration _apply(HomeConfiguration next) {
    _configuration = HomeGridLayout(next).positionedConfiguration;
    _repository.save(_configuration);
    notifyListeners();
    return _configuration;
  }

  void moveToCell(String id, HomeGridPosition position) =>
      _apply(HomeGridLayout(_configuration).moveToCell(id, position));

  void insertBefore(String id, String beforeId) => _apply(HomeGridLayout(_configuration).moveBefore(id, beforeId));

  void removeItem(String id) => _apply(_configuration.removeItem(id));

  bool isOnHome(HomeItemDefinition definition) =>
      _configuration.items.any((item) => item.definitionId == definition.id);

  List<HomeItemDefinition> get widgetDefinitions =>
      registry.all.where((definition) => definition.kind == HomeItemKind.widget).toList();

  List<ShortcutDefinition> get shortcutDefinitions => registry.all.whereType<ShortcutDefinition>().toList();

  List<ShortcutDefinition> get shortcutsOnHome => [
    for (final item in _configuration.items)
      if (item.kind == HomeItemKind.shortcut)
        if (registry.byId(item.definitionId) case final ShortcutDefinition definition) definition,
  ];

  List<WalletItemBase> get wallets => _wallets();

  bool get hasWalletShortcutsOnHome =>
      _configuration.items.any((item) => registry.byId(item.definitionId)?.requiresWalletContext ?? false);

  ShortcutWalletContext? walletContextWithoutAsking() {
    final wallets = _wallets();
    if (wallets.isEmpty) return const ShortcutWalletContext.askEveryTime();
    if (wallets.length == 1) {
      return shortcutWalletContext.mode == ShortcutWalletMode.askEveryTime
          ? ShortcutWalletContext.wallet(wallets.single.id)
          : shortcutWalletContext;
    }
    return null;
  }

  void addItem(HomeItemDefinition definition, {ShortcutWalletContext? walletContext}) {
    final base =
        walletContext == null
            ? _configuration
            : HomeConfiguration(
              version: _configuration.version,
              items: _configuration.items,
              shortcutWalletContext: walletContext,
            );
    _apply(
      base.addItem(
        HomeItem(
          id: 'item-${DateTime.now().microsecondsSinceEpoch}',
          definitionId: definition.id,
          kind: definition.kind,
          order: 0,
          span: definition.supportedSpans.first,
        ),
      ),
    );
  }

  void removeDefinition(HomeItemDefinition definition) {
    var next = _configuration;
    for (final item in _configuration.items.where((item) => item.definitionId == definition.id)) {
      next = next.removeItem(item.id);
    }
    _apply(next);
  }

  bool shouldAddWalletBeforeLaunch(FeatureItem feature) =>
      feature.context == FeatureContext.wallet && _wallets().isEmpty;
}
