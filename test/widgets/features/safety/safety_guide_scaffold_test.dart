import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/widgets/common/buttons/fixed_bottom_button.dart';
import 'package:coconut_wallet/widgets/features/safety/safety_guide_scaffold.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';

import '../../../screens/safety/safety_test_harness.dart';

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
  await tester.tap(findText('open'));
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
          expect(findText(text), findsOneWidget);
        }
        expect(_fill(tester), 0.25);
        await tester.tap(findText('Moved'));
        await tester.tap(find.byKey(const Key('safety-guide-later')));
        expect((pressed, later), (1, 1));
      });

      testWidgets('guide page without a button handler draws no bottom button', (tester) async {
        await _push(
          tester,
          variant,
          const SafetyGuidePage(progress: 0.04, title: 'Step 1', buttonText: '', children: [Text('Rows')]),
        );
        expect(findText('Rows'), findsOneWidget);
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
        expect(findText('Go'), findsOneWidget);
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
        expect(tester.widget<Text>(findText('C')).style!.color, colors.secondaryText);
        expect(tester.widget<Text>(findText('A')).style!.color, colors.primaryText);

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
        expect(findText('Pending'), findsOneWidget);
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
        expect(findText('Finished'), findsOneWidget);
        expect(findText('Extra'), findsOneWidget);
        expect(_fill(tester), 1);
        await tester.tap(findText('Done'));
        expect(done, 1);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(findText('Finished'), findsOneWidget); // PopScope가 뒤로 가기를 막는다
      });
    });
  }

  // D4/M10: 320dp·2.0배에서 버튼이 두 줄이 되고 부가 줄이 붙어도 마지막 내용이 버튼 묶음 위로 스크롤된다
  for (final withSub in [false, true]) {
    testWidgets('guide and result pages scroll their last content clear of the footer at 2.0x (subWidget: $withSub)', (
      tester,
    ) async {
      useSmallPhone(tester, 2.0);
      const button = 'Continue the security review';
      final rows = [
        for (var i = 0; i < 6; i++) SizedBox(height: 120, child: Text('row $i')),
        const Text('last', key: Key('last')),
      ];
      final pages = [
        (
          SafetyResultPage(
            title: 'Finished',
            description: 'Body',
            buttonText: button,
            onButton: () {},
            subWidget: withSub ? const Text('Back up the new wallet now') : null,
            children: rows,
          ),
          'safety-result',
        ),
        (
          SafetyGuidePage(
            progress: 0.25,
            title: 'Step',
            buttonText: button,
            onButton: () {},
            laterText: withSub ? 'Do it later on another day' : null,
            onLater: withSub ? () {} : null,
            children: rows,
          ),
          'safety-guide',
        ),
      ];
      for (final (page, footer) in pages) {
        await tester.pumpWidget(const SizedBox()); // 앞 화면의 경로 쌓임을 비운다
        await _push(tester, CoconutThemeVariant.light, page);
        final scroll = find.descendant(of: find.byWidget(page), matching: find.byType(SingleChildScrollView));
        // 2.0배에서는 버튼 묶음이 스크롤 영역 가운데를 덮으므로 위쪽에서 끈다
        await tester.dragFrom(tester.getTopLeft(scroll) + const Offset(40, 24), const Offset(0, -8000));
        await tester.pumpAndSettle();
        // 버튼 묶음(부가 줄 포함)과 그 위 페이드 모두 비켜 간다
        final last = tester.getRect(find.byKey(const Key('last'))).bottom;
        expect(last, lessThanOrEqualTo(tester.getRect(find.byKey(Key('$footer-button'))).top));
        final fade = tester.getRect(find.byKey(Key('$footer-fade')));
        expect(last, lessThanOrEqualTo(fade.top + fade.height / 2)); // 페이드의 불투명한 절반 위(X1)
        expect(tester.takeException(), isNull);
      }
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

  // G10: 결과 화면 아이콘과 제목 사이 표시(Premium 구매 완료의 칩). 없으면 자리도 없다
  testWidgets('the result page shows an optional badge between the icon and the title', (tester) async {
    await _push(
      tester,
      CoconutThemeVariant.light,
      SafetyResultPage(
        title: 'Finished',
        description: 'Body',
        buttonText: 'Done',
        onButton: () {},
        badge: const Text('Badge', key: Key('result-badge')),
      ),
    );
    final badge = tester.getRect(find.byKey(const Key('result-badge')));
    expect(badge.top, greaterThan(tester.getRect(find.byType(Lottie)).bottom));
    expect(badge.bottom, lessThan(tester.getRect(findText('Finished')).top));
  });

  // D13: 결과 화면 체크 애니메이션(과 진동)은 화면이 다 밀려 들어온 뒤에 시작한다(전환 중에 끝나 버리지 않게)
  testWidgets('the result check animation waits until the route has settled', (tester) async {
    await _push(
      tester,
      CoconutThemeVariant.light,
      SafetyResultPage(title: 'Finished', description: 'Body', buttonText: 'Done', onButton: () {}),
      settle: false,
    );
    await tester.pump(const Duration(milliseconds: 100)); // 아직 밀려 들어오는 중
    final check = tester.widget<Lottie>(find.byType(Lottie)).controller!;
    expect(check.value, 0);
    await tester.pumpAndSettle();
    expect(check.value, 1);
  });

  // X1: 보조 줄이 있으면 페이드의 불투명한 아래 절반이 보조 줄 위에서 시작한다(모든 배율)
  // 버튼 글이 큰 글자에서 여러 줄로 감겨도(재서 키운다) 보조 줄은 불투명한 띠 위에 있다
  for (final (scale, button) in [(1.0, 'Continue the security review'), (2.0, 'Continue the security review')]) {
    testWidgets('the fade is opaque behind the sub line at ${scale}x on 320dp', (tester) async {
      useSmallPhone(tester, scale);
      final pages = [
        (
          SafetyGuidePage(
            progress: 0.25,
            title: 'Step',
            buttonText: button,
            onButton: () {},
            laterText: 'Do it later',
            onLater: () {},
          ),
          'safety-guide-fade',
          const Key('safety-guide-later'),
        ),
        (
          SafetyResultPage(
            title: 'Finished',
            description: 'Body',
            buttonText: button,
            onButton: () {},
            subWidget: const Text('Back up now', key: Key('result-sub')),
          ),
          'safety-result-fade',
          const Key('result-sub'),
        ),
        // Assist 검토 화면과 같은 쓰임: 수수료 줄을 footer 자리에(보조 줄로) 넘긴다
        (
          SafetyGuidePage(
            progress: 0.25,
            title: 'Review the move',
            buttonText: 'Sign and send the transaction',
            onButton: () {},
            footer: const Text('Network fee 0.0000 1410 BTC', key: Key('review-fee')),
          ),
          'safety-guide-fade',
          const Key('review-fee'),
        ),
      ];
      for (final (page, fade, sub) in pages) {
        await tester.pumpWidget(const SizedBox());
        await _push(tester, CoconutThemeVariant.light, page);
        final rect = tester.getRect(find.byKey(Key(fade)));
        final opaqueTop = rect.top + rect.height / 2; // 그라데이션 stops [0, 0.5]
        expect(opaqueTop, lessThanOrEqualTo(tester.getRect(find.byKey(sub)).top));
      }
    });
  }
}
