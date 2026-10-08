import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/home/home_item.dart';
import 'package:coconut_wallet/model/home/home_item_ids.dart';
import 'package:coconut_wallet/model/home/home_preset.dart';
import 'package:coconut_wallet/services/feature/feature_registry.dart';

/// Safety Check 기능은 Epic 3에서 등록된다. 등록 전에는 프리셋 적용 때 건너뛴다.
const safetyCheckFeatureId = 'safety_check';

List<HomePreset> builtinHomePresets() => [
  HomePreset(
    id: 'default',
    name: () => t.home_presets.default_name,
    description: () => t.home_presets.default_description,
    spans: const {HomeItemIds.bitcoinBalanceTrend: HomeSpan.wide, HomeItemIds.allWalletStack: HomeSpan.small},
    definitionIds: [
      HomeItemIds.bitcoinBalanceTrend,
      HomeItemIds.fiatPriceTrend,
      HomeItemIds.utxoStatus,
      HomeItemIds.allWalletStack,
      HomeItemIds.shortcut(FeatureIds.receive),
      HomeItemIds.shortcut(FeatureIds.send),
      HomeItemIds.shortcut(FeatureIds.utxoOrganizer),
      HomeItemIds.shortcut(FeatureIds.hodlInsights),
      HomeItemIds.recentTransactions,
    ],
  ),
  HomePreset(
    id: 'simple',
    name: () => t.home_presets.simple_name,
    description: () => t.home_presets.simple_description,
    spans: const {HomeItemIds.allWalletStack: HomeSpan.wide},
    definitionIds: [
      HomeItemIds.allWalletStack,
      HomeItemIds.shortcut(FeatureIds.receive),
      HomeItemIds.shortcut(FeatureIds.send),
      HomeItemIds.shortcut(FeatureIds.utxoOrganizer),
      HomeItemIds.shortcut(FeatureIds.utxoOverview),
      HomeItemIds.shortcut(FeatureIds.addresses),
      HomeItemIds.shortcut(FeatureIds.transactionDraft),
      HomeItemIds.shortcut(FeatureIds.labelManagement),
      HomeItemIds.shortcut(FeatureIds.calculator),
      HomeItemIds.recentTransactions,
    ],
  ),
  HomePreset(
    id: 'hide_balances',
    name: () => t.home_presets.hide_balances_name,
    description: () => t.home_presets.hide_balances_description,
    spans: const {HomeItemIds.watchOnlyWalletStack: HomeSpan.small, HomeItemIds.hotWalletStack: HomeSpan.small},
    definitionIds: [
      HomeItemIds.watchOnlyWalletStack,
      HomeItemIds.hotWalletStack,
      HomeItemIds.transactionActivity,
      HomeItemIds.utxoStatus,
      HomeItemIds.shortcut(FeatureIds.receive),
      HomeItemIds.shortcut(FeatureIds.send),
      HomeItemIds.shortcut(FeatureIds.utxoOrganizer),
      HomeItemIds.shortcut(FeatureIds.utxoOverview),
    ],
  ),
  // Epic 3에서 안전 위젯이 완성되면 다시 켠다.
  // HomePreset(
  //   id: 'safety',
  //   name: () => t.home_presets.safety_name,
  //   description: () => t.home_presets.safety_description,
  //   spans: const {HomeItemIds.watchOnlyWalletStack: HomeSpan.small, HomeItemIds.hotWalletStack: HomeSpan.small},
  //   definitionIds: [
  //     HomeItemIds.safetyStatusWide,
  //     HomeItemIds.watchOnlyWalletStack,
  //     HomeItemIds.hotWalletStack,
  //     HomeItemIds.shortcut(safetyCheckFeatureId),
  //     HomeItemIds.shortcut(FeatureIds.mnemonicWordList),
  //     HomeItemIds.shortcut(FeatureIds.addresses),
  //     HomeItemIds.shortcut(FeatureIds.glossary),
  //     HomeItemIds.shortcut(FeatureIds.receive),
  //     HomeItemIds.shortcut(FeatureIds.send),
  //     HomeItemIds.shortcut(FeatureIds.utxoOrganizer),
  //     HomeItemIds.shortcut(FeatureIds.utxoOverview),
  //   ],
  // ),
  HomePreset(
    id: 'statistics',
    name: () => t.home_presets.statistics_name,
    description: () => t.home_presets.statistics_description,
    spans: const {HomeItemIds.bitcoinBalanceTrend: HomeSpan.wide},
    definitionIds: [
      HomeItemIds.bitcoinBalanceTrend,
      HomeItemIds.balanceByWallet,
      HomeItemIds.savingsGoal,
      HomeItemIds.shortcut(FeatureIds.receive),
      HomeItemIds.shortcut(FeatureIds.send),
      HomeItemIds.shortcut(FeatureIds.utxoOrganizer),
      HomeItemIds.shortcut(FeatureIds.hodlInsights),
    ],
  ),
];
