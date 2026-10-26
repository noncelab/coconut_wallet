import 'package:coconut_wallet/widgets/features/home/home_cube_pager.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

VoidCallback? _showHome;

Future<void> _pump(WidgetTester tester, {ValueChanged<int>? onPageChanged}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: HomeCubePager(
          home: const ColoredBox(color: Colors.white, child: SizedBox.expand(child: Text('home'))),
          onPageChanged: onPageChanged,
          allFeaturesBuilder: (showHome) {
            _showHome = showHome;
            return const ColoredBox(color: Colors.white, child: SizedBox.expand(child: Text('all features')));
          },
        ),
      ),
    ),
  );
}

double _page(WidgetTester tester) => tester.widget<PageView>(find.byType(PageView)).controller!.page!;

Transform _face(WidgetTester tester, int page) {
  final key = Key(page == 0 ? 'home-cube-home' : 'home-cube-all-features');
  return tester.widget<Transform>(find.ancestor(of: find.byKey(key), matching: find.byType(Transform)).first);
}

void _expectSettledFace(WidgetTester tester, int page) {
  expect(_page(tester), closeTo(page.toDouble(), 0.000001));
  final matrix = _face(tester, page).transform;
  expect(matrix.entry(0, 0), closeTo(1, 0.000001), reason: 'The visible page must face the viewer.');
  expect(matrix.entry(0, 2), closeTo(0, 0.000001));
  expect(matrix.entry(2, 0), closeTo(0, 0.000001));
  expect(matrix.entry(2, 2), closeTo(1, 0.000001));
}

enum _PagerUpdate { rebuild, physics, devicePixelRatio }

