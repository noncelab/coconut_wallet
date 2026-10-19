import 'dart:ui' as ui;
import 'dart:io';

import 'package:coconut_wallet/localization/strings.g.dart';

import 'package:coconut_wallet/ccos/ccos_feature_runtime.dart';
import 'package:coconut_wallet/ccos/ccos_feature_registry.dart';
import 'package:coconut_wallet/ccos/open_store/coconut_open_store_navigation.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/screens/ccos/coconut_open_store_intro_screen.dart';
import 'package:coconut_wallet/screens/ccos/coconut_open_store_build_scene.dart';
import 'package:coconut_wallet/screens/ccos/coconut_open_store_first_pow_scene.dart';
import 'package:coconut_wallet/widgets/common/buttons/coconut_icon_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

const _previousScreenColor = Color(0xFF17B83D);
const _loadingKey = ValueKey('open-store-loading');
const _storyKey = ValueKey('open-store-story');
const _captureKey = ValueKey('capture');

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

class _Routes extends NavigatorObserver {
  Route<void>? intro;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (previousRoute != null) intro = route as Route<void>;
  }
}

Future<_Routes> _pumpHost(
  WidgetTester tester, {
  TargetPlatform platform = TargetPlatform.iOS,
  bool disableAnimations = false,
  ValueNotifier<bool>? motionSetting,
  CoconutThemeVariant variant = CoconutThemeVariant.dark,
  double textScale = 1,
  Size viewport = const Size(414, 896),
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = viewport;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  final preferences = _Preferences(variant);
  addTearDown(preferences.dispose);
  final motion = motionSetting ?? ValueNotifier(disableAnimations);
  if (motionSetting == null) addTearDown(motion.dispose);
  final routes = _Routes();
  await tester.pumpWidget(
    RepaintBoundary(
      key: _captureKey,
      child: ChangeNotifierProvider<PreferenceProvider>.value(
        value: preferences,
        child: MaterialApp(
          theme: buildCoconutThemeData(variant: variant).copyWith(platform: platform),
          navigatorObservers: [routes],
          builder:
              (context, child) => ValueListenableBuilder<bool>(
                valueListenable: motion,
                builder:
                    (context, reduced, _) => MediaQuery(
                      data: MediaQuery.of(
                        context,
                      ).copyWith(disableAnimations: reduced, textScaler: TextScaler.linear(textScale)),
                      child: child!,
                    ),
              ),
          home: Builder(
            builder:
                (context) => Scaffold(
                  backgroundColor: _previousScreenColor,
                  body: Align(
                    alignment: Alignment.topCenter,
                    child: TextButton(
                      key: const ValueKey('open-store'),
                      onPressed: () => openCoconutOpenStoreIntroScreen(context),
                      child: const Text('Open Store'),
                    ),
                  ),
                ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const ValueKey('open-store')));
  await tester.pump();
  await tester.pump();
  return routes;
}

Animation<double> _loadingAnimation(WidgetTester tester) {
  final builder = tester.widget<AnimatedBuilder>(
    find.descendant(of: find.byKey(_loadingKey), matching: find.byType(AnimatedBuilder)).first,
  );
  return builder.listenable as Animation<double>;
}

Future<void> _finishPush(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 1));
  await tester.pump();
}

Future<TestGesture> _beginBack(WidgetTester tester, double distance) async {
  final gesture = await tester.startGesture(const Offset(1, 400));
  await gesture.moveBy(Offset(distance, 0), timeStamp: const Duration(milliseconds: 250));
  await tester.pump();
  return gesture;
}

void main() {
  setUpAll(() async {
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
  });

  for (final variant in CoconutThemeVariant.values) {
    for (final width in [320.0, 344.38]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('overview numbers and copy never overlap $variant width=$width scale=$scale', (tester) async {
          await _pumpHost(
            tester,
            variant: variant,
            disableAnimations: true,
            textScale: scale,
            viewport: Size(width, 882.29),
          );
          await _finishPush(tester);
          await tester.pump(const Duration(seconds: 2));
          await tester.tap(find.byType(CoconutAppBarActionButton).last);
          await tester.pump(const Duration(seconds: 2));
          await tester.pump();
          final titles = [
            t.ccos.intro_screen.scenes.idea.overview_title,
            t.ccos.intro_screen.scenes.build.overview_title,
            t.ccos.intro_screen.scenes.first_pow.overview_title,
            t.ccos.intro_screen.scenes.discover.overview_title,
            t.ccos.intro_screen.scenes.contribute.overview_title,
          ];
          for (var index = 0; index < titles.length; index++) {
            final step = (index + 1).toString().padLeft(2, '0');
            final number = find.text(step);
            await tester.scrollUntilVisible(number, 250, scrollable: find.byType(Scrollable).last);
            await tester.pump(const Duration(seconds: 1));
            final copy = find.byWidgetPredicate(
              (widget) => widget is RichText && widget.text.toPlainText() == titles[index],
            );
            expect(copy, findsOneWidget);
            final numberRect = tester.getRect(number);
            final copyRect = tester.getRect(copy);
            final overview = find.byKey(const ValueKey('open-store-overview-list'));
            final close = find.byKey(const ValueKey('open-store-overview-close'));
            expect(tester.getRect(overview).top, greaterThanOrEqualTo(tester.getRect(close).bottom));
            expect(tester.widget<ListView>(overview).clipBehavior, isNot(Clip.none));
            final evidence = Platform.environment['CCOS_OVERVIEW_EVIDENCE_DIR'];
            if (evidence != null) {
              final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(_captureKey));
              await tester.runAsync(() async {
                final image = await boundary.toImage();
                try {
                  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
                  Directory(evidence).createSync(recursive: true);
                  File(
                    '$evidence/${variant.name}-$width-$scale-$step.png',
                  ).writeAsBytesSync(bytes!.buffer.asUint8List());
                } finally {
                  image.dispose();
                }
              });
            }
            expect(
              numberRect.bottom,
              lessThanOrEqualTo(copyRect.top),
              reason: 'Chapter$step numeric ink must precede readable copy',
            );
            final paragraph = tester.renderObject<RenderParagraph>(copy);
            expect(
              paragraph.textScaler.scale(18),
              closeTo(18 * scale, .01),
              reason: 'Overview copy respects user text scale',
            );
            expect(copyRect.left, greaterThanOrEqualTo(0));
            expect(copyRect.right, lessThanOrEqualTo(width));
            expect(tester.takeException(), isNull);
          }
        });
      }
    }
  }

  for (final variant in CoconutThemeVariant.values) {
    for (final reduced in [false, true]) {
      for (final textScale in [1.0, 2.0]) {
        testWidgets(
          'all five settled scene copy and counters have rendered contrast: $variant reduced=$reduced scale=$textScale',
          (tester) async {
            await _pumpHost(tester, variant: variant, disableAnimations: reduced, textScale: textScale);
            await _finishPush(tester);
            await tester.pump(const Duration(seconds: 10));
            await tester.pump(const Duration(seconds: 60));
            await tester.pump(const Duration(seconds: 5));
            final lines = [
              t.ccos.idea_scene.line1,
              t.ccos.build_scene.line1,
              t.ccos.first_pow_scene.intro_line1,
              t.ccos.discover_scene.line1,
              t.ccos.contribute_scene.line1,
            ];
            for (var scene = 0; scene < 5; scene++) {
              final counter = find.text('${(scene + 1).toString().padLeft(2, '0')} / 05');
              expect(counter, findsOneWidget);
              final copy = find.byWidgetPredicate(
                (widget) => widget is RichText && widget.text.toPlainText().replaceAll('\u2060', '') == lines[scene],
              );
              expect(copy, findsOneWidget, reason: 'Scene $scene actual settled body copy');
              final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(_captureKey));
              final bytes = await tester.runAsync(() async {
                final image = await boundary.toImage(pixelRatio: 1);
                try {
                  final evidenceDir = Platform.environment['CCOS_CONTRAST_EVIDENCE_DIR'];
                  if (evidenceDir != null) {
                    final directory = Directory(evidenceDir)..createSync(recursive: true);
                    final png = await image.toByteData(format: ui.ImageByteFormat.png);
                    File(
                      '${directory.path}/${variant.name}-reduced-$reduced-scale-$textScale-scene-$scene.png',
                    ).writeAsBytesSync(png!.buffer.asUint8List());
                  }
                  return await image.toByteData(format: ui.ImageByteFormat.rawRgba);
                } finally {
                  image.dispose();
                }
              });
              final targets = [counter, copy];
              if (scene == 1) {
                targets.addAll(
                  [
                    t.ccos.build_scene.orbit.widget,
                    t.ccos.build_scene.orbit.theme,
                    t.ccos.build_scene.orbit.analysis,
                    t.ccos.build_scene.orbit.tool,
                    t.ccos.build_scene.orbit.layer2,
                    t.ccos.build_scene.orbit.backup,
                  ].map(find.text),
                );
              }
              for (final target in targets) {
                final rect = tester.getRect(target);
                var darkest = 1.0;
                var lightest = 0.0;
                for (var y = rect.top.ceil(); y < rect.bottom.floor().clamp(0, 896); y++) {
                  for (var x = rect.left.ceil().clamp(0, 413); x < rect.right.floor().clamp(0, 414); x++) {
                    final offset = (y * 414 + x) * 4;
                    final luminance =
                        Color.fromARGB(
                          255,
                          bytes!.getUint8(offset),
                          bytes.getUint8(offset + 1),
                          bytes.getUint8(offset + 2),
                        ).computeLuminance();
                    if (luminance < darkest) darkest = luminance;
                    if (luminance > lightest) lightest = luminance;
                  }
                }
                final contrast = (lightest + .05) / (darkest + .05);
                debugPrint(
                  'CCOS pixel contrast: ${variant.name} reduced=$reduced scale=$textScale scene=$scene ratio=$contrast',
                );
                expect(
                  contrast,
                  greaterThanOrEqualTo(4.5),
                  reason: 'Actual composited glyph/background pixels in scene $scene',
                );
              }
              if (scene < 4) {
                await tester.tap(find.byIcon(Icons.arrow_forward_rounded));
                await tester.pump();
                await tester.pump(const Duration(seconds: 1));
                await tester.pump(const Duration(seconds: 60));
                await tester.pump(const Duration(seconds: 5));
              }
            }
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets('$platform waits for the route to enter before playing the intro', (tester) async {
      final routes = await _pumpHost(tester, platform: platform);
      final route = routes.intro! as TransitionRoute<void>;
      expect(route.animation!.status, AnimationStatus.forward);
      expect(_loadingAnimation(tester).value, 0);

      await tester.pump(route.transitionDuration ~/ 2);
      expect(route.animation!.status, AnimationStatus.forward);
      expect(_loadingAnimation(tester).value, 0, reason: 'The native page transition owns entry motion.');

      await _finishPush(tester);
      expect(route.animation!.status, AnimationStatus.completed);
      final intro = find.byType(CoconutOpenStoreIntroScreen);
      expect(find.descendant(of: intro, matching: find.byType(AppBar)), findsNothing);
      expect(find.byKey(const ValueKey('open-store-back')), findsNothing);
      expect(find.byKey(const ValueKey('open-store-skip')), findsNothing);
      expect(find.descendant(of: intro, matching: find.byType(TextButton)), findsNothing);
      expect(find.descendant(of: intro, matching: find.byType(IconButton)), findsNothing);
      expect(
        tester.getRect(find.byKey(_loadingKey)),
        tester.getRect(intro),
        reason: 'The original intro uses the entire page without a toolbar.',
      );
      await tester.pump(const Duration(milliseconds: 600));
      expect(_loadingAnimation(tester).value, greaterThan(0));
      expect(tester.takeException(), isNull);
    });

    testWidgets('$platform can return immediately without completing the intro', (tester) async {
      final routes = await _pumpHost(tester, platform: platform);
      routes.intro!.navigator!.pop();
      await tester.pumpAndSettle();
      expect(find.byType(CoconutOpenStoreIntroScreen), findsNothing);
      expect(find.byKey(const ValueKey('open-store')), findsOneWidget);
      await tester.pump(const Duration(seconds: 8));
      expect(tester.takeException(), isNull, reason: 'A disposed intro must not receive route or ticker callbacks.');
    });

    testWidgets('$platform finishes the intro and presents the story without interaction', (tester) async {
      await _pumpHost(tester, platform: platform);
      await _finishPush(tester);
      await tester.pump(const Duration(seconds: 6));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      expect(find.byKey(_loadingKey), findsNothing);
      expect(find.byKey(_storyKey), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('the story retains its working app-bar back action after the intro', (tester) async {
    await _pumpHost(tester);
    await _finishPush(tester);
    await tester.pump(const Duration(seconds: 6));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(find.byKey(_loadingKey), findsNothing);
    expect(find.byKey(_storyKey), findsOneWidget);
    final appBar = find.byType(AppBar);
    expect(appBar, findsOneWidget);
    await tester.tap(find.descendant(of: appBar, matching: find.byType(IconButton)).first);
    await tester.pumpAndSettle();
    expect(find.byType(CoconutOpenStoreIntroScreen), findsNothing);
    expect(find.byKey(const ValueKey('open-store')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion enters the story without the giant logo animation', (tester) async {
    await _pumpHost(tester, disableAnimations: true);
    await _finishPush(tester);
    expect(find.byKey(_loadingKey), findsNothing);
    expect(find.byKey(_storyKey), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('story decorative loops stop and resume when reduced motion changes', (tester) async {
    final motion = ValueNotifier(true);
    addTearDown(motion.dispose);
    await _pumpHost(tester, motionSetting: motion);
    await _finishPush(tester);
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 40),
    );
    expect(find.byKey(_storyKey), findsOneWidget);
    expect(tester.binding.transientCallbackCount, 0);
    motion.value = false;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.binding.transientCallbackCount, greaterThan(0));
    motion.value = true;
    await tester.pumpAndSettle();
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('First PoW wiggle stops live and does not resume on an inactive scene', (tester) async {
    final motion = ValueNotifier(false);
    final current = ValueNotifier(true);
    addTearDown(motion.dispose);
    addTearDown(current.dispose);
    tester.view.physicalSize = const Size(414, 896);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder<bool>(
          valueListenable: motion,
          builder:
              (context, reduced, child) =>
                  MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: reduced), child: child!),
          child: ValueListenableBuilder<bool>(
            valueListenable: current,
            builder:
                (context, active, _) => Scaffold(
                  body: FirstPowSceneBody(
                    animation: const AlwaysStoppedAnimation(1),
                    sceneDurationMs: 11000,
                    listing: CcosFeatureRegistrySource.featuredListing,
                    isAdded: false,
                    isApplied: false,
                    isCurrentScene: active,
                    onAdd: () {},
                    onRemove: () {},
                  ),
                ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.binding.transientCallbackCount, greaterThan(0));
    motion.value = true;
    await tester.pumpAndSettle();
    expect(tester.binding.transientCallbackCount, 0);
    current.value = false;
    motion.value = false;
    await tester.pumpAndSettle();
    expect(tester.binding.transientCallbackCount, 0);
    current.value = true;
    await tester.pump();
    expect(tester.binding.transientCallbackCount, greaterThan(0));
  });

  testWidgets('Build hero stops both decorative controllers when accessibility changes', (tester) async {
    final motion = ValueNotifier(false);
    addTearDown(motion.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder<bool>(
          valueListenable: motion,
          builder:
              (context, reduced, child) =>
                  MediaQuery(data: MediaQuery.of(context).copyWith(accessibleNavigation: reduced), child: child!),
          child: const Scaffold(body: BuildSceneBody(animation: AlwaysStoppedAnimation(1))),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.binding.transientCallbackCount, greaterThan(0));
    motion.value = true;
    await tester.pumpAndSettle();
    expect(tester.binding.transientCallbackCount, 0);
    motion.value = false;
    await tester.pump();
    expect(tester.binding.transientCallbackCount, greaterThan(0));
  });

  testWidgets('a completed iOS edge swipe returns while the logo is still animating', (tester) async {
    final routes = await _pumpHost(tester);
    await _finishPush(tester);
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byKey(_loadingKey), findsOneWidget);
    final gesture = await _beginBack(tester, 300);
    expect(routes.intro!.navigator!.userGestureInProgress, isTrue);
    await gesture.up(timeStamp: const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
    expect(find.byType(CoconutOpenStoreIntroScreen), findsNothing);
    expect(find.byKey(const ValueKey('open-store')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a canceled iOS edge swipe retains progress and naturally reaches the story', (tester) async {
    final routes = await _pumpHost(tester);
    await _finishPush(tester);
    await tester.pump(const Duration(milliseconds: 700));
    final progressBefore = _loadingAnimation(tester).value;
    final gesture = await _beginBack(tester, 100);
    expect(routes.intro!.navigator!.userGestureInProgress, isTrue);
    await gesture.up(timeStamp: const Duration(milliseconds: 700));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(routes.intro!.isCurrent, isTrue);
    expect(routes.intro!.navigator!.userGestureInProgress, isFalse);
    expect(_loadingAnimation(tester).value, greaterThanOrEqualTo(progressBefore));
    await tester.pump(const Duration(seconds: 6));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(find.byKey(_loadingKey), findsNothing);
    expect(find.byKey(_storyKey), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the oversized logo cannot paint into the revealed previous screen during an iOS swipe', (tester) async {
    await _pumpHost(tester);
    await _finishPush(tester);
    final gesture = await _beginBack(tester, 170);
    try {
      final storeRect = tester.getRect(find.byType(CoconutOpenStoreIntroScreen));
      expect(storeRect.left, greaterThan(100), reason: 'The assertion must run during an actual interactive pop.');
      final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(_captureKey));
      final bytes = await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1);
        try {
          return await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        } finally {
          image.dispose();
        }
      });
      expect(bytes, isNotNull);
      var mismatchedPixels = 0;
      var sampledPixels = 0;
      // Leave room for the native page edge shadow and the previous screen's header.
      for (var y = 180; y < 710; y += 4) {
        for (var x = 20; x < storeRect.left.floor() - 24; x += 4) {
          final offset = (y * 414 + x) * 4;
          final actual = Color.fromARGB(
            bytes!.getUint8(offset + 3),
            bytes.getUint8(offset),
            bytes.getUint8(offset + 1),
            bytes.getUint8(offset + 2),
          );
          sampledPixels++;
          if (actual != _previousScreenColor) mismatchedPixels++;
        }
      }
      expect(sampledPixels, greaterThan(1000));
      expect(mismatchedPixels, 0, reason: 'Only the previous screen may paint in the exposed area.');
    } finally {
      await gesture.up(timeStamp: const Duration(milliseconds: 700));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    }
    expect(tester.takeException(), isNull);
  });
}
