import 'package:coconut_wallet/ccos/open_store/coconut_open_store_content.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/widgets/features/ccos/card/coconut_open_store_intro_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final accessibleNavigation in [false, true]) {
    testWidgets('intro card decoration responds live and keeps actions: accessibleNavigation=$accessibleNavigation', (
      tester,
    ) async {
      final reduced = ValueNotifier(true);
      addTearDown(reduced.dispose);
      var opened = 0;
      var dismissed = 0;
      void dismiss() => dismissed++;
      final intro = CcosOpenStoreContentSource.intro;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildCoconutThemeData(),
          home: ValueListenableBuilder<bool>(
            valueListenable: reduced,
            builder:
                (context, value, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    disableAnimations: !accessibleNavigation && value,
                    accessibleNavigation: accessibleNavigation && value,
                  ),
                  child: child!,
                ),
            child: Center(
              child: SizedBox(
                width: 360,
                child: CoconutOpenStoreIntroCard(intro: intro, onTap: () => opened++, onDismiss: dismiss),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      Animation<double> background() =>
          tester
                  .widget<AnimatedBuilder>(
                    find
                        .descendant(of: find.byType(CoconutOpenStoreIntroCard), matching: find.byType(AnimatedBuilder))
                        .first,
                  )
                  .listenable
              as Animation<double>;
      expect(background().value, 0);
      await tester.pump(const Duration(seconds: 23));
      expect(background().value, 0);
      expect(tester.binding.transientCallbackCount, 0);
      expect(find.text(intro.headline), findsOneWidget);
      await tester.tap(find.text(intro.ctaLabel));
      expect(opened, 1);
      await tester.tap(find.byWidgetPredicate((widget) => widget is GestureDetector && widget.onTap == dismiss));
      expect(dismissed, 1);
      reduced.value = false;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(background().value, greaterThan(0));
      expect(tester.binding.transientCallbackCount, greaterThan(0));
      reduced.value = true;
      await tester.pumpAndSettle();
      expect(background().value, 0);
      await tester.pump(const Duration(seconds: 23));
      expect(tester.binding.transientCallbackCount, 0);
      reduced.value = false;
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 23));
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.takeException(), isNull);
    });
  }
}
