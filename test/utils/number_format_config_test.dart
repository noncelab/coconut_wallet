import 'package:coconut_wallet/config/number_format_config.dart';
import 'package:coconut_wallet/enums/number_format_preset.dart';
import 'package:coconut_wallet/extensions/string_extensions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizeNumTextForNumParsing', () {
    test('dotDecimal preset: strips "," grouping, keeps "." decimal', () {
      NumberFormatConfig.instance.applyPreset(NumberFormatPreset.dotDecimal);
      expect(normalizeNumTextForNumParsing('1,234,567.89'), '1234567.89');
      expect(normalizeNumTextForNumParsing('0.5'), '0.5');
    });

    test('commaDecimal preset: strips "." grouping, converts "," to "."', () {
      NumberFormatConfig.instance.applyPreset(NumberFormatPreset.commaDecimal);
      expect(normalizeNumTextForNumParsing('1.234.567,89'), '1234567.89');
      expect(normalizeNumTextForNumParsing('0,5'), '0.5');
    });

    test('swiss preset: strips "’" grouping, keeps "." decimal', () {
      NumberFormatConfig.instance.applyPreset(NumberFormatPreset.swiss);
      expect(normalizeNumTextForNumParsing('1’234’567.89'), '1234567.89');
      expect(normalizeNumTextForNumParsing('0.5'), '0.5');
    });

    test('frenchSpace preset: strips " " grouping, converts "," to "."', () {
      NumberFormatConfig.instance.applyPreset(NumberFormatPreset.frenchSpace);
      expect(normalizeNumTextForNumParsing('1 234 567,89'), '1234567.89');
      expect(normalizeNumTextForNumParsing('0,5'), '0.5');
    });

    test('BTC 표시 포맷(소수부 공백 그룹핑)은 공백이 남으므로 별도 제거가 필요하다', () {
      // BTC 표시 포맷은 소수부를 공백으로 그룹핑하므로 정규화 후에도 공백이 남는다.
      NumberFormatConfig.instance.applyPreset(NumberFormatPreset.commaDecimal);
      expect(normalizeNumTextForNumParsing('1.234,5678 9012').replaceAll(' ', ''), '1234.56789012');

      NumberFormatConfig.instance.applyPreset(NumberFormatPreset.swiss);
      expect(normalizeNumTextForNumParsing('1’234.5678 9012').replaceAll(' ', ''), '1234.56789012');

      NumberFormatConfig.instance.applyPreset(NumberFormatPreset.frenchSpace);
      expect(normalizeNumTextForNumParsing('1 234,5678 9012').replaceAll(' ', ''), '1234.56789012');
    });
  });

  group('toDoubleSafe / toIntSafe', () {
    test('각 preset의 로케일 텍스트를 올바른 숫자로 파싱한다', () {
      NumberFormatConfig.instance.applyPreset(NumberFormatPreset.dotDecimal);
      expect('1,234.56'.toDoubleSafe(), 1234.56);

      NumberFormatConfig.instance.applyPreset(NumberFormatPreset.commaDecimal);
      expect('1.234,56'.toDoubleSafe(), 1234.56);

      NumberFormatConfig.instance.applyPreset(NumberFormatPreset.swiss);
      expect('1’234.56'.toDoubleSafe(), 1234.56);

      NumberFormatConfig.instance.applyPreset(NumberFormatPreset.frenchSpace);
      expect('1 234,56'.toDoubleSafe(), 1234.56);
    });

    test('canonical 텍스트("." 소수점)에는 double.tryParse를 써야 한다', () {
      // toDoubleSafe는 로케일 텍스트 전용이다.
      // commaDecimal에서 canonical "50.25"를 넘기면 "."가 grouping으로 제거되어 5025가 된다.
      NumberFormatConfig.instance.applyPreset(NumberFormatPreset.commaDecimal);
      expect(double.tryParse('50.25'), 50.25);
      expect('50.25'.toDoubleSafe(), 5025.0);
    });
  });
}
