import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/screens/ccos/ark/ark_move_parts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => LocaleSettings.setLocaleSync(AppLocale.ko));

  Future<void> pump(WidgetTester tester, ArkMoveRoute route) => tester.pumpWidget(
    MaterialApp(
      theme: buildCoconutThemeData(variant: CoconutThemeVariant.dark),
      home: Scaffold(body: SingleChildScrollView(child: route)),
    ),
  );

  testWidgets('reads from the sending wallet down to the receiving one, fees on the arrow between', (tester) async {
    await pump(
      tester,
      const ArkMoveRoute(
        fromName: '내 지갑',
        fromBalance: '240,198 sats',
        amount: Text('amount box'),
        fees: ['네트워크 수수료 530 sats'],
        toName: '아크 지갑',
        toBalance: '310 sats',
        arrival: '49,470 sats',
        arrivalDetail: '3블록(약 30분) 뒤 아크 잔액에 들어와요',
        total: '50,000 sats',
      ),
    );

    final from = tester.getTopLeft(find.text('내 지갑'));
    final amount = tester.getTopLeft(find.text('amount box'));
    final fee = tester.getTopLeft(find.text('네트워크 수수료 530 sats'));
    final to = tester.getTopLeft(find.text('아크 지갑'));
    final arrival = tester.getTopLeft(find.text('+ 49,470 sats'));
    expect([
      from.dy,
      amount.dy,
      fee.dy,
      to.dy,
      arrival.dy,
    ], orderedEquals([from.dy, amount.dy, fee.dy, to.dy, arrival.dy]..sort()));
    expect(find.text(t.ark_wallet.fill_from), findsOneWidget);
    expect(find.text(t.ark_wallet.export_to), findsOneWidget);
    expect(find.text(t.ark_wallet.wallet_balance(amount: '240,198 sats')), findsOneWidget);
    expect(find.text(t.ark_wallet.wallet_balance(amount: '310 sats')), findsOneWidget);
    expect(find.text('3블록(약 30분) 뒤 아크 잔액에 들어와요'), findsOneWidget);
    expect(find.text(t.ark_wallet.move_total), findsOneWidget);
    final total = tester.getTopLeft(find.text('50,000 sats')).dy;
    expect(total, greaterThan(fee.dy));
    expect(total, lessThan(to.dy));
  });

  testWidgets('without an amount yet the receiving card shows no arrival', (tester) async {
    await pump(
      tester,
      const ArkMoveRoute(
        fromName: '아크 지갑',
        fromBalance: '310 sats',
        amount: Text('amount box'),
        fees: [],
        toName: '내 지갑',
        toBalance: '240,198 sats',
      ),
    );

    expect(find.textContaining('+ '), findsNothing);
  });

  testWidgets('a wallet that can be changed shows an arrow and opens the picker on tap', (tester) async {
    var tapped = 0;
    await pump(
      tester,
      ArkMoveRoute(
        fromName: '내 지갑',
        fromBalance: '240,198 sats',
        onFromTap: () => tapped++,
        amount: const Text('amount box'),
        fees: const [],
        toName: '아크 지갑',
        toBalance: '310 sats',
      ),
    );

    expect(find.byKey(const Key('ark-move-from-change')), findsOneWidget);
    expect(find.byKey(const Key('ark-move-to-change')), findsNothing);
    await tester.tap(find.text('내 지갑'));
    expect(tapped, 1);
  });
}
