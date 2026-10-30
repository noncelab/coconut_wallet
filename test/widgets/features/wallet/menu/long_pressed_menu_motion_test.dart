import 'dart:ui' as ui;

import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/widgets/features/wallet/menu/long_pressed_menu_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _sceneKey = Key('motion-scene');
const _targetKey = Key('motion-target');
const _menuKey = Key('long-pressed-menu-box');
const _rootKey = Key('motion-root');
const _destinationKey = Key('motion-destination');
const _headerKey = Key('motion-header-action');

class _Host {
  final navigatorKey = GlobalKey<NavigatorState>();
  final menuStateKey = GlobalKey<LongPressedMenuWidgetState>();
  final platformCalls = <MethodCall>[];
  int selections = 0;
  int destinationTaps = 0;
  int headerSelections = 0;

  bool get handlesBack =>
      platformCalls.lastWhere((call) => call.method == 'SystemNavigator.setFrameworkHandlesBack').arguments as bool;
  int get exits => platformCalls.where((call) => call.method == 'SystemNavigator.pop').length;
}

Future<_Host> _pumpHost(
  WidgetTester tester, {
  bool reducedMotion = false,
  bool pushOnSelection = false,
  bool withHeader = false,
  ValueNotifier<bool>? motionSetting,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(414, 896);
  addTearDown(tester.view.reset);
  final host = _Host();
  final motion = motionSetting ?? ValueNotifier(reducedMotion);
  if (motionSetting == null) addTearDown(motion.dispose);
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
    host.platformCalls.add(call);
    return null;
  });
  addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  await tester.pumpWidget(
    RepaintBoundary(
      key: _sceneKey,
      child: MaterialApp(
        navigatorKey: host.navigatorKey,
        theme: buildCoconutThemeData().copyWith(platform: TargetPlatform.android),
        builder:
            (context, child) => ValueListenableBuilder<bool>(
              valueListenable: motion,
              builder:
                  (context, reduced, _) =>
                      MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: reduced), child: child!),
            ),
        home: Stack(
          key: _rootKey,
          fit: StackFit.expand,
          children: [
            // The black/white edge lets the raster assertion distinguish blur
            // fading from the dim layer merely becoming more transparent.
            const Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: ColoredBox(color: Colors.black)),
                Expanded(child: ColoredBox(color: Colors.white)),
              ],
            ),
            Center(
              child: LongPressedMenuWidget(
                key: host.menuStateKey,
                useGlassOverlay: true,
                menuHeaderHeight: withHeader ? 48 : 0,
                menuHeaderBuilder:
                    withHeader
                        ? (close) => TextButton(
                          key: _headerKey,
                          onPressed: () {
                            close();
                            host.headerSelections++;
                          },
                          child: const Text('Change size'),
                        )
                        : null,
                menuItems: [
                  LongPressedMenuItem(
                    title: 'Configure widget',
                    iconPath: CommonActionIconPath.editHome,
                    onSelected: () {
                      host.selections++;
                      if (!pushOnSelection) return;
                      host.navigatorKey.currentState!.push(
                        PageRouteBuilder<void>(
                          transitionDuration: Duration.zero,
                          reverseTransitionDuration: Duration.zero,
                          pageBuilder:
                              (context, animation, secondaryAnimation) => Scaffold(
                                key: _destinationKey,
                                body: Center(
                                  child: TextButton(
                                    onPressed: () => host.destinationTaps++,
                                    child: const Text('Destination action'),
                                  ),
                                ),
                              ),
                        ),
                      );
                    },
                  ),
                ],
                child: const SizedBox(key: _targetKey, width: 172, height: 172, child: ColoredBox(color: Colors.blue)),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  expect(host.handlesBack, isFalse);
  return host;
}

Future<void> _open(WidgetTester tester) async {
  await tester.longPress(find.byKey(_targetKey));
  await tester.pumpAndSettle();
  expect(find.byKey(_menuKey), findsOneWidget);
}

Future<void> _close(WidgetTester tester, String method) async {
  if (method == 'back') {
    await tester.binding.handlePopRoute();
  } else {
    await tester.tapAt(const Offset(350, 100));
  }
  await tester.pump();
  await tester.pump();
}

double _menuPaintOpacity(WidgetTester tester) {
  var opacity = 1.0;
  tester.element(find.byKey(_menuKey)).visitAncestorElements((element) {
    if (element is RenderObjectElement) {
      final renderObject = element.renderObject;
      if (renderObject is RenderOpacity) opacity *= renderObject.opacity;
      if (renderObject is RenderAnimatedOpacity) opacity *= renderObject.opacity.value;
    }
    return true;
  });
  return opacity;
}

Future<ByteData> _pixels(WidgetTester tester) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(_sceneKey));
  final bytes = await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    try {
      return await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    } finally {
      image.dispose();
    }
  });
  return bytes!;
}

