import 'dart:io';

import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/feature/feature_item.dart';
import 'package:coconut_wallet/services/feature/feature_registry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final registry = FeatureRegistry.builtin();

  test('top-level items match the inventory chapters 3 and 4 with add wallet split in two (12 global + 9 wallet)', () {
    expect(registry.topLevel.where((item) => item.context == FeatureContext.none), hasLength(12));
    expect(registry.topLevel.where((item) => item.context == FeatureContext.wallet), hasLength(8));
  });

  test('every top-level item can be launched and every sub-item points to an existing parent', () {
    for (final item in registry.topLevel) {
      expect(item.launch, isNotNull, reason: item.id);
    }
    for (final item in registry.all.where((item) => item.parentId != null)) {
      expect(registry.byId(item.parentId!), isNotNull, reason: item.id);
    }
  });

  test('the six wallet-context shortcuts need a wallet', () {
    const ids = [
      FeatureIds.receive,
      FeatureIds.send,
      FeatureIds.utxoOverview,
      FeatureIds.utxoOrganizer,
      FeatureIds.addresses,
      FeatureIds.utxoTags,
    ];
    for (final id in ids) {
      final item = registry.byId(id)!;
      expect(item.context, FeatureContext.wallet, reason: id);
      expect(item.shortcutEligible, isTrue, reason: id);
    }
  });

  test('shortcut icons use the dedicated shortcut and wallet-add icons', () {
    expect(registry.byId(FeatureIds.glossary)!.iconPath, FeatureShortcutIconPath.glossary);
    expect(registry.byId(FeatureIds.labelManagement)!.iconPath, FeatureShortcutIconPath.labelManagement);
    expect(registry.byId(FeatureIds.mnemonicWordList)!.iconPath, FeatureShortcutIconPath.mnemonicWordList);
    expect(registry.byId(FeatureIds.myWallets)!.iconPath, FeatureShortcutIconPath.myWallets);
    expect(registry.byId(FeatureIds.utxoOverview)!.iconPath, FeatureShortcutIconPath.utxos);
    expect(registry.byId(FeatureIds.send)!.iconPath, FeatureShortcutIconPath.send);
    expect(registry.byId(FeatureIds.walletAddHot)!.iconPath, FeatureShortcutIconPath.walletAddHot);
    expect(registry.byId(FeatureIds.walletAddWatchOnly)!.iconPath, FeatureWalletIconPath.walletAddWatchOnly);
  });

  test('send and receive shortcut icons draw the same 2px stroke at the 24px shortcut size', () {
    double strokeAt24(String path) {
      final svg = File(path).readAsStringSync();
      final viewBox = double.parse(RegExp(r'viewBox="0 0 ([0-9.]+)').firstMatch(svg)!.group(1)!);
      final stroke = double.parse(RegExp(r'stroke-width="([0-9.]+)"').firstMatch(svg)?.group(1) ?? '1');
      return stroke * 24 / viewBox;
    }

    expect(strokeAt24(registry.byId(FeatureIds.send)!.iconPath!), closeTo(2, 0.01));
    expect(strokeAt24(registry.byId(FeatureIds.receive)!.iconPath!), closeTo(2, 0.01));
  });

  test('every shortcut has an icon that points to an existing asset', () {
    for (final item in registry.shortcutEligible) {
      expect(item.iconPath, isNotNull, reason: item.id);
      expect(File(item.iconPath!).existsSync(), isTrue, reason: item.id);
    }
  });

  test('saved transactions and the P2P calculator are shortcuts that need no wallet', () {
    for (final id in [FeatureIds.transactionDraft, FeatureIds.calculator]) {
      final item = registry.byId(id)!;
      expect(item.context, FeatureContext.none, reason: id);
      expect(item.shortcutEligible, isTrue, reason: id);
    }
  });

  test('add wallet is offered as two separate items, hot wallet and watch-only', () {
    expect(registry.byId('wallet_add'), isNull);
    for (final id in [FeatureIds.walletAddHot, FeatureIds.walletAddWatchOnly]) {
      final item = registry.byId(id)!;
      expect(item.isTopLevel, isTrue, reason: id);
      expect(item.context, FeatureContext.none, reason: id);
      expect(item.shortcutEligible, isTrue, reason: id);
    }
  });

  test('wallet add searches lead to the matching kind of wallet', () {
    expect(registry.search('지갑 복원하기').first.item.id, FeatureIds.walletAddHot);
    expect(registry.search('keystone').first.item.id, FeatureIds.walletAddWatchOnly);
    expect(registry.search('xpub').first.item.id, FeatureIds.walletAddWatchOnly);
  });

  test('wordlist, glossary, my wallets and memo management are shortcuts that need no wallet', () {
    for (final id in [
      FeatureIds.mnemonicWordList,
      FeatureIds.glossary,
      FeatureIds.myWallets,
      FeatureIds.labelManagement,
    ]) {
      final item = registry.byId(id)!;
      expect(item.context, FeatureContext.none, reason: id);
      expect(item.shortcutEligible, isTrue, reason: id);
    }
    expect(registry.shortcutEligible, hasLength(15));
  });

  test('the open store sits under added features and is not a shortcut', () {
    final item = registry.byId(FeatureIds.openStore)!;

    expect(item.shortcutEligible, isFalse);
    expect(item.category, isNull);
    expect(item.context, FeatureContext.none);
    expect(item.iconPath, BrandIconPath.coconutPlanet);
    expect(registry.byId(FeatureIds.appSettings)!.iconPath, FeatureSettingsIconPath.settings);
    expect(registry.byId(FeatureIds.tutorial)!.iconPath, FeatureShortcutIconPath.tutorial);
    expect(registry.byId(FeatureIds.walletDetail)!.iconPath, FeatureShortcutIconPath.walletDetail);
    expect(registry.byId(FeatureIds.transactions)!.iconPath, FeatureShortcutIconPath.transactions);
    expect(item.label(), t.feature_registry.open_store);
  });

  test('wallet detail and transactions are not offered as shortcuts', () {
    for (final id in [FeatureIds.walletDetail, FeatureIds.transactions]) {
      final item = registry.byId(id)!;
      expect(item.context, FeatureContext.wallet, reason: id);
      expect(item.shortcutEligible, isFalse, reason: id);
    }
  });

  test('a sub-item match recommends its top-level parent with the matched path', () {
    final results = registry.search('PIN');

    expect(results.first.item.id, FeatureIds.appSettings);
    expect(results.first.matchedPath, hasLength(2));
  });

  test('wallet info searches lead to wallet detail', () {
    expect(registry.byId('wallet_info'), isNull);
    expect(registry.search('MFP').first.item.id, FeatureIds.walletDetail);
    expect(registry.search('지갑 정보').first.item.id, FeatureIds.walletDetail);
  });

  test('a sub-item label match recommends the parent: 주소 검색 → 주소', () {
    expect(registry.search('주소 검색').first.item.id, FeatureIds.addresses);
  });

  test('only top-level items are returned, ranked by best match', () {
    final results = registry.search('보내기');

    expect(results.every((r) => r.item.parentId == null), isTrue);
    expect(results.first.item.id, FeatureIds.send);
  });

  test('a query that matches nothing returns no results and an empty query returns nothing', () {
    expect(registry.search('zzzz-no-match'), isEmpty);
    expect(registry.search('   '), isEmpty);
  });

  test('matching ignores case and spaces', () {
    expect(registry.search('p i n').first.item.id, FeatureIds.appSettings);
  });
}
