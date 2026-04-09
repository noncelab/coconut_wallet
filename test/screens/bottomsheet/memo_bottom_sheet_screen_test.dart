import 'package:coconut_wallet/screens/common/single_text_field_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Transaction memo SingleTextFieldBottomSheet Tests', () {
    const mockMemo = 'updateMemo';

    testWidgets('calls onComplete with correct data when changing memo', (WidgetTester tester) async {
      String? resultMemo;

      await tester.pumpWidget(
        MaterialApp(
          home: SingleTextFieldBottomSheet(
            originalText: mockMemo,
            completeButtonText: '완료',
            onComplete: (memo) {
              resultMemo = memo;
            },
          ),
        ),
      );

      final editableFinder = find.byType(EditableText);
      expect(editableFinder, findsOneWidget);

      await tester.enterText(editableFinder, 'changeMemo');
      await tester.pumpAndSettle();

      final completeButtonFinder = find.text('완료');
      expect(completeButtonFinder, findsOneWidget);
      await tester.tap(completeButtonFinder);
      await tester.pumpAndSettle();

      expect(resultMemo, isNotEmpty);
      expect(resultMemo, equals('changeMemo'));
    });
  });
}
