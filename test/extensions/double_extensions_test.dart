import 'package:flutter_test/flutter_test.dart';
import 'package:coconut_wallet/extensions/double_extensions.dart';

void main() {
  group('DoubleFormatting', () {
    test('toTrimmedString - integer values', () {
      expect(1.0.toTrimmedString(), '1');
      expect(42.0.toTrimmedString(), '42');
      expect((-5.0).toTrimmedString(), '-5');
      expect(0.0.toTrimmedString(), '0');
    });

    test('toTrimmedString - decimal values', () {
      expect(1.5.toTrimmedString(), '1.5');
      expect(3.14.toTrimmedString(), '3.14');
      expect((-2.7).toTrimmedString(), '-2.7');
      expect(0.001.toTrimmedString(), '0.001');
    });
  });
}
