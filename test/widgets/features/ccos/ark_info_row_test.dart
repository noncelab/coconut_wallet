import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/utils/text_utils.dart';
import 'package:coconut_wallet/widgets/features/ccos/ark/ark_info_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final _bubble = find.text(
  TextUtils.preventLineBreakInsideWords('Paid generously, the rest comes back'),
  findRichText: true,
);

void main() {
  Future<void> pump(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      theme: buildCoconutThemeData(variant: CoconutThemeVariant.dark),
      home: Scaffold(
        body: ListView(
          children: const [
            ArkInfoRow(label: 'Network fee', value: '343 sats', labelTooltip: 'Paid generously, the rest comes back'),
            SizedBox(height: 400),
          ],
        ),
      ),
    ),
  );

  testWidgets(
    'the info icon beside the label opens a bubble, wrapped only between words, that closes on a tap elsewhere',
    (tester) async {
      await pump(tester);
      expect(_bubble, findsNothing);

      await tester.tap(find.byKey(const Key('ark-info-row-tooltip')));
      await tester.pumpAndSettle();
      expect(_bubble, findsOneWidget);

      await tester.tapAt(const Offset(200, 380));
      await tester.pumpAndSettle();
      expect(_bubble, findsNothing);
    },
  );

  testWidgets('the bubble closes by itself after a while', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('ark-info-row-tooltip')));
    await tester.pumpAndSettle();

    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(_bubble, findsNothing);
  });

  testWidgets('the box keeps rows 20 in from its sides and 8 from its top', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildCoconutThemeData(variant: CoconutThemeVariant.dark),
        home: const Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: ArkInfoBox(children: [ArkInfoRow(label: 'Fee', value: '20 sats')]),
          ),
        ),
      ),
    );

    final box = tester.getTopLeft(find.byType(ArkInfoBox));
    final label = tester.getTopLeft(find.text('Fee'));
    expect(label.dx - box.dx, 20);
    expect(tester.getTopLeft(find.byType(ArkInfoRow)).dy - box.dy, 8);
  });

  testWidgets('rows in a box are split by a divider, none before the first or after the last', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildCoconutThemeData(variant: CoconutThemeVariant.dark),
        home: const Scaffold(
          body: ArkInfoBox(
            children: [
              ArkInfoRow(label: 'A', value: '1'),
              ArkInfoRow(label: 'B', value: '2'),
              ArkInfoRow(label: 'C', value: '3'),
            ],
          ),
        ),
      ),
    );

    expect(find.byType(ArkInfoDivider), findsNWidgets(2));
  });
}
