import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/widgets/common/amount/animated_balance.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpBalance(
    WidgetTester tester,
    int value, {
    bool reduceMotion = false,
    bool visible = true,
    BitcoinUnit unit = BitcoinUnit.sats,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduceMotion),
          child: TickerMode(
            enabled: visible,
            child: AnimatedBalance(prevValue: value, value: value, currentUnit: unit, duration: 400),
          ),
        ),
      ),
    );
  }

  int displayed(WidgetTester tester) => int.parse(tester.widget<Text>(find.byType(Text)).data!.replaceAll(',', ''));

  testWidgets('a final balance animates from the displayed amount', (tester) async {
    await pumpBalance(tester, 1000000);
    await pumpBalance(tester, 999000);
    expect(displayed(tester), 1000000);
    await tester.pump(const Duration(milliseconds: 200));
    expect(displayed(tester), inExclusiveRange(999000, 1000000));
    await tester.pumpAndSettle();
    expect(displayed(tester), 999000);
  });

  testWidgets('a new target continues from the current frame without jumping', (tester) async {
    await pumpBalance(tester, 1000000);
    await pumpBalance(tester, 900000);
    await tester.pump(const Duration(milliseconds: 100));
    final before = displayed(tester);
    await pumpBalance(tester, 800000);
    expect(displayed(tester), before);
    await tester.pump(const Duration(milliseconds: 100));
    expect(displayed(tester), inExclusiveRange(800000, before));
    await tester.pumpAndSettle();
    expect(displayed(tester), 800000);
  });

  testWidgets('reduced motion applies the final value immediately', (tester) async {
    await pumpBalance(tester, 1000000, reduceMotion: true);
    await pumpBalance(tester, 999000, reduceMotion: true);
    expect(displayed(tester), 999000);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('BTC animation retains fractional amounts when the final balance is a whole bitcoin or zero', (
    tester,
  ) async {
    double btcAmount() => double.parse(tester.widget<Text>(find.byType(Text)).data!.replaceAll(' ', ''));
    await pumpBalance(tester, 110000000, unit: BitcoinUnit.btc);
    await pumpBalance(tester, 100000000, unit: BitcoinUnit.btc);
    expect(btcAmount(), 1.1);
    await tester.pump(const Duration(milliseconds: 200));
    expect(btcAmount(), inExclusiveRange(1, 1.1));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.byType(Text)).data, '1');
    await pumpBalance(tester, 0, unit: BitcoinUnit.btc);
    await tester.pump(const Duration(milliseconds: 200));
    expect(btcAmount(), inExclusiveRange(0, 1));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.byType(Text)).data, '0');
  });

  testWidgets('a balance received behind the signing screen starts animating on return', (tester) async {
    await pumpBalance(tester, 1000000);
    await pumpBalance(tester, 1000000, visible: false);
    await pumpBalance(tester, 999000, visible: false);
    await tester.pump(const Duration(seconds: 2));
    await pumpBalance(tester, 999000);
    expect(displayed(tester), 1000000);
    await tester.pump(const Duration(milliseconds: 100));
    final after100 = displayed(tester);
    await tester.pump(const Duration(milliseconds: 100));
    final after200 = displayed(tester);
    await tester.pump(const Duration(milliseconds: 100));
    final after300 = displayed(tester);
    expect(1000000 - after100, greaterThan(after100 - after200));
    expect(after100 - after200, greaterThan(after200 - after300));
    await tester.pumpAndSettle();
    expect(displayed(tester), 999000);
  });

  testWidgets('popping the send flow waits for the route transition before animating', (tester) async {
    final navigator = GlobalKey<NavigatorState>();
    final balance = ValueNotifier(1000000);
    addTearDown(balance.dispose);
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        home: ValueListenableBuilder<int>(
          valueListenable: balance,
          builder:
              (context, value, child) =>
                  AnimatedBalance(prevValue: value, value: value, currentUnit: BitcoinUnit.sats, duration: 400),
        ),
      ),
    );
    navigator.currentState!.push(MaterialPageRoute<void>(builder: (_) => const Scaffold()));
    await tester.pumpAndSettle();
    balance.value = 999000;
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    navigator.currentState!.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    expect(displayed(tester), 1000000);
    await tester.pump(const Duration(milliseconds: 200));
    expect(displayed(tester), 1000000);
    await tester.pump(const Duration(milliseconds: 100));
    expect(displayed(tester), inExclusiveRange(999000, 1000000));
    await tester.pumpAndSettle();
    expect(displayed(tester), 999000);
  });
}
