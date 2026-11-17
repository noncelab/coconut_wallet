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
    final preferences = FakeStorePreferences()..activated.add(CoconutThemeFeature.id);
    final context = await _pump(tester, preferences);

    FeatureRegistry.builtin().byId('${FeatureIds.appSettings}.ccos.${CoconutThemeFeature.id}')!.launch!(context, null);
    await tester.pumpAndSettle();

    expect(find.byType(CoconutOpenStoreFeatureDetailScreen), findsOneWidget);
  });

  testWidgets('ark is searchable only where ark works', (tester) async {
    final item = FeatureRegistry.builtin().byId('${FeatureIds.appSettings}.ccos.${ArkFeature.id}')!;

    expect(item.isAvailable!(await _pump(tester, FakeStorePreferences())), isTrue);
    expect(item.isAvailable!(await _pump(tester, FakeStorePreferences(), arkEnabled: false)), isFalse);
  });
}
