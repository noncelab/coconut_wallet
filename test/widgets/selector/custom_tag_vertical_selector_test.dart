import 'package:coconut_wallet/widgets/selector/custom_tag_vertical_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coconut_wallet/model/app/utxo/utxo_tag.dart';

void main() {
  group('CustomTagVerticalSelector', () {
    final tags = [
      const UtxoTag(
          id: 'uuid1',
          walletId: 1,
          name: 'Tag1',
          colorIndex: 0,
          utxoIdList: ['a', 'b', 'c', 'd', 'e']),
      const UtxoTag(
          id: 'uuid2',
          walletId: 2,
          name: 'Tag2',
          colorIndex: 1,
          utxoIdList: []),
      const UtxoTag(
          id: 'uuid3',
          walletId: 3,
          name: 'Tag3',
          colorIndex: 2,
          utxoIdList: ['a', 'b']),
    ];
    UtxoTag? selectedTag;

    testWidgets('렌더링, 콜백 테스트', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomTagVerticalSelector(
              tags: tags,
              onSelectedTag: (tag) {
                selectedTag = tag;
              },
            ),
          ),
        ),
      );

      // 리스트 렌더링
      expect(find.text('#Tag1'), findsOneWidget);
      expect(find.text('#Tag2'), findsOneWidget);
      expect(find.text('#Tag3'), findsOneWidget);

      // usedCount > 0일 경우 subtitle 표시
      expect(find.text('5개에 적용'), findsOneWidget);
      expect(find.text('2개에 적용'), findsOneWidget);

      // 콜백
      await tester.tap(find.text('#Tag2'));
      await tester.pumpAndSettle();

      expect(selectedTag, isNotNull);
      expect(selectedTag?.name, 'Tag2');
    });
  });
}
