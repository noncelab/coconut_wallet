import 'package:coconut_design_system/coconut_design_system.dart' show CoconutTypography;
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/model/feature/feature_item.dart';
import 'package:coconut_wallet/services/feature/feature_registry.dart';
import 'package:coconut_wallet/model/home/home_item.dart';
import 'package:coconut_wallet/model/home/home_item_definition.dart';
import 'package:coconut_wallet/model/home/home_item_ids.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_svg/flutter_svg.dart';

typedef ShortcutTap = void Function(BuildContext context, FeatureItem feature);

class ShortcutDefinition extends HomeItemDefinition {
  final FeatureItem feature;
  final ShortcutTap? onTap;

  ShortcutDefinition(this.feature, {this.onTap})
    : super(
        id: HomeItemIds.shortcut(feature.id),
        kind: HomeItemKind.shortcut,
        supportedSpans: const [HomeSpan.shortcut],
        category: HomeItemCategory.shortcut,
        requiresWalletContext: feature.context == FeatureContext.wallet,
      );

  @override
  String displayName() => feature.label();

  @override
  Widget build(BuildContext context, HomeItem item) {
    final colors = context.coconutColors;
    final iconPath = feature.iconPath;
    return DecoratedBox(
      key: ValueKey('shortcut-background-${feature.id}'),
      decoration: BoxDecoration(color: colors.homeSurface, borderRadius: BorderRadius.circular(16)),
      child: SizedBox.expand(
        child: CupertinoButton(
          padding: const EdgeInsets.all(4),
          onPressed: onTap == null ? null : () => onTap!(context, feature),
          child:
              iconPath == null
                  ? FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      feature.shortcutLabel(),
                      textAlign: TextAlign.center,
                      style: CoconutTypography.body3_12.copyWith(color: colors.primaryText),
                    ),
                  )
                  : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SvgPicture.asset(
                        iconPath,
                        key: ValueKey('shortcut-icon-${feature.id}'),
                        width: 24 * feature.iconScale,
                        height: 24 * feature.iconScale,
                        colorFilter: ColorFilter.mode(colors.primaryText, BlendMode.srcIn),
                      ),
                      const SizedBox(height: 6),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          feature.shortcutLabel(),
                          textAlign: TextAlign.center,
                          style: CoconutTypography.body3_12.copyWith(color: colors.primaryText),
                        ),
                      ),
                    ],
                  ),
        ),
      ),
    );
  }
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

  void registerShortcuts(FeatureRegistry features, {ShortcutTap? onTap}) {
    for (final feature in features.shortcutEligible) {
      register(ShortcutDefinition(feature, onTap: onTap));
    }
  }
}
