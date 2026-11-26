import 'package:coconut_wallet/widgets/features/ccos/creator_statement_box.dart';
import 'package:coconut_wallet/widgets/features/ccos/coconut_open_store_backdrop.dart';
import 'package:coconut_wallet/design_system/tokens/coconut_colors.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_feature.dart';
import 'package:coconut_wallet/ccos/features/coconut_theme/coconut_theme_feature.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/ccos/ccos_feature_status.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_server_config.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/screens/ccos/store/coconut_open_store_feature_detail_screen.dart';
import 'package:coconut_wallet/screens/settings/theme_bottom_sheet.dart';
import 'package:coconut_wallet/ui/coconut/coconut_overlays.dart';
import 'package:coconut_wallet/widgets/common/buttons/shrink_animation_button.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../../ccos/ccos_store_test_fakes.dart';

Future<FakeStorePreferences> _pump(
  WidgetTester tester,
  String featureId, {
  Set<String> activated = const {},
  bool arkInUse = false,
  CoconutThemeVariant variant = CoconutThemeVariant.dark,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(414, 2400);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  final preferences =
      FakeStorePreferences()
        ..activated.addAll(activated)
        ..variant = variant;
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<PreferenceProvider>.value(value: preferences),
        ChangeNotifierProvider<CcosFeatureStatusRegistry>.value(
          value: storeStatusRegistryWith(preferences, inUse: {if (arkInUse) ArkFeature.id}),
        ),
      ],
      child: MaterialApp(
        theme: buildCoconutThemeData(variant: CoconutThemeVariant.dark),
        builder:
            (context, child) =>
                MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: true), child: child!),
        home: CoconutOpenStoreFeatureDetailScreen(featureId: featureId),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return preferences;
}

