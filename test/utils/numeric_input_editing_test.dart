import 'package:coconut_wallet/config/number_format_config.dart';
import 'package:coconut_wallet/enums/number_format_preset.dart';
import 'package:coconut_wallet/utils/numeric_input_formatters.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

TextEditingValue editing(String text, {int? caret, int? end}) => TextEditingValue(
  text: text,
  selection: TextSelection(baseOffset: caret ?? text.length, extentOffset: end ?? caret ?? text.length),
);

TextEditingValue replaceSelection(TextInputFormatter formatter, TextEditingValue oldValue, String inserted) {
  final start = oldValue.selection.start;
  final text = oldValue.text.replaceRange(start, oldValue.selection.end, inserted);
  return formatter.formatEditUpdate(oldValue, editing(text, caret: start + inserted.length));
}

void main() {
  tearDown(() => NumberFormatConfig.instance.applyPreset(NumberFormatPreset.dotDecimal));

  for (final preset in NumberFormatPreset.values) {
    final d = preset.decimalSeparator;
    final g = preset.groupingSeparator;
    final alt = d == '.' ? ',' : '.';

    group(preset.name, () {
      setUp(() => NumberFormatConfig.instance.applyPreset(preset));

      for (final entry
          in <String, TextInputFormatter>{
            'BTC': const BtcAmountInputFormatter(),
            'fiat': const FiatAmountInputFormatter(decimalPlaces: 2),
          }.entries) {
        final formatter = entry.value;
        group(entry.key, () {
          test('batch decimal entry agrees with typing for either decimal key', () {
            for (final separator in [d, alt]) {
              for (final input in ['12${separator}50', '0${separator}01', '${separator}25']) {
                var typed = editing('');
                for (final key in input.split('')) {
                  typed = replaceSelection(formatter, typed, key);
                }
                final pasted = replaceSelection(formatter, editing(''), input);
                expect(pasted, typed, reason: 'batch and keyboard must preserve the same decimal value');
              }
            }
          });

          test('pastes grouped amounts in the selected preset', () {
            for (final text in ['1${g}234${d}50', '1${g}234${g}567', '12${g}345']) {
              expect(replaceSelection(formatter, editing(''), text), editing(text));
            }
          });

          test('inserts alternate decimal fragments at the caret', () {
            final oldValue = editing('1234', caret: 2);
            expect(replaceSelection(formatter, oldValue, alt), editing('12${d}34', caret: 3));
            expect(replaceSelection(formatter, editing('1${g}234'), '${alt}50'), editing('1${g}234${d}50'));
          });

          test('replaces selections including reversed and shorter replacements', () {
            expect(replaceSelection(formatter, editing('12${d}34', caret: 5, end: 0), '0${alt}25'), editing('0${d}25'));
            expect(replaceSelection(formatter, editing('123', caret: 0, end: 3), '4${alt}5'), editing('4${d}5'));
            expect(
              replaceSelection(formatter, editing('12${d}34', caret: 2, end: 3), alt),
              editing('12${d}34', caret: 3),
            );
          });

          test('rejects invalid replacements without losing the previous value or selection', () {
            for (final inserted in ['-2', '+2', '1e2', '1a', 'NaN', '1/2', '１２', '\n']) {
              final oldValue = editing('1234', caret: 0, end: 4);
              expect(replaceSelection(formatter, oldValue, inserted), oldValue);
            }
          });

          test('rejects malformed grouping and repeated decimals without stripping digits', () {
            for (final inserted in [
              '1${g}23${g}456',
              '1${g}23${d}45',
              '1${d}2${g}345',
              '1${g}234${d}5${g}678',
              '1${d}2${d}3',
            ]) {
              final oldValue = editing('');
              expect(replaceSelection(formatter, oldValue, inserted), oldValue);
            }
          });

          test('middle digit edits preserve caret and decimal meaning', () {
            expect(
              replaceSelection(formatter, editing('1${g}234${d}50', caret: 3), '9'),
              editing('12${g}934${d}50', caret: 4),
            );
            expect(
              formatter.formatEditUpdate(editing('1${g}234${d}50', caret: 3), editing('1${g}34${d}50', caret: 2)),
              editing('134${d}50', caret: 1),
            );
            expect(replaceSelection(formatter, editing('12${d}34', caret: 1, end: 4), ''), editing('14', caret: 1));
            expect(replaceSelection(formatter, editing('12${d}34', caret: 0, end: 5), ''), editing(''));
          });

          test('selection-only updates retain both selection endpoints', () {
            final next = editing('1${g}234${d}50', caret: 7, end: 2);
            expect(formatter.formatEditUpdate(editing(next.text), next), next);
          });

          test('leading zero normalization keeps the caret in place', () {
            expect(replaceSelection(formatter, editing('0${d}5', caret: 0), '0'), editing('0${d}5', caret: 0));
            expect(replaceSelection(formatter, editing(''), '${alt}5'), editing('0${d}5'));
          });
        });
      }

      test('BTC preserves all satoshi digits and rejects excess precision or supply', () {
        const formatter = BtcAmountInputFormatter();
        expect(replaceSelection(formatter, editing(''), '0${alt}00000001'), editing('0${d}00000001'));
        expect(
          replaceSelection(formatter, editing(''), '20999999${d}99999999'),
          editing('20${g}999${g}999${d}99999999'),
        );
        for (final text in ['0${d}000000001', '21000000${d}00000001', '999999999999999999999999999']) {
          expect(replaceSelection(formatter, editing(''), text), editing(''));
        }
      });

      test('grouped integer paste follows the preset while a decimal key stays a decimal', () {
        const formatter = BtcAmountInputFormatter();
        expect(replaceSelection(formatter, editing(''), '1${g}234'), editing('1${g}234'));
        expect(replaceSelection(formatter, editing(''), '1${alt}23'), editing('1${d}23'));
        expect(replaceSelection(formatter, editing('1'), alt), editing('1$d'));
      });

      test('zero-decimal fiat accepts grouped integers but never drops a decimal separator', () {
        const formatter = FiatAmountInputFormatter(decimalPlaces: 0);
        expect(replaceSelection(formatter, editing(''), '1${g}234'), editing('1${g}234'));
        expect(replaceSelection(formatter, editing(''), '12${alt}5'), editing(''));
        expect(replaceSelection(formatter, editing(''), '12${d}5'), editing(''));
      });

      test('fiat rejects excess fractional precision for both decimal keys', () {
        for (final separator in [d, alt]) {
          expect(
            replaceSelection(const FiatAmountInputFormatter(decimalPlaces: 2), editing(''), '0${separator}001'),
            editing(''),
          );
          expect(
            replaceSelection(const FiatAmountInputFormatter(decimalPlaces: 0), editing(''), '12${separator}5'),
            editing(''),
          );
        }
      });

      test('satoshi paste accepts grouping and rejects decimal or overflow', () {
        const formatter = SatoshiAmountInputFormatter();
        expect(replaceSelection(formatter, editing(''), '1${g}234'), editing('1${g}234'));
        for (final text in ['1${d}5', '1${alt}5', '-1', '12x', '2100000000000001', '999999999999999999999999999']) {
          expect(replaceSelection(formatter, editing(''), text), editing(''));
        }
      });

      test('rate edits preserve the caret and validate shorter replacements', () {
        const formatter = RateInputFormatter();
        expect(replaceSelection(formatter, editing('1234', caret: 2), alt), editing('12${d}34', caret: 3));
        expect(replaceSelection(formatter, editing('1234', caret: 0, end: 4), '4${alt}5'), editing('4${d}5'));
        final oldValue = editing('1234', caret: 0, end: 4);
        expect(replaceSelection(formatter, oldValue, '-2'), oldValue);
      });

      test('numeric IME edits retain a valid composing range until commit', () {
        for (final formatter in const [
          BtcAmountInputFormatter(),
          FiatAmountInputFormatter(decimalPlaces: 2),
          RateInputFormatter(),
        ]) {
          final composing = editing('12${alt}5').copyWith(composing: const TextRange(start: 0, end: 4));
          final result = formatter.formatEditUpdate(editing(''), composing);
          expect(result.text, '12${d}5');
          expect(result.composing, const TextRange(start: 0, end: 4));
          final committed = result.copyWith(composing: TextRange.empty);
          expect(formatter.formatEditUpdate(result, committed), committed);
          final invalid = editing('-1').copyWith(composing: const TextRange(start: 0, end: 2));
          expect(formatter.formatEditUpdate(committed, invalid), committed);
        }
      });

      testWidgets('toolbar paste preserves the amount through the editable text pipeline', (tester) async {
        final controller = TextEditingController();
        addTearDown(controller.dispose);
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.getData') return {'text': '1${g}234${d}50'};
          return null;
        });
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null),
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: TextField(controller: controller, inputFormatters: const [BtcAmountInputFormatter()])),
          ),
        );
        await tester.showKeyboard(find.byType(TextField));
        await tester.state<EditableTextState>(find.byType(EditableText)).pasteText(SelectionChangedCause.toolbar);
        await tester.pump();
        expect(controller.value, editing('1${g}234${d}50'));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });

      testWidgets('text field receives a full paste, middle edit and invalid replacement', (tester) async {
        final controller = TextEditingController();
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: TextField(controller: controller, inputFormatters: const [BtcAmountInputFormatter()])),
          ),
        );
        final field = find.byType(TextField);
        await tester.enterText(field, '0${alt}12345678');
        expect(controller.text, '0${d}12345678');
        controller.selection = const TextSelection(baseOffset: 2, extentOffset: 4);
        tester.testTextInput.updateEditingValue(editing('0${d}99345678', caret: 4));
        expect(controller.value, editing('0${d}99345678', caret: 4));
        controller.selection = TextSelection(baseOffset: 0, extentOffset: controller.text.length);
        final previous = controller.value;
        tester.testTextInput.updateEditingValue(editing('-1'));
        expect(controller.value, previous);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    });
  }
}
