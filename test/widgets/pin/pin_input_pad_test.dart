import 'package:coconut_wallet/widgets/pin/pin_input_pad.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PinInputPad', () {
    late String enteredPin;
    late List<String> pinShuffleNumbers;
    late int step;
    late VoidCallback onReset;

    setUp(() {
      enteredPin = '';
      pinShuffleNumbers = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0'];
      step = 0;
      onReset = () {
        enteredPin = '';
      };
    });

    testWidgets('rendering, callback test', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PinInputPad(
              title: 'PIN',
              pin: enteredPin,
              errorMessage: 'Error Message',
              pinShuffleNumbers: pinShuffleNumbers,
              step: step,
              onKeyTap: (key) {
                enteredPin += key;
              },
              onClosePressed: () {},
              onReset: onReset,
            ),
          ),
        ),
      );

      expect(find.text('PIN'), findsOneWidget);
      expect(find.text('Error Message'), findsOneWidget);

      await tester.tap(find.text('1'));
      await tester.tap(find.text('2'));
      await tester.tap(find.text('3'));
      await tester.tap(find.text('4'));
      await tester.pumpAndSettle();
      expect(enteredPin, '1234');
    });
  });
}
