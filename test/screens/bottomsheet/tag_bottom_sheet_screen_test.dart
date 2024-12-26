import 'package:coconut_wallet/model/utxo.dart';
import 'package:coconut_wallet/model/utxo_tag.dart';
import 'package:coconut_wallet/screens/bottomsheet/tag_bottom_sheet_container.dart';
import 'package:coconut_wallet/widgets/custom_tag_chip.dart';
import 'package:coconut_wallet/widgets/button/custom_tag_chip_color_button.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

void main() {
  group('TagBottomSheetScreen Tests', () {
    late List<UtxoTag> mockTags;
    late UTXO mockUtxo;

    setUp(() {
      mockTags = [
        const UtxoTag(id: 'uuid1', walletId: 1, name: 'kyc', colorIndex: 0),
        const UtxoTag(id: 'uuid2', walletId: 2, name: 'coconut', colorIndex: 2),
        const UtxoTag(id: 'uuid3', walletId: 3, name: 'strike', colorIndex: 7),
      ];
      mockUtxo = UTXO(
        'timestamp',
        'blockHeight',
        0,
        'address',
        'derivationPath',
        'txHash',
        1,
        tags: const ['kyc', 'coconut'],
      );
    });

    testWidgets('calls onComplete with correct data when selecting tags',
        (WidgetTester tester) async {
      UTXO? resultUtxo;

      await tester.pumpWidget(MaterialApp(
        home: TagBottomSheetContainer(
          type: TagBottomSheetType.select,
          utxoTags: mockTags,
          selectUtxo: mockUtxo,
          onComplete: (_, utxoTag, utxo) {
            resultUtxo = utxo;
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

      expect(resultUtxo, isNotNull);
      expect(resultUtxo!.tags, isNot(contains('kyc'))); // 제외
      expect(resultUtxo!.tags, contains('coconut'));
      expect(resultUtxo!.tags, contains('strike')); // 등록
    });

    testWidgets('calls onComplete with correct data when creating tags',
        (WidgetTester tester) async {
      List<UtxoTag>? resultTags;

      await tester.pumpWidget(MaterialApp(
        home: TagBottomSheetContainer(
          type: TagBottomSheetType.create,
          utxoTags: mockTags,
          onComplete: (utxoTags, utxoTag, _) {
            resultTags = utxoTags;
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
      expect(resultTags, isNotNull);
      final newTag = resultTags!.firstWhere(
        (tag) => tag.name == 'keystone',
        orElse: () => throw Exception('Tag "keystone" not found'),
      );

      // 태그와 colorIndex 확인
      expect(newTag.colorIndex, equals(2));
    });

    testWidgets('calls onComplete with correct data when updating tags',
        (WidgetTester tester) async {
      List<UtxoTag>? resultTags;

      await tester.pumpWidget(MaterialApp(
        home: TagBottomSheetContainer(
          type: TagBottomSheetType.manage,
          utxoTags: mockTags,
          manageUtxoTag: mockTags[2],
          onComplete: (utxoTags, utxoTag, _) {
            resultTags = utxoTags;
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

      // onComplete 콜백 결과 검증
      expect(resultTags, isNotNull);
      final newTag = resultTags!.firstWhere(
        (tag) => tag.name == 'nunchuk',
        orElse: () => throw Exception('Tag "nunchuk" not found'),
      );

      // 태그와 colorIndex 확인
      expect(newTag.colorIndex, equals(0));
    });
  });
}
