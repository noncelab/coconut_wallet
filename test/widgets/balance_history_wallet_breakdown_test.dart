import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/balance_history_edge_painter.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/balance_history_wallet_breakdown.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../mock/transaction_mock.dart';
import '../mock/wallet_mock.dart';

void main() {
  test('small nonzero shares keep their minimum width and zero shares are excluded', () {
    final widths = balanceHistoryShareWidths({1: 1000000, 2: 1, 3: 0}, 300);
    expect(widths[1], 276);
    expect(widths[2], 24);
    expect(widths[3], 0);
    expect(widths.values.fold<double>(0, (sum, value) => sum + value), 300);
    expect(balanceHistoryShareWidths({1: 0, 2: 0}, 300).values, everyElement(0));
  });

  test('many small shares overflow horizontally instead of losing their minimum width', () {
    final widths = balanceHistoryShareWidths({for (var i = 0; i < 30; i++) i: 1}, 300);
    expect(widths.values, everyElement(24));
    expect(widths.values.reduce((a, b) => a + b), 720);
  });

  List<BalanceHistoryWalletSlice> slices(List<int> balances, {bool withTransactions = true}) => [
    for (var i = 0; i < balances.length; i++)
      BalanceHistoryWalletSlice(
        wallet: WalletMock.createSingleSigWalletItem(id: i + 1),
        balance: balances[i],
        transactions: [
          if (withTransactions) ...[
            TransactionMock.createMockTransactionRecord(amount: -10, transactionType: TransactionType.sent),
            if (balances[i] > 0)
              TransactionMock.createMockTransactionRecord(amount: 20, transactionType: TransactionType.received),
          ],
        ],
      ),
  ];

  Future<void> show(
    WidgetTester tester,
    List<int> balances, {
    DateTime? date,
    bool singleWallet = false,
    bool withTransactions = true,
  }) => tester.pumpWidget(
    MaterialApp(
      theme: buildCoconutThemeData(variant: CoconutThemeVariant.light),
      home: Scaffold(
        body: Align(
          alignment: Alignment.topCenter,
          child: SingleChildScrollView(
            child: SizedBox(
              width: 300,
              child: BalanceHistoryWalletBreakdown(
                slices: slices(balances, withTransactions: withTransactions),
                periodLabel: '10/1 ~ 10/7',
                focusedDate: date,
                singleWallet: singleWallet,
                amountText: (amount) => '$amount sats',
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Finder segment(int id) => find.byKey(ValueKey('balance-history-share-$id'));
  Finder getTooltip() => find.byKey(const Key('balance-history-share-tooltip'));
  void expectPointer(WidgetTester tester, int id) {
    final arrow = find.byKey(const Key('balance-history-share-pointer'));
    final painter = tester.widget<CustomPaint>(arrow).painter! as BalanceHistorySharePointer;
    expect(tester.getTopLeft(arrow).dx + painter.center, closeTo(tester.getCenter(segment(id)).dx, 0.01));
  }

  testWidgets('the first wallet tooltip opens by default and tapping a tiny share moves it to that segment', (
    tester,
  ) async {
    await show(tester, [1000000, 1, 0]);
    await tester.pumpAndSettle();
    expect(getTooltip(), findsOneWidget);
    expectPointer(tester, 1);
    expect(segment(3), findsNothing);
    expect(tester.getSize(segment(2)).width, 24);
    await tester.tap(segment(2));
    await tester.pumpAndSettle();
    expect(getTooltip(), findsOneWidget);
    expect(find.text('1 sats (+10 sats)'), findsOneWidget);
    expectPointer(tester, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty sent and received show only counts without amounts', (tester) async {
    await show(tester, [100], singleWallet: true, withTransactions: false);
    await tester.pumpAndSettle();
    for (final label in [t.home_widgets.sent, t.home_widgets.received]) {
      final summary = t.wallet_list.balance_history_detail.flow_count(count: 0);
      expect(find.text('$label $summary'), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('a zero balance wallet still shows transactions in single wallet mode', (tester) async {
    await show(tester, [10], singleWallet: true);
    await tester.pumpAndSettle();
    await show(tester, [0], singleWallet: true, date: DateTime(2026, 10, 7));
    await tester.pumpAndSettle();
    expect(getTooltip(), findsOneWidget);
    expect(find.text('0 sats (-10 sats)'), findsOneWidget);
    expect(find.byKey(const Key('balance-history-shares')), findsNothing);
    expect(find.byKey(const Key('balance-history-share-pointer')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('zero balance transactions remain visible alongside wallets with positive balances', (tester) async {
    await show(tester, [100, 0]);
    await tester.pumpAndSettle();
    expect(segment(1), findsOneWidget);
    expect(segment(2), findsNothing);
    expect(find.byKey(const ValueKey('balance-history-zero-balance-summary-2')), findsOneWidget);
    expect(find.text('0 sats (-10 sats)'), findsOneWidget);
    expectPointer(tester, 1);
    await show(tester, [0, 0]);
    await tester.pumpAndSettle();
    expect(getTooltip(), findsOneWidget);
    expect(find.byKey(const ValueKey('balance-history-zero-balance-summary-2')), findsOneWidget);
    expect(find.byKey(const Key('balance-history-share-pointer')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an interrupted bar animation continues from its current widths', (tester) async {
    await show(tester, [90, 10]);
    await tester.pumpAndSettle();
    await tester.tap(segment(1));
    await tester.pumpAndSettle();
    await show(tester, [10, 90]);
    await tester.pump(const Duration(milliseconds: 100));
    final inFlight = tester.getSize(segment(1)).width;
    expect(inFlight, greaterThan(30));
    expect(inFlight, lessThan(270));
    expect(getTooltip(), findsOneWidget);
    expectPointer(tester, 1);
    await show(tester, [80, 20]);
    expect(tester.getSize(segment(1)).width, closeTo(inFlight, 0.01));
    expectPointer(tester, 1);
    await tester.pumpAndSettle();
    expect(tester.getSize(segment(1)).width, closeTo(240, 0.01));
    expect(tester.getSize(segment(2)).width, closeTo(60, 0.01));
    expectPointer(tester, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('only a selected wallet chip hides the bar and pointer, regardless of date focus', (tester) async {
    await show(tester, [50, 50], date: DateTime(2026, 10, 1));
    await tester.pumpAndSettle();
    expect(getTooltip(), findsOneWidget);
    expect(find.byKey(const Key('balance-history-shares')), findsOneWidget);
    expectPointer(tester, 1);
    await show(tester, [40], singleWallet: true);
    await tester.pumpAndSettle();
    expect(getTooltip(), findsOneWidget);
    expect(find.byKey(const Key('balance-history-shares')), findsNothing);
    expect(find.byKey(const Key('balance-history-share-pointer')), findsNothing);
    await show(tester, [40], singleWallet: true, date: DateTime(2026, 10, 2));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('balance-history-shares')), findsNothing);
    expect(find.byKey(const Key('balance-history-share-pointer')), findsNothing);
    await show(tester, [50, 50], date: DateTime(2026, 10, 2));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('balance-history-shares')), findsOneWidget);
    expectPointer(tester, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('when the selected wallet becomes empty another nonzero wallet receives the tooltip', (tester) async {
    await show(tester, [50, 50], date: DateTime(2026, 10, 1));
    await tester.pumpAndSettle();
    await show(tester, [0, 100], date: DateTime(2026, 10, 2));
    await tester.pumpAndSettle();
    expect(segment(1), findsNothing);
    expect(getTooltip(), findsOneWidget);
    expectPointer(tester, 2);
    await show(tester, [0, 0], date: DateTime(2026, 10, 3));
    await tester.pumpAndSettle();
    expect(getTooltip(), findsOneWidget);
    expect(find.byKey(const Key('balance-history-share-pointer')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('date changes keep the selected share visible as the bar grows and retargets', (tester) async {
    final few = [for (var i = 0; i < 30; i++) i == 0 || i == 29 ? 1 : 0];
    await show(tester, few, date: DateTime(2026, 10, 1));
    await tester.pumpAndSettle();
    await tester.tap(segment(30));
    await tester.pumpAndSettle();

    void expectSelectedVisible() {
      final viewport = tester.getRect(find.byKey(const Key('balance-history-shares')));
      final center = tester.getCenter(segment(30));
      expect(center.dx, inInclusiveRange(viewport.left, viewport.right));
      expectPointer(tester, 30);
    }

    await show(tester, List.filled(30, 1), date: DateTime(2026, 10, 2));
    for (var frame = 0; frame < 24; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
      // Apply the post-layout scroll correction without advancing the animation.
      await tester.pump();
      expectSelectedVisible();
    }
    await tester.pumpAndSettle();
    expectSelectedVisible();
    await show(tester, few, date: DateTime(2026, 10, 3));
    await tester.pump(const Duration(milliseconds: 100));
    await show(tester, List.filled(30, 1), date: DateTime(2026, 10, 4));
    for (var frame = 0; frame < 24; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
      // Apply the post-layout scroll correction without advancing the animation.
      await tester.pump();
      expectSelectedVisible();
    }
    await tester.pumpAndSettle();
    expectSelectedVisible();
    expect(tester.takeException(), isNull);
  });

  testWidgets('share bar clamps at both ends and shows feedback until the drag ends', (tester) async {
    await show(tester, List.filled(30, 1));
    await tester.pumpAndSettle();
    final bar = find.byKey(const Key('balance-history-shares'));
    final controller = tester.widget<SingleChildScrollView>(bar).controller!;
    double feedback() {
      final paint = tester.widget<CustomPaint>(
        find.descendant(
          of: find.byKey(const Key('balance-history-shares-edge-feedback')),
          matching: find.byType(CustomPaint),
        ),
      );
      return (paint.painter! as BalanceHistoryEdgePainter).overscroll;
    }

    for (final right in [false, true]) {
      controller.jumpTo(right ? controller.position.maxScrollExtent : 0);
      await tester.pumpAndSettle();
      final edgeOffset = controller.offset;
      final gesture = await tester.startGesture(tester.getCenter(bar));
      await gesture.moveBy(Offset(right ? -30 : 30, 0));
      await gesture.moveBy(Offset(right ? -50 : 50, 0));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));
      expect(controller.offset, edgeOffset);
      expect(feedback(), right ? greaterThan(0) : lessThan(0));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(feedback(), 0);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('the tooltip pointer follows a selected small segment after horizontal scrolling', (tester) async {
    await show(tester, List.filled(30, 1));
    await tester.pumpAndSettle();
    await tester.drag(find.byKey(const Key('balance-history-shares')), const Offset(-800, 0));
    await tester.pumpAndSettle();
    await tester.tap(segment(30));
    await tester.pumpAndSettle();
    expect(getTooltip(), findsOneWidget);
    expect(tester.getSize(segment(30)).width, 24);
    expectPointer(tester, 30);
    expect(tester.takeException(), isNull);
  });
}
