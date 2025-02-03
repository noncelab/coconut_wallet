import 'package:coconut_wallet/widgets/pin/pin_box.dart';
import 'package:flutter_svg/svg.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PinBox', () {
    testWidgets('rendering test', (tester) async {
      await tester.pumpWidget(
        const PinBox(isSet: true),
      );

      expect(find.byType(SvgPicture), findsOneWidget);
    });

    testWidgets('rendering test', (tester) async {
      await tester.pumpWidget(
        const PinBox(isSet: false),
      );

      expect(find.byType(SvgPicture), findsNothing);
    });
  });
}
