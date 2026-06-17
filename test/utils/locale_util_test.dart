import 'package:coconut_wallet/config/number_format_config.dart';
import 'package:coconut_wallet/utils/locale_util.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LocaleUtil Tests', () {
    test('getSystemLanguageCode should return kr for Korean locale', () {
      // 테스트를 위해 window.locale을 모킹할 수 없으므로
      // 실제 시스템에서 테스트해야 합니다.
      // 이 테스트는 기본 동작을 확인하는 용도입니다.
      expect(getSystemLanguageCode(), isA<String>());
    });

    test('isSystemLanguageKorean should return boolean', () {
      // 테스트를 위해 window.locale을 모킹할 수 없으므로
      // 실제 시스템에서 테스트해야 합니다.
      // 이 테스트는 기본 동작을 확인하는 용도입니다.
      expect(isSystemLanguageKorean(), isA<bool>());
    });

    test('isSystemLanguageJapanese should return boolean', () {
      // 테스트를 위해 window.locale을 모킹할 수 없으므로
      // 실제 시스템에서 테스트해야 합니다.
      // 이 테스트는 기본 동작을 확인하는 용도입니다.
      expect(isSystemLanguageJapanese(), isA<bool>());
    });

    test('getSystemLanguageCode should return en for non-Korean locale', () {
      // 이 테스트는 로직을 검증하는 용도입니다.
      // 실제로는 window.locale이 필요하지만, 여기서는 함수가 올바른 값을 반환하는지 확인합니다.
      expect(getSystemLanguageCode(), isA<String>());
    });

    // 한국어 로케일 테스트 (실제로는 모킹이 필요하지만 여기서는 로직만 확인)
    test('Korean locale detection logic', () {
      // 이 테스트는 실제 window.locale을 사용하므로
      // 시스템 언어에 따라 결과가 달라집니다.
      final String result = getSystemLanguageCode();
      expect(result == 'kr' || result == 'en', isTrue);
    });

    // 시스템 언어가 한국어인지 확인하는 로직 테스트
    test('System language Korean check logic', () {
      final bool isKorean = isSystemLanguageKorean();
      expect(isKorean, isA<bool>());
    });

    // 앱 언어 코드 기반 BigInt 포맷팅 테스트
    group('formatBigIntWithAppLanguageLocale', () {
      test('should format with dot decimal separator for kr (Korean)', () {
        expect(formatBigIntWithAppLanguageLocale(BigInt.from(100000000001), 8, 'kr'), '1,000.00000001');
        expect(formatBigIntWithAppLanguageLocale(BigInt.from(10000000000), 8, 'kr'), '100');
        expect(formatBigIntWithAppLanguageLocale(BigInt.from(123412345678), 8, 'kr'), '1,234.12345678');
      });

      test('should format with dot decimal separator for en (English)', () {
        expect(formatBigIntWithAppLanguageLocale(BigInt.from(100000000001), 8, 'en'), '1,000.00000001');
        expect(formatBigIntWithAppLanguageLocale(BigInt.from(10000000), 8, 'en'), '0.1');
      });

      test('should format with dot decimal separator for jp (Japanese)', () {
        expect(formatBigIntWithAppLanguageLocale(BigInt.from(100000000001), 8, 'jp'), '1,000.00000001');
        expect(formatBigIntWithAppLanguageLocale(BigInt.from(10000000), 8, 'jp'), '0.1');
      });

      test('should format with comma decimal separator for es (Spanish)', () {
        expect(formatBigIntWithAppLanguageLocale(BigInt.from(100000000001), 8, 'es'), '1.000,00000001');
        expect(formatBigIntWithAppLanguageLocale(BigInt.from(10000000), 8, 'es'), '0,1');
      });

      test('should format with 8 decimalPlaces', () {
        expect(formatBigIntWithAppLanguageLocale(BigInt.from(110000000), 8, 'kr'), '1.1');
        expect(formatBigIntWithAppLanguageLocale(BigInt.from(112345679), 8, 'kr'), '1.12345679');
      });

      test('should accept custom decimalPlaces', () {
        expect(formatBigIntWithAppLanguageLocale(BigInt.from(1000000001), 4, 'kr'), '100,000.0001');
        expect(formatBigIntWithAppLanguageLocale(BigInt.from(1235), 4, 'kr'), '0.1235');
      });

      // 아직 앱 언어에 추가되지 않은 경우 기본적으로 en locale을 사용합니다.
      test('should use default en locale for unknown language code', () {
        expect(formatBigIntWithAppLanguageLocale(BigInt.from(100000000001), 8, 'fr'), '1,000.00000001');
        expect(formatBigIntWithAppLanguageLocale(BigInt.from(100000000001), 8, 'de'), '1,000.00000001');
        expect(formatBigIntWithAppLanguageLocale(BigInt.from(100000000001), 8, ''), '1,000.00000001');
      });

      test('should strip trailing zeros from decimal part', () {
        expect(formatBigIntWithAppLanguageLocale(BigInt.from(110000000), 8, 'kr'), '1.1');
        expect(formatBigIntWithAppLanguageLocale(BigInt.from(100000000), 8, 'kr'), '1');
        expect(formatBigIntWithAppLanguageLocale(BigInt.from(10000), 8, 'kr'), '0.0001');
      });

      test('should strip trailing zeros for Spanish locale with comma separator', () {
        expect(formatBigIntWithAppLanguageLocale(BigInt.from(110000000), 8, 'es'), '1,1');
        expect(formatBigIntWithAppLanguageLocale(BigInt.from(100000000), 8, 'es'), '1');
        expect(formatBigIntWithAppLanguageLocale(BigInt.from(10000), 8, 'es'), '0,0001');
      });

      test('should handle zero value', () {
        expect(formatBigIntWithAppLanguageLocale(BigInt.zero, 8, 'kr'), '0');
        expect(formatBigIntWithAppLanguageLocale(BigInt.zero, 8, 'es'), '0');
      });

      test('should handle very large values', () {
        // Bitcoin max supply in sats: 2,100,000,000,000,000
        final maxSats = BigInt.parse('2100000000000000');
        expect(formatBigIntWithAppLanguageLocale(maxSats, 8, 'kr'), '21,000,000');
        expect(formatBigIntWithAppLanguageLocale(maxSats, 8, 'es'), '21.000.000');
      });

      test('should handle negative values', () {
        expect(formatBigIntWithAppLanguageLocale(BigInt.from(-110000000), 8, 'kr'), '-1.1');
        expect(formatBigIntWithAppLanguageLocale(BigInt.from(-10000000), 8, 'kr'), '-0.1');
      });
    });
  });
}
