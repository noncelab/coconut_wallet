import 'dart:async';

import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/widgets/features/wallet/menu/long_pressed_menu_widget.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _targetKey = Key('menu-target');
const _pageKey = Key('menu-page');
const _rootKey = Key('root-page');
const _menuBoxKey = Key('long-pressed-menu-box');

class _MenuHost {
  final navigatorKey = GlobalKey<NavigatorState>();
  final menuKey = GlobalKey<LongPressedMenuWidgetState>();
  late MaterialPageRoute<void> route;
  int selectionCount = 0;
}

Future<_MenuHost> _pumpHost(WidgetTester tester, {VoidCallback? onMenuOpen}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(414, 896);
  addTearDown(tester.view.reset);
  final host = _MenuHost();
  await tester.pumpWidget(
    MaterialApp(
      navigatorKey: host.navigatorKey,
      theme: buildCoconutThemeData().copyWith(platform: TargetPlatform.android),
      home: Scaffold(
        key: _rootKey,
        body: TextButton(
          onPressed: () {
            host.route = MaterialPageRoute<void>(
              builder:
                  (context) => Scaffold(
                    key: _pageKey,
                    body: Center(
                      child: LongPressedMenuWidget(
                        key: host.menuKey,
                        useGlassOverlay: true,
                        onMenuOpen: onMenuOpen,
                        menuItems: [
                          LongPressedMenuItem(
                            title: 'Edit widget',
                            iconPath: CommonActionIconPath.editHome,
                            onSelected: () => host.selectionCount++,
                          ),
                        ],
                        child: const SizedBox(
                          key: _targetKey,
                          width: 172,
                          height: 172,
                          child: ColoredBox(color: Colors.blue),
                        ),
                      ),
                    ),
                  ),
            );
            host.navigatorKey.currentState!.push(host.route);
          },
          child: const Text('Open widgets'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open widgets'));
  await tester.pumpAndSettle();
  expect(find.byKey(_pageKey), findsOneWidget);
  return host;
}

Future<void> _openMenu(WidgetTester tester) async {
  await tester.longPress(find.byKey(_targetKey));
  await tester.pumpAndSettle();
  expect(find.byKey(_menuBoxKey), findsOneWidget);
  expect(tester.takeException(), isNull);
}

Future<void> _platformBack(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
}

void _expectRootPage(WidgetTester tester) {
  expect(find.byKey(_rootKey), findsOneWidget);
  expect(find.byKey(_pageKey), findsNothing);
  expect(find.byKey(_menuBoxKey), findsNothing);
  expect(tester.takeException(), isNull);
}

void main() {
  for (final cupertino in [false, true]) {
    testWidgets(
      '${cupertino ? 'CupertinoApp' : 'MaterialApp'} root menu registers Android Back handling and releases it',
      (tester) async {
        final calls = <MethodCall>[];
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
          calls.add(call);
          return null;
        });
        addTearDown(() {
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null);
        });
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        final navigatorKey = GlobalKey<NavigatorState>();
        final menuKey = GlobalKey<LongPressedMenuWidgetState>();
        final theme = buildCoconutThemeData().copyWith(platform: TargetPlatform.android);
        final home = ColoredBox(
          key: _rootKey,
          color: Colors.white,
          child: Center(
            child: LongPressedMenuWidget(
              key: menuKey,
              useGlassOverlay: true,
              menuItems: [
                LongPressedMenuItem(title: 'Edit widget', iconPath: CommonActionIconPath.editHome, onSelected: () {}),
              ],
              child: const SizedBox(key: _targetKey, width: 172, height: 172, child: ColoredBox(color: Colors.blue)),
            ),
          ),
        );
        await tester.pumpWidget(
          cupertino
              ? CupertinoApp(
                navigatorKey: navigatorKey,
                builder: (context, child) => Theme(data: theme, child: child!),
                home: home,
              )
              : MaterialApp(navigatorKey: navigatorKey, theme: theme, home: home),
        );
        await tester.pumpAndSettle();
        bool lastFrameworkHandlesBack() =>
            calls.lastWhere((call) => call.method == 'SystemNavigator.setFrameworkHandlesBack').arguments as bool;
        int appExitRequests() => calls.where((call) => call.method == 'SystemNavigator.pop').length;
        expect(navigatorKey.currentState!.canPop(), isFalse);
        expect(lastFrameworkHandlesBack(), isFalse);

        for (final dismissal in ['back', 'outside', 'selection', 'drag']) {
          await _openMenu(tester);
          expect(
            lastFrameworkHandlesBack(),
            isTrue,
            reason: 'The root route must tell Android to deliver Back to Flutter while the menu is open.',
          );
          switch (dismissal) {
            case 'back':
              await _platformBack(tester);
            case 'outside':
              await tester.tapAt(const Offset(20, 20));
            case 'selection':
              await tester.tap(find.text('Edit widget'));
            case 'drag':
              menuKey.currentState!.dismissMenu();
          }
          await tester.pumpAndSettle();
          expect(find.byKey(_rootKey), findsOneWidget);
          expect(find.byKey(_menuBoxKey), findsNothing);
          expect(lastFrameworkHandlesBack(), isFalse, reason: '$dismissal must release the native Back handler.');
          expect(navigatorKey.currentState!.canPop(), isFalse);
          expect(appExitRequests(), 0);
          expect(tester.takeException(), isNull);
        }

        await _platformBack(tester);
        expect(appExitRequests(), 1, reason: 'After menu dismissal, root Back follows the normal app exit policy.');
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );
  }

  testWidgets('platform Back closes only the menu, then the next Back leaves the page', (tester) async {
    await _pumpHost(tester);

    for (var attempt = 0; attempt < 3; attempt++) {
      await _openMenu(tester);
      await _platformBack(tester);
      expect(find.byKey(_menuBoxKey), findsNothing);
      expect(find.byKey(_pageKey), findsOneWidget);
      expect(find.byKey(_rootKey), findsNothing);
    }

    await _platformBack(tester);
    _expectRootPage(tester);
  });

  testWidgets('closing outside the menu leaves no extra Back entry', (tester) async {
    await _pumpHost(tester);
    await _openMenu(tester);
    await tester.tapAt(const Offset(20, 800));
    await tester.pumpAndSettle();
    expect(find.byKey(_menuBoxKey), findsNothing);
    expect(find.byKey(_pageKey), findsOneWidget);

    await _platformBack(tester);
    _expectRootPage(tester);
  });

  testWidgets('selecting a menu item calls it once and leaves no extra Back entry', (tester) async {
    final host = await _pumpHost(tester);
    await _openMenu(tester);
    await tester.tap(find.text('Edit widget'));
    await tester.pumpAndSettle();
    expect(host.selectionCount, 1);
    expect(find.byKey(_menuBoxKey), findsNothing);
    expect(find.byKey(_pageKey), findsOneWidget);

    await _platformBack(tester);
    _expectRootPage(tester);
  });

  testWidgets('drag dismissal and lifecycle interruption remove the menu Back entry', (tester) async {
    for (final interrupt in [false, true]) {
      final host = await _pumpHost(tester);
      await _openMenu(tester);
      if (interrupt) {
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
        await tester.pump();
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      } else {
        // HomeItemDraggable uses this public API when the held pointer moves.
        host.menuKey.currentState!.dismissMenu();
      }
      await tester.pumpAndSettle();
      expect(find.byKey(_menuBoxKey), findsNothing);
      expect(find.byKey(_pageKey), findsOneWidget);
      await _platformBack(tester);
      _expectRootPage(tester);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('disposing the route removes its open overlay without navigation exceptions', (tester) async {
    final host = await _pumpHost(tester);
    await _openMenu(tester);

    host.navigatorKey.currentState!.removeRoute(host.route);
    await tester.pumpAndSettle();
    _expectRootPage(tester);
    expect(host.menuKey.currentState, isNull);
    expect(host.navigatorKey.currentState!.canPop(), isFalse);
  });

  testWidgets('Back while a glass menu starts capturing cannot pop the page or reopen the menu later', (tester) async {
    Future<void>? pendingBack;
    final host = await _pumpHost(
      tester,
      onMenuOpen: () {
        // Called by the real long press before the asynchronous image capture.
        pendingBack = tester.binding.handlePopRoute();
        unawaited(pendingBack);
      },
    );
    await tester.longPress(find.byKey(_targetKey));
    expect(pendingBack, isNotNull);
    await pendingBack;
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(_menuBoxKey), findsNothing);
    expect(find.byKey(_pageKey), findsOneWidget);
    expect(host.selectionCount, 0);
    expect(tester.takeException(), isNull);

    await _platformBack(tester);
    _expectRootPage(tester);
  });
}
