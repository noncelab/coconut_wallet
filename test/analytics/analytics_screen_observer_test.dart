import 'dart:async';

import 'package:coconut_wallet/analytics/analytics_screen_observer.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/services/analytics_service.dart';
import 'package:coconut_wallet/widgets/common/overlays/common_bottom_sheets.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

class _RecordingAnalytics extends Fake implements FirebaseAnalytics {
  final List<String> screens = [];

  @override
  Future<void> logScreenView({
    String? screenClass,
    String? screenName,
    Map<String, Object>? parameters,
    AnalyticsCallOptions? callOptions,
  }) async {
    screens.add(screenName!);
  }

  @override
  Future<void> setDefaultEventParameters(Map<String, Object?>? defaultParameters) async {}
}

class _Harness {
  final analytics = _RecordingAnalytics();
  final navigatorKey = GlobalKey<NavigatorState>();
  late BuildContext context;
  String rootScreenName = '/wallet-detail';
  late AnalyticsScreenObserver observer = AnalyticsScreenObserver(
    logScreenView: analytics.screens.add,
    nameExtractor: (settings) => settings.name == '/' ? rootScreenName : settings.name,
  );

  Future<void> mount(WidgetTester tester) async {
    PackageInfo.setMockInitialValues(
      appName: 'test',
      packageName: 'test',
      version: '0.19.0',
      buildNumber: '1',
      buildSignature: '',
    );
    await tester.pumpWidget(
      Provider<AnalyticsService>.value(
        value: AnalyticsService(analytics, false),
        child: MaterialApp(
          navigatorKey: navigatorKey,
          navigatorObservers: [observer],
          theme: buildCoconutThemeData(),
          home: Builder(
            builder: (context) {
              this.context = context;
              return const Scaffold(body: Text('wallet detail'));
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(analytics.screens, [rootScreenName]);
  }

  Route<bool> page(String name) =>
      MaterialPageRoute<bool>(settings: RouteSettings(name: name), builder: (_) => Scaffold(body: Text(name)));

  Future<void> push(WidgetTester tester, String name) async {
    unawaited(navigatorKey.currentState!.push(page(name)));
    await tester.pumpAndSettle();
  }
}

void main() {
  final sheetOpeners = <String, Future<Object?> Function(BuildContext)>{
    'standard':
        (context) => CommonBottomSheets.showBottomSheet<Object>(
          title: 'sheet',
          context: context,
          screenName: 'wallet-detail-faucet-sheet',
          child: const SizedBox(height: 100),
        ),
    'custom height':
        (context) => CommonBottomSheets.showCustomHeightBottomSheet<Object>(
          context: context,
          screenName: 'wallet-detail-faucet-sheet',
          heightRatio: 0.5,
          child: const SizedBox(height: 100),
        ),
    'full height':
        (context) => CommonBottomSheets.showBottomSheet_100<Object>(
          context: context,
          screenName: 'wallet-detail-faucet-sheet',
          child: const SizedBox(height: 100),
        ),
    'draggable':
        (context) => CommonBottomSheets.showDraggableBottomSheet<Object>(
          context: context,
          screenName: 'wallet-detail-faucet-sheet',
          childBuilder: (controller) => ListView(controller: controller, children: const [Text('sheet')]),
        ),
    'draggable scrollable':
        (context) => CommonBottomSheets.showDraggableScrollableSheet<Object>(
          context: context,
          screenName: 'wallet-detail-faucet-sheet',
          expand: false,
          child: const SizedBox(height: 100),
        ),
  };

  for (final entry in sheetOpeners.entries) {
    testWidgets('${entry.key} sheet restores its parent screen once after closing', (tester) async {
      final harness = _Harness();
      await harness.mount(tester);
      unawaited(entry.value(harness.context));
      await tester.pumpAndSettle();
      expect(harness.analytics.screens, ['/wallet-detail', 'wallet-detail-faucet-sheet']);
      harness.navigatorKey.currentState!.pop();
      await tester.pumpAndSettle();
      expect(harness.analytics.screens, ['/wallet-detail', 'wallet-detail-faucet-sheet', '/wallet-detail']);
    });
  }

  for (final dismissal in ['close button', 'barrier', 'drag', 'system back']) {
    testWidgets('sheet $dismissal restores the visible screen', (tester) async {
      final harness = _Harness();
      await harness.mount(tester);
      unawaited(
        CommonBottomSheets.showBottomSheet<Object>(
          title: 'sheet',
          context: harness.context,
          screenName: 'wallet-detail-faucet-sheet',
          showCloseButton: true,
          child: const SizedBox(height: 100),
        ),
      );
      await tester.pumpAndSettle();
      switch (dismissal) {
        case 'close button':
          await tester.tap(find.byIcon(Icons.close_rounded));
        case 'barrier':
          await tester.tapAt(const Offset(10, 10));
        case 'drag':
          await tester.drag(find.byType(BottomSheet), const Offset(0, 500));
        case 'system back':
          await tester.binding.handlePopRoute();
      }
      await tester.pumpAndSettle();
      expect(harness.analytics.screens, ['/wallet-detail', 'wallet-detail-faucet-sheet', '/wallet-detail']);
    });
  }

  testWidgets('nested named sheets restore the outer sheet then the page', (tester) async {
    final harness = _Harness();
    await harness.mount(tester);
    for (final name in ['outer-sheet', 'inner-sheet']) {
      unawaited(
        showModalBottomSheet<Object>(
          context: harness.context,
          routeSettings: RouteSettings(name: name),
          builder: (_) => const SizedBox(height: 100),
        ),
      );
      await tester.pumpAndSettle();
    }
    harness.navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();
    harness.navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();
    expect(harness.analytics.screens, [
      '/wallet-detail',
      'outer-sheet',
      'inner-sheet',
      'outer-sheet',
      '/wallet-detail',
    ]);
  });

  testWidgets('removing a sheet underneath a newly opened page never restores the old host', (tester) async {
    final harness = _Harness();
    await harness.mount(tester);
    late Route<Object?> sheet;
    unawaited(
      showModalBottomSheet<Object>(
        context: harness.context,
        routeSettings: const RouteSettings(name: 'outer-sheet'),
        builder: (context) {
          sheet = ModalRoute.of(context)!;
          return const SizedBox(height: 100);
        },
      ),
    );
    await tester.pumpAndSettle();
    await harness.push(tester, '/new-page');
    harness.navigatorKey.currentState!.removeRoute(sheet);
    await tester.pumpAndSettle();
    expect(harness.analytics.screens, ['/wallet-detail', 'outer-sheet', '/new-page']);
    harness.navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();
    expect(harness.analytics.screens.last, '/wallet-detail');
  });

  testWidgets('unnamed dialogs leave the existing screen attribution unchanged', (tester) async {
    final harness = _Harness();
    await harness.mount(tester);
    unawaited(showDialog<void>(context: harness.context, builder: (_) => const AlertDialog(content: Text('dialog'))));
    await tester.pumpAndSettle();
    harness.navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();
    expect(harness.analytics.screens, ['/wallet-detail']);
  });

  testWidgets('returning from an unnamed page with its own screen logging restores the named parent', (tester) async {
    final harness = _Harness();
    await harness.mount(tester);
    unawaited(
      harness.navigatorKey.currentState!.push(
        MaterialPageRoute<void>(
          builder: (context) {
            context.read<AnalyticsService>().logScreenView(screenName: 'ccos-card-detail');
            return const Scaffold(body: Text('card detail'));
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    harness.navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();
    expect(harness.analytics.screens, ['/wallet-detail', 'ccos-card-detail', '/wallet-detail']);
  });

  testWidgets('top route replacement and removal update the screen while hidden replacement does not', (tester) async {
    final harness = _Harness();
    await harness.mount(tester);
    final navigator = harness.navigatorKey.currentState!;
    final hiddenPage = harness.page('/hidden-page');
    unawaited(navigator.push(hiddenPage));
    await tester.pumpAndSettle();
    final topPage = harness.page('/top-page');
    unawaited(navigator.push(topPage));
    await tester.pumpAndSettle();
    final replacedHiddenPage = harness.page('/hidden-replacement');
    navigator.replace(oldRoute: hiddenPage, newRoute: replacedHiddenPage);
    await tester.pumpAndSettle();
    expect(harness.analytics.screens, ['/wallet-detail', '/hidden-page', '/top-page']);
    final replacedTopPage = harness.page('/top-replacement');
    navigator.replace(oldRoute: topPage, newRoute: replacedTopPage);
    await tester.pumpAndSettle();
    expect(harness.analytics.screens.last, '/top-replacement');
    navigator.removeRoute(replacedTopPage);
    await tester.pumpAndSettle();
    expect(harness.analytics.screens.last, '/hidden-replacement');
  });

  testWidgets('root splash PIN and home changes are recorded without replacing the root route', (tester) async {
    final harness = _Harness()..rootScreenName = '/splash';
    await harness.mount(tester);
    harness.rootScreenName = '/pin-check';
    harness.observer.refreshScreenName();
    await tester.pump();
    harness.rootScreenName = '/wallet-home';
    harness.observer.refreshScreenName();
    await tester.pump();
    harness.observer.refreshScreenName();
    await tester.pump();
    expect(harness.analytics.screens, ['/splash', '/pin-check', '/wallet-home']);
  });

  testWidgets('a route pushed then removed before it is painted does not create a screen view', (tester) async {
    final harness = _Harness();
    await harness.mount(tester);
    unawaited(harness.navigatorKey.currentState!.push(harness.page('/transient-page')));
    harness.navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();
    expect(harness.analytics.screens, ['/wallet-detail']);
  });

  testWidgets('backup result pop chain records only the final screen and preserves results', (tester) async {
    final harness = _Harness();
    await harness.mount(tester);
    final navigator = harness.navigatorKey.currentState!;
    final results = <String>[];
    final guideResult = navigator.push(harness.page('/backup-guide'));
    await tester.pumpAndSettle();
    unawaited(guideResult.then((result) => results.add('guide:$result')));
    final mnemonicResult = navigator.push(harness.page('/backup-mnemonic'));
    await tester.pumpAndSettle();
    unawaited(
      mnemonicResult.then((result) {
        results.add('mnemonic:$result');
        if (result == true) navigator.pop(true);
      }),
    );
    final confirmResult = navigator.push(harness.page('/backup-confirm'));
    await tester.pumpAndSettle();
    unawaited(
      confirmResult.then((result) {
        results.add('confirm:$result');
        if (result == true) navigator.pop(true);
      }),
    );
    final completeResult = navigator.push(harness.page('/backup-complete'));
    await tester.pumpAndSettle();
    unawaited(
      completeResult.then((result) {
        results.add('complete:$result');
        if (result == true) navigator.pop(true);
      }),
    );
    harness.analytics.screens.clear();
    navigator.pop(true);
    await tester.pumpAndSettle();
    expect(results, ['complete:true', 'confirm:true', 'mnemonic:true', 'guide:true']);
    expect(harness.analytics.screens, ['/wallet-detail']);
  });

  testWidgets('normal back navigation still records each screen the user sees', (tester) async {
    final harness = _Harness();
    await harness.mount(tester);
    await harness.push(tester, '/backup-guide');
    await harness.push(tester, '/backup-mnemonic');
    harness.analytics.screens.clear();
    harness.navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();
    harness.navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();
    expect(harness.analytics.screens, ['/backup-guide', '/wallet-detail']);
  });
}
