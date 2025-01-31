import 'package:coconut_wallet/widgets/textfield/custom_text_field.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CustomTextField', () {
    late TextEditingController controller;

    setUp(() {
      controller = TextEditingController();
    });

    testWidgets('rendering, callback test', (tester) async {
      String? changedText;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomTextField(
              controller: controller,
              placeholder: 'Placeholder text',
              onChanged: (text) {
                changedText = text;
              },
            ),
          ),
        ),
      );

      expect(find.text('Placeholder text'), findsOneWidget);

      await tester.enterText(find.byType(CupertinoTextField), 'coconut');
      await tester.pump();
      expect(controller.text, 'coconut');
      expect(changedText, 'coconut');
      expect(find.text('coconut'), findsOneWidget);
    });
  });
}
