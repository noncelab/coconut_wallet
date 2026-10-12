// 숫자 형식 표시 문자열 테스트 — 커밋 7719688b "숫자 형식(소수점 구분자, 천단위 구분자) 선택 옵션 추가"
//
// 의도: 사용자가 고른 프리셋(NumberFormatConfig.applyPreset)이 화면에 쓰이는 표시 문자열 전부에 적용된다.
//  - BTC 잔액(BalanceFormatUtil.formatSatoshiToReadableBitcoin / toBtcDisplayString): 정수부 천단위 구분자, 소수점,
//    소수부 4+4 공백. 프리셋 예시(displayLabel "1,234.5678 9012")가 같은 숫자의 기대 모양이다.
//  - sats 잔액·법정화폐 정수 금액(int.toThousandsSeparatedString): 천단위 구분자.
//  - 법정화폐 최소단위 금액(FiatUtil.formatMinorUnits): USD처럼 소수가 있으면 프리셋 소수점, KRW는 정수만.
//  - BTC 입력 텍스트(formatSatoshiToBtcInputText): 프리셋 소수점·천단위 구분자.
// 기대값은 프리셋의 구분자로 이 파일에서 직접 만든다(앱 포맷 코드를 기대값으로 쓰지 않음).
import 'package:coconut_wallet/config/number_format_config.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/enums/number_format_preset.dart';
import 'package:coconut_wallet/extensions/int_extensions.dart';
import 'package:coconut_wallet/extensions/string_extensions.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:coconut_wallet/utils/fiat_util.dart';
import 'package:flutter_test/flutter_test.dart';

String _group(String digits, String sep) {
  final b = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) b.write(sep);
    b.write(digits[i]);
  }
  return b.toString();
}

void main() {
  tearDown(() => NumberFormatConfig.instance.applyPreset(NumberFormatPreset.dotDecimal));

  for (final p in NumberFormatPreset.values) {
    final d = p.decimalSeparator;
    final g = p.groupingSeparator;
    group('${p.name} (소수점 "$d", 천단위 "$g")', () {
      setUp(() => NumberFormatConfig.instance.applyPreset(p));

      test('BTC 잔액: 1234.56789012 BTC → 1${g}234${d}5678 9012', () {
        expect(BalanceFormatUtil.formatSatoshiToReadableBitcoin(123456789012), '1${g}234${d}5678 9012');
      });
      test('BTC 잔액: 소수 4자리 이하는 공백 없이, 정수만이면 소수점 없이', () {
        expect(BalanceFormatUtil.formatSatoshiToReadableBitcoin(150000000), '1${d}5');
        expect(BalanceFormatUtil.formatSatoshiToReadableBitcoin(1200000), '0${d}012');
        expect(BalanceFormatUtil.formatSatoshiToReadableBitcoin(100000000000), _group('1000', g));
        expect(BalanceFormatUtil.formatSatoshiToReadableBitcoin(1), '0${d}0000 0001');
      });
      test('BTC 잔액: 8자리 고정 표시도 같은 구분자', () {
        expect(BalanceFormatUtil.formatSatoshiToReadableBitcoin(100000000, forceEightDecimals: true), '1${d}0000 0000');
      });
      test('canonical 문자열 toBtcDisplayString', () {
        expect('1234.56789012'.toBtcDisplayString(), '1${g}234${d}5678 9012');
      });
      test('설정 화면 예시(displayLabel)와 실제 BTC 표시가 같은 문자를 쓴다', () {
        expect(BalanceFormatUtil.formatSatoshiToReadableBitcoin(123456789012), p.displayLabel);
      });
      test('sats 잔액·법정화폐 정수 금액: 천단위 구분자', () {
        expect(1234567.toThousandsSeparatedString(), '1${g}234${g}567');
        expect(999.toThousandsSeparatedString(), '999');
        expect((-1234567).toThousandsSeparatedString(), '-1${g}234${g}567');
      });
      test('법정화폐 최소단위: USD는 소수점, KRW·JPY는 정수만', () {
        expect(FiatUtil.formatMinorUnits(123456789, FiatCode.USD), '1${g}234${g}567${d}89');
        expect(FiatUtil.formatMinorUnits(5000, FiatCode.EUR), '50${d}00');
        expect(FiatUtil.formatMinorUnits(1234567, FiatCode.KRW), '1${g}234${g}567');
        expect(FiatUtil.formatMinorUnits(1234567, FiatCode.JPY), '1${g}234${g}567');
      });
      test('BTC 입력 텍스트: 소수점·천단위 구분자, 뒤 0 제거', () {
        expect(BalanceFormatUtil.formatSatoshiToBtcInputText(123450000000), '1${g}234${d}5');
        expect(BalanceFormatUtil.formatSatoshiToBtcInputText(12345678), '0${d}12345678');
      });
      test('표시한 정수·소수 금액을 다시 읽으면 같은 값 (toDoubleSafe)', () {
        expect('1${g}234${d}5'.toDoubleSafe(), 1234.5);
        expect('1${g}234${g}567'.toDoubleSafe(), 1234567);
      });
    });
  }
}
