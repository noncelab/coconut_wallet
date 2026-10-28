import 'dart:ui' show Tristate;

import 'package:coconut_wallet/app/router/feature_entry_routes.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/ui/coconut/coconut_app_bar.dart';
import 'package:coconut_wallet/ui/coconut/coconut_app_bar_button.dart';
import 'package:coconut_wallet/widgets/common/buttons/coconut_icon_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final variant in CoconutThemeVariant.values) {
    for (final width in [320.0, 390.0]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('$variant width$width scale$scale: separate 48px targets, title and route semantics', (
          tester,
        ) async {
          tester.view.physicalSize = Size(width, 800);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final semantics = tester.ensureSemantics();

          final nav = GlobalKey<NavigatorState>();
          var first = 0;
          var second = 0;
          await tester.pumpWidget(
            MaterialApp(
              navigatorKey: nav,
              navigatorObservers: [FeatureEntryRoutes.instance],
              theme: buildCoconutThemeData(variant: variant),
              builder:
                  (context, child) => MediaQuery(
                    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
                    child: child!,
                  ),
              home: const Scaffold(body: Text('Root')),
            ),
          );
          void push({bool sheet = false}) {
            nav.currentState!.push(
              MaterialPageRoute<void>(
                builder:
                    (context) => Scaffold(
                      appBar: CoconutAppBar.build(
                        context: context,
                        title: 'A long wallet title that cannot fit on one line',
                        isBottom: sheet,
                        actionButtonList: [
                          CoconutAppBarActionButton(
                            buttonKey: const Key('first'),
                            size: 40,
                            tooltip: 'Search',
                            icon: const Icon(Icons.search, size: 24),
                            onPressed: () => first++,
                          ),
                          CoconutAppBarActionButton(
                            buttonKey: const Key('second'),
                            tooltip: 'Settings',
                            icon: const Icon(Icons.settings, size: 24),
                            onPressed: () => second++,
                          ),
                        ],
                      ),
                    ),
              ),
            );
          }

          push();
          await tester.pumpAndSettle();
          final one = tester.getRect(find.byKey(const Key('first')));
          final two = tester.getRect(find.byKey(const Key('second')));
          expect(one.size, const Size(48, 48));
          expect(two.size, const Size(48, 48));
          expect(one.right, lessThanOrEqualTo(two.left));
          expect(two.right, lessThanOrEqualTo(width));
          expect(tester.getSize(find.byIcon(Icons.search)), const Size(24, 24));
          final title = find.text('A long wallet title that cannot fit on one line');
          expect(tester.getRect(title).right, lessThanOrEqualTo(one.left));
          expect(tester.widget<Text>(title).style!.fontSize, 16);
          expect(tester.widget<AppBar>(find.byType(AppBar)).centerTitle, isTrue);
          expect(find.byType(BackdropFilter), findsOneWidget);
          final back = find.byTooltip('Back');
          expect(tester.getRect(back).size, const Size.square(CoconutAppBarActionButton.highlightSize));
          expect(tester.getRect(back).center.dx, 24);
          for (final point in [one.topLeft + const Offset(1, 1), one.bottomRight - const Offset(1, 1)]) {
            await tester.tapAt(point);
            await tester.pumpAndSettle();
          }
          expect(first, 2);
          expect(second, 0);
          await tester.tapAt(two.topLeft + const Offset(1, 1));
          await tester.pumpAndSettle();
          expect(first, 2);
          expect(second, 1);
          final cancelled = await tester.startGesture(one.center);
          await cancelled.cancel();
          await tester.pumpAndSettle();
          expect(first, 2);
          await tester.tap(back);
          await tester.pumpAndSettle();
          expect(find.text('Root'), findsOneWidget);
          push(sheet: true);
          await tester.pumpAndSettle();
          expect(find.byTooltip('Close'), findsOneWidget);
          await tester.tap(find.byTooltip('Close'));
          await tester.pumpAndSettle();
          await FeatureEntryRoutes.instance.launching(() async => push());
          await tester.pumpAndSettle();
          expect(find.byTooltip('Close'), findsOneWidget);
          await tester.tap(find.byTooltip('Close'));
          await tester.pumpAndSettle();
          expect(find.text('Root'), findsOneWidget);
          expect(tester.takeException(), isNull);
          semantics.dispose();
        });
      }
    }
    testWidgets('$variant: next app bar fits at 320 and 390 with large text', (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final width in [320.0, 390.0]) {
        tester.view.physicalSize = Size(width, 800);
        await tester.pumpWidget(
          MaterialApp(
            theme: buildCoconutThemeData(variant: variant),
            builder:
                (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)),
                  child: child!,
                ),
            home: Builder(
              builder:
                  (context) => Scaffold(
                    appBar: CoconutAppBar.buildWithNext(
                      context: context,
                      title: 'Next step with long title',
                      nextButtonTitle: 'Next',
                      onNextPressed: () {},
                    ),
                  ),
            ),
          ),
        );
        final title = find.text('Next step with long title');
        final action = find.byType(TextButton);
        expect(tester.getRect(title).right, lessThanOrEqualTo(tester.getRect(action).left));
        final paragraph = tester.renderObject<RenderParagraph>(title);
        expect(paragraph.size.height, paragraph.getMaxIntrinsicHeight(paragraph.size.width));
        // Flutter AppBar caps title scaling at 1.34; the requested system scale is 2.
        expect(MediaQuery.textScalerOf(tester.element(title)).scale(18), closeTo(18 * 1.34, .001));
        expect(tester.getRect(title).bottom, lessThanOrEqualTo(56));
        expect(tester.getSize(action).height, greaterThanOrEqualTo(48));
        expect(tester.takeException(), isNull);
      }
    });
    testWidgets('$variant: next action exposes disabled state and dispatches pointer and keyboard once', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();

      var taps = 0;
      Widget host(bool enabled) => MaterialApp(
        theme: buildCoconutThemeData(variant: variant),
        home: Scaffold(
          body: Center(child: CoconutAppBarButton(isActive: enabled, onPressed: () => taps++, text: 'Next')),
        ),
      );
      await tester.pumpWidget(host(true));
      expect(tester.getSize(find.byType(TextButton)).width, greaterThanOrEqualTo(48));
      expect(tester.getSize(find.byType(TextButton)).height, greaterThanOrEqualTo(48));
      await tester.tap(find.text('Next'));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(taps, 3);
      await tester.pumpWidget(host(false));
      final data = tester.getSemantics(find.byType(TextButton)).getSemanticsData();
      expect(data.flagsCollection.isButton, isTrue);
      expect(data.flagsCollection.isEnabled, isNot(Tristate.isTrue));
      expect(data.hasAction(SemanticsAction.tap), isFalse);
      await tester.tap(find.text('Next'));
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(taps, 3);
      semantics.dispose();
    });
  }
}
