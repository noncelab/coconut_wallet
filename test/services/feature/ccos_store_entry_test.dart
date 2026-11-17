import 'package:coconut_wallet/ccos/features/ark/ark_feature.dart';
import 'package:coconut_wallet/ccos/features/coconut_theme/coconut_theme_feature.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/ark_provider.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/screens/ccos/store/coconut_open_store_feature_detail_screen.dart';
import 'package:coconut_wallet/screens/ccos/store/coconut_open_store_screen.dart';
import 'package:coconut_wallet/services/feature/feature_registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../ccos/ccos_store_test_fakes.dart';

Future<BuildContext> _pump(WidgetTester tester, FakeStorePreferences preferences, {bool arkEnabled = true}) async {
  late BuildContext captured;
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<PreferenceProvider>.value(value: preferences),
        ChangeNotifierProvider<ArkProvider>.value(value: FakeStoreArk()..enabled = arkEnabled),
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
  setUp(() => LocaleSettings.setLocaleSync(AppLocale.ko));

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
    final results = FeatureRegistry.builtin().search('아크');

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

  testWidgets('ark is searchable only where ark works', (tester) async {
    final item = FeatureRegistry.builtin().byId('${FeatureIds.openStore}.${ArkFeature.id}')!;

    expect(item.isAvailable!(await _pump(tester, FakeStorePreferences())), isTrue);
    expect(item.isAvailable!(await _pump(tester, FakeStorePreferences(), arkEnabled: false)), isFalse);
  });
}
