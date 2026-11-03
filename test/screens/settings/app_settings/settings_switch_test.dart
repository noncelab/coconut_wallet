import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_extension.dart';
import 'package:coconut_wallet/screens/settings/app_settings/settings_switch.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('theme changes preserve the saved choice and each tap requests its explicit target once', (tester) async {
    final variant = ValueNotifier(CoconutThemeVariant.dark);
    addTearDown(variant.dispose);
    final changes = <bool>[];
    var isOn = false;

    await tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder<CoconutThemeVariant>(
          valueListenable: variant,
          builder:
              (context, value, child) => Theme(
                data: buildCoconutThemeData(variant: value),
                child: StatefulBuilder(
                  builder:
                      (context, setState) => Scaffold(
                        body: Center(
                          child: SettingsSwitch(
                            isOn: isOn,
                            onChanged:
                                (value) => setState(() {
                                  changes.add(value);
                                  isOn = value;
                                }),
                          ),
                        ),
                      ),
                ),
              ),
        ),
      ),
    );

    for (final current in CoconutThemeVariant.values) {
      variant.value = current;
      await tester.pumpAndSettle();
      final colors = buildCoconutThemeData(variant: current).extension<CoconutThemeExtension>()!.colors;
      final control = tester.widget<CoconutSwitch>(find.byType(CoconutSwitch));
      expect(control.isOn, isFalse);
      expect(control.activeTrackColor, colors.switchActiveTrack);
      expect(control.activeThumbColor, colors.switchActiveThumb);
      expect(control.inactiveTrackColor, colors.switchInactiveTrack);
      expect(control.inactiveThumbColor, colors.switchInactiveThumb);

      final before = changes.length;
      await tester.tap(find.byType(CoconutSwitch));
      await tester.pumpAndSettle();
      expect(changes.sublist(before), [true]);
      expect(tester.widget<CoconutSwitch>(find.byType(CoconutSwitch)).isOn, isTrue);
      await tester.tap(find.byType(CoconutSwitch));
      await tester.pumpAndSettle();
      expect(changes.sublist(before), [true, false]);
      expect(tester.widget<CoconutSwitch>(find.byType(CoconutSwitch)).isOn, isFalse);
    }
  });
}
