import 'package:coconut_wallet/model/utxo/utxo_tag.dart';
import 'package:coconut_wallet/screens/common/tag_bottom_sheet.dart';
import 'package:coconut_wallet/widgets/deprecated_custom_tag_chip.dart';
import 'package:coconut_wallet/widgets/button/custom_tag_chip_color_button.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

void main() {
  group('TagBottomSheetScreen Tests', () {
    late List<UtxoTag> mockTags;
    late List<String> mockSelectedTags;

    setUp(() {
      mockTags = [
        const UtxoTag(id: 'uuid1', walletId: 1, name: 'kyc', colorIndex: 0),
        const UtxoTag(id: 'uuid2', walletId: 2, name: 'coconut', colorIndex: 2),
        const UtxoTag(id: 'uuid3', walletId: 3, name: 'strike', colorIndex: 7),
      ];
      mockSelectedTags = const ['kyc', 'coconut'];
    });

    testWidgets('calls onComplete with correct data when selecting tags',
        (WidgetTester tester) async {
      List<String> resultTagNames = [];
      // List<UtxoTag> resultUtxoTags = [];

      await tester.pumpWidget(MaterialApp(
        home: TagBottomSheet(
          type: TagBottomSheetType.select,
          utxoTags: mockTags,
          selectedUtxoTagNames: mockSelectedTags,
          onSelected: (utxoTagNames, createdUtxoTags) {
            resultTagNames = utxoTagNames;
            // resultUtxoTags = createdUtxoTags;
          },
        ),
      ));

      // kyc 클릭
      final gestureFinder = find.byWidgetPredicate(
        (widget) =>
            widget is GestureDetector &&
            widget.child is CustomTagChip &&
            (widget.child as CustomTagChip).tag == 'kyc',
      );
      expect(gestureFinder, findsOneWidget);
      await tester.tap(gestureFinder);

      // strike 클릭
      final gestureFinder2 = find.byWidgetPredicate(
        (widget) =>
            widget is GestureDetector &&
            widget.child is CustomTagChip &&
            (widget.child as CustomTagChip).tag == 'strike',
      );
      expect(gestureFinder2, findsOneWidget);
      await tester.tap(gestureFinder2);

      await tester.pumpAndSettle();

      // Check if onComplete is called with updated data
      await tester.tap(find.text('완료'));
      await tester.pump();

      expect(resultTagNames, isNotEmpty);
      expect(resultTagNames, isNot(contains('kyc'))); // 제외
      expect(resultTagNames, contains('coconut'));
      expect(resultTagNames, contains('strike')); // 등록

      // expect(resultUtxoTags, isNotEmpty);
      // expect(resultUtxoTags.first.name, contains('strike')); // 등록
    });

    testWidgets('calls onComplete with correct data when creating tags',
        (WidgetTester tester) async {
      UtxoTag? resultTag;

      await tester.pumpWidget(MaterialApp(
        home: TagBottomSheet(
          type: TagBottomSheetType.create,
          utxoTags: mockTags,
          onUpdated: (utxoTag) {
            resultTag = utxoTag;
          },
        ),
      ));

      // CupertinoTextField 찾기
      final textFieldFinder = find.byType(CupertinoTextField);
      expect(textFieldFinder, findsOneWidget);

      // CupertinoTextField 'keystone' 입력
      await tester.enterText(textFieldFinder, '#keystone');
      await tester.pumpAndSettle();

      // CustomTagColorSelector 찾기
      final chipButtonFinder = find.byType(CustomTagChipColorButton);
      expect(chipButtonFinder, findsOneWidget);

      // CustomTagChipButton 2회 클릭
      await tester.tap(chipButtonFinder);
      await tester.pump();
      await tester.tap(chipButtonFinder);
      await tester.pump();

      // 완료 버튼 클릭
      final completeButtonFinder = find.text('완료');
      expect(completeButtonFinder, findsOneWidget);
      await tester.tap(completeButtonFinder);
      await tester.pumpAndSettle();

      // onComplete 콜백 결과 검증
      expect(resultTag, isNotNull);
      expect(resultTag!.name, equals('keystone'));
      expect(resultTag!.colorIndex, equals(2));
    });

    testWidgets('calls onComplete with correct data when updating tags',
        (WidgetTester tester) async {
      UtxoTag? resultTag;

      await tester.pumpWidget(MaterialApp(
        home: TagBottomSheet(
          type: TagBottomSheetType.update,
          utxoTags: mockTags,
          updateUtxoTag: mockTags[2],
          onUpdated: (utxoTag) {
            resultTag = utxoTag;
          },
        ),
      ));

      // CupertinoTextField 찾기
      final textFieldFinder = find.byType(CupertinoTextField);
      expect(textFieldFinder, findsOneWidget);

      // CupertinoTextField 'nunchuk' 입력
      await tester.enterText(textFieldFinder, '#nunchuk');
      await tester.pumpAndSettle();

      // CustomTagColorSelectButton 찾기
      final chipButtonFinder = find.byType(CustomTagChipColorButton);
      expect(chipButtonFinder, findsOneWidget);

      // CustomTagColorSelectButton 3회 클릭
      await tester.tap(chipButtonFinder);
      await tester.pump();
      await tester.tap(chipButtonFinder);
      await tester.pump();
      await tester.tap(chipButtonFinder);
      await tester.pump();

      // 완료 버튼 클릭
      final completeButtonFinder = find.text('완료');
      expect(completeButtonFinder, findsOneWidget);
      await tester.tap(completeButtonFinder);
      await tester.pumpAndSettle();

      // 태그와 colorIndex 확인
      expect(resultTag, isNotNull);
      expect(resultTag!.name, equals('nunchuk'));
      expect(resultTag!.colorIndex, equals(0));
    });
  });
}
