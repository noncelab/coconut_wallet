import 'dart:io';

import 'package:coconut_wallet/ccos/ccos_feature_registry.dart';
import 'package:coconut_wallet/ccos/ccos_feature_runtime.dart';
import 'package:coconut_wallet/ccos/open_store/coconut_open_store_navigation.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/screens/ccos/coconut_open_store_first_pow_scene.dart';
import 'package:coconut_wallet/screens/ccos/coconut_open_store_discover_screen.dart';
import 'package:coconut_wallet/screens/ccos/coconut_open_store_contribute_screen.dart';
import 'package:coconut_wallet/screens/ccos/coconut_open_store_scene_viewport.dart';
import 'package:coconut_wallet/widgets/common/side_safe_area.dart';
import 'package:coconut_wallet/screens/ccos/coconut_open_store_intro_screen.dart';
import 'package:coconut_wallet/services/analytics_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// Outer iPhone Duo display from the grouped-followup IOS_TUI009 run
/// (logical 466x678, DPR 3, padding top 0, bottom 34, right inset 84,
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

void _applyView(
  WidgetTester tester, {
  required Size logical,
  required double dpr,
  required double bottomPadding,
  double sideInset = 0,
  double topPadding = 0,
}) {
  tester.view.devicePixelRatio = dpr;
  tester.view.physicalSize = Size(logical.width * dpr, logical.height * dpr);
  final bottom = bottomPadding * dpr;
  const zero = FakeViewPadding();
  final padding = FakeViewPadding(bottom: bottom, right: sideInset * dpr, top: topPadding * dpr);
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
  double sideInset = 0,
  double topPadding = 0,
  CoconutThemeVariant variant = CoconutThemeVariant.dark,
}) async {
  _applyView(
    tester,
    logical: logical,
    dpr: dpr,
    bottomPadding: bottomPadding,
    sideInset: sideInset,
    topPadding: topPadding,
  );
  addTearDown(tester.view.reset);
  final preferences = _Preferences(variant);
  addTearDown(preferences.dispose);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<PreferenceProvider>.value(value: preferences),
        Provider<AnalyticsService>.value(value: AnalyticsService(null, true)),
      ],
      child: MaterialApp(
        theme: buildCoconutThemeData(variant: variant).copyWith(platform: TargetPlatform.iOS),
        builder:
            (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                disableAnimations: true,
                platformBrightness: Brightness.dark,
                textScaler: TextScaler.linear(textScale),
              ),
              child: SideSafeArea(child: child!),
            ),
        home: Builder(
          builder:
              (context) => Scaffold(
                body: Center(
                  child: TextButton(
                    onPressed: () => openCoconutOpenStoreIntroScreen(context),
                    child: const Text('Open Store'),
                  ),
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
  // Advance past the longest translated typewriter so both
  // lines are fully laid out, which is the tallest return-path frame.
  await tester.pump(const Duration(seconds: 30));
  return _drain(tester);
}

Finder _button(String label) => find.ancestor(of: find.text(label), matching: find.byType(InkWell)).first;

void _expectPaintWithinClips(RenderBox box, {bool vertical = false, bool horizontal = true}) {
  RenderObject child = box;
  while (child.parent != null) {
    final parent = child.parent!;
    final clip =
        parent is RenderClipRect && parent.clipBehavior != Clip.none
            ? parent.clipper?.getClip(parent.size) ?? Offset.zero & parent.size
            : parent.describeApproximatePaintClip(child);
    if (clip != null) {
      final painted = MatrixUtils.transformRect(box.getTransformTo(parent), box.paintBounds);
      if (horizontal) {
        expect(painted.left, greaterThanOrEqualTo(clip.left - 0.5), reason: '$box clipped by $parent');
        expect(painted.right, lessThanOrEqualTo(clip.right + 0.5), reason: '$box clipped by $parent');
      }
      if (vertical) {
        expect(painted.top, greaterThanOrEqualTo(clip.top - 0.5), reason: '$box clipped by $parent');
        expect(painted.bottom, lessThanOrEqualTo(clip.bottom + 0.5), reason: '$box clipped by $parent');
      }
    }
    child = parent;
  }
}

Future<void> _expectReachable(WidgetTester tester, Finder target, Finder viewport) async {
  final box = tester.renderObject<RenderBox>(target);
  // Reveal vertically without shifting the containing horizontal story pager.
  await Scrollable.maybeOf(tester.element(target), axis: Axis.vertical)?.position.ensureVisible(box);
  await tester.pump();
  expect(target.hitTestable(), findsOneWidget);
  final bounds = tester.getRect(viewport);
  final rect = MatrixUtils.transformRect(box.getTransformTo(null), box.paintBounds);
  expect(rect.top, greaterThanOrEqualTo(bounds.top - 0.5));
  expect(rect.bottom, lessThanOrEqualTo(bounds.bottom + 0.5));
  final screen = Offset.zero & (tester.view.physicalSize / tester.view.devicePixelRatio);
  expect(rect.left, greaterThanOrEqualTo(screen.left - 0.5));
  expect(rect.right, lessThanOrEqualTo(screen.right + 0.5));
  // Layout rectangles miss scaled/translated ink and viewport clipping. Follow
  // every actual paint clip, allowing the original horizontal scene gutter.
  _expectPaintWithinClips(box);
}

void main() {
  setUpAll(() async {
    LocaleSettings.setLocaleSync(AppLocale.ko);
    await _loadFonts();
  });
  setUp(() => LocaleSettings.setLocaleSync(AppLocale.ko));
  tearDown(() => LocaleSettings.setLocaleSync(AppLocale.ko));

  testWidgets('scene scrolls independently of the PrimaryScrollController on iOS', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.iOS),
        home: Scaffold(
          body: PrimaryScrollController(
            controller: controller,
            child: const Center(
              child: SizedBox(
                width: 200,
                height: 100,
                child: CcosSceneViewport(height: 100, child: SizedBox(height: 200)),
              ),
            ),
          ),
        ),
      ),
    );
    expect(PrimaryScrollController.of(tester.element(find.byType(CcosSceneViewport))), same(controller));
    expect(controller.hasClients, isFalse);
    final state = tester.state<ScrollableState>(find.byType(Scrollable));
    expect(state.position.maxScrollExtent, 100);
    await tester.drag(find.byType(CcosSceneViewport), const Offset(0, -50));
    await tester.pumpAndSettle();
    expect(state.position.pixels, greaterThan(0));
    expect(controller.hasClients, isFalse);
    expect(_drain(tester), isEmpty);
  });

  testWidgets('viewport clips only overflowing content without a delayed fitting frame', (tester) async {
    final contentHeight = ValueNotifier(100.0);
    addTearDown(contentHeight.dispose);
    const ink = ValueKey('paint-above-scene');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 200,
              height: 100,
              child: CcosSceneViewport(
                height: 100,
                child: ValueListenableBuilder<double>(
                  valueListenable: contentHeight,
                  builder:
                      (context, height, child) => SizedBox(
                        height: height,
                        child: const Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Positioned(
                              top: -8,
                              left: 0,
                              width: 12,
                              height: 12,
                              child: ColoredBox(key: ink, color: Colors.red),
                            ),
                          ],
                        ),
                      ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    for (final height in [100.0, 180.0, 100.0]) {
      contentHeight.value = height;
      await tester.pump();
      final state = tester.state<ScrollableState>(find.byType(Scrollable));
      expect(state.position.maxScrollExtent, height - 100);
      final box = tester.renderObject<RenderBox>(find.byKey(ink));
      var clippedAbove = false;
      RenderObject child = box;
      while (child.parent != null) {
        final parent = child.parent!;
        final clip = parent.describeApproximatePaintClip(child);
        final painted = MatrixUtils.transformRect(box.getTransformTo(parent), box.paintBounds);
        if (clip != null && painted.top < clip.top) clippedAbove = true;
        child = parent;
      }
      expect(clippedAbove, height > 100, reason: 'The very first paint must use the current content extent');
    }
    expect(_drain(tester), isEmpty);
  });

  testWidgets('fitting first-pow paints photo tips and CTA bounce beyond the scene on the same frame', (tester) async {
    await _pumpIntro(tester, logical: const Size(414, 896), dpr: 3, bottomPadding: 34, topPadding: 62, textScale: 1);
    expect(await _showFirstPow(tester), isEmpty);
    final scene = find.byType(FirstPowSceneBody);
    final sceneRect = tester.getRect(scene);
    final body = tester.widget<FirstPowSceneBody>(scene);
    final controller = body.animation as AnimationController;
    final scrollable = tester.state<ScrollableState>(
      find.descendant(of: scene, matching: find.byType(Scrollable)).first,
    );
    final cards = find.descendant(of: scene, matching: find.byType(GestureDetector));
    var tipsAboveScene = 0;
    for (final element in cards.evaluate()) {
      final box = element.renderObject! as RenderBox;
      final painted = MatrixUtils.transformRect(box.getTransformTo(null), box.paintBounds);
      if (painted.top < sceneRect.top) {
        tipsAboveScene++;
        _expectPaintWithinClips(box, vertical: true, horizontal: false);
      }
    }
    expect(tipsAboveScene, greaterThan(0), reason: 'The original rotated photo tips extend above the body');
    final ctaStart = FirstPowSceneBody.ctaStartMs([
      t.ccos.first_pow_scene.intro_line1,
      t.ccos.first_pow_scene.intro_line2,
    ]);
    controller.value = (ctaStart + FirstPowSceneBody.buttonEntranceMs * 0.15) / body.sceneDurationMs;
    await tester.pump();
    expect(scrollable.position.maxScrollExtent, 0);
    final button = tester.renderObject<RenderBox>(_button(t.ccos.first_pow_scene.add_button));
    final painted = MatrixUtils.transformRect(button.getTransformTo(null), button.paintBounds);
    expect(painted.bottom, greaterThan(sceneRect.bottom), reason: 'Exercise the original elastic CTA overshoot');
    _expectPaintWithinClips(button, vertical: true);
    expect(_drain(tester), isEmpty);
  });

  testWidgets('German first-pow CTA at 1.6 on iPhone 17 keeps its original right alignment', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      LocaleSettings.setLocaleSync(AppLocale.de);
      await _pumpIntro(
        tester,
        logical: const Size(402, 874),
        dpr: 3,
        bottomPadding: 34,
        topPadding: 62,
        textScale: 1.6,
      );
      expect(await _showFirstPow(tester), isEmpty);
      final scene = find.byType(FirstPowSceneBody);
      final button = _button(t.ccos.first_pow_scene.add_button);
      final buttonRect = tester.getRect(button);
      final sceneRect = tester.getRect(scene);
      expect(buttonRect.width, greaterThan(sceneRect.width), reason: 'Exercise the unbounded original CTA row');
      expect(buttonRect.right, closeTo(sceneRect.right, 0.01));
      final node = tester.getSemantics(button);
      var semanticsRect = node.rect;
      for (var current = node; ; current = current.parent!) {
        if (current.transform != null) semanticsRect = MatrixUtils.transformRect(current.transform!, semanticsRect);
        if (current.parent == null) break;
      }
      // The root semantics transform includes the view's physical pixel scale.
      final dpr = tester.view.devicePixelRatio;
      semanticsRect = Rect.fromLTRB(
        semanticsRect.left / dpr,
        semanticsRect.top / dpr,
        semanticsRect.right / dpr,
        semanticsRect.bottom / dpr,
      );
      expect(semanticsRect.left, lessThanOrEqualTo(buttonRect.left + 0.01));
      expect(semanticsRect.right, greaterThanOrEqualTo(buttonRect.right - 0.01));
      expect(semanticsRect.top, lessThanOrEqualTo(buttonRect.top + 0.01));
      expect(semanticsRect.bottom, greaterThanOrEqualTo(buttonRect.bottom - 0.01));
      await _expectReachable(tester, button, scene);
      _expectCopyClearsAddButton(tester);
      expect(_drain(tester), isEmpty);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('German Discover on SE keeps transformed horizontal ink visible while scrolling', (tester) async {
    LocaleSettings.setLocaleSync(AppLocale.de);
    await _pumpIntro(tester, logical: const Size(375, 667), dpr: 2, bottomPadding: 0, topPadding: 20, textScale: 1);
    await _showFirstPow(tester);
    await tester.tap(find.byIcon(Icons.arrow_forward_rounded).hitTestable().first);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 30));
    expect(_drain(tester), isEmpty);
    final scene = find.byType(DiscoverSceneBody);
    final scrollable = tester.state<ScrollableState>(
      find.descendant(of: scene, matching: find.byType(Scrollable)).first,
    );
    expect(scrollable.position.maxScrollExtent, greaterThan(0));
    final lastLine = _introLine(t.ccos.discover_scene.line3);
    await _expectReachable(tester, lastLine, scene);
    final paragraph = tester.renderObject<RenderParagraph>(lastLine);
    final ink = MatrixUtils.transformRect(paragraph.getTransformTo(null), paragraph.paintBounds);
    expect(ink.left, lessThan(tester.getRect(scene).left), reason: 'Exercise the horizontal animation gutter');
    for (final line in [t.ccos.discover_scene.line1, t.ccos.discover_scene.line2, t.ccos.discover_scene.line3]) {
      await _expectReachable(tester, _introLine(line), scene);
    }
    expect(_drain(tester), isEmpty);
  });

  testWidgets('Duo outer display lays out the full first-pow copy without a bottom overflow', (tester) async {
    await _pumpIntro(
      tester,
      logical: _duoLogical,
      dpr: _duoDpr,
      bottomPadding: _duoBottomPadding,
      textScale: 1,
      sideInset: 84,
    );
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
    expect(find.descendant(of: find.byType(FirstPowSceneBody), matching: find.byType(Scrollable)), findsOneWidget);

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
    await _expectReachable(tester, _button(t.ccos.first_pow_scene.add_button), find.byType(FirstPowSceneBody));
  });

  testWidgets('Duo outer display keeps large text and the add button inside the scene', (tester) async {
    await _pumpIntro(
      tester,
      logical: _duoLogical,
      dpr: _duoDpr,
      bottomPadding: _duoBottomPadding,
      textScale: 1.3,
      sideInset: 84,
    );
    _drain(tester);
    final duringScene = await _showFirstPow(tester);
    expect(duringScene.where((message) => message.contains('RenderFlex')), isEmpty, reason: duringScene.join('\n'));
    expect(_introLine(t.ccos.first_pow_scene.intro_line2), findsOneWidget);
    await _expectReachable(tester, _button(t.ccos.first_pow_scene.add_button), find.byType(FirstPowSceneBody));
    _expectCopyClearsAddButton(tester);
    // Keep the authored typography restored by 81de8fa88; verify the full copy is readable.
    await _expectReachable(tester, _introLine(t.ccos.first_pow_scene.intro_line1), find.byType(FirstPowSceneBody));
    await _expectReachable(tester, _introLine(t.ccos.first_pow_scene.intro_line2), find.byType(FirstPowSceneBody));
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
    final scrollable = tester.state<ScrollableState>(
      find.descendant(of: find.byType(FirstPowSceneBody), matching: find.byType(Scrollable)).first,
    );
    expect(scrollable.position.maxScrollExtent, 0);
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
    expect(find.byType(Scrollable), findsOneWidget);

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
    await _expectReachable(tester, _introLine(t.ccos.first_pow_scene.intro_line1), find.byType(FirstPowSceneBody));
    await _expectReachable(tester, copy, find.byType(FirstPowSceneBody));
    final button = find.text(t.ccos.first_pow_scene.add_button);
    await tester.ensureVisible(button);
    expect(button.hitTestable(), findsOneWidget);
    expect(_drain(tester).where((message) => message.contains('RenderFlex')), isEmpty);
  });
  for (final variant in CoconutThemeVariant.values) {
    for (final (name, size, dpr, bottom, top, side) in [
      ('Duo closed', const Size(466, 678), 3.0, 34.0, 0.0, 84.0),
      ('Duo open', const Size(951, 669), 3.0, 34.0, 0.0, 84.0),
      ('iPhone 17', const Size(402, 874), 3.0, 34.0, 62.0, 0.0),
      ('iPhone SE', const Size(375, 667), 2.0, 0.0, 20.0, 0.0),
    ]) {
      testWidgets('all story scenes remain reachable on $name ${variant.name}', (tester) async {
        await _pumpIntro(
          tester,
          logical: size,
          dpr: dpr,
          bottomPadding: bottom,
          textScale: 1,
          sideInset: side,
          topPadding: top,
          variant: variant,
        );
        void expectRegularPhoneDoesNotScroll(Type scene) {
          if (name != 'iPhone 17' && !(name == 'iPhone SE' && scene == ContributeSceneBody)) return;
          final scrollable = find.descendant(of: find.byType(scene), matching: find.byType(Scrollable));
          if (scene == DiscoverSceneBody) {
            expect(scrollable, findsNothing, reason: 'Keep the original preview paint layers when it fits');
            return;
          }
          final state = tester.state<ScrollableState>(scrollable.first);
          expect(state.position.maxScrollExtent, 0, reason: '$scene must keep its original layout');
        }

        expect(await _showFirstPow(tester), isEmpty);
        expectRegularPhoneDoesNotScroll(FirstPowSceneBody);
        await _expectReachable(tester, _introLine(t.ccos.first_pow_scene.intro_line2), find.byType(FirstPowSceneBody));
        await _expectReachable(tester, _button(t.ccos.first_pow_scene.add_button), find.byType(FirstPowSceneBody));
        _expectCopyClearsAddButton(tester);
        for (final (scene, lastLine) in [
          (DiscoverSceneBody, t.ccos.discover_scene.line3),
          (ContributeSceneBody, t.ccos.contribute_scene.line4),
        ]) {
          await tester.tap(find.byIcon(Icons.arrow_forward_rounded).hitTestable().first);
          await tester.pump();
          await tester.pump(const Duration(seconds: 1));
          await tester.pump(const Duration(seconds: 30));
          expect(_drain(tester), isEmpty);
          expectRegularPhoneDoesNotScroll(scene);
          await _expectReachable(tester, _introLine(lastLine), find.byType(scene));
          if (scene == ContributeSceneBody) {
            await _expectReachable(tester, _button(t.ccos.contribute_scene.cta_start_first_pr), find.byType(scene));
          }
          expect(find.byIcon(Icons.arrow_back_rounded).hitTestable(), findsWidgets);
        }
      });
    }
  }
}
