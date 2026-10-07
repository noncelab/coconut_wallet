import 'dart:io';

import 'package:coconut_wallet/model/feature/feature_item.dart';
import 'package:coconut_wallet/services/feature/feature_registry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final registry = FeatureRegistry.builtin();

  test('top-level items match the inventory chapters 3 and 4 (11 global + 9 wallet)', () {
    expect(registry.topLevel.where((item) => item.context == FeatureContext.none), hasLength(11));
    expect(registry.topLevel.where((item) => item.context == FeatureContext.wallet), hasLength(9));
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

  test('wallet detail, wallet info and transactions are not offered as shortcuts', () {
    for (final id in [FeatureIds.walletDetail, FeatureIds.walletInfo, FeatureIds.transactions]) {
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
