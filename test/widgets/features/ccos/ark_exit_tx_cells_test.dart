import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/widgets/features/ccos/ark/ark_exit_tx_cells.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

int _cells(WidgetTester tester) {
  final finder = find.byKey(const Key('ark-exit-tx-cells'));
  return finder.evaluate().isEmpty ? 0 : tester.widget<Wrap>(finder).children.length;
}

void main() {
  setUp(() => LocaleSettings.setLocaleSync(AppLocale.ko));

  Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
    MaterialApp(
      theme: buildCoconutThemeData(variant: CoconutThemeVariant.dark),
      home: Scaffold(body: SizedBox(width: 300, child: child)),
    ),
  );

  testWidgets('a few transactions show one cell each with how many confirmed', (tester) async {
    await pump(tester, const ArkExitTxCells(done: 4, total: 10, maxWidth: 300));

    expect(_cells(tester), 10);
    expect(find.byKey(const Key('ark-exit-tx-bar')), findsNothing);
    expect(find.text(t.ark_wallet.exit_step_send_detail(done: 4, total: 10)), findsOneWidget);
  });

  testWidgets('many transactions become one bar instead of a wall of cells', (tester) async {
    await pump(tester, const ArkExitTxCells(done: 12, total: 30, maxWidth: 300));

    expect(_cells(tester), 0);
    expect(find.byKey(const Key('ark-exit-tx-bar')), findsOneWidget);
    expect(find.text(t.ark_wallet.exit_step_send_detail(done: 12, total: 30)), findsOneWidget);
  });

  testWidgets('cells that would not fit on one line become the bar, so no cell is left alone on a second line', (
    tester,
  ) async {
    await pump(tester, const ArkExitTxCells(done: 7, total: 20, maxWidth: 300));

    expect(_cells(tester), 0);
    expect(find.byKey(const Key('ark-exit-tx-bar')), findsOneWidget);
  });

  testWidgets('the cell being sent glows, and stays still when motion is reduced', (tester) async {
    await pump(tester, const ArkExitTxCells(done: 2, total: 5, maxWidth: 300));
    expect(find.byKey(const Key('ark-exit-tx-sending')), findsOneWidget);
    final before =
        tester
            .widget<DecoratedBox>(
              find.descendant(of: find.byKey(const Key('ark-exit-tx-sending')), matching: find.byType(DecoratedBox)),
            )
            .decoration;
    await tester.pump(const Duration(milliseconds: 1300));
    final after =
        tester
            .widget<DecoratedBox>(
              find.descendant(of: find.byKey(const Key('ark-exit-tx-sending')), matching: find.byType(DecoratedBox)),
            )
            .decoration;
    expect(after, isNot(before));

    await tester.pumpWidget(
      MaterialApp(
        theme: buildCoconutThemeData(variant: CoconutThemeVariant.dark),
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: const Scaffold(body: SizedBox(width: 300, child: ArkExitTxCells(done: 2, total: 5, maxWidth: 300))),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ark-exit-tx-sending')), findsOneWidget);
  });
}
