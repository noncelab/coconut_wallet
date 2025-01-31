import 'package:coconut_wallet/widgets/tooltip/faucet_tooltip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FaucetTooltip', () {
    const double testScreenWidth = 500.0;

    testWidgets('rendering, callback test', (tester) async {
      bool isOnTapRemove = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                FaucetTooltip(
                  text: 'Faucet tooltip',
                  width: testScreenWidth,
                  isVisible: true,
                  iconPosition: const Offset(30, 30),
                  iconSize: const Size(18, 18),
                  onTapRemove: () {
                    isOnTapRemove = true;
                  },
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Faucet tooltip'), findsOneWidget);

      await tester.tap(find.byType(GestureDetector));
      await tester.pump();
      expect(isOnTapRemove, true);
    });
  });
}
