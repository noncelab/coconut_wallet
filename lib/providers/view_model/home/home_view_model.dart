import 'package:collection/collection.dart';
import 'package:coconut_wallet/model/feature/feature_item.dart';
import 'package:coconut_wallet/model/home/home_configuration.dart';
import 'package:coconut_wallet/model/home/home_item.dart';
import 'package:coconut_wallet/model/home/home_item_definition.dart';
import 'package:coconut_wallet/model/home/home_item_ids.dart';
import 'package:coconut_wallet/model/home/home_preset.dart';
import 'package:coconut_wallet/model/home/shortcut_wallet_context.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/repository/shared_preference/home_configuration_repository.dart';
import 'package:coconut_wallet/services/feature/feature_registry.dart';
import 'package:coconut_wallet/services/home/home_grid_layout.dart';
import 'package:coconut_wallet/services/home/home_item_registry.dart';
import 'package:coconut_wallet/services/home/home_presets.dart';
import 'package:coconut_wallet/services/home/builtin_home_widgets.dart';
import 'package:flutter/foundation.dart';

class HomeViewModel extends ChangeNotifier {
  static const _legacyDummyWidgetId = 'dummy_widget';

  final HomeConfigurationRepository _repository;
  final List<WalletItemBase> Function() _wallets;
  final FeatureRegistry features;
  final List<HomePreset> _presets;
  final bool Function(FeatureItem feature) _isFeatureAvailable;
  late final HomeItemRegistry registry;
  late HomeConfiguration _configuration;

