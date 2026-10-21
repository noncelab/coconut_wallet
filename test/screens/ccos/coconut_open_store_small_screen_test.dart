import 'dart:io';
import 'dart:ui' as ui;

import 'package:coconut_wallet/ccos/ccos_feature_runtime.dart';
import 'package:coconut_wallet/ccos/ccos_feature_registry.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/screens/ccos/coconut_open_store_intro_screen.dart';
import 'package:coconut_wallet/screens/ccos/coconut_open_store_first_pow_scene.dart';
import 'package:coconut_wallet/services/analytics_service.dart';
import 'package:coconut_wallet/widgets/common/buttons/coconut_icon_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _Preferences extends Fake with ChangeNotifier implements PreferenceProvider {
  _Preferences({this.isAdded = false, this.isApplied = false});

  bool isAdded;
  final bool isApplied;

  void setAdded(bool value) {
    isAdded = value;
    notifyListeners();
  }

  @override
  CoconutThemeVariant get themeVariant =>
      isApplied ? CcosFeatureRegistrySource.featuredListing.linkedVariant! : CoconutThemeVariant.dark;

  @override
  CcosFeatureAvailability getCcosFeatureAvailability(String featureId) => CcosFeatureAvailability(
    featureId: featureId,
    isVisible: false,
    isActivated: isAdded,
    isEntitled: false,
    isAvailable: false,
  );
}

Finder _type(String name) => find.byWidgetPredicate((widget) => widget.runtimeType.toString() == name);

const _captureKey = ValueKey('small-screen-capture');

