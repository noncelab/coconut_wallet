import 'package:coconut_wallet/widgets/common/buttons/positioned_card_close_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('card close button keeps its size and top-right position across card heights', (tester) async {
    var closed = 0;
    for (final height in [100.0, 180.0]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: Center(
              child: SizedBox(
                key: const ValueKey('card'),
                width: 300,
                height: height,
                child: Stack(children: [PositionedCardCloseButton(onPressed: () => closed++, color: Colors.black)]),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final card = tester.getRect(find.byKey(const ValueKey('card')));
      final button = tester.getRect(find.byType(InkWell));
      expect(button.size, const Size(40, 40));
      expect(button.top - card.top, 4);
      expect(card.right - button.right, 6);
      expect(tester.getSize(find.byType(SvgPicture)), const Size(24, 24));
      await tester.tap(find.byType(InkWell));
      expect(tester.takeException(), isNull);
    }
    expect(closed, 2);
  });
}
