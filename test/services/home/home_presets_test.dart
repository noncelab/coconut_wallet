import 'package:coconut_wallet/model/home/home_configuration.dart';
import 'package:coconut_wallet/model/home/home_item.dart';
import 'package:coconut_wallet/model/home/home_item_definition.dart';
import 'package:coconut_wallet/model/home/home_item_ids.dart';
import 'package:coconut_wallet/services/feature/feature_registry.dart';
import 'package:coconut_wallet/services/home/builtin_home_widgets.dart';
import 'package:coconut_wallet/services/home/home_grid_layout.dart';
import 'package:coconut_wallet/services/home/home_item_registry.dart';
import 'package:coconut_wallet/services/home/home_presets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final registry = HomeItemRegistry();
  for (final definition in builtinHomeWidgets()) {
    registry.register(definition);
  }
  registry.registerShortcuts(FeatureRegistry.builtin());

  test('there are four presets with unique ids', () {
    final ids = builtinHomePresets().map((preset) => preset.id).toList();

    expect(ids, ['default', 'simple', 'hide_balances', 'statistics']);
  });

  test('every preset item is registered', () {
    for (final preset in builtinHomePresets()) {
      expect(preset.definitionIds.toSet(), hasLength(preset.definitionIds.length), reason: preset.id);
      for (final id in preset.definitionIds) {
        expect(registry.byId(id), isNotNull, reason: '${preset.id}: $id');
      }
    }
  });

  test('the default preset follows the design', () {
    final preset = builtinHomePresets().firstWhere((preset) => preset.id == 'default');

    expect(preset.spans[HomeItemIds.bitcoinBalanceTrend], HomeSpan.wide);
    expect(preset.spans[HomeItemIds.allWalletStack], HomeSpan.small);
    expect(preset.definitionIds, [
      HomeItemIds.bitcoinBalanceTrend,
      HomeItemIds.fiatPriceTrend,
      HomeItemIds.utxoStatus,
      HomeItemIds.allWalletStack,
      HomeItemIds.shortcut(FeatureIds.receive),
      HomeItemIds.shortcut(FeatureIds.send),
      HomeItemIds.shortcut(FeatureIds.utxoOrganizer),
      HomeItemIds.shortcut(FeatureIds.hodlInsights),
      HomeItemIds.recentTransactions,
    ]);
  });

  test('the statistics preset follows the design', () {
    final preset = builtinHomePresets().firstWhere((preset) => preset.id == 'statistics');

    expect(preset.spans[HomeItemIds.bitcoinBalanceTrend], HomeSpan.wide);
    expect(preset.definitionIds, [
      HomeItemIds.bitcoinBalanceTrend,
      HomeItemIds.balanceByWallet,
      HomeItemIds.savingsGoal,
      HomeItemIds.shortcut(FeatureIds.receive),
      HomeItemIds.shortcut(FeatureIds.send),
      HomeItemIds.shortcut(FeatureIds.utxoOrganizer),
      HomeItemIds.shortcut(FeatureIds.hodlInsights),
    ]);
  });

  test('hide balances has no balance widget and no 4×2 wallet stack, which would show balances', () {
    final preset = builtinHomePresets().firstWhere((preset) => preset.id == 'hide_balances');
    final widgets = [
      for (final id in preset.definitionIds) registry.byId(id)!,
    ].where((definition) => definition.kind == HomeItemKind.widget);

    expect(widgets.any((definition) => definition.category == HomeItemCategory.balance), isFalse);
    expect(
      widgets.any(
        (definition) =>
            definition.category == HomeItemCategory.wallets &&
            (preset.spans[definition.id] ?? definition.supportedSpans.first) == HomeSpan.wide,
      ),
      isFalse,
    );
    expect(preset.definitionIds, isNot(contains(HomeItemIds.balanceByWallet)));
  });

  test('each preset except the default fills about one phone screen: six rows', () {
    for (final preset in builtinHomePresets().where((preset) => preset.id != 'default')) {
      final items = [
        for (final (index, id) in preset.definitionIds.indexed)
          if (registry.byId(id) case final definition?)
            HomeItem(
              id: '$index',
              definitionId: id,
              kind: definition.kind,
              order: index,
              span: preset.spans[id] ?? definition.supportedSpans.first,
              position: index == 0 ? const HomeGridPosition(0, 0) : null,
            ),
      ];
      expect(HomeGridLayout(HomeConfiguration(items: items)).rows, 6, reason: preset.id);
    }
  });
}