  HomeViewModel({
    required HomeConfigurationRepository repository,
    required List<WalletItemBase> Function() wallets,
    required ShortcutTap onShortcutTap,
    FeatureRegistry? features,
    List<HomeItemDefinition>? widgetDefinitions,
    List<HomePreset>? presets,
    bool Function(FeatureItem feature)? isFeatureAvailable,
  }) : _repository = repository,
       _isFeatureAvailable = isFeatureAvailable ?? ((_) => true),
       _wallets = wallets,
       _presets = presets ?? builtinHomePresets(),
       features = features ?? FeatureRegistry.builtin() {
    registry = HomeItemRegistry();
    for (final definition in widgetDefinitions ?? builtinHomeWidgets()) {
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

  List<(HomeItemCategory, List<HomeItemDefinition>)> get widgetSections => [
    for (final category in HomeItemCategory.values)
      if (widgetDefinitions.where((definition) => definition.category == category).toList() case final definitions
          when definitions.isNotEmpty)
        (category, definitions),
  ];

  List<ShortcutDefinition> get shortcutDefinitions => registry.all.whereType<ShortcutDefinition>().toList();

  /// 홈에 아직 없고 지금 쓸 수 있는 바로가기 (예: 용어집은 앱 언어가 한국어·일본어일 때만)
  List<ShortcutDefinition> get addableShortcutDefinitions =>
      shortcutDefinitions
          .where((definition) => !isOnHome(definition) && _isFeatureAvailable(definition.feature))
          .toList();

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

  void addItem(
    HomeItemDefinition definition, {
    ShortcutWalletContext? walletContext,
    Map<String, Object?> configuration = const {},
    HomeSpan? span,
  }) {
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
          span: span != null && definition.supportedSpans.contains(span) ? span : definition.supportedSpans.first,
          configuration: configuration,
        ),
      ),
    );
  }

  /// 설정 시트로 바꿀 수 있는 값 포함 여부
  /// 지갑이 필요한 바로가기는 공통 지갑을 바꿀 수 있다.
  bool canConfigure(HomeItemDefinition definition) =>
      definition is ShortcutDefinition ? definition.requiresWalletContext : !definition.settings.isEmpty;

  bool _isArranging = false;

  /// 홈 화면 편집 중(모든 항목이 흔들리고 끌어서 옮기거나 지울 수 있음)
  bool get isArranging => _isArranging;

  void startArranging() {
    if (_isArranging) return;
    _isArranging = true;
    notifyListeners();
  }

  void finishArranging() {
    if (!_isArranging) return;
    _isArranging = false;
    notifyListeners();
  }

  HomeItem? itemOf(HomeItemDefinition definition) =>
      _configuration.items.firstWhereOrNull((item) => item.definitionId == definition.id);

  void updateItemConfiguration(String id, Map<String, Object?> configuration) {
    _apply(
      HomeConfiguration(
        version: _configuration.version,
        items: [
          for (final item in _configuration.items) item.id == id ? item.copyWith(configuration: configuration) : item,
        ],
        shortcutWalletContext: _configuration.shortcutWalletContext,
      ),
    );
  }

  void updateShortcutWalletContext(ShortcutWalletContext walletContext) {
    _apply(
      HomeConfiguration(
        version: _configuration.version,
        items: _configuration.items,
        shortcutWalletContext: walletContext,
      ),
    );
  }

  List<HomePreset> get presets => _presets;

  List<HomeItemDefinition> definitionsOf(HomePreset preset) =>
      preset.definitionIds.map(registry.byId).whereType<HomeItemDefinition>().toList();

  /// 프리셋을 적용했을 때의 홈 구성(저장 x)
  HomeConfiguration previewOf(HomePreset preset) {
    final definitions = definitionsOf(preset);
    final needsWallet = definitions.any((definition) => definition.requiresWalletContext);
    return HomeGridLayout(
      HomeConfiguration(
        version: _configuration.version,
        items: [
          for (final (index, definition) in definitions.indexed)
            HomeItem(
              id: 'preset-${preset.id}-$index',
              definitionId: definition.id,
              kind: definition.kind,
              order: index,
              span: preset.spans[definition.id] ?? definition.supportedSpans.first,
              position: index == 0 ? const HomeGridPosition(0, 0) : null,
            ),
        ],
        shortcutWalletContext:
            needsWallet
                ? walletContextWithoutAsking() ?? _configuration.shortcutWalletContext
                : _configuration.shortcutWalletContext,
      ),
    ).positionedConfiguration;
  }

  /// 홈 구성을 프리셋으로 바꾸고, 되돌릴 수 있게 바꾸기 전 구성을 돌려준다.
  HomeConfiguration applyPreset(HomePreset preset) {
    final previous = _configuration;
    _apply(previewOf(preset));
    return previous;
  }

  void restore(HomeConfiguration configuration) => _apply(configuration);

  final Map<String, ({HomeConfiguration before, HomeConfiguration after})> _resizeHistory = {};

  /// 위젯 크기를 바꾼다. 키울 때는 그 항목부터 뒤 항목을 순서대로 다시 채우고 앞 항목은 그대로 둔다.
  /// 키운 뒤 다른 편집 없이 다시 줄이면 키우기 전 배치로 되돌린다.
  void resizeItem(String id, HomeSpan span) {
    final items = _configuration.items;
    final index = items.indexWhere((item) => item.id == id);
    if (index < 0) return;
    final item = items[index];
    final definition = registry.byId(item.definitionId);
    if (item.span == span || definition == null || !definition.supportedSpans.contains(span)) return;
    final history = _resizeHistory.remove(id);
    if (history != null && history.after == _configuration) {
      _apply(history.before);
      return;
    }
    final growing = span.width * span.height > item.span.width * item.span.height;
    final before = _configuration;
    _apply(
      HomeConfiguration(
        version: before.version,
        items: [
          for (final (i, other) in items.indexed)
            if (i < index || (!growing && i > index))
              other
            else
              HomeItem(
                id: other.id,
                definitionId: other.definitionId,
                kind: other.kind,
                order: other.order,
                span: i == index ? span : other.span,
                position:
                    (!growing || i == index) && other.position != null
                        ? HomeGridLayout.anchorForSpan(other.position!, span)
                        : null,
                configuration: other.configuration,
              ),
        ],
        shortcutWalletContext: before.shortcutWalletContext,
      ),
    );
    if (growing) _resizeHistory[id] = (before: before, after: _configuration);
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
