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
  final Listenable? _walletListChanges;
  final void Function()? _onAddWalletHintDismissed;
  late final ValueNotifier<bool> _noWallets = ValueNotifier(_wallets().isEmpty);
  bool _addWalletHintDismissed;
  final void Function()? _onAllFeaturesHintDismissed;
  bool _allFeaturesHintDismissed;
  bool _addWalletHintReminded = false;
  int _addWalletHintNudges = 0;

  HomeViewModel({
    required HomeConfigurationRepository repository,
    required List<WalletItemBase> Function() wallets,
    required ShortcutTap onShortcutTap,
    FeatureRegistry? features,
    List<HomeItemDefinition>? widgetDefinitions,
    List<HomePreset>? presets,
    bool Function(FeatureItem feature)? isFeatureAvailable,
    Listenable? walletListChanges,
    bool addWalletHintDismissed = false,
    void Function()? onAddWalletHintDismissed,
    bool allFeaturesHintDismissed = false,
    void Function()? onAllFeaturesHintDismissed,
  }) : _repository = repository,
       _allFeaturesHintDismissed = allFeaturesHintDismissed,
       _onAllFeaturesHintDismissed = onAllFeaturesHintDismissed,
       _walletListChanges = walletListChanges,
       _addWalletHintDismissed = addWalletHintDismissed,
       _onAddWalletHintDismissed = onAddWalletHintDismissed,
       _isFeatureAvailable = isFeatureAvailable ?? ((_) => true),
       _wallets = wallets,
       _presets = presets ?? builtinHomePresets(),
       features = features ?? FeatureRegistry.builtin() {
    registry = HomeItemRegistry();
    for (final definition in widgetDefinitions ?? builtinHomeWidgets()) {
      registry.register(definition);
    }
    registry.registerShortcuts(this.features, onTap: onShortcutTap, noWallets: _noWallets);
    _configuration = _load();
    _walletListChanges?.addListener(_onWalletListChanged);
  }

  /// 지갑이 하나도 없으면 true. 지갑이 필요한 바로가기를 흐리게 하고 지갑 추가 말풍선을 띄운다.
  ValueListenable<bool> get noWallets => _noWallets;

  /// 앱 바 지갑 추가 버튼의 말풍선. 지갑이 없고, 닫지 않았거나 흐린 바로가기를 눌러 다시 부른 경우에 보인다.
  bool get showsAddWalletHint => _noWallets.value && (!_addWalletHintDismissed || _addWalletHintReminded);

  /// 흐린 바로가기를 누를 때마다 늘어난다. 말풍선이 이 값이 바뀔 때 살짝 흔들린다.
  int get addWalletHintNudges => _addWalletHintNudges;

  void _onWalletListChanged() {
    final empty = _wallets().isEmpty;
    if (_noWallets.value == empty) return;
    _noWallets.value = empty;
    if (!empty) _addWalletHintReminded = false;
    notifyListeners();
  }

  void remindAddWallet() {
    _addWalletHintReminded = true;
    _addWalletHintNudges++;
    notifyListeners();
  }

  /// 홈을 옆으로 밀면 All Features가 나온다는 말풍선. 지갑 추가 말풍선이 떠 있지 않을 때, All Features를 한 번도 열지 않았으면 보인다.
  bool get showsAllFeaturesHint => !_allFeaturesHintDismissed && !showsAddWalletHint;

  void dismissAllFeaturesHint() {
    if (_allFeaturesHintDismissed) return;
    _allFeaturesHintDismissed = true;
    _onAllFeaturesHintDismissed?.call();
    notifyListeners();
  }

  void dismissAddWalletHint() {
    _addWalletHintReminded = false;
    if (!_addWalletHintDismissed) {
      _addWalletHintDismissed = true;
      _onAddWalletHintDismissed?.call();
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _walletListChanges?.removeListener(_onWalletListChanged);
    _noWallets.dispose();
    super.dispose();
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
    final cleaned = usable == null ? _firstInstallConfiguration() : _withoutUnregisteredShortcuts(usable);
    final positioned = HomeGridLayout(cleaned.normalize(registry.byId)).positionedConfiguration;
    if (positioned != saved) _repository.save(positioned);
    return positioned;
  }

  /// 처음 설치하면 기본 프리셋으로 시작한다. 기본 프리셋의 항목이 하나도 등록되지 않았으면 [defaultConfiguration]
  HomeConfiguration _firstInstallConfiguration() {
    final preset = _presets.where((preset) => preset.id == defaultPresetId).firstOrNull ?? _presets.firstOrNull;
    final configuration = preset == null ? null : _presetConfiguration(preset, HomeConfiguration(items: const []));
    return configuration == null || configuration.items.isEmpty ? defaultConfiguration() : configuration;
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

  ShortcutWalletContext? walletContextWithoutAsking() => _walletContextWithoutAsking(shortcutWalletContext);

  ShortcutWalletContext? _walletContextWithoutAsking(ShortcutWalletContext current) {
    final wallets = _wallets();
    if (wallets.isEmpty) return const ShortcutWalletContext.askEveryTime();
    if (wallets.length == 1) {
      return current.mode == ShortcutWalletMode.askEveryTime
          ? ShortcutWalletContext.wallet(wallets.single.id)
          : current;
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
  HomeConfiguration previewOf(HomePreset preset) => _presetConfiguration(preset, _configuration);

  HomeConfiguration _presetConfiguration(HomePreset preset, HomeConfiguration base) {
    final definitions = definitionsOf(preset);
    final needsWallet = definitions.any((definition) => definition.requiresWalletContext);
    return HomeGridLayout(
      HomeConfiguration(
        version: base.version,
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
                ? _walletContextWithoutAsking(base.shortcutWalletContext) ?? base.shortcutWalletContext
                : base.shortcutWalletContext,
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

  /// 위젯 크기를 바꾼다. 키우든 줄이든 앞 항목은 그대로 두고, 그 항목부터 뒤 항목을 순서대로 다시 채운다.
  /// 그래서 키우면 뒤 항목이 밀려나고, 줄이면 생긴 빈칸을 뒤 항목이 당겨 와 채운다.
  void resizeItem(String id, HomeSpan span) {
    final items = HomeGridLayout(_configuration).itemsInVisualOrder;
    final index = items.indexWhere((item) => item.id == id);
    if (index < 0) return;
    final item = items[index];
    final definition = registry.byId(item.definitionId);
    if (item.span == span || definition == null || !definition.supportedSpans.contains(span)) return;
    final before = _configuration;
    _apply(
      HomeConfiguration(
        version: before.version,
        items: [
          for (final (i, other) in items.indexed)
            if (i < index)
              other.copyWith(order: i)
            else
              HomeItem(
                id: other.id,
                definitionId: other.definitionId,
                kind: other.kind,
                order: i,
                span: i == index ? span : other.span,
                position: i == 0 && other.position != null ? HomeGridLayout.anchorForSpan(other.position!, span) : null,
                configuration: other.configuration,
              ),
        ],
        shortcutWalletContext: before.shortcutWalletContext,
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
