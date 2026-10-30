import 'dart:math' as math;

import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/ui/coconut/coconut_option_picker.dart';
import 'package:coconut_wallet/ui/coconut/coconut_text_field.dart';
import 'package:coconut_wallet/widgets/features/wallet/trezor/trezor_digit_box.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

double _contrast(Color foreground, Color background) {
  final a = foreground.computeLuminance();
  final b = background.computeLuminance();
  return (math.max(a, b) + 0.05) / (math.min(a, b) + 0.05);
}

void main() {
  for (final variant in CoconutThemeVariant.values) {
    final colors = resolveCoconutThemeExtension(variant: variant).colors;

    testWidgets('$variant Trezor digit uses input surface and preserves verification/error states', (tester) async {
      for (final state in ['normal', 'verifying', 'error', 'empty']) {
        await tester.pumpWidget(
          MaterialApp(
            theme: buildCoconutThemeData(variant: variant),
            home: Scaffold(
              body: SizedBox(
                width: 40,
                child: TrezorDigitBox(
                  digit: state == 'empty' ? '' : '5',
                  hasError: state == 'error',
                  isVerifying: state == 'verifying',
                ),
              ),
            ),
          ),
        );
        final box = find.descendant(of: find.byType(TrezorDigitBox), matching: find.byType(Container));
        final decoration = tester.widget<Container>(box).decoration! as BoxDecoration;
        expect(decoration.color, colors.inputSurface);
        expect(tester.getSize(box), const Size(40, 48));
        if (state == 'empty') {
          expect(find.text('5'), findsNothing);
        } else {
          final text = tester.widget<Text>(find.text('5'));
          expect(text.style!.color, switch (state) {
            'error' => colors.danger,
            'verifying' => colors.mutedText,
            _ => colors.primaryText,
          });
          if (state == 'normal') expect(_contrast(text.style!.color!, decoration.color!), greaterThanOrEqualTo(4.5));
        }
      }
    });

    testWidgets('$variant option picker divider uses border role and respects expanded/explicit states', (
      tester,
    ) async {
      var taps = 0;
      for (final expanded in [false, true]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: buildCoconutThemeData(variant: variant),
            home: Scaffold(body: CoconutOptionPicker(text: 'Selection', isExpanded: expanded, onTap: () => taps++)),
          ),
        );
        await tester.pumpAndSettle();
        final underline = tester.widget<AnimatedContainer>(find.byType(AnimatedContainer));
        expect(
          (underline.decoration! as BoxDecoration).color,
          expanded ? colors.primaryText : colors.inputBorderUnfocused,
        );
        expect(tester.getSize(find.byType(AnimatedContainer)).height, 1);
        await tester.tap(find.text('Selection'));
        expect(taps, expanded ? 2 : 1);
      }
      await tester.pumpWidget(
        MaterialApp(
          theme: buildCoconutThemeData(variant: variant),
          home: Scaffold(body: CoconutOptionPicker(text: 'Selection', dividerColor: colors.borderStrong, onTap: () {})),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        (tester.widget<AnimatedContainer>(find.byType(AnimatedContainer)).decoration! as BoxDecoration).color,
        colors.borderStrong,
      );
    });

    testWidgets('$variant rendered search and underline placeholders retain the input surface pair', (tester) async {
      final controller = TextEditingController();
      final focus = FocusNode();
      addTearDown(controller.dispose);
      addTearDown(focus.dispose);
      for (final style in CoconutTextFieldStyle.values) {
        await tester.pumpWidget(
          MaterialApp(
            theme: buildCoconutThemeData(variant: variant),
            home: Scaffold(
              body: CoconutTextField(
                controller: controller,
                focusNode: focus,
                onChanged: (_) {},
                style: style,
                size: CoconutTextFieldSize.search,
                backgroundColor: colors.inputSurface,
                placeholderText: 'Enter amount',
                maxLines: 1,
              ),
            ),
          ),
        );
        final surface = find.descendant(
          of: find.byType(CoconutTextField),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Container &&
                widget.decoration is BoxDecoration &&
                (widget.decoration! as BoxDecoration).color == colors.inputSurface,
          ),
        );
        expect(surface, findsOneWidget);
        final fill = (tester.widget<Container>(surface).decoration! as BoxDecoration).color!;
        final placeholder = tester.widget<Text>(find.text('Enter amount'));
        expect(placeholder.style!.color, colors.inputPlaceholder);
        expect(_contrast(placeholder.style!.color!, fill), greaterThanOrEqualTo(4.5));
      }
    });
  }
}