void main() {
  testWidgets('starts on home', (tester) async {
    await _pump(tester);

    expect(_page(tester), 0);
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('swiping left shows all features and swiping right returns home', (tester) async {
    final changedPages = <int>[];
    await _pump(tester, onPageChanged: changedPages.add);

    await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
    await tester.pumpAndSettle();
    expect(_page(tester), 1);

    await tester.fling(find.byType(PageView), const Offset(400, 0), 1000);
    await tester.pumpAndSettle();
    expect(_page(tester), 0);
    expect(changedPages, [1, 0]);
  });

  testWidgets('the faces rotate while dragging', (tester) async {
    await _pump(tester);

    final gesture = await tester.startGesture(tester.getCenter(find.byType(PageView)));
    await gesture.moveBy(const Offset(-150, 0));
    await tester.pump();

    final transforms = tester.widgetList<Transform>(
      find.ancestor(of: find.text('home'), matching: find.byType(Transform)),
    );
    expect(transforms.any((transform) => transform.transform.entry(0, 2) != 0), isTrue);

    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('the all features back action returns home', (tester) async {
    await _pump(tester);
    await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
    await tester.pumpAndSettle();

    _showHome!();
    await tester.pumpAndSettle();

    expect(_page(tester), 0);
  });

  testWidgets('system back on all features returns home instead of leaving', (tester) async {
    await _pump(tester);
    await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
    await tester.pumpAndSettle();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(_page(tester), 0);
    expect(find.byType(HomeCubePager), findsOneWidget);
  });

  for (final update in _PagerUpdate.values) {
    testWidgets('a settled face survives ${update.name} without duplicate page callbacks', (tester) async {
      final phase = ValueNotifier(0);
      final pagerKey = GlobalKey<HomeCubePagerState>();
      final changedPages = <int>[];
      addTearDown(phase.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: ValueListenableBuilder<int>(
            valueListenable: phase,
            builder:
                (context, value, _) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(devicePixelRatio: update == _PagerUpdate.devicePixelRatio && value > 0 ? 2 : 1),
                  child: HomeCubePager(
                    key: pagerKey,
                    swipeEnabled: update != _PagerUpdate.physics || value == 0,
                    onPageChanged: changedPages.add,
                    home: const ColoredBox(color: Colors.white),
                    allFeaturesBuilder: (_) => const ColoredBox(color: Colors.blue),
                  ),
                ),
          ),
        ),
      );
      pagerKey.currentState!.showAllFeatures();
      await tester.pumpAndSettle();
      _expectSettledFace(tester, 1);
      expect(changedPages, [1]);

      phase.value++;
      await tester.pumpAndSettle();
      _expectSettledFace(tester, 1);
      expect(changedPages, [1]);

      phase.value = 0;
      await tester.pumpAndSettle();
      _expectSettledFace(tester, 1);
      expect(changedPages, [1]);
      await tester.fling(find.byType(PageView), const Offset(400, 0), 1000);
      await tester.pumpAndSettle();
      _expectSettledFace(tester, 0);
      expect(changedPages, [1, 0]);
    });
  }

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
      'both faces stay aligned after Material route return in CupertinoApp on ${platform.name}',
      (tester) async {
        final pagerKey = GlobalKey<HomeCubePagerState>();
        final changedPages = <int>[];

        Widget storeButton(BuildContext context) => CupertinoButton(
          key: const Key('open-store'),
          onPressed:
              () => Navigator.of(context).push<void>(
                // The app uses CupertinoApp, while openCoconutOpenStoreIntroScreen pushes this route type.
                MaterialPageRoute<void>(
                  builder:
                      (context) => Center(
                        child: CupertinoButton(
                          key: const Key('close-store'),
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Close store'),
                        ),
                      ),
                ),
              ),
          child: const Text('Open store'),
        );

        await tester.pumpWidget(
          CupertinoApp(
            localizationsDelegates: const [DefaultMaterialLocalizations.delegate],
            builder: (context, child) => Theme(data: ThemeData(platform: platform), child: child!),
            home: HomeCubePager(
              key: pagerKey,
              onPageChanged: changedPages.add,
              home: Builder(builder: (context) => Center(child: storeButton(context))),
              allFeaturesBuilder:
                  (showHome) => Builder(
                    builder:
                        (context) => Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            storeButton(context),
                            CupertinoButton(
                              key: const Key('show-home'),
                              onPressed: showHome,
                              child: const Text('Home'),
                            ),
                          ],
                        ),
                  ),
            ),
          ),
        );
        pagerKey.currentState!.showAllFeatures();
        await tester.pumpAndSettle();

        for (final page in [1, 0]) {
          _expectSettledFace(tester, page);
          final callbacksBeforeRoute = List<int>.of(changedPages);
          await tester.tap(find.byKey(const Key('open-store')).hitTestable());
          await tester.pumpAndSettle();
          final closeButton = find.byKey(const Key('close-store'));
          expect(ModalRoute.of(tester.element(closeButton)), isA<MaterialPageRoute<void>>());
          await tester.tap(closeButton);
          await tester.pumpAndSettle();

          _expectSettledFace(tester, page);
          expect(changedPages, callbacksBeforeRoute);
          if (page == 1) {
            await tester.tap(find.byKey(const Key('show-home')));
            await tester.pumpAndSettle();
          }
        }
        expect(changedPages, [1, 0]);
      },
      variant: TargetPlatformVariant({platform}),
    );
  }

  testWidgets('resizing the viewport preserves the settled page and face', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 600);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final changedPages = <int>[];
    await _pump(tester, onPageChanged: changedPages.add);
    await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
    await tester.pumpAndSettle();
    _expectSettledFace(tester, 1);

    tester.view.physicalSize = const Size(600, 800);
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(PageView)), const Size(600, 800));
    _expectSettledFace(tester, 1);
    expect(changedPages, [1]);

    _showHome!();
    await tester.pumpAndSettle();
    _expectSettledFace(tester, 0);
    expect(changedPages, [1, 0]);
  });

  for (final initialPage in [0, 1]) {
    testWidgets('canceling a partial drag returns page $initialPage to a flat face', (tester) async {
      final changedPages = <int>[];
      await _pump(tester, onPageChanged: changedPages.add);
      if (initialPage == 1) {
        await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
        await tester.pumpAndSettle();
      }
      _expectSettledFace(tester, initialPage);
      final callbacksBeforeDrag = List<int>.of(changedPages);
      final pager = find.byType(PageView);
      final direction = initialPage == 0 ? -1 : 1;
      final segment = Offset(tester.getSize(pager).width * 0.1 * direction, 0);
      final gesture = await tester.startGesture(tester.getCenter(pager));
      await gesture.moveBy(segment);
      await tester.pump(const Duration(milliseconds: 16));
      await gesture.moveBy(segment);
      await tester.pump(const Duration(milliseconds: 16));
      expect((_page(tester) - initialPage).abs(), inExclusiveRange(0, 0.5));
      expect(_face(tester, initialPage).transform.entry(0, 2).abs(), greaterThan(0));

      await gesture.cancel();
      await tester.pumpAndSettle();
      _expectSettledFace(tester, initialPage);
      expect(changedPages, callbacksBeforeDrag);
    });
  }
}