Future<void> _capture(WidgetTester tester, String name) async {
  const directory = String.fromEnvironment('SMALL_SCREEN_EVIDENCE');
  if (directory.isEmpty) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(_captureKey));
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory(directory).create(recursive: true);
    await File('$directory/$name.png').writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUpAll(() async {
    LocaleSettings.setLocaleSync(AppLocale.ko);
    for (final family in ['Pretendard', 'SpaceGrotesk']) {
      final loader = FontLoader(family);
      for (final weight in ['Regular', 'Bold']) {
        loader.addFont(Future.value(ByteData.sublistView(File('assets/fonts/$family-$weight.ttf').readAsBytesSync())));
      }
      await loader.load();
    }
  });

  for (final viewport in [const Size(375, 667), const Size(320, 568), const Size(414, 896)]) {
    for (final scale in viewport.height > 800 ? [1.0] : [1.0, 1.3, 2.0]) {
      testWidgets('First PoW detail return keeps copy and action reachable: $viewport $scale', (tester) async {
        tester.view.devicePixelRatio = 2;
        tester.view.physicalSize = viewport * 2;
        tester.view.padding = const FakeViewPadding(top: 40);
        tester.view.viewPadding = const FakeViewPadding(top: 40);
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final preferences = _Preferences();
        addTearDown(preferences.dispose);
        await tester.pumpWidget(
          RepaintBoundary(
            key: _captureKey,
            child: MultiProvider(
              providers: [
                ChangeNotifierProvider<PreferenceProvider>.value(value: preferences),
                Provider<AnalyticsService>.value(value: AnalyticsService(null, true)),
              ],
              child: MaterialApp(
                theme: buildCoconutThemeData().copyWith(platform: TargetPlatform.iOS),
                home: const CoconutOpenStoreIntroScreen(),
              ),
            ),
          ),
        );
        await tester.runAsync(() async {
          final context = tester.element(find.byType(CoconutOpenStoreIntroScreen));
          for (final name in ['creator', 'feature', 'delivery']) {
            await precacheImage(AssetImage('assets/images/ccos/$name.png'), context);
          }
        });
        await tester.pump();
        await tester.pump(const Duration(seconds: 6));
        await tester.pump(const Duration(seconds: 2));
        await tester.tap(find.byType(CoconutAppBarActionButton).last);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 800));
        final overview = _type('_SceneOverviewOverlay');
        final entry = find.descendant(of: overview, matching: find.text(t.ccos.intro_screen.scenes.first_pow.label));
        await tester.scrollUntilVisible(
          entry,
          160,
          scrollable: find.descendant(of: overview, matching: find.byType(Scrollable)),
        );
        await tester.pump();
        await tester.tap(entry.hitTestable());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 800));
        expect(tester.widget<PageView>(find.byType(PageView)).controller!.page, closeTo(2, .01));
        final feature = find.byWidgetPredicate(
          (widget) =>
              widget is Image &&
              widget.image is AssetImage &&
              (widget.image as AssetImage).assetName == 'assets/images/ccos/feature.png',
        );
        await tester.tap(feature.hitTestable());
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        for (final label in [
          t.ccos.first_pow_scene.creator_detail.panel_label,
          t.ccos.first_pow_scene.feature_detail.panel_label,
          t.ccos.first_pow_scene.delivery_detail.panel_label,
        ]) {
          await tester.tap(find.ancestor(of: find.text(label), matching: _type('_FirstPowDetailSegment')));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
          await tester.pump(const Duration(seconds: 6));
          if (viewport.width == 320 || viewport.height > 800) {
            await _capture(
              tester,
              '${viewport.width.toInt()}x${viewport.height.toInt()}-$scale-${label.toLowerCase()}',
            );
          }
        }
        await tester.tap(find.byIcon(Icons.arrow_back_rounded));
        await tester.pump();
        for (var frame = 0; frame < 20; frame++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        await tester.pump(const Duration(seconds: 15));
        final name = '${viewport.width.toInt()}x${viewport.height.toInt()}-$scale';
        await _capture(tester, '$name-top');
        expect(tester.takeException(), isNull);

        final body = _type('FirstPowSceneBody');
        final button = find.descendant(of: body, matching: _type('_AddThemeButton'));
        final lastLine = find.descendant(
          of: body,
          matching: find.byWidgetPredicate(
            (widget) => widget is RichText && widget.text.toPlainText() == t.ccos.first_pow_scene.intro_line2,
          ),
        );
        await tester.drag(body, const Offset(0, -1500));
        final scrollable = find.descendant(of: body, matching: find.byType(Scrollable));
        final position = tester.state<ScrollableState>(scrollable).position;
        if (viewport.height < 800) expect(position.pixels, greaterThan(0));
        position.jumpTo(position.maxScrollExtent);
        await tester.pump();
        expect(
          find.descendant(of: button, matching: find.text(t.ccos.first_pow_scene.add_button)).hitTestable(),
          findsOneWidget,
        );
        expect(tester.getRect(lastLine).bottom, lessThan(tester.getRect(button).top));
        expect(tester.getRect(button).bottom, lessThanOrEqualTo(tester.getRect(body).bottom + 0.001));
        if (scale <= 1.3) {
          expect(tester.getRect(lastLine).top, greaterThanOrEqualTo(tester.getRect(body).top));
        }
        await _capture(tester, '$name-bottom');
        if (viewport.height > 800) {
          expect(position.maxScrollExtent, 0);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 2));
      });
    }
  }

  testWidgets('large-text added badge and remove action remain reachable together', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    var removals = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildCoconutThemeData(),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: FirstPowSceneBody(
              animation: const AlwaysStoppedAnimation(1),
              sceneDurationMs: FirstPowSceneBody.baseDurationMs,
              listing: CcosFeatureRegistrySource.featuredListing,
              isAdded: true,
              isApplied: true,
              isCurrentScene: false,
              onAdd: () {},
              onRemove: () => removals++,
            ),
          ),
        ),
      ),
    );
    final scrollable = find.byType(Scrollable);
    final position = tester.state<ScrollableState>(scrollable).position;
    position.jumpTo(position.maxScrollExtent);
    await tester.pump();
    final button = find.text(t.ccos.first_pow_scene.remove_button);
    final badge = find.text(t.ccos.first_pow_scene.status_applied);
    expect(button.hitTestable(), findsOneWidget);
    expect(tester.getRect(badge).top, greaterThanOrEqualTo(tester.getRect(scrollable).top));
    expect(tester.getRect(badge).bottom, lessThanOrEqualTo(tester.getRect(scrollable).bottom));
    await tester.tap(button);
    await tester.pump();
    expect(removals, 1);
    expect(tester.takeException(), isNull);
  });

  for (final (viewport, scale, locale) in [
    (const Size(320, 568), 2.0, AppLocale.ko),
    (const Size(375, 667), 2.0, AppLocale.ko),
    (const Size(414, 896), 1.0, AppLocale.ko),
    (const Size(320, 568), 2.0, AppLocale.en),
    (const Size(375, 667), 2.0, AppLocale.en),
    (const Size(414, 896), 1.0, AppLocale.en),
  ]) {
    for (final status in ['new', 'added', 'applied']) {
      testWidgets('feature detail CTA stays inside viewport: $viewport $scale ${locale.languageCode} $status', (
        tester,
      ) async {
        LocaleSettings.setLocaleSync(locale);
        addTearDown(() => LocaleSettings.setLocaleSync(AppLocale.ko));
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = viewport;
        tester.view.padding = const FakeViewPadding(top: 20, bottom: 34);
        tester.view.viewPadding = const FakeViewPadding(top: 20, bottom: 34);
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final preferences = _Preferences(isAdded: status != 'new', isApplied: status == 'applied');
        addTearDown(preferences.dispose);
        var additions = 0;
        var removals = 0;
        await tester.pumpWidget(
          RepaintBoundary(
            key: _captureKey,
            child: MultiProvider(
              providers: [
                ChangeNotifierProvider<PreferenceProvider>.value(value: preferences),
                Provider<AnalyticsService>.value(value: AnalyticsService(null, true)),
              ],
              child: MaterialApp(
                theme: buildCoconutThemeData().copyWith(platform: TargetPlatform.iOS),
                home: Scaffold(
                  body: Padding(
                    padding: const EdgeInsets.all(24),
                    child: FirstPowSceneBody(
                      animation: const AlwaysStoppedAnimation(1),
                      sceneDurationMs: FirstPowSceneBody.baseDurationMs,
                      listing: CcosFeatureRegistrySource.featuredListing,
                      isAdded: preferences.isAdded,
                      isApplied: preferences.isApplied,
                      isCurrentScene: false,
                      onAdd: () {
                        additions++;
                        preferences.setAdded(true);
                      },
                      onRemove: () {
                        removals++;
                        preferences.setAdded(false);
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.runAsync(() async {
          final context = tester.element(find.byType(FirstPowSceneBody));
          for (final name in ['creator', 'feature', 'delivery']) {
            await precacheImage(AssetImage('assets/images/ccos/$name.png'), context);
          }
        });
        final feature = find.byWidgetPredicate(
          (widget) =>
              widget is Image &&
              widget.image is AssetImage &&
              (widget.image as AssetImage).assetName == 'assets/images/ccos/feature.png',
        );
        await tester.tap(feature.hitTestable());
        await tester.pump();
        // Drive the full entrance sequence; the preview's floating animation never settles.
        await tester.pumpFrames(
          tester.widget(find.byKey(_captureKey)),
          const Duration(seconds: 7),
          const Duration(milliseconds: 100),
        );
        final detail = _type('_FirstPowDetailScreen');
        final button = find.descendant(of: detail, matching: _type('_AddThemeButton'));
        final badge = find.descendant(of: detail, matching: _type('_AddedGlassBadge'));
        final content = find.descendant(of: detail, matching: find.byType(SingleChildScrollView));

        Future<void> checkBounds(String step) async {
          expect(tester.takeException(), isNull);
          final buttonRect = tester.getRect(button);
          final badgeRect = preferences.isAdded ? tester.getRect(badge) : null;
          final ctaRect = badgeRect == null ? buttonRect : buttonRect.expandToInclude(badgeRect);
          final name =
              '${viewport.width.toInt()}x${viewport.height.toInt()}-$scale-${locale.languageCode}-$status-$step';
          await _capture(tester, 'detail-cta-$name');
          debugPrint('Detail CTA $name: button=$buttonRect badge=$badgeRect content=${tester.getRect(content)}');
          expect(buttonRect.width, greaterThan(0));
          expect(buttonRect.height, greaterThan(0));
          expect(ctaRect.left, greaterThanOrEqualTo(0), reason: 'Complete CTA/badge must fit: $ctaRect');
          expect(ctaRect.right, lessThanOrEqualTo(viewport.width));
          expect(ctaRect.top, greaterThanOrEqualTo(20));
          expect(ctaRect.bottom, lessThanOrEqualTo(viewport.height - 34));
          expect(tester.getRect(content).bottom, lessThanOrEqualTo(ctaRect.top));
          final label = preferences.isAdded ? t.ccos.first_pow_scene.remove_button : t.ccos.first_pow_scene.add_button;
          expect(find.descendant(of: button, matching: find.text(label)).hitTestable(), findsOneWidget);
          if (preferences.isAdded) {
            final badgeLabel =
                preferences.isApplied ? t.ccos.first_pow_scene.status_applied : t.ccos.first_pow_scene.status_added;
            expect(find.descendant(of: badge, matching: find.text(badgeLabel)), findsOneWidget);
          } else {
            expect(badge, findsNothing);
          }
        }

        await checkBounds('initial');
        for (var tap = 0; tap < 2; tap++) {
          await tester.tap(find.descendant(of: button, matching: find.byType(InkWell)));
          await tester.pump();
          await tester.pump(const Duration(seconds: 2));
          await checkBounds('tap-${tap + 1}');
        }
        expect(additions, 1);
        expect(removals, 1);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
