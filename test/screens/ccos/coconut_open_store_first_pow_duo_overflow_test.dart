import 'dart:io';

import 'package:coconut_wallet/ccos/ccos_feature_registry.dart';
import 'package:coconut_wallet/ccos/ccos_feature_runtime.dart';
import 'package:coconut_wallet/ccos/open_store/coconut_open_store_navigation.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/screens/ccos/coconut_open_store_first_pow_scene.dart';
import 'package:coconut_wallet/screens/ccos/coconut_open_store_intro_screen.dart';
import 'package:coconut_wallet/services/analytics_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// Outer iPhone Duo display from the grouped-followup IOS_TUI009 run
/// (Runner 9e18, logical 466x678, DPR 3, padding top 0, bottom 34, inset 0,
/// text scale 1, portrait). Not a generic phone size.
const _duoLogical = Size(466, 678);
const _duoDpr = 3.0;
const _duoBottomPadding = 34.0;

class _Preferences extends Fake with ChangeNotifier implements PreferenceProvider {
  _Preferences([this.variant = CoconutThemeVariant.dark]);

  final CoconutThemeVariant variant;

  @override
  CoconutThemeVariant get themeVariant => variant;

  @override
  CcosFeatureAvailability getCcosFeatureAvailability(String featureId) => CcosFeatureAvailability(
    featureId: featureId,
    isVisible: false,
    isActivated: false,
    isEntitled: false,
    isAvailable: false,
  );
}

Future<void> _loadFonts() async {
  for (final entry
      in {
        'Pretendard': ['Pretendard-Regular.ttf', 'Pretendard-Bold.ttf'],
        'SpaceGrotesk': ['SpaceGrotesk-Regular.ttf', 'SpaceGrotesk-Bold.ttf'],
      }.entries) {
    final loader = FontLoader(entry.key);
    for (final name in entry.value) {
      loader.addFont(Future.value(ByteData.sublistView(File('assets/fonts/$name').readAsBytesSync())));
    }
    await loader.load();
  }
}

void _applyView(WidgetTester tester, {required Size logical, required double dpr, required double bottomPadding}) {
  tester.view.devicePixelRatio = dpr;
  tester.view.physicalSize = Size(logical.width * dpr, logical.height * dpr);
  final bottom = bottomPadding * dpr;
  const zero = FakeViewPadding();
  final padding = FakeViewPadding(bottom: bottom);
  tester.view.viewPadding = padding;
  tester.view.padding = padding;
  tester.view.viewInsets = zero;
  tester.view.systemGestureInsets = zero;
}

Future<void> _pumpIntro(
  WidgetTester tester, {
  required Size logical,
  required double dpr,
  required double bottomPadding,
  required double textScale,
}) async {
  _applyView(tester, logical: logical, dpr: dpr, bottomPadding: bottomPadding);
  addTearDown(tester.view.reset);
  final preferences = _Preferences();
  addTearDown(preferences.dispose);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<PreferenceProvider>.value(value: preferences),
        Provider<AnalyticsService>.value(value: AnalyticsService(null, true)),
      ],
      child: MaterialApp(
        theme: buildCoconutThemeData(variant: CoconutThemeVariant.dark).copyWith(platform: TargetPlatform.iOS),
        builder:
            (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                disableAnimations: true,
                platformBrightness: Brightness.dark,
                textScaler: TextScaler.linear(textScale),
              ),
              child: child!,
            ),
        home: Builder(
          builder:
              (context) => Scaffold(
                body: TextButton(
                  onPressed: () => openCoconutOpenStoreIntroScreen(context),
                  child: const Text('Open Store'),
                ),
              ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open Store'));
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

List<String> _drain(WidgetTester tester) {
  final messages = <String>[];
  Object? error;
  while ((error = tester.takeException()) != null) {
    messages.add(error.toString());
  }
  return messages;
}

Finder _introLine(String source) => find.byWidgetPredicate((widget) {
  if (widget is! RichText) return false;
  return widget.text.toPlainText().replaceAll('\u2060', '') == source;
});

void _expectCopyClearsAddButton(WidgetTester tester) {
  final copyBottom = tester.getBottomLeft(_introLine(t.ccos.first_pow_scene.intro_line2)).dy;
  final buttonTop =
      tester
          .getTopLeft(
            find
                .ancestor(of: find.text(t.ccos.first_pow_scene.add_button), matching: find.byType(AnimatedContainer))
                .first,
          )
          .dy;
  expect(buttonTop, greaterThanOrEqualTo(copyBottom - 0.5));
}

Future<List<String>> _showFirstPow(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 15));
  final earlier = _drain(tester);
  final next = find.byIcon(Icons.arrow_forward_rounded);
  expect(next.hitTestable(), findsWidgets, reason: 'next missing after story: $earlier');
  await tester.tap(next.hitTestable().first);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 800));
  await tester.tap(find.byIcon(Icons.arrow_forward_rounded).hitTestable().first);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 800));
  _drain(tester);
  // Korean first-pow duration is about 10.2s. Advance past the typewriter so both
  // lines are fully laid out, which is the tallest return-path frame.
  await tester.pump(const Duration(seconds: 12));
  return _drain(tester);
}