int _red(ByteData pixels, int x) => pixels.getUint8((100 * 414 + x) * 4);

void main() {
  testWidgets('closing scale decreases on every frame without replaying the opening overshoot', (tester) async {
    await _pumpHost(tester);
    await _open(tester);
    var width = tester.getRect(find.byKey(_menuKey)).width;
    await _close(tester, 'outside');
    for (var frame = 0; frame < 10; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
      final next = tester.getRect(find.byKey(_menuKey)).width;
      expect(next, lessThan(width), reason: 'Closing frame $frame must shrink toward the source.');
      width = next;
    }
    await tester.pumpAndSettle();
    expect(find.byKey(_menuKey), findsNothing);
  });

  testWidgets('enabling reduced motion during close removes the overlay and releases Back', (tester) async {
    final motion = ValueNotifier(false);
    addTearDown(motion.dispose);
    final host = await _pumpHost(tester, motionSetting: motion);
    await _open(tester);
    await _close(tester, 'outside');
    await tester.pump(const Duration(milliseconds: 16));
    motion.value = true;
    await tester.pumpAndSettle();
    expect(find.byKey(_menuKey), findsNothing);
    expect(host.handlesBack, isFalse);
    expect(tester.takeException(), isNull);
  });

  for (final method in ['back', 'outside']) {
    testWidgets(
      '$method reverses the menu, widget expansion, dim and blur before removing the overlay',
      (tester) async {
        final host = await _pumpHost(tester);
        final restingWidget = tester.getRect(find.byKey(_targetKey));
        expect(_red(await _pixels(tester), 350), 255);
        await _open(tester);
        final expandedWidget = tester.getRect(find.byKey(_targetKey));
        final openPixels = await _pixels(tester);
        expect(expandedWidget.width, greaterThan(restingWidget.width));
        expect(_menuPaintOpacity(tester), closeTo(1, 0.001));

        await _close(tester, method);
        expect(find.byKey(_menuKey), findsOneWidget);
        expect(tester.getRect(find.byKey(_targetKey)), expandedWidget);
        expect(host.handlesBack, isTrue);
        await tester.pump(const Duration(milliseconds: 80));

        expect(find.byKey(_menuKey), findsOneWidget);
        final closingWidget = tester.getRect(find.byKey(_targetKey));
        expect(closingWidget.width, inExclusiveRange(restingWidget.width, expandedWidget.width));
        expect(_menuPaintOpacity(tester), inExclusiveRange(0, 1));
        final closingPixels = await _pixels(tester);
        expect(_red(closingPixels, 350), greaterThan(_red(openPixels, 350)), reason: 'The dim layer fades out.');
        expect(_red(closingPixels, 350), lessThan(255));
        expect(
          _red(closingPixels, 209) / _red(closingPixels, 350),
          greaterThan(_red(openPixels, 209) / _red(openPixels, 350)),
          reason: 'The white side of the edge sharpens as background blur fades, independently of dim opacity.',
        );
        expect(host.handlesBack, isTrue);
        expect(host.exits, 0);

        await tester.pump(const Duration(milliseconds: 200));
        await tester.pump();
        expect(find.byKey(_menuKey), findsNothing);
        expect(tester.getRect(find.byKey(_targetKey)), restingWidget);
        expect(host.handlesBack, isFalse);
        expect(_red(await _pixels(tester), 350), 255);
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );
  }

  testWidgets(
    'closing during entrance continues from the visible geometry without jumping',
    (tester) async {
      await _pumpHost(tester);
      final gesture = await tester.startGesture(tester.getCenter(find.byKey(_targetKey)));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      expect(find.byKey(_menuKey), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 50));
      final menuBefore = tester.getRect(find.byKey(_menuKey));
      final widgetBefore = tester.getRect(find.byKey(_targetKey));
      final opacityBefore = _menuPaintOpacity(tester);
      expect(opacityBefore, inExclusiveRange(0, 1));
      await gesture.up();

      await _close(tester, 'outside');
      expect(tester.getRect(find.byKey(_menuKey)), menuBefore);
      expect(tester.getRect(find.byKey(_targetKey)), widgetBefore);
      expect(_menuPaintOpacity(tester), closeTo(opacityBefore, 0.001));
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.getRect(find.byKey(_menuKey)).width, lessThan(menuBefore.width));
      await tester.pumpAndSettle();
      expect(find.byKey(_menuKey), findsNothing);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'repeated Back during closing consumes only the menu without restarting its animation',
    (tester) async {
      final host = await _pumpHost(tester);
      await _open(tester);
      await _close(tester, 'back');
      await tester.pump(const Duration(milliseconds: 80));
      expect(find.byKey(_menuKey), findsOneWidget);
      final opacityBefore = _menuPaintOpacity(tester);

      await _close(tester, 'back');
      expect(_menuPaintOpacity(tester), closeTo(opacityBefore, 0.001));
      expect(host.exits, 0);
      expect(host.handlesBack, isTrue);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump();
      expect(find.byKey(_menuKey), findsNothing);
      expect(host.handlesBack, isFalse);
      expect(host.exits, 0);
      await tester.binding.handlePopRoute();
      expect(host.exits, 1);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  for (final method in ['back', 'outside']) {
    testWidgets(
      '$method respects reduced motion by closing immediately',
      (tester) async {
        final host = await _pumpHost(tester, reducedMotion: true);
        await _open(tester);
        await _close(tester, method);
        expect(find.byKey(_menuKey), findsNothing);
        expect(host.handlesBack, isFalse);
        expect(host.exits, 0);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );
  }

  testWidgets(
    'drag dismissal and lifecycle cancellation stay immediate even while closing',
    (tester) async {
      final host = await _pumpHost(tester);
      for (final lifecycle in [false, true]) {
        await _open(tester);
        await _close(tester, 'outside');
        await tester.pump(const Duration(milliseconds: 40));
        expect(find.byKey(_menuKey), findsOneWidget);
        if (lifecycle) {
          tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
        } else {
          host.menuStateKey.currentState!.dismissMenu();
        }
        await tester.pump();
        expect(find.byKey(_menuKey), findsNothing);
        expect(host.handlesBack, isFalse);
        expect(host.exits, 0);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await tester.pump();
      }
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'Back and outside closing suppress header actions until the menu disappears',
    (tester) async {
      final host = await _pumpHost(tester, withHeader: true);
      for (final method in ['back', 'outside']) {
        await _open(tester);
        await _close(tester, method);
        await tester.pump(const Duration(milliseconds: 40));
        expect(find.byKey(_menuKey), findsOneWidget);
        await tester.tapAt(tester.getCenter(find.byKey(_headerKey)));
        expect(host.headerSelections, 0, reason: 'A closing header must not resize a widget after dismissal.');
        expect(host.handlesBack, isTrue);
        expect(host.exits, 0);
        await tester.pumpAndSettle();
        expect(find.byKey(_menuKey), findsNothing);
        expect(host.handlesBack, isFalse);
        expect(tester.takeException(), isNull);
      }
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'a selected action runs once and its new route receives input and Back during the old fade',
    (tester) async {
      final host = await _pumpHost(tester, pushOnSelection: true);
      await _open(tester);
      await tester.tap(find.text('Configure widget'));
      await tester.pump();
      await tester.pump();
      expect(host.selections, 1);
      expect(find.byKey(_destinationKey), findsOneWidget);
      await tester.tap(find.text('Destination action'));
      expect(host.destinationTaps, 1);

      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.pump();
      expect(find.byKey(_destinationKey), findsNothing);
      expect(find.byKey(_rootKey), findsOneWidget);
      expect(host.selections, 1);
      expect(host.exits, 0);
      await tester.pumpAndSettle();
      expect(find.byKey(_menuKey), findsNothing);
      expect(host.handlesBack, isFalse);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
}
