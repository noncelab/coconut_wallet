import 'package:coconut_design_system/coconut_design_system.dart' show CoconutButton;
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/screens/home/analysis_period_bottom_sheet.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tuple/tuple.dart';

class _Preferences extends Fake with ChangeNotifier implements PreferenceProvider {
  @override
  String get language => 'en';
  @override
  Tuple2<DateTime?, DateTime?> get analysisPeriodRange => Tuple2(DateTime(2026, 1, 1), DateTime(2026, 1, 31));
}

void main() {
  for (final variant in CoconutThemeVariant.values) {
    testWidgets('${variant.name} legacy date callers keep readable held text and cancel/release behavior', (
      tester,
    ) async {
      var selected = 0;
      await tester.pumpWidget(
        ChangeNotifierProvider<PreferenceProvider>(
          create: (_) => _Preferences(),
          child: MaterialApp(
            theme: buildCoconutThemeData(variant: variant),
            home: AnalysisPeriodBottomSheet(
              initialPeriodPreset: 0,
              onSelected: (_) => selected++,
              onTransactionTypeSelected: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final colors = resolveCoconutThemeExtension(variant: variant).colors;
      final expectedHeld = Color.alphaBlend(
        colors.surfacePressOverlay.withValues(alpha: colors.surfacePressOverlayOpacity),
        colors.inputSurface,
      );
      for (var index = 0; index < 2; index++) {
        final button = find.byType(CoconutButton).at(index);
        Color fill() =>
            tester
                .widgetList<Container>(find.descendant(of: button, matching: find.byType(Container)))
                .map((widget) => widget.decoration)
                .whereType<BoxDecoration>()
                .first
                .color!;
        final gesture = await tester.startGesture(tester.getCenter(button));
        await tester.pump(const Duration(milliseconds: 150));
        expect(fill(), expectedHeld);
        final text = tester.widget<Text>(find.descendant(of: button, matching: find.byType(Text)));
        expect(text.style!.color, colors.primaryText);
        final a = text.style!.color!.computeLuminance() + .05;
        final b = fill().computeLuminance() + .05;
        expect(a > b ? a / b : b / a, greaterThanOrEqualTo(4.5));
        expect(find.byType(CupertinoDatePicker), findsNothing);
        await gesture.cancel();
        await tester.pumpAndSettle();
        expect(fill(), variant == CoconutThemeVariant.dark ? Colors.black : Colors.white);
        expect(find.byType(CupertinoDatePicker), findsNothing);
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(find.byType(CupertinoDatePicker), findsOneWidget);
        Navigator.of(tester.element(find.byType(CupertinoDatePicker))).pop();
        await tester.pumpAndSettle();
        expect(fill(), variant == CoconutThemeVariant.dark ? Colors.black : Colors.white);
        expect(selected, 0);
        expect(tester.takeException(), isNull);
      }
    });
  }
}