void main() {
  setUpAll(() async {
    LocaleSettings.setLocaleSync(AppLocale.ko);
    await _loadFonts();
  });

  testWidgets('Duo outer display lays out the full first-pow copy without a bottom overflow', (tester) async {
    await _pumpIntro(tester, logical: _duoLogical, dpr: _duoDpr, bottomPadding: _duoBottomPadding, textScale: 1);
    _drain(tester);
    final duringScene = await _showFirstPow(tester);
    expect(find.byType(FirstPowSceneBody), findsOneWidget);
    final sceneSize = tester.getSize(find.byType(FirstPowSceneBody));
    expect(
      duringScene.where((message) => message.contains('RenderFlex')),
      isEmpty,
      reason: 'scene=${sceneSize.width.toStringAsFixed(1)}x${sceneSize.height.toStringAsFixed(1)} $duringScene',
    );
    _expectCopyClearsAddButton(tester);
    expect(
      find.descendant(of: find.byType(FirstPowSceneBody), matching: find.byType(SingleChildScrollView)),
      findsNothing,
    );

    final feature = find.byWidgetPredicate(
      (widget) =>
          widget is Image &&
          widget.image is AssetImage &&
          (widget.image as AssetImage).assetName == 'assets/images/ccos/feature.png',
    );
    await tester.tap(feature.hitTestable());
    await tester.pump();
    // Detail entrance starts 620ms after the route builds. The back control
    // finishes its 250-700ms interval on the 4150ms feature entrance.
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 900));
    final duringDetail = _drain(tester);
    final back = find.byIcon(Icons.arrow_back_rounded);
    expect(back.hitTestable(), findsOneWidget, reason: 'detail=$duringDetail icons=${back.evaluate().length}');
    await tester.tap(back);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    final duringReturn = _drain(tester);
    expect(
      [...duringDetail, ...duringReturn].where((message) => message.contains('RenderFlex')),
      isEmpty,
      reason: 'detail=$duringDetail return=$duringReturn',
    );
    expect(find.byType(CoconutOpenStoreIntroScreen), findsOneWidget);
    expect(_introLine(t.ccos.first_pow_scene.intro_line1), findsOneWidget);
    expect(_introLine(t.ccos.first_pow_scene.intro_line2), findsOneWidget);
    expect(find.text(t.ccos.first_pow_scene.add_button).hitTestable(), findsOneWidget);
  });

  testWidgets('Duo outer display keeps large text and the add button inside the scene', (tester) async {
    await _pumpIntro(tester, logical: _duoLogical, dpr: _duoDpr, bottomPadding: _duoBottomPadding, textScale: 1.3);
    _drain(tester);
    final duringScene = await _showFirstPow(tester);
    expect(duringScene.where((message) => message.contains('RenderFlex')), isEmpty, reason: duringScene.join('\n'));
    expect(_introLine(t.ccos.first_pow_scene.intro_line2), findsOneWidget);
    expect(find.text(t.ccos.first_pow_scene.add_button).hitTestable(), findsOneWidget);
    _expectCopyClearsAddButton(tester);
    final scaled = tester.renderObject<RenderParagraph>(_introLine(t.ccos.first_pow_scene.intro_line1));
    expect(scaled.textScaler, const TextScaler.linear(1.3));
    // Unscaled strut is 18 * 1.4 * 1.3 = 32.76, two lines. Scaled paint is taller.
    expect(scaled.size.height, greaterThan(32.76 * 2 + 8));
  });

  testWidgets('a roomy phone keeps the designed 44px gap above the first-pow copy', (tester) async {
    await _pumpIntro(tester, logical: const Size(414, 896), dpr: 1, bottomPadding: 0, textScale: 1);
    _drain(tester);
    final duringScene = await _showFirstPow(tester);
    expect(duringScene.where((message) => message.contains('RenderFlex')), isEmpty, reason: duringScene.join('\n'));
    final sceneTop = tester.getTopLeft(find.byType(FirstPowSceneBody)).dy;
    final textTop = tester.getTopLeft(_introLine(t.ccos.first_pow_scene.intro_line1)).dy;
    final width = tester.getSize(find.byType(FirstPowSceneBody)).width;
    final idealCardWidth = width / 3 * 1.4;
    final idealCardHeight = idealCardWidth * 1.42;
    final cardBlock = idealCardHeight + idealCardHeight * 0.08 + 24;
    expect(textTop - sceneTop, closeTo(cardBlock + 44, 0.5));
    final lineGap =
        tester.getTopLeft(_introLine(t.ccos.first_pow_scene.intro_line2)).dy -
        tester.getBottomLeft(_introLine(t.ccos.first_pow_scene.intro_line1)).dy;
    expect(lineGap, closeTo(22, 0.5));
    _expectCopyClearsAddButton(tester);
    expect(
      find.descendant(of: find.byType(FirstPowSceneBody), matching: find.byType(SingleChildScrollView)),
      findsNothing,
    );
  });

  testWidgets('a short large-text scene keeps cards, copy, and the add button reachable', (tester) async {
    final preferences = _Preferences();
    addTearDown(preferences.dispose);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<PreferenceProvider>.value(value: preferences),
          Provider<AnalyticsService>.value(value: AnalyticsService(null, true)),
        ],
        child: MaterialApp(
          theme: buildCoconutThemeData(variant: CoconutThemeVariant.dark),
          builder:
              (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(disableAnimations: true, textScaler: const TextScaler.linear(2)),
                child: child!,
              ),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 320,
                height: 180,
                child: FirstPowSceneBody(
                  animation: const AlwaysStoppedAnimation<double>(1),
                  sceneDurationMs: 20000,
                  listing: CcosFeatureRegistrySource.featuredListing,
                  isAdded: false,
                  isApplied: false,
                  isCurrentScene: false,
                  onAdd: () {},
                  onRemove: () {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(_drain(tester).where((message) => message.contains('RenderFlex')), isEmpty);
    expect(find.byType(SingleChildScrollView), findsOneWidget);

    for (final asset in [
      'assets/images/ccos/creator.png',
      'assets/images/ccos/feature.png',
      'assets/images/ccos/delivery.png',
    ]) {
      final image = find.byWidgetPredicate(
        (widget) => widget is Image && widget.image is AssetImage && (widget.image as AssetImage).assetName == asset,
      );
      await tester.ensureVisible(image);
      final card = find.ancestor(of: image, matching: find.byType(GestureDetector)).first;
      expect(tester.getSize(card).shortestSide, greaterThanOrEqualTo(48));
    }

    final feature = find.byWidgetPredicate(
      (widget) =>
          widget is Image &&
          widget.image is AssetImage &&
          (widget.image as AssetImage).assetName == 'assets/images/ccos/feature.png',
    );
    await tester.ensureVisible(feature);
    await tester.pump();
    expect(feature.hitTestable(), findsOneWidget);
    await tester.tap(feature.hitTestable());
    await tester.pump();
    await tester.pump();
    expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
    Navigator.of(tester.element(find.byType(FirstPowSceneBody))).pop();
    await tester.pump();
    // Detail initState schedules a 620ms entrance. Let that timer finish
    // after the route is gone, and let the 260ms pop transition end.
    await tester.pump(const Duration(milliseconds: 700));

    final copy = _introLine(t.ccos.first_pow_scene.intro_line2);
    await tester.ensureVisible(copy);
    expect(copy, findsOneWidget);
    final scaled = tester.renderObject<RenderParagraph>(_introLine(t.ccos.first_pow_scene.intro_line1));
    expect(scaled.textScaler, const TextScaler.linear(2));
    final button = find.text(t.ccos.first_pow_scene.add_button);
    await tester.ensureVisible(button);
    expect(button.hitTestable(), findsOneWidget);
    expect(_drain(tester).where((message) => message.contains('RenderFlex')), isEmpty);
  });
}
