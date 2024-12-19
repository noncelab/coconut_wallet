import 'package:coconut_wallet/screens/bottomsheet/memo_bottom_sheet_container.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

void main() {
  group('MemoBottomSheetScreen Tests', () {
    String mockMemo = 'updateMemo';

    testWidgets('calls onComplete with correct data when changing memo',
        (WidgetTester tester) async {
      String? resultMemo;

      await tester.pumpWidget(MaterialApp(
        home: MemoBottomSheetContainer(
          updateMemo: mockMemo,
          onComplete: (memo) {
            resultMemo = memo;
          },
        ),
      ));

      // CupertinoTextField 찾기
      final textFieldFinder = find.byType(CupertinoTextField);
      expect(textFieldFinder, findsOneWidget);

      // CupertinoTextField 'changeMemo' 입력
      await tester.enterText(textFieldFinder, 'changeMemo');
      await tester.pumpAndSettle();

      // 완료 버튼 클릭
      final completeButtonFinder = find.text('완료');
      expect(completeButtonFinder, findsOneWidget);
      await tester.tap(completeButtonFinder);
      await tester.pumpAndSettle();

      // onComplete 콜백 결과 검증
      expect(resultMemo, isNotEmpty);
      expect(resultMemo, equals('changeMemo'));
    });
  });
}