void main() {
  setUp(() => ArkServerConfig.isConfiguredOverride = true);
  tearDown(() {
    ArkServerConfig.isConfiguredOverride = null;
    ArkServerConfig.isRegtestOverride = null;
  });

  tearDown(() => LocaleSettings.setLocaleSync(AppLocale.ko));

  testWidgets('header shows icon, title, subtitle and the add button', (tester) async {
    LocaleSettings.setLocaleSync(AppLocale.ko);
    final preferences = await _pump(tester, ArkFeature.id);
    final listing = ArkFeature.listing;

    expect(find.text(listing.title), findsWidgets);
    expect(find.text(listing.subtitle), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('ccos-detail-action')));
    await tester.pumpAndSettle();
    expect(preferences.activated, contains(ArkFeature.id));
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('feature section shows every screenshot with its caption', (tester) async {
    LocaleSettings.setLocaleSync(AppLocale.ko);
    await _pump(tester, ArkFeature.id);

    for (final shot in ArkFeature.listing.screenshots) {
      await tester.scrollUntilVisible(find.text(shot.caption), 200, scrollable: find.byType(Scrollable).last);
      expect(find.text(shot.caption), findsOneWidget);
    }
  });

  testWidgets('creator section omits the quote when there is none', (tester) async {
    LocaleSettings.setLocaleSync(AppLocale.ko);
    await _pump(tester, ArkFeature.id);
    expect(find.byKey(const ValueKey('ccos-detail-quote')), findsNothing);
    expect(
      tester.widget<CreatorStatementBox>(find.byType(CreatorStatementBox)).text,
      ArkFeature.listing.creatorStory.belief,
    );
  });

  testWidgets('the theme shows no feedback quote', (tester) async {
    LocaleSettings.setLocaleSync(AppLocale.ko);
    await _pump(tester, CoconutThemeFeature.id);
    expect(find.byKey(const ValueKey('ccos-detail-quote')), findsNothing);
  });

  testWidgets('remove is disabled with a reason while ark is in use', (tester) async {
    LocaleSettings.setLocaleSync(AppLocale.ko);
    final preferences = await _pump(tester, ArkFeature.id, activated: {ArkFeature.id}, arkInUse: true);

    expect(find.text(blockedReasonForTest), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('ccos-detail-remove')), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(preferences.activated, contains(ArkFeature.id));
  });

  testWidgets('removing ark not in use removes it', (tester) async {
    LocaleSettings.setLocaleSync(AppLocale.ko);
    final preferences = await _pump(tester, ArkFeature.id, activated: {ArkFeature.id});

    await tester.tap(find.byKey(const ValueKey('ccos-detail-remove')));
    await tester.pumpAndSettle();
    expect(preferences.activated, isNot(contains(ArkFeature.id)));
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('japanese locale shows english screenshots', (tester) async {
    LocaleSettings.setLocaleSync(AppLocale.ja);
    await _pump(tester, ArkFeature.id);

    final images = tester.widgetList<Image>(find.byType(Image)).map((image) => image.image).whereType<AssetImage>();
    final paths = images.map((image) => image.assetName).toList();
    expect(paths, isNotEmpty);
    expect(paths.every((path) => path.contains('/ark/en/')), isTrue);
  });

  testWidgets('removing the applied theme asks first, then switches to dark and removes it', (tester) async {
    LocaleSettings.setLocaleSync(AppLocale.ko);
    final preferences = await _pump(
      tester,
      CoconutThemeFeature.id,
      activated: {CoconutThemeFeature.id},
      variant: CoconutThemeVariant.coconutTheme,
    );

    await tester.ensureVisible(find.byKey(const ValueKey('ccos-detail-remove')));
    await tester.tap(find.byKey(const ValueKey('ccos-detail-remove')));
    await tester.pumpAndSettle();
    expect(find.byType(CoconutPopup), findsOneWidget);

    await tester.tap(find.text(t.delete));
    await tester.pumpAndSettle();
    expect(preferences.variant, CoconutThemeVariant.dark);
    expect(preferences.activated, isNot(contains(CoconutThemeFeature.id)));
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('cancelling the applied theme removal keeps it', (tester) async {
    LocaleSettings.setLocaleSync(AppLocale.ko);
    final preferences = await _pump(
      tester,
      CoconutThemeFeature.id,
      activated: {CoconutThemeFeature.id},
      variant: CoconutThemeVariant.coconutTheme,
    );

    await tester.ensureVisible(find.byKey(const ValueKey('ccos-detail-remove')));
    await tester.tap(find.byKey(const ValueKey('ccos-detail-remove')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(t.cancel));
    await tester.pumpAndSettle();
    expect(preferences.variant, CoconutThemeVariant.coconutTheme);
    expect(preferences.activated, contains(CoconutThemeFeature.id));
  });

  testWidgets('an added theme can be opened in the theme settings', (tester) async {
    LocaleSettings.setLocaleSync(AppLocale.ko);
    await _pump(tester, CoconutThemeFeature.id, activated: {CoconutThemeFeature.id});

    await tester.tap(find.byKey(const ValueKey('ccos-detail-open')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(ThemeBottomSheet), findsOneWidget);
  });

  testWidgets('ark has no open action', (tester) async {
    LocaleSettings.setLocaleSync(AppLocale.ko);
    await _pump(tester, ArkFeature.id, activated: {ArkFeature.id});
    expect(find.byKey(const ValueKey('ccos-detail-open')), findsNothing);
  });

  testWidgets('screenshots keep their aspect ratio', (tester) async {
    LocaleSettings.setLocaleSync(AppLocale.ko);
    await _pump(tester, ArkFeature.id);

    final size = tester.getSize(find.byType(Image).first);
    expect(size.width / size.height, closeTo(540 / 1049, 0.01));
  });

  testWidgets('screenshot border is drawn above the image', (tester) async {
    LocaleSettings.setLocaleSync(AppLocale.ko);
    await _pump(tester, ArkFeature.id);

    final frame = tester.widget<Container>(
      find.ancestor(of: find.byType(Image).first, matching: find.byType(Container)).first,
    );
    expect((frame.foregroundDecoration as BoxDecoration?)?.border, isNotNull);
  });

  testWidgets('applied state label sits on a button background', (tester) async {
    LocaleSettings.setLocaleSync(AppLocale.ko);
    await _pump(tester, ArkFeature.id, activated: {ArkFeature.id}, arkInUse: true);

    final pill = tester.widget<Container>(
      find.ancestor(of: find.text(t.ccos.store.applied), matching: find.byType(Container)).first,
    );
    expect((pill.decoration as BoxDecoration?)?.color, isNotNull);
  });

  testWidgets('header shows the author just above the action, without a category line', (tester) async {
    LocaleSettings.setLocaleSync(AppLocale.ko);
    await _pump(tester, ArkFeature.id);
    final author = find.text(ArkFeature.listing.author);
    expect(author, findsOneWidget);
    expect(find.textContaining(t.ccos.store.category.layer2), findsNothing);
    final authorRect = tester.getRect(author);
    final action = tester.getRect(find.byKey(const ValueKey('ccos-detail-action')));
    expect(action.top - authorRect.bottom, inInclusiveRange(0, 12));
    final subtitle = tester.getRect(find.text(ArkFeature.listing.subtitle));
    expect(authorRect.top, greaterThan(subtitle.bottom));
  });

  testWidgets('an unknown feature still has a way back', (tester) async {
    LocaleSettings.setLocaleSync(AppLocale.ko);
    await _pump(tester, 'ccos-feature-unknown');
    expect(
      find.byType(BackButtonIcon).evaluate().isNotEmpty ||
          find.byIcon(Icons.arrow_back).evaluate().isNotEmpty ||
          find.byType(AppBar).evaluate().isNotEmpty ||
          find.byType(CupertinoNavigationBar).evaluate().isNotEmpty,
      isTrue,
    );
  });

  testWidgets('captions grow with the text size', (tester) async {
    LocaleSettings.setLocaleSync(AppLocale.ko);
    final preferences = FakeStorePreferences();
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(414, 2400);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<PreferenceProvider>.value(value: preferences),
          ChangeNotifierProvider<CcosFeatureStatusRegistry>.value(value: storeStatusRegistry(preferences)),
        ],
        child: MaterialApp(
          theme: buildCoconutThemeData(variant: CoconutThemeVariant.dark),
          builder:
              (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2), disableAnimations: true),
                child: child!,
              ),
          home: const CoconutOpenStoreFeatureDetailScreen(featureId: ArkFeature.id),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('blocked remove stays visible on the background with its reason centered', (tester) async {
    LocaleSettings.setLocaleSync(AppLocale.ko);
    await _pump(tester, ArkFeature.id, activated: {ArkFeature.id}, arkInUse: true);

    final context = tester.element(find.byKey(const ValueKey('ccos-detail-remove')));
    final colors = context.coconutColors;
    final button = tester.widget<ShrinkAnimationButton>(find.byKey(const ValueKey('ccos-detail-remove')));
    expect(button.disabledColor, isNot(colors.background));
    expect(button.disabledColor, colors.surfaceButton);

    final reason = find.text(blockedReasonForTest);
    expect(
      tester.getCenter(reason).dx,
      closeTo(tester.getCenter(find.byKey(const ValueKey('ccos-detail-remove'))).dx, 1),
    );
  });

  testWidgets('screenshots scroll across the full screen width', (tester) async {
    LocaleSettings.setLocaleSync(AppLocale.ko);
    await _pump(tester, ArkFeature.id);

    final strip = find.byWidgetPredicate(
      (widget) => widget is Scrollable && widget.axisDirection == AxisDirection.right,
    );
    expect(tester.getSize(strip).width, 414);
    expect(tester.getTopLeft(find.byType(Image).first).dx, 16);
  });

  testWidgets('the detail keeps the store light look on a dark app theme', (tester) async {
    LocaleSettings.setLocaleSync(AppLocale.ko);
    await _pump(tester, ArkFeature.id);

    final context = tester.element(find.text(ArkFeature.listing.title).first);
    expect(context.coconutColors.primaryText, CoconutColors.light().primaryText);
    expect(find.byType(CoconutOpenStoreBackdrop), findsOneWidget);
  });

  testWidgets('the creator belief is centered in its quote box', (tester) async {
    LocaleSettings.setLocaleSync(AppLocale.ko);
    await _pump(tester, ArkFeature.id);

    final box = find.byType(CreatorStatementBox);
    final text = tester.widget<Text>(find.descendant(of: box, matching: find.byType(Text)));
    expect(text.textAlign, TextAlign.center);
    final boxCenter = tester.getCenter(box).dx;
    expect(tester.getCenter(find.descendant(of: box, matching: find.byType(Text))).dx, closeTo(boxCenter, 1));
  });

  testWidgets('header lines up title with the icon top and the action with the icon bottom', (tester) async {
    LocaleSettings.setLocaleSync(AppLocale.ko);
    await _pump(tester, ArkFeature.id);

    final icon = tester.getRect(find.byKey(const ValueKey('ccos-detail-icon')));
    final title = tester.getRect(find.text(ArkFeature.listing.title).first);
    final action = tester.getRect(find.byKey(const ValueKey('ccos-detail-action')));
    expect(title.top, closeTo(icon.top, 4));
    expect(action.bottom, closeTo(icon.bottom, 1));
    expect(find.text(ArkFeature.listing.subtitle), findsOneWidget);
  });

  testWidgets('scrolling past the header shows the icon and action in the app bar', (tester) async {
    LocaleSettings.setLocaleSync(AppLocale.ko);
    await _pump(tester, ArkFeature.id);
    tester.view.physicalSize = const Size(414, 896);
    await tester.pumpAndSettle();

    double opacity() =>
        tester.widget<AnimatedOpacity>(find.byKey(const ValueKey('ccos-detail-appbar-content'))).opacity;
    expect(opacity(), 0);

    await tester.drag(find.byType(ListView).first, const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(opacity(), 1);
    expect(find.byKey(const ValueKey('ccos-detail-appbar-action')), findsOneWidget);

    await tester.drag(find.byType(ListView).first, const Offset(0, 300));
    await tester.pumpAndSettle();
    expect(opacity(), 0);
  });

  testWidgets('scrolling puts a glass circle behind the back button and content under the bar', (tester) async {
    LocaleSettings.setLocaleSync(AppLocale.ko);
    await _pump(tester, ArkFeature.id);
    tester.view.physicalSize = const Size(414, 896);
    await tester.pumpAndSettle();

    double glass() => tester.widget<AnimatedOpacity>(find.byKey(const ValueKey('ccos-detail-back-glass'))).opacity;
    expect(glass(), 0);
    expect(tester.getSize(find.byKey(const ValueKey('ccos-detail-back-glass'))), const Size(36, 36));
    expect(tester.getTopLeft(find.byType(Scrollable).first).dy, 0);

    await tester.drag(find.byType(ListView).first, const Offset(0, -40));
    await tester.pumpAndSettle();
    expect(glass(), 1);
    expect(tester.widget<AnimatedOpacity>(find.byKey(const ValueKey('ccos-detail-top-fade'))).opacity, 1);
  });

  testWidgets('mainnet-only ark shows the notice and cannot be added or removed', (tester) async {
    LocaleSettings.setLocaleSync(AppLocale.ko);
    ArkServerConfig.isConfiguredOverride = false;
    ArkServerConfig.isRegtestOverride = true;
    final preferences = await _pump(tester, ArkFeature.id);

    expect(find.text(t.ccos.store.mainnet_only), findsWidgets);
    expect(find.text(t.ark_wallet.store_mainnet_only), findsOneWidget);
    expect(find.text(t.ccos.store.add), findsNothing);
    expect(find.byKey(const ValueKey('ccos-detail-remove')), findsNothing);
    expect(find.text(ArkFeature.listing.description), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('ccos-detail-action')));
    await tester.pumpAndSettle();
    expect(preferences.activated, isEmpty);
  });

  testWidgets('detail for a hidden listing closes', (tester) async {
    ArkServerConfig.isConfiguredOverride = false;
    ArkServerConfig.isRegtestOverride = false;
    final preferences = FakeStorePreferences();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<PreferenceProvider>.value(value: preferences),
          ChangeNotifierProvider<CcosFeatureStatusRegistry>.value(value: storeStatusRegistry(preferences)),
        ],
        child: MaterialApp(
          theme: buildCoconutThemeData(variant: CoconutThemeVariant.dark),
          home: Builder(
            builder:
                (context) => TextButton(
                  onPressed:
                      () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const CoconutOpenStoreFeatureDetailScreen(featureId: ArkFeature.id),
                        ),
                      ),
                  child: const Text('open'),
                ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byType(CoconutOpenStoreFeatureDetailScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
