import 'package:coconut_wallet/widgets/textfield/custom_limit_text_field.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CustomLimitTextField', () {
    late TextEditingController controller;
    late FocusNode focusNode;

    setUp(() {
      controller = TextEditingController();
      focusNode = FocusNode();
    });

    testWidgets('rendering, callback test', (tester) async {
      String? changedText;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: CustomLimitTextField(
            controller: controller,
            focusNode: focusNode,
            maxLength: 10,
            onChanged: (text) {
              // controller.text = text;
              changedText = text;
            },
            onClear: () {
              controller.text = '';
              changedText = null;
            },
          ),
        ),
      ));

      expect(find.byType(CupertinoTextField), findsOneWidget);
      expect(find.text('0/10'), findsOneWidget);

      await tester.enterText(find.byType(CupertinoTextField), 'coconut');
      await tester.pumpAndSettle();
      expect(controller.text, 'coconut');
      expect(changedText, 'coconut');
      // expect(find.text('7/10'), findsOneWidget);

      // Tap the clear button
      await tester.tap(find.byType(GestureDetector));
      await tester.pumpAndSettle();
      expect(controller.text, '');
      expect(changedText, isNull);
      //expect(find.text('0/10'), findsOneWidget);
    });
  });
}
