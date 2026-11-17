import 'package:coconut_wallet/screens/ccos/store/widgets/ccos_store_scope.dart';
import 'package:coconut_wallet/screens/ccos/store/widgets/ccos_store_feature_thumbnail.dart';
import 'package:coconut_wallet/widgets/features/ccos/coconut_open_store_backdrop.dart';
import 'package:coconut_wallet/design_system/tokens/coconut_colors.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_design_system/coconut_design_system.dart' show CoconutSegmentedControl;
import 'package:coconut_wallet/ccos/features/ark/ark_feature.dart';
import 'package:coconut_wallet/ccos/features/coconut_theme/coconut_theme_feature.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/ark_provider.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/screens/ccos/coconut_open_store_intro_screen.dart';
import 'package:coconut_wallet/screens/ccos/store/coconut_open_store_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../../ccos/ccos_store_test_fakes.dart';

Future<FakeStorePreferences> _pump(WidgetTester tester, {Set<String> activated = const {}}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(414, 896);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  final preferences = FakeStorePreferences()..activated.addAll(activated);
  final ark = FakeStoreArk();
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<PreferenceProvider>.value(value: preferences),
        ChangeNotifierProvider<ArkProvider>.value(value: ark),
      ],
      child: MaterialApp(
        theme: buildCoconutThemeData(variant: CoconutThemeVariant.dark),
        builder:
            (context, child) =>
                MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: true), child: child!),
        home: const CoconutOpenStoreScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return preferences;
}

void main() {
  setUp(() => LocaleSettings.setLocaleSync(AppLocale.ko));

  testWidgets('every feature is a large card with its state, without tabs or a featured label', (tester) async {
    await _pump(tester, activated: {CoconutThemeFeature.id});

    final ark = find.byKey(ValueKey('ccos-store-card-${ArkFeature.id}'));
    final theme = find.byKey(ValueKey('ccos-store-card-${CoconutThemeFeature.id}'));
    expect(ark, findsOneWidget);
    expect(theme, findsOneWidget);
    expect(tester.getTopLeft(ark).dy, lessThan(tester.getTopLeft(theme).dy));
    expect(find.descendant(of: ark, matching: find.text(t.ccos.store.add)), findsOneWidget);
    expect(find.descendant(of: theme, matching: find.text(t.ccos.store.added)), findsOneWidget);
    expect(find.byType(CoconutSegmentedControl), findsNothing);
  });

  testWidgets('tapping add on a card adds the feature', (tester) async {
    final preferences = await _pump(tester);
    final card = find.byKey(ValueKey('ccos-store-card-${CoconutThemeFeature.id}'));

    await tester.scrollUntilVisible(card, 200, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.descendant(of: card, matching: find.text(t.ccos.store.add)));
    await tester.pumpAndSettle();

    expect(preferences.activated, contains(CoconutThemeFeature.id));
    expect(find.descendant(of: card, matching: find.text(t.ccos.store.added)), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('what is opens the intro story', (tester) async {
    await _pump(tester);

    await tester.tap(find.textContaining(t.ccos.store.what_is));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(CoconutOpenStoreIntroScreen), findsOneWidget);
  });

  testWidgets('tapping anywhere on the banner opens the intro story', (tester) async {
    await _pump(tester);

    await tester.tap(find.text(t.ccos.store.header_title));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(CoconutOpenStoreIntroScreen), findsOneWidget);
  });

  testWidgets('banner and feature cards are announced as buttons', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester);

    for (final finder in [
      find.text(t.ccos.store.header_title),
      find.byKey(ValueKey('ccos-store-card-${ArkFeature.id}')),
      find.byKey(ValueKey('ccos-store-card-${CoconutThemeFeature.id}')),
    ]) {
      expect(tester.getSemantics(finder.first).flagsCollection.isButton, isTrue);
    }
    handle.dispose();
  });

  testWidgets('the store keeps its own light look on a dark app theme', (tester) async {
    await _pump(tester);

    final context = tester.element(find.text(t.ccos.store.header_title));
    expect(context.coconutColors.primaryText, CoconutColors.light().primaryText);
    expect(find.byType(CoconutOpenStoreBackdrop), findsOneWidget);
  });

  testWidgets('card thumbnails are not detail screenshots', (tester) async {
    await _pump(tester);

    final paths =
        tester
            .widgetList<Image>(find.byType(Image))
            .map((image) => image.image)
            .whereType<AssetImage>()
            .map((image) => image.assetName)
            .toList();
    expect(paths.where((path) => path.contains('/ark/') || path.contains('/theme/')), isEmpty);
    expect(paths, contains('assets/images/ccos/preview_transaction_card.png'));
  });

  testWidgets('card thumbnails sit on their own background', (tester) async {
    await _pump(tester);

    final thumbnail = tester.widget<Container>(
      find.descendant(of: find.byType(CcosStoreFeatureThumbnail).first, matching: find.byType(Container)).first,
    );
    expect((thumbnail.decoration as BoxDecoration?)?.color, CcosStoreScope.thumbnailColor);
  });

  testWidgets('each card shows its category where the featured label used to be', (tester) async {
    await _pump(tester);

    final ark = find.byKey(ValueKey('ccos-store-card-${ArkFeature.id}'));
    final theme = find.byKey(ValueKey('ccos-store-card-${CoconutThemeFeature.id}'));
    expect(find.descendant(of: ark, matching: find.text(t.ccos.store.category.layer2)), findsOneWidget);
    await tester.scrollUntilVisible(theme, 200, scrollable: find.byType(Scrollable).first);
    expect(find.descendant(of: theme, matching: find.text(t.ccos.store.category.theme)), findsOneWidget);
  });
}
