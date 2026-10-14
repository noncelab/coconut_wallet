import 'dart:ui' as ui;

import 'package:coconut_wallet/ccos/ccos_feature_runtime.dart';
import 'package:coconut_wallet/ccos/open_store/coconut_open_store_navigation.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/screens/ccos/coconut_open_store_intro_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

const _previousScreenColor = Color(0xFF17B83D);
const _loadingKey = ValueKey('open-store-loading');
const _storyKey = ValueKey('open-store-story');
const _captureKey = ValueKey('capture');

class _Preferences extends Fake with ChangeNotifier implements PreferenceProvider {
  @override
  CoconutThemeVariant get themeVariant => CoconutThemeVariant.dark;

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
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(414, 896);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  final preferences = _Preferences();
  addTearDown(preferences.dispose);
  final routes = _Routes();
  await tester.pumpWidget(
    RepaintBoundary(
      key: _captureKey,
      child: ChangeNotifierProvider<PreferenceProvider>.value(
        value: preferences,
        child: MaterialApp(
          theme: buildCoconutThemeData().copyWith(platform: platform),
          navigatorObservers: [routes],
          builder:
              (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(disableAnimations: disableAnimations),
                child: child!,
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
