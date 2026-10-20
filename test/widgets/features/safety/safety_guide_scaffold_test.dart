import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/widgets/common/buttons/fixed_bottom_button.dart';
import 'package:coconut_wallet/widgets/features/safety/safety_guide_scaffold.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';

Widget _app(CoconutThemeVariant variant, Widget home, {bool reduceMotion = false}) => MaterialApp(
  theme: buildCoconutThemeData(variant: variant),
  builder:
      (context, child) =>
          MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion), child: child!),
  home: home,
);

/// 경로 전환 뒤 채우는 동작까지 보려고 첫 화면에서 push한다
Future<void> _push(WidgetTester tester, CoconutThemeVariant variant, Widget page, {bool settle = true}) async {
  await tester.pumpWidget(
    _app(
      variant,
      Builder(
        builder:
            (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).push(CupertinoPageRoute<void>(builder: (_) => page)),
                  child: const Text('open'),
                ),
              ),
            ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

double _fill(WidgetTester tester) =>
    tester
        .widget<FractionallySizedBox>(
          find.descendant(of: find.byType(SafetyGuideProgressBar), matching: find.byType(FractionallySizedBox)),
        )
        .widthFactor!;

void main() {
  for (final variant in CoconutThemeVariant.values) {
    final colors = resolveCoconutThemeExtension(variant: variant).colors;

    group(variant.name, () {
      testWidgets('progress bar fills to its value after the route settles and reads the step', (tester) async {
        final handle = tester.ensureSemantics();
        await _push(tester, variant, const Scaffold(body: SafetyGuideProgressBar(value: 0.5)), settle: false);
        await tester.pump(const Duration(milliseconds: 150));
        expect(_fill(tester), lessThan(0.5)); // 전환 중에는 아직 채우지 않는다
        await tester.pumpAndSettle();
        expect(_fill(tester), 0.5);
        final track = tester.widget<ColoredBox>(
          find.descendant(of: find.byType(SafetyGuideProgressBar), matching: find.byType(ColoredBox)),
        );
        expect(track.color, colors.pageIndicatorInactive);
        expect(
          tester.getSemantics(find.byType(SafetyGuideProgressBar)),
          matchesSemantics(
            label: t.safety_guide.progress_label,
            value: t.safety_guide.progress_a11y(total: 4, step: 3),
          ),
        );
        handle.dispose();
      });

      testWidgets('guide page shows content in order, then the button and the later link', (tester) async {
        var pressed = 0;
        var later = 0;
        await _push(
          tester,
          variant,
          SafetyGuidePage(
            progress: 0.25,
            iconPath: 'assets/svg/features/shortcuts/utxos.svg',
            title: 'Title',
            description: 'Description',
            buttonText: 'Moved',
            onButton: () => pressed++,
            laterText: 'Later',
            onLater: () => later++,
            children: const [Text('Card')],
          ),
        );
        for (final text in ['Title', 'Description', 'Card', 'Moved', 'Later']) {
          expect(find.text(text), findsOneWidget);
        }
        expect(_fill(tester), 0.25);
        await tester.tap(find.text('Moved'));
        await tester.tap(find.byKey(const Key('safety-guide-later')));
        expect((pressed, later), (1, 1));
      });

      testWidgets('guide page without a button handler draws no bottom button', (tester) async {
        await _push(
          tester,
          variant,
          const SafetyGuidePage(progress: 0.04, title: 'Step 1', buttonText: '', children: [Text('Rows')]),
        );
        expect(find.text('Rows'), findsOneWidget);
        expect(find.byType(FixedBottomButton), findsNothing);
      });

      testWidgets('reduce motion shows the whole page on the first frame', (tester) async {
        await tester.pumpWidget(
          _app(
            variant,
            SafetyGuidePage(
              progress: 0.75,
              title: 'Title',
              description: 'Description',
              buttonText: 'Go',
              onButton: () {},
            ),
            reduceMotion: true,
          ),
        );
        expect(find.text('Go'), findsOneWidget);
        expect(_fill(tester), 0.75);
        final opacities = tester.widgetList<AnimatedOpacity>(find.byType(AnimatedOpacity));
        expect(opacities.every((o) => o.opacity == 1), isTrue);
      });

      testWidgets('step list marks done, active and pending rows', (tester) async {
        await tester.pumpWidget(
          _app(variant, const Scaffold(body: SafetyStepList(steps: ['A', 'B', 'C'], activeIndex: 1))),
        );
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.byKey(const ValueKey('done')), findsOneWidget);
        expect(find.byKey(const ValueKey('pending')), findsOneWidget);
        expect(tester.widget<Text>(find.text('C')).style!.color, colors.secondaryText);
        expect(tester.widget<Text>(find.text('A')).style!.color, colors.primaryText);

        await tester.pumpWidget(
          _app(variant, const Scaffold(body: SafetyStepList(steps: ['A', 'B', 'C'], activeIndex: 1, failed: true))),
        );
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.byKey(const ValueKey('failed')), findsOneWidget);
      });

      testWidgets('result page with a custom icon shows it instead of the check animation', (tester) async {
        await tester.pumpWidget(
          _app(
            variant,
            SafetyResultPage(
              title: 'Pending',
              description: 'Waiting for the store',
              buttonText: 'OK',
              onButton: () {},
              icon: const SizedBox(key: Key('custom-result-icon'), width: 64, height: 64),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('custom-result-icon')), findsOneWidget);
        expect(find.byType(Lottie), findsNothing);
        expect(find.text('Pending'), findsOneWidget);
      });

      testWidgets('result page shows the outcome, blocks back and runs its button', (tester) async {
        var done = 0;
        await _push(
          tester,
          variant,
          SafetyResultPage(
            title: 'Finished',
            description: 'Checked again on next sync',
            buttonText: 'Done',
            onButton: () => done++,
            progress: 1,
            children: const [Text('Extra')],
          ),
        );
        expect(find.text('Finished'), findsOneWidget);
        expect(find.text('Extra'), findsOneWidget);
        expect(_fill(tester), 1);
        await tester.tap(find.text('Done'));
        expect(done, 1);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.text('Finished'), findsOneWidget); // PopScope가 뒤로 가기를 막는다
      });
    });
  }

  // D7: 동작 줄이기(두 가지 설정 모두)면 진행 중 표시가 돌지 않는다. 돌면 pumpAndSettle이 끝나지 않는다
  for (final (flag, reduce) in [
    ('disableAnimations', (MediaQueryData m) => m.copyWith(disableAnimations: true)),
    ('accessibleNavigation', (MediaQueryData m) => m.copyWith(accessibleNavigation: true)),
  ]) {
    testWidgets('reduced motion ($flag) keeps the active step indicator still', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildCoconutThemeData(),
          home: Builder(
            builder:
                (context) => MediaQuery(
                  data: reduce(MediaQuery.of(context)),
                  child: const Scaffold(body: SafetyStepList(steps: ['A', 'B'], activeIndex: 0)),
                ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<CircularProgressIndicator>(find.byType(CircularProgressIndicator)).value, isNotNull);
    });
  }

  // D8: 실패한 단계는 화면 낭독기에 실패 상태를 알린다
  testWidgets('a failed step announces its failure to screen readers', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _app(
        CoconutThemeVariant.light,
        const Scaffold(body: SafetyStepList(steps: ['A', 'B'], activeIndex: 1, failed: true)),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      tester.getSemantics(find.bySemanticsLabel('B')),
      matchesSemantics(label: 'B', value: t.safety_guide.move.step_failed_a11y),
    );
    expect(tester.getSemantics(find.bySemanticsLabel('A')), matchesSemantics(label: 'A', value: t.done));
    handle.dispose();
  });
}
