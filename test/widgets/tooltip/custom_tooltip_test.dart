import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/widgets/tooltip/custom_tooltip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CustomTooltip', () {
    testWidgets('rendering test', (WidgetTester tester) async {
      const type = TooltipType.info;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomTooltip(
              richText: RichText(
                text: const TextSpan(
                  text: 'Test info',
                ),
              ),
              showIcon: true,
              type: type,
            ),
          ),
        ),
      );

      // Verify text is displayed
      expect(
        find.byWidgetPredicate((widget) =>
            widget is RichText &&
            widget.text is TextSpan &&
            (widget.text as TextSpan).toPlainText() == 'Test info'),
        findsOneWidget,
      );

      // showIcon
      expect(find.byType(SvgPicture), findsOneWidget);

      // Ensure container background color matches expected
      final containerFinder = find.byType(Container);
      final containerWidget = tester.widget<Container>(containerFinder.at(1));
      expect(containerWidget.decoration, isNotNull);
      final boxDecoration = containerWidget.decoration as BoxDecoration;
      expect(boxDecoration.color,
          BackgroundColorPalette[type.colorIndex].withOpacity(0.18));
    });
  });
}
