import 'package:flutter/foundation.dart';
import 'package:coconut_wallet/ccos/ccos_feature_registry.dart';
import 'package:coconut_wallet/model/feature/feature_item.dart';
import 'package:coconut_wallet/services/feature/feature_registry.dart';
import 'package:coconut_wallet/model/home/home_item.dart';
import 'package:coconut_wallet/model/home/home_item_definition.dart';
import 'package:coconut_wallet/model/home/home_item_ids.dart';
import 'package:flutter/cupertino.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/home_shortcut_tile.dart';

typedef ShortcutTap = void Function(BuildContext context, FeatureItem feature);

class ShortcutDefinition extends HomeItemDefinition {
  final FeatureItem feature;
  final ShortcutTap? onTap;

  /// 지갑이 없으면 true. 지갑이 필요한 바로가기는 이때 흐리게 보인다(눌림은 [onTap]이 처리한다).
  final ValueListenable<bool>? noWallets;

  ShortcutDefinition(this.feature, {this.onTap, this.noWallets})
    : super(
        id: HomeItemIds.shortcut(feature.id),
        kind: HomeItemKind.shortcut,
        supportedSpans: const [HomeSpan.shortcut],
        category: HomeItemCategory.shortcut,
        requiresWalletContext: feature.context == FeatureContext.wallet,
        ccosFeatureId: feature.ccosFeatureId,
      );

  @override
  String displayName() => feature.label();

  @override
  Widget build(BuildContext context, HomeItem item) {
    final noWallets = this.noWallets;
    if (noWallets == null || !requiresWalletContext) return _build(context);
    return ValueListenableBuilder<bool>(
      valueListenable: noWallets,
      builder:
          (context, disabled, child) => Opacity(
            key: ValueKey('shortcut-${feature.id}-${disabled ? 'disabled' : 'enabled'}'),
            opacity: disabled ? 0.35 : 1,
            child: child,
          ),
      child: _build(context),
    );
  }

  Widget _build(BuildContext context) => HomeShortcutTile(
    id: feature.id,
    label: feature.shortcutLabel(),
    iconPath: feature.iconPath,
    iconScale: feature.iconScale,
    onPressed: onTap == null ? null : () => onTap!(context, feature),
  );
}

class HomeItemRegistry {
  final Map<String, HomeItemDefinition> _definitions = {};

  List<HomeItemDefinition> get all => List.unmodifiable(_definitions.values);

  HomeItemDefinition? byId(String id) => _definitions[id];

  void register(HomeItemDefinition definition) {
    if (_definitions.containsKey(definition.id)) {
      throw StateError('Home item definition already registered: ${definition.id}');
    }
    _definitions[definition.id] = definition;
  }

  void registerShortcuts(FeatureRegistry features, {ShortcutTap? onTap, ValueListenable<bool>? noWallets}) {
    for (final feature in features.shortcutEligible) {
      register(ShortcutDefinition(feature, onTap: onTap, noWallets: noWallets));
    }
  }

  void registerCcosEntries(List<CcosFeatureListing> listings, {ShortcutTap? onTap}) {
    for (final listing in listings) {
      if (listing.homeShortcut case final shortcut?) {
        register(
          ShortcutDefinition(
            FeatureItem(
              id: shortcut.id,
              label: shortcut.label,
              iconPath: shortcut.iconPath,
              iconScale: shortcut.iconScale,
              shortcutEligible: true,
              source: FeatureSource.ccos,
              ccosFeatureId: listing.id,
              launch: (context, _) async => shortcut.launch(context),
            ),
            onTap: onTap,
          ),
        );
      }
      if (listing.homeWidget case final widget?) {
        final definition = widget.definition();
        if (definition.ccosFeatureId != listing.id) {
          throw StateError('Home widget ${definition.id} must set ccosFeatureId to ${listing.id}');
        }
        register(definition);
      }
    }
  }
}
