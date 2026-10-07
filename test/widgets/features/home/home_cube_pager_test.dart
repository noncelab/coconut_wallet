import 'package:coconut_wallet/widgets/features/home/home_cube_pager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

VoidCallback? _showHome;

Future<void> _pump(WidgetTester tester) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: HomeCubePager(
          home: const ColoredBox(color: Colors.white, child: SizedBox.expand(child: Text('home'))),
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

void main() {
  testWidgets('starts on home', (tester) async {
    await _pump(tester);

    expect(_page(tester), 0);
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('swiping left shows all features and swiping right returns home', (tester) async {
    await _pump(tester);

    await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
    await tester.pumpAndSettle();
    expect(_page(tester), 1);

    await tester.fling(find.byType(PageView), const Offset(400, 0), 1000);
    await tester.pumpAndSettle();
    expect(_page(tester), 0);
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
}
