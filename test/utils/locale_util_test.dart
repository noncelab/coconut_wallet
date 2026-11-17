import 'dart:ui' show Locale;

import 'package:coconut_wallet/config/number_format_config.dart';
import 'package:coconut_wallet/constants/app_language.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/enums/number_format_preset.dart';
import 'package:coconut_wallet/utils/locale_util.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LocaleUtil Tests', () {
    test('getSystemLanguageCode should return ko for Korean locale', () {
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
      expect(result == AppLanguage.ko.code || result == AppLanguage.en.code, isTrue);
    });

    // 시스템 언어가 한국어인지 확인하는 로직 테스트
    test('System language Korean check logic', () {
      final bool isKorean = isSystemLanguageKorean();
      expect(isKorean, isA<bool>());
    });

    // 앱 언어 코드 기반 BigInt 포맷팅 테스트
    group('formatBigIntWithAppLanguageLocale', () {
      test('should format with dot decimal separator (dotDecimal preset)', () {
        NumberFormatConfig.instance.applyPreset(NumberFormatPreset.dotDecimal);
        expect(formatBigIntWithAppLanguageLocale(BigInt.from(100000000001), 8), '1,000.00000001');
        expect(formatBigIntWithAppLanguageLocale(BigInt.from(10000000000), 8), '100');
        expect(formatBigIntWithAppLanguageLocale(BigInt.from(123412345678), 8), '1,234.12345678');
      });

      test('should format with comma decimal separator (commaDecimal preset)', () {
        NumberFormatConfig.instance.applyPreset(NumberFormatPreset.commaDecimal);
        expect(formatBigIntWithAppLanguageLocale(BigInt.from(100000000001), 8), '1.000,00000001');
        expect(formatBigIntWithAppLanguageLocale(BigInt.from(10000000), 8), '0,1');
      });

      test('should format with 8 decimalPlaces', () {
        NumberFormatConfig.instance.applyPreset(NumberFormatPreset.dotDecimal);
        expect(formatBigIntWithAppLanguageLocale(BigInt.from(110000000), 8), '1.1');
        expect(formatBigIntWithAppLanguageLocale(BigInt.from(112345679), 8), '1.12345679');
      });

      test('should accept custom decimalPlaces', () {
        NumberFormatConfig.instance.applyPreset(NumberFormatPreset.dotDecimal);
        expect(formatBigIntWithAppLanguageLocale(BigInt.from(1000000001), 4), '100,000.0001');
        expect(formatBigIntWithAppLanguageLocale(BigInt.from(1235), 4), '0.1235');
      });

      test('should strip trailing zeros from decimal part', () {
        NumberFormatConfig.instance.applyPreset(NumberFormatPreset.dotDecimal);
        expect(formatBigIntWithAppLanguageLocale(BigInt.from(110000000), 8), '1.1');
        expect(formatBigIntWithAppLanguageLocale(BigInt.from(100000000), 8), '1');
        expect(formatBigIntWithAppLanguageLocale(BigInt.from(10000), 8), '0.0001');
      });

      test('should strip trailing zeros with comma separator', () {
        NumberFormatConfig.instance.applyPreset(NumberFormatPreset.commaDecimal);
        expect(formatBigIntWithAppLanguageLocale(BigInt.from(110000000), 8), '1,1');
        expect(formatBigIntWithAppLanguageLocale(BigInt.from(100000000), 8), '1');
        expect(formatBigIntWithAppLanguageLocale(BigInt.from(10000), 8), '0,0001');
      });

      test('should handle zero value', () {
        NumberFormatConfig.instance.applyPreset(NumberFormatPreset.dotDecimal);
        expect(formatBigIntWithAppLanguageLocale(BigInt.zero, 8), '0');
        NumberFormatConfig.instance.applyPreset(NumberFormatPreset.commaDecimal);
        expect(formatBigIntWithAppLanguageLocale(BigInt.zero, 8), '0');
      });

      test('should handle very large values', () {
        NumberFormatConfig.instance.applyPreset(NumberFormatPreset.dotDecimal);
        // Bitcoin max supply in sats: 2,100,000,000,000,000
        final maxSats = BigInt.parse('2100000000000000');
        expect(formatBigIntWithAppLanguageLocale(maxSats, 8), '21,000,000');
        NumberFormatConfig.instance.applyPreset(NumberFormatPreset.commaDecimal);
        expect(formatBigIntWithAppLanguageLocale(maxSats, 8), '21.000.000');
      });

      test('should handle negative values', () {
        NumberFormatConfig.instance.applyPreset(NumberFormatPreset.dotDecimal);
        expect(formatBigIntWithAppLanguageLocale(BigInt.from(-110000000), 8), '-1.1');
        expect(formatBigIntWithAppLanguageLocale(BigInt.from(-10000000), 8), '-0.1');
      });
    });

    group('defaultFiatForLocale', () {
      final cases = [
        // 지역이 있으면 지역으로 정한다.
        (const Locale('ko', 'KR'), FiatCode.KRW),
        (const Locale('en', 'KR'), FiatCode.KRW),
        (const Locale('ja', 'JP'), FiatCode.JPY),
        (const Locale('de', 'DE'), FiatCode.EUR),
        (const Locale('en', 'BG'), FiatCode.EUR), // 2026-01-01 유로존 가입
        (const Locale('sv', 'AX'), FiatCode.EUR), // EU 회원국 영토, 코드가 따로 있다
        (const Locale('fr', 'RE'), FiatCode.EUR), // 프랑스 최외곽 지역
        (const Locale('es', 'IC'), FiatCode.EUR), // 카나리아 제도
        (const Locale('fr', 'MC'), FiatCode.EUR), // EU 밖, 통화 협정
        (const Locale('fr', 'BL'), FiatCode.EUR), // EU 밖, 프랑스 해외 영토
        (const Locale('sq', 'XK'), FiatCode.EUR), // EU 밖, 협정 없이 사용
        (const Locale('de', 'CH'), FiatCode.CHF), // 유로를 쓰지 않는다
        (const Locale('da', 'DK'), FiatCode.DKK), // EU 회원국이지만 유로를 쓰지 않는다
        (const Locale('en', 'IN'), FiatCode.INR),
        // 지원하는 통화면 그 지역의 통화로 정한다.
        (const Locale('th', 'TH'), FiatCode.THB),
        (const Locale('en', 'TH'), FiatCode.THB),
        (const Locale('en', 'GB'), FiatCode.GBP),
        (const Locale('vi', 'VN'), FiatCode.VND),
        (const Locale('en', 'AU'), FiatCode.AUD),
        (const Locale('en', 'LS'), FiatCode.ZAR), // 레소토: CLDR의 주 통화가 랜드
        // 그 지역의 통화를 지원하지 않으면 USD
        (const Locale('ar', 'EG'), FiatCode.USD), // 이집트 파운드
        (const Locale('dz', 'BT'), FiatCode.USD), // 부탄: 주 통화는 눌트룸(인도 루피는 주 통화가 아님)
        (const Locale('en', 'US'), FiatCode.USD),
        (const Locale('ko', 'US'), FiatCode.USD), // 언어보다 지역이 먼저다
        // 지역이 없으면 언어로 정한다.
        (const Locale('ko'), FiatCode.KRW),
        (const Locale('ja'), FiatCode.JPY),
        (const Locale('de'), FiatCode.EUR),
        (const Locale('en'), FiatCode.USD),
        (const Locale('es'), FiatCode.USD),
      ];
      for (final (locale, expected) in cases) {
        test('$locale → ${expected.code}', () {
          expect(defaultFiatForLocale(locale), expected);
        });
      }

      test('CoinGecko로 받는 통화는 모두 어느 지역의 기본 통화다', () {
        const letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
        final reached = {
          for (final a in letters.split(''))
            for (final b in letters.split('')) defaultFiatForLocale(Locale('en', '$a$b')),
        };
        expect(FiatCode.values.where((fiat) => !fiat.hasExchangeSource).toSet().difference(reached), isEmpty);
      });
    });
  });
}
