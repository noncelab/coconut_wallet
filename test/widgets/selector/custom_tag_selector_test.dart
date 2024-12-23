import 'package:coconut_wallet/widgets/selector/custom_tag_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coconut_wallet/model/utxo_tag.dart';
import 'package:coconut_wallet/styles.dart';

void main() {
  group('CustomTagSelector', () {
    final tags = [
      const UtxoTag(tag: 'Tag1', colorIndex: 0, usedCount: 5),
      const UtxoTag(tag: 'Tag2', colorIndex: 1, usedCount: 0),
      const UtxoTag(tag: 'Tag3', colorIndex: 2, usedCount: 2),
    ];

    testWidgets('태그 리스트 렌더링', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomTagSelector(
              tags: tags,
              onSelectedTag: (tag) {},
            ),
          ),
        ),
      );

      expect(find.text('#Tag1'), findsOneWidget);
      expect(find.text('#Tag2'), findsOneWidget);
      expect(find.text('#Tag3'), findsOneWidget);
    });

    testWidgets('onSelectedTag 콜백 호출', (tester) async {
      UtxoTag? selectedTag;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomTagSelector(
              tags: tags,
              onSelectedTag: (tag) {
                selectedTag = tag;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('#Tag2'));
      await tester.pumpAndSettle();

      expect(selectedTag, isNotNull);
      expect(selectedTag?.tag, 'Tag2');
    });

    testWidgets('선택된 태그 강조', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomTagSelector(
              tags: tags,
              onSelectedTag: (tag) {},
            ),
          ),
        ),
      );

      await tester.tap(find.text('#Tag3'));
      await tester.pumpAndSettle();

      final selectedTagFinder = find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.decoration is BoxDecoration &&
            (widget.decoration as BoxDecoration).color ==
                MyColors.selectBackground,
      );

      expect(selectedTagFinder, findsOneWidget);
    });

    testWidgets('usedCount = 0일 경우 subtitle 표시 제한', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomTagSelector(
              tags: tags,
              onSelectedTag: (tag) {},
            ),
          ),
        ),
      );

      expect(find.text('0개에 적용'), findsNothing);
    });

    testWidgets('usedCount > 0일 경우 subtitle 표시', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomTagSelector(
              tags: tags,
              onSelectedTag: (tag) {},
            ),
          ),
        ),
      );

      expect(find.text('5개에 적용'), findsOneWidget);
      expect(find.text('2개에 적용'), findsOneWidget);
    });
  });
}
