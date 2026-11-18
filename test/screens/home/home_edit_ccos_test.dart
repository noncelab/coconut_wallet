import 'package:coconut_wallet/analytics/analytics_screen_names.dart';
import 'package:coconut_wallet/ccos/ccos_feature_registry.dart';
import 'package:coconut_wallet/ccos/ccos_feature_status.dart';
import 'package:coconut_wallet/ccos/ccos_home_entry.dart';
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/model/home/home_item.dart';
import 'package:coconut_wallet/model/home/home_item_definition.dart';
import 'package:coconut_wallet/model/home/home_item_ids.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/view_model/home/home_view_model.dart';
import 'package:coconut_wallet/repository/shared_preference/home_configuration_repository.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:coconut_wallet/screens/home/home_edit_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../ccos/ccos_store_test_fakes.dart';

class _CcosWidget extends HomeItemDefinition {
  _CcosWidget()
    : super(
        id: 'ccos_test_widget',
        kind: HomeItemKind.widget,
        supportedSpans: const [HomeSpan.small],
        category: HomeItemCategory.wallets,
        ccosFeatureId: 'ccos-test',
      );

  @override
  String displayName() => 'Ccos Widget';

  @override
  Widget build(BuildContext context, HomeItem item) => const ColoredBox(color: Colors.grey);
}

class _Pushes extends NavigatorObserver {
  final names = <String?>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => names.add(route.settings.name);
}

final _listing = CcosFeatureListing(
  id: 'ccos-test',
  category: CcosFeatureCategory.tool,
  title: 'ccos-test',
  description: '',
  author: '',
  authorBio: '',
  authorIntent: '',
  whyItBelongs: '',
  featureHelp: '',
  priceType: CcosListingPriceType.free,
  subtitle: '',
  iconPath: '',
  creatorStory: const CcosCreatorStory(paragraphs: [], belief: ''),
  homeShortcut: CcosHomeShortcut(
    id: 'ccos_test_shortcut',
    label: () => 'Ccos Shortcut',
    iconPath: FeatureShortcutIconPath.openStore,
    launch: (_) {},
  ),
  homeWidget: CcosHomeWidget(definition: _CcosWidget.new),
);

Future<_Pushes> _open(WidgetTester tester, HomeEditTab tab) async {
  tester.view.physicalSize = const Size(800, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final prefs = SharedPrefsRepository()..setSharedPreferencesForTest(await SharedPreferences.getInstance());
  final viewModel = HomeViewModel(
    repository: HomeConfigurationRepository(prefs),
    wallets: () => [],
    onShortcutTap: (_, __) {},
    widgetDefinitions: const [],
    isCcosFeatureActivated: (_) => false,
    ccosListings: () => [_listing],
  );
  addTearDown(viewModel.dispose);
  final preferences = FakeStorePreferences();
  final pushes = _Pushes();
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<PreferenceProvider>.value(value: preferences),
        ChangeNotifierProvider<CcosFeatureStatusRegistry>.value(value: storeStatusRegistry(preferences)),
        ChangeNotifierProvider<HomeViewModel>.value(value: viewModel),
      ],
      child: MaterialApp(
        theme: buildCoconutThemeData(variant: CoconutThemeVariant.dark),
        navigatorObservers: [pushes],
        home: HomeEditScreen(initialTab: tab),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 500));
  pushes.names.clear();
  return pushes;
}

void main() {
  testWidgets('a locked widget opens the store detail instead of adding', (tester) async {
    final pushes = await _open(tester, HomeEditTab.widgets);

    await tester.tap(find.byKey(const ValueKey('home-edit-widget-tap-ccos_test_widget')));
    await tester.pump(const Duration(milliseconds: 500));

    expect(pushes.names, contains(AnalyticsScreenNames.ccosOpenStoreFeatureDetail));
    expect(tester.widget<HomeEditScreen>(find.byType(HomeEditScreen, skipOffstage: false)), isNotNull);
  });

  testWidgets('a locked shortcut opens the store detail instead of adding', (tester) async {
    final pushes = await _open(tester, HomeEditTab.shortcuts);
    final id = HomeItemIds.shortcut('ccos_test_shortcut');

    await tester.tap(find.byKey(ValueKey('home-edit-shortcut-$id')));
    await tester.pump(const Duration(milliseconds: 500));

    expect(pushes.names, contains(AnalyticsScreenNames.ccosOpenStoreFeatureDetail));
  });
}
