import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/widgets/common/bottom_sheet/selectable_settings_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final variant in CoconutThemeVariant.values) {
    for (final selected in [false, true]) {
      testWidgets('${variant.name} numeric title uses requested font with themed defaults and selected=$selected', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        try {
          await tester.pumpWidget(
            MaterialApp(
              theme: buildCoconutThemeData(variant: variant),
              home: Scaffold(
                body: SizedBox(
                  width: 320,
                  child: Column(
                    children: [
                      SelectableSettingsRow(
                        title: '1,234,567.89',
                        titleStyle: const TextStyle(fontFamily: 'SpaceGrotesk'),
                        isSelected: selected,
                        onTap: () {},
                      ),
                      const SelectableSettingsRowContent(title: 'Default title', isSelected: false),
                    ],
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final numericStyle = tester.widget<Text>(find.text('1,234,567.89')).style!;
          final defaultStyle = tester.widget<Text>(find.text('Default title')).style!;
          expect(numericStyle.fontFamily, 'SpaceGrotesk');
          expect(numericStyle.fontSize, defaultStyle.fontSize);
          expect(numericStyle.fontWeight, defaultStyle.fontWeight);
          expect(numericStyle.color, resolveCoconutThemeExtension(variant: variant).colors.primaryText);
          expect(
            tester.getSemantics(find.bySemanticsLabel('1,234,567.89')).getSemanticsData().flagsCollection.isSelected,
            selected,
          );
          expect(tester.takeException(), isNull);
        } finally {
          semantics.dispose();
        }
      });
    }
  }
}
