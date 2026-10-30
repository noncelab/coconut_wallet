import 'dart:io';

import 'package:coconut_wallet/ccos/open_store/coconut_open_store_content.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/widgets/features/ccos/card/coconut_open_store_intro_card.dart';
import 'package:coconut_wallet/widgets/common/buttons/shrink_tap_wrapper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/semantics.dart' show SemanticsAction;
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async {
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
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets('intro CTA and dismiss have named 48px targets and edge actions at ${scale}x', (tester) async {
      final semantics = tester.ensureSemantics();
      var opened = 0;
      var dismissed = 0;
      final intro = CcosOpenStoreContentSource.intro;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildCoconutThemeData(),
          home: Builder(
            builder:
                (context) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(disableAnimations: true, textScaler: TextScaler.linear(scale)),
                  child: Material(
                    child: Center(
                      child: SizedBox(
                        width: 360,
                        child: CoconutOpenStoreIntroCard(
                          intro: intro,
                          onTap: () => opened++,
                          onDismiss: () => dismissed++,
                        ),
                      ),
                    ),
                  ),
                ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final compactCard = tester.getRect(find.byType(CoconutOpenStoreIntroCard));
      // Measured against the complete original widget with these real fonts and 360px width.
      expect(compactCard.height, scale == 1.0 ? 158 : 395);
      expect(tester.getRect(find.text(intro.title)).top - compactCard.top, 16);
      final visibleCta = find.descendant(of: find.byType(ShrinkTapWrapper), matching: find.text(intro.ctaLabel));
      expect(compactCard.bottom - tester.getRect(visibleCta).bottom, 16);
      expect(tester.getRect(visibleCta).top - tester.getRect(find.text(intro.description)).bottom, 8);
      for (final label in [intro.ctaLabel, t.close]) {
        final target = find.bySemanticsLabel(label);
        expect(target, findsOneWidget);
        final node = tester.getSemantics(target);
        expect(node.flagsCollection.isButton, isTrue);
        expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
        expect(node.rect.width, greaterThanOrEqualTo(48));
        expect(node.rect.height, greaterThanOrEqualTo(48));
        final bounds = tester.getRect(target);
        final cardBounds = tester.getRect(find.byType(CoconutOpenStoreIntroCard));
        expect(cardBounds.contains(bounds.topLeft), isTrue);
        expect(cardBounds.contains(bounds.bottomRight - const Offset(.01, .01)), isTrue);
        expect(bounds.width, greaterThanOrEqualTo(48));
        expect(bounds.height, greaterThanOrEqualTo(48));
        final gesture = await tester.startGesture(bounds.topLeft + const Offset(3, 3));
        await tester.pump(const Duration(milliseconds: 150));
        await tester.pump(const Duration(milliseconds: 150));
        if (label == intro.ctaLabel) {
          final scale = tester.widget<ScaleTransition>(
            find.descendant(of: find.byType(ShrinkTapWrapper), matching: find.byType(ScaleTransition)),
          );
          expect(scale.scale.value, closeTo(.97, .0001));
        }
        await gesture.cancel();
        await tester.pumpAndSettle();
        expect(opened, 0);
        expect(dismissed, 0);
      }
      await tester.tapAt(tester.getRect(find.bySemanticsLabel(intro.ctaLabel)).topLeft + const Offset(3, 3));
      await tester.pumpAndSettle();
      expect(opened, 1);
      await tester.tapAt(tester.getRect(find.bySemanticsLabel(t.close)).topLeft + const Offset(3, 3));
      await tester.pumpAndSettle();
      expect(dismissed, 1);
      final restored = tester.widget<ScaleTransition>(
        find.descendant(of: find.byType(ShrinkTapWrapper), matching: find.byType(ScaleTransition)),
      );
      expect(restored.scale.value, 1);
      expect(tester.widget<ShrinkTapWrapper>(find.byType(ShrinkTapWrapper)).shrinkScale, .97);
      expect(
        tester
            .widget<Text>(find.descendant(of: find.byType(ShrinkTapWrapper), matching: find.text(intro.ctaLabel)))
            .style!
            .fontSize,
        10,
      );
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });
  }
}
