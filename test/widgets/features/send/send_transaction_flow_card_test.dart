import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/enums/transaction_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/widgets/features/send/send_transaction_flow_card.dart';
import 'package:flutter/material.dart';
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
}
