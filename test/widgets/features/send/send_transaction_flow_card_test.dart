import 'dart:convert';
import 'dart:math';

import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/enums/transaction_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/widgets/features/send/send_transaction_flow_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() => LocaleSettings.setLocaleSync(AppLocale.ko));

  Future<void> showCard(WidgetTester tester, SendTransactionFlowCard card) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildCoconutThemeData(variant: CoconutThemeVariant.dark),
        home: Scaffold(body: SingleChildScrollView(child: card)),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
  }

  for (final mode in SendTransactionFlowCardMode.values) {
    testWidgets('$mode keeps zero-based indices across change outputs and missing input amounts', (tester) async {
      const targets = [
        FlowOutputTapTarget(address: 'recipient-0', amount: 10000, outputIndex: 0),
        FlowOutputTapTarget(address: 'recipient-2', amount: 10000, outputIndex: 2),
      ];
      FlowOutputTapTarget? tapped;
      await showCard(
        tester,
        SendTransactionFlowCard(
          inputAmounts: const [30000, null],
          externalOutputAmounts: targets.map((target) => target.amount).toList(),
          externalOutputTapTargets: targets,
          changeOutputAmounts: const [9000],
          fee: 1000,
          currentUnit: BitcoinUnit.sats,
          mode: mode,
          isOutputMine: (_) => true,
          navigableOutputTapTargets: const [
            FlowOutputTapTarget(address: 'change-1', amount: 9000, outputIndex: 1, isChange: true),
            ...targets,
          ],
          onOutputTap: (target) => tapped = target,
        ),
      );
      for (final label in ['입력 #0', '입력 #1', '출력 #0', '출력 #2', t.change]) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.text('입력 #2'), findsNothing);
      expect(find.text('출력 #1'), findsNothing);
      if (mode == SendTransactionFlowCardMode.navigable) {
        await tester.tap(find.text('출력 #2'));
        expect(tapped, same(targets.last));
      }
    });

    testWidgets('$mode preserves original indices when intermediate nodes are collapsed', (tester) async {
      final targets = [
        for (final index in [20, 21, 22, 23, 500])
          FlowOutputTapTarget(address: 'recipient-$index', amount: 1000, outputIndex: index),
      ];
      await showCard(
        tester,
        SendTransactionFlowCard(
          inputAmounts: List.filled(7, 1000),
          externalOutputAmounts: targets.map((target) => target.amount).toList(),
          externalOutputTapTargets: targets,
          changeOutputAmounts: const [],
          fee: 2000,
          currentUnit: BitcoinUnit.sats,
          mode: mode,
        ),
      );
      for (final label in ['입력 #0', '입력 #1', '입력 #2', '입력 #6', '출력 #20', '출력 #500']) {
        expect(find.text(label), findsOneWidget);
      }
      for (final label in ['입력 #3', '입력 #7', '출력 #0', '출력 #4', '출력 #21']) {
        expect(find.text(label), findsNothing);
      }
    });
  }

  testWidgets('receiving flow keeps the actual output indices around hidden unrelated outputs', (tester) async {
    final outputs = [
      for (var index = 0; index <= 501; index++)
        FlowOutputTapTarget(address: 'recipient-$index', amount: 1000, outputIndex: index),
    ];
    FlowOutputTapTarget? tapped;
    await showCard(
      tester,
      SendTransactionFlowCard(
        inputAmounts: const [503000],
        externalOutputAmounts: outputs.map((target) => target.amount).toList(),
        changeOutputAmounts: const [],
        fee: 1000,
        currentUnit: BitcoinUnit.sats,
        mode: SendTransactionFlowCardMode.navigable,
        transactionStatus: TransactionStatus.received,
        orderedOutputs: outputs,
        isOutputMine: (address) => address == 'recipient-20' || address == 'recipient-500',
        navigableOutputTapTargets: [outputs[20], outputs[500]],
        onOutputTap: (target) => tapped = target,
      ),
    );
    for (final index in [0, 20, 500, 501]) {
      expect(find.text('출력 #$index'), findsOneWidget);
    }
    expect(find.text('출력 #1'), findsNothing);
    await tester.tap(find.text('출력 #500'));
    expect(tapped, same(outputs[500]));
  });

  testWidgets('connection anchors follow a width change that does not rebuild the card (fold/unfold)', (tester) async {
    const card = SendTransactionFlowCard(
      inputAmounts: [1224344782395, 69990, 1410],
      externalOutputAmounts: [100000000],
      changeOutputAmounts: [1224244789259],
      fee: 276,
      currentUnit: BitcoinUnit.btc,
      mode: SendTransactionFlowCardMode.plain,
    );
    addTearDown(tester.view.reset);
    tester.view.devicePixelRatio = 1;
    Future<List<List<Offset>>> anchorsAt(double width, {bool fresh = false}) async {
      tester.view.physicalSize = Size(width, 900);
      if (fresh) {
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(
          MaterialApp(
            theme: buildCoconutThemeData(variant: CoconutThemeVariant.dark),
            home: const Scaffold(body: SingleChildScrollView(child: card)),
          ),
        );
      }
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      final painter =
          tester
                  .widget<CustomPaint>(
                    find.descendant(of: find.byType(SendTransactionFlowCard), matching: find.byType(CustomPaint)).first,
                  )
                  .painter
              as dynamic;
      return [
        List<Offset>.of(painter.inputAnchors as List<Offset>),
        List<Offset>.of(painter.outputAnchors as List<Offset>),
      ];
    }

    final expected = await anchorsAt(867, fresh: true);
    // 넓은 화면: 입력 글자 바로 뒤에서 출력 글자 바로 앞까지 선이 이어지고, 출력은 카드 오른쪽 끝에 붙는다.
    final cardRect = tester.getRect(find.byType(SendTransactionFlowCard));
    final paintLeft = cardRect.left + 16;
    final texts = [
      for (final e in find.descendant(of: find.byType(SendTransactionFlowCard), matching: find.byType(Text)).evaluate())
        tester.getRect(find.byWidget(e.widget)),
    ];
    final inputTexts = texts.where((r) => r.center.dx < cardRect.center.dx);
    final outputTexts = texts.where((r) => r.center.dx > cardRect.center.dx);
    final inputRight = inputTexts.map((r) => r.right).reduce(max) - paintLeft;
    final outputLeft = outputTexts.map((r) => r.left).reduce(min) - paintLeft;
    expect(expected[0].map((o) => o.dx).reduce(max), closeTo(inputRight + 8, 0.5));
    expect(expected[1].map((o) => o.dx).reduce(min), closeTo(outputLeft - 8, 0.5));
    expect(outputTexts.map((r) => r.right).reduce(max), closeTo(cardRect.right - 16, 0.5));
    final narrow = await anchorsAt(382, fresh: true);
    // 일반 폰 폭에서 긴 금액은 글자 영역이 남는 폭의 절반((350 - 128) / 2 = 111)에서 멈추고, 선은 그 8pt 뒤에서 시작한다.
    expect(narrow[0].first.dx, 111 + 8);
    expect(narrow[1].first.dx, 350 - 111 - 8);
    // 같은 카드 위젯을 그대로 둔 채 폭만 넓힌다(Duo 펼침). 카드가 다시 빌드되지 않아도 기준점이 새 폭을 따라야 한다.
    expect(await anchorsAt(867), expected);
  });

  for (final width in [382.0, 867.0]) {
    testWidgets('columns hug their text on both card edges at width $width', (tester) async {
      addTearDown(tester.view.reset);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 900);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildCoconutThemeData(variant: CoconutThemeVariant.light),
          home: const Scaffold(
            body: SingleChildScrollView(
              child: SendTransactionFlowCard(
                inputAmounts: [120000000, 6999, 141],
                externalOutputAmounts: [100000000],
                changeOutputAmounts: [20000000],
                fee: 276,
                currentUnit: BitcoinUnit.btc,
                mode: SendTransactionFlowCardMode.plain,
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      final cardRect = tester.getRect(find.byType(SendTransactionFlowCard));
      final paintLeft = cardRect.left + 16;
      final texts = [
        for (final e
            in find.descendant(of: find.byType(SendTransactionFlowCard), matching: find.byType(Text)).evaluate())
          tester.getRect(find.byWidget(e.widget)),
      ];
      final inputTexts = texts.where((r) => r.center.dx < cardRect.center.dx);
      final outputTexts = texts.where((r) => r.center.dx > cardRect.center.dx);
      final painter =
          tester
                  .widget<CustomPaint>(
                    find.descendant(of: find.byType(SendTransactionFlowCard), matching: find.byType(CustomPaint)).first,
                  )
                  .painter
              as dynamic;
      final inputAnchors = painter.inputAnchors as List<Offset>;
      final outputAnchors = painter.outputAnchors as List<Offset>;
      // 입력 글자 8pt 뒤에서 선이 시작하고, 출력 글자 8pt 앞에서 끝나며, 출력은 카드 오른쪽 끝에 붙는다(좌우 여백 같음).
      expect(
        inputAnchors.map((o) => o.dx).reduce(max),
        closeTo(inputTexts.map((r) => r.right).reduce(max) - paintLeft + 8, 0.5),
      );
      expect(
        outputAnchors.map((o) => o.dx).reduce(min),
        closeTo(outputTexts.map((r) => r.left).reduce(min) - paintLeft - 8, 0.5),
      );
      expect(inputTexts.map((r) => r.left).reduce(min) - cardRect.left, closeTo(16, 0.5));
      expect(cardRect.right - outputTexts.map((r) => r.right).reduce(max), closeTo(16, 0.5));
      expect(tester.takeException(), isNull);
    });
  }

  // 금액이 잘리거나 넘치는지는 실제 글자 폭에 달려 있으므로 앱 폰트로 그린다(테스트 기본 폰트는 글자가 훨씬 넓다).
  group('with the app fonts', () {
    setUpAll(() async {
      final manifest = json.decode(await rootBundle.loadString('FontManifest.json')) as List<dynamic>;
      for (final family in manifest.cast<Map<String, dynamic>>()) {
        final loader = FontLoader(family['family'] as String);
        for (final font in (family['fonts'] as List<dynamic>).cast<Map<String, dynamic>>()) {
          loader.addFont(rootBundle.load(font['asset'] as String));
        }
        await loader.load();
      }
    });
    for (final unit in [BitcoinUnit.btc, BitcoinUnit.sats]) {
      for (final width in [360.0, 375.0, 867.0]) {
        testWidgets('extreme amounts in $unit at width $width stay inside the card without overflow', (tester) async {
          addTearDown(tester.view.reset);
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = Size(width, 900);
          await tester.pumpWidget(
            MaterialApp(
              theme: buildCoconutThemeData(variant: CoconutThemeVariant.light),
              home: Scaffold(
                body: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: SendTransactionFlowCard(
                      inputAmounts: const [2099999999999999, 1, null],
                      externalOutputAmounts: const [2099999999999999, 123456789012],
                      changeOutputAmounts: const [2099999999999998],
                      fee: 99999999,
                      currentUnit: unit,
                      mode: SendTransactionFlowCardMode.plain,
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pump(const Duration(milliseconds: 300));
          await tester.pump(const Duration(milliseconds: 300));
          expect(tester.takeException(), isNull);
          final cardRect = tester.getRect(find.byType(SendTransactionFlowCard));
          for (final e
              in find.descendant(of: find.byType(SendTransactionFlowCard), matching: find.byType(Text)).evaluate()) {
            final rect = tester.getRect(find.byWidget(e.widget));
            expect(rect.left, greaterThanOrEqualTo(cardRect.left + 16 - 0.5));
            expect(rect.right, lessThanOrEqualTo(cardRect.right - 16 + 0.5));
          }
        });
      }
    }
  });
}
