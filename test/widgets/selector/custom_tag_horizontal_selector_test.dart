import 'package:coconut_wallet/widgets/selector/custom_tag_horizontal_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CustomTagHorizontalSelector', () {
    final tags = ['coconut', 'keystone', 'jade', 'blue_wallet', 'nun_chuck'];

    testWidgets('rendering, callback test', (tester) async {
      String? selectedTag;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomTagHorizontalSelector(
              tags: tags,
              onSelectedTag: (tag) {
                selectedTag = tag;
              },
            ),
          ),
        ),
      );

      expect(find.text('전체'), findsOneWidget);
      expect(find.text('#coconut'), findsOneWidget);
      expect(find.text('#keystone'), findsOneWidget);
      expect(find.text('#blue_wallet'), findsOneWidget);
      expect(find.text('#nun_chuck'), findsOneWidget);

      await tester.tap(find.text('#nun_chuck'));
      await tester.pumpAndSettle();
      expect(selectedTag, 'nun_chuck');

      await tester.tap(find.text('#coconut'));
      await tester.pumpAndSettle();
      expect(selectedTag, 'coconut');
    });
  });
}
