import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/ui/coconut/coconut_overlays.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child) {
  return MaterialApp(
    theme: buildCoconutThemeData(variant: CoconutThemeVariant.values.first),
    home: Scaffold(body: child),
  );
}

void main() {
  testWidgets('long description scrolls while title and buttons stay fixed', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final description = List.generate(80, (i) => 'line $i').join('\n');
    await tester.pumpWidget(
      _app(
        CoconutPopup(
          title: 'Add failed',
          description: description,
          languageCode: 'en',
          rightButtonText: 'OK',
          onTapRight: () {},
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(find.ancestor(of: find.text('Add failed'), matching: find.byType(SingleChildScrollView)), findsNothing);
    expect(find.ancestor(of: find.text('OK'), matching: find.byType(SingleChildScrollView)), findsNothing);

    final titleTop = tester.getTopLeft(find.text('Add failed')).dy;
    final buttonTop = tester.getTopLeft(find.text('OK')).dy;
    expect(buttonTop, lessThan(640));

    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -300));
    await tester.pump();

    expect(tester.getTopLeft(find.text('Add failed')).dy, titleTop);
    expect(tester.getTopLeft(find.text('OK')).dy, buttonTop);
    expect(tester.widget<SingleChildScrollView>(find.byType(SingleChildScrollView)).controller, isNull);
    final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
    expect(scrollable.position.pixels, greaterThan(0));
  });

  testWidgets('short description keeps popup compact', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _app(
        CoconutPopup(
          title: 'Add failed',
          description: 'Invalid QR',
          languageCode: 'en',
          rightButtonText: 'OK',
          onTapRight: () {},
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    final dialogHeight =
        tester.getSize(find.descendant(of: find.byType(Dialog), matching: find.byType(ClipRRect)).first).height;
    expect(dialogHeight, lessThan(300));
    await tester.pump();
    final fade = tester.state<ScrollEdgeFadeState>(find.byType(ScrollEdgeFade));
    expect(fade.fadeTop, isFalse);
    expect(fade.fadeBottom, isFalse);
  });

  testWidgets('edge fades show only toward remaining scroll content', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _app(
        CoconutPopup(
          title: 'Add failed',
          description: List.generate(80, (i) => 'line $i').join('\n'),
          languageCode: 'en',
          checkboxText: 'Checked',
          onCheckboxChanged: (_) {},
          rightButtonText: 'OK',
          onTapRight: () {},
        ),
      ),
    );
    await tester.pump();

    ScrollEdgeFadeState fade() => tester.state<ScrollEdgeFadeState>(find.byType(ScrollEdgeFade));
    final position = tester.state<ScrollableState>(find.byType(Scrollable)).position;

    expect(fade().fadeTop, isFalse);
    expect(fade().fadeBottom, isTrue);

    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -200));
    await tester.pump();
    expect(fade().fadeTop, isTrue);
    expect(fade().fadeBottom, isTrue);
    final scrolled = position.pixels;
    expect(scrolled, greaterThan(0));

    position.jumpTo(position.maxScrollExtent);
    await tester.pump();
    expect(fade().fadeTop, isTrue);
    expect(fade().fadeBottom, isFalse);
    expect(position.pixels, position.maxScrollExtent);
    expect(tester.takeException(), isNull);
  });
}
