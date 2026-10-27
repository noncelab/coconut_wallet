import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/widgets/features/home/all_features_hint.dart';
import 'package:coconut_wallet/widgets/features/home/home_cube_pager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('peeking slides home a little toward All Features and comes back', (tester) async {
    final pager = GlobalKey<HomeCubePagerState>();
    final pages = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: buildCoconutThemeData(),
        home: HomeCubePager(
          key: pager,
          home: const Text('home'),
          allFeaturesBuilder: (_) => const Text('all'),
          onPageChanged: pages.add,
        ),
      ),
    );
    final homeLeft = tester.getTopLeft(find.text('home')).dx;

    pager.currentState!.peek();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.getTopLeft(find.text('home')).dx, lessThan(homeLeft));

    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('home')).dx, homeLeft);
    expect(pages, isEmpty);

    pager.currentState!.showAllFeatures();
    await tester.pumpAndSettle();
    expect(pages, [1]);
  });

  testWidgets('the hint opens All Features on tap and closes with X', (tester) async {
    var opened = 0;
    var closed = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildCoconutThemeData(),
        home: Scaffold(body: Center(child: AllFeaturesHint(onOpen: () => opened++, onClose: () => closed++))),
      ),
    );

    await tester.tap(find.byKey(const Key('all-features-hint-close')));
    expect(closed, 1);
    expect(opened, 0);

    await tester.tap(find.byKey(const Key('all-features-hint')), warnIfMissed: false);
    expect(opened, 1);
  });
}
