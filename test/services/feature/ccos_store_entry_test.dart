import 'package:coconut_wallet/ccos/features/ark/ark_feature.dart';
import 'package:coconut_wallet/ccos/features/coconut_theme/coconut_theme_feature.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/ccos/ccos_feature_status.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_server_config.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_wallet_provider.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/screens/ccos/ark/ark_wallet_home_screen.dart';
import 'package:coconut_wallet/screens/ccos/store/coconut_open_store_feature_detail_screen.dart';
import 'package:coconut_wallet/screens/ccos/store/coconut_open_store_screen.dart';
import 'package:coconut_wallet/services/feature/feature_registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../ccos/ccos_store_test_fakes.dart';
import '../../ccos/features/ark/ark_test_fakes.dart';

Future<BuildContext> _pump(WidgetTester tester, FakeStorePreferences preferences) async {
  late BuildContext captured;
  final wallet = await fakeArkWalletProvider();
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<PreferenceProvider>.value(value: preferences),
        ChangeNotifierProvider<CcosFeatureStatusRegistry>.value(value: storeStatusRegistry(preferences)),
        ChangeNotifierProvider<ArkWalletProvider>.value(value: wallet),
      ],
      child: MaterialApp(
        theme: buildCoconutThemeData(variant: CoconutThemeVariant.dark),
        builder:
            (context, child) =>
                MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: true), child: child!),
        home: Builder(
          builder: (context) {
            captured = context;
            return const SizedBox();
          },
        ),
      ),
    ),
  );
  return captured;
}

void main() {
  setUp(() {
    LocaleSettings.setLocaleSync(AppLocale.ko);
    ArkServerConfig.isConfiguredOverride = true;
  });
  tearDown(() => ArkServerConfig.isConfiguredOverride = null);

  testWidgets('open store entry opens the store', (tester) async {
    final context = await _pump(tester, FakeStorePreferences());

    FeatureRegistry.builtin().byId(FeatureIds.openStore)!.launch!(context, null);
    await tester.pumpAndSettle();

    expect(find.byType(CoconutOpenStoreScreen), findsOneWidget);
  });

  testWidgets('ccos search opens the feature detail even when added', (tester) async {
    final preferences = FakeStorePreferences()..activated.add(ArkFeature.id);
    final context = await _pump(tester, preferences);

    FeatureRegistry.builtin().byId('${FeatureIds.openStore}.${ArkFeature.id}')!.launch!(context, null);
    await tester.pumpAndSettle();

    expect(find.byType(CoconutOpenStoreFeatureDetailScreen), findsOneWidget);
  });

  test('searching ark lists the open store and leads to the ark detail', () {
    final results = FeatureRegistry.builtin().search('아크', isAvailable: (item) => item.ccosFeatureId == null);

    expect(results.map((result) => result.item.id), [FeatureIds.openStore]);
    expect(results.single.matchedItem.id, '${FeatureIds.openStore}.${ArkFeature.id}');
  });

  for (final query in ['코코넛', '코코넛 테마']) {
    test('searching $query lists the open store and leads to the coconut theme detail', () {
      final results = FeatureRegistry.builtin().search(query);

      final store = results.singleWhere((result) => result.item.id == FeatureIds.openStore);
      expect(store.matchedItem.id, '${FeatureIds.openStore}.${CoconutThemeFeature.id}');
    });
  }

  for (final query in ['코코넛 테마', '테마', '밝은 테마', '라이트 테마', '다크 테마', '라이트', '다크']) {
    test('searching $query offers the theme settings', () {
      final results = FeatureRegistry.builtin().search(query);

      expect(results.map((result) => result.matchedItem.id), contains('${FeatureIds.appSettings}.theme'));
    });
  }

  test('ark search entry is absent without an ark server', () {
    ArkServerConfig.isConfiguredOverride = false;
    final registry = FeatureRegistry.builtin();

    expect(registry.byId('${FeatureIds.openStore}.${ArkFeature.id}'), isNull);
    expect(registry.all.where((item) => item.id.contains(ArkFeature.id)), isEmpty);
  });

  for (final added in [false, true]) {
    testWidgets('the ark wallet is searchable only once added (added=$added)', (tester) async {
      final preferences = FakeStorePreferences();
      if (added) preferences.activated.add(ArkFeature.id);
      final context = await _pump(tester, preferences);

      final results = FeatureRegistry.builtin().search(
        '아크 지갑',
        isAvailable: (item) => item.ccosFeatureId == null || (item.isAvailable?.call(context) ?? true),
      );
      final wallet = results.where((result) => result.item.ccosFeatureId == ArkFeature.id);

      expect(wallet, added ? hasLength(1) : isEmpty);
      if (added) {
        expect(wallet.single.item.label(), ArkFeature.listing.title);
        wallet.single.item.launch!(context, null);
        await tester.pumpAndSettle();
        expect(find.byType(ArkWalletHomeScreen), findsOneWidget);
      }
    });
  }
}
