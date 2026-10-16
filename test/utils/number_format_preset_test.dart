// 숫자 형식 프리셋 테스트 — 커밋 7719688b "숫자 형식(소수점 구분자, 천단위 구분자) 선택 옵션 추가"
//
// 의도(커밋 메시지·doc comment):
//  - NumberFormatPreset: 4개 프리셋(dotDecimal·commaDecimal·swiss·frenchSpace)이 소수점/천단위 구분자 조합을 정의한다.
//    fromCode는 저장된 이름을 되살리고 모르는 값은 dotDecimal, fromLocale은 locale에서 가장 가까운 프리셋을 고르되
//    NBSP·narrow NBSP는 일반 공백과 같게 본다. 잘못된 locale은 dotDecimal.
//  - NumberFormatConfig.applyPreset: 이후 포맷터·표시·파싱이 모두 그 프리셋의 구분자를 따른다.
//  - 입력 포맷터: 반대쪽 구분자를 누르면 (소수점이 아직 없을 때만) 소수점으로 바꾸고, 천단위 구분자 직접 입력은 거부한다.
//  - resolveAmountKeyInput: 표시 텍스트의 꼬리 diff로 키 입력을 추론하며 천단위 구분자는 무시한다.
//  - 수수료율 텍스트는 canonical('.' 소수점)이므로 로케일 정규화 없이 파싱해야 한다(commaDecimal에서 값이 왜곡되면 안 됨).
import 'package:coconut_wallet/config/number_format_config.dart';
import 'package:coconut_wallet/enums/number_format_preset.dart';
import 'package:coconut_wallet/extensions/string_extensions.dart';
import 'package:coconut_wallet/utils/fee_rate_mixin.dart';
import 'package:coconut_wallet/utils/numeric_input_formatters.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _FeeRateHost extends ChangeNotifier with FeeRateMixin {}

TextEditingValue _tv(String text) =>
    TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));

/// 키를 하나씩 눌러 최종 텍스트를 얻는다 ('<'는 백스페이스).
String _typeKeys(TextInputFormatter f, String keys, {String start = ''}) {
  var cur = _tv(start);
  for (final k in keys.split('')) {
    final next = k == '<' ? _tv(cur.text.substring(0, cur.text.length - 1)) : _tv(cur.text + k);
    cur = f.formatEditUpdate(cur, next);
  }
  return cur.text;
}

void main() {
  tearDown(() => NumberFormatConfig.instance.applyPreset(NumberFormatPreset.dotDecimal));

  group('NumberFormatPreset.fromCode', () {
    test('저장된 name으로 각 프리셋을 되살린다', () {
      for (final p in NumberFormatPreset.values) {
        expect(NumberFormatPreset.fromCode(p.name), p);
      }
    });
    test('모르는 값·빈 값은 dotDecimal', () {
      expect(NumberFormatPreset.fromCode(''), NumberFormatPreset.dotDecimal);
      expect(NumberFormatPreset.fromCode('unknown'), NumberFormatPreset.dotDecimal);
      expect(NumberFormatPreset.fromCode('DOTDECIMAL'), NumberFormatPreset.dotDecimal);
    });
  });

  group('NumberFormatPreset.fromLocale', () {
    final cases = <String, NumberFormatPreset>{
      'en_US': NumberFormatPreset.dotDecimal,
      'ko': NumberFormatPreset.dotDecimal,
      'ja': NumberFormatPreset.dotDecimal,
      'de_DE': NumberFormatPreset.commaDecimal,
      'es_ES': NumberFormatPreset.commaDecimal,
      'fr_FR': NumberFormatPreset.frenchSpace,
      'de_CH': NumberFormatPreset.swiss,
    };
    cases.forEach((locale, expected) {
      test('$locale → ${expected.name}', () {
        expect(NumberFormatPreset.fromLocale(locale), expected);
      });
    });
    test('grouping이 같지 않아도 소수점 구분자가 같으면 그 계열로 fallback (pt_PT: 소수점 ",")', () {
      expect(NumberFormatPreset.fromLocale('pt_PT').decimalSeparator, ',');
    });
    test('잘못된 locale은 dotDecimal', () {
      expect(NumberFormatPreset.fromLocale('!!not-a-locale!!'), NumberFormatPreset.dotDecimal);
      expect(NumberFormatPreset.fromLocale(''), NumberFormatPreset.dotDecimal);
    });
    test('모든 프리셋은 소수점과 천단위 구분자가 서로 다르다', () {
      for (final p in NumberFormatPreset.values) {
        expect(p.decimalSeparator == p.groupingSeparator, isFalse, reason: p.name);
      }
    });
  });

  group('applyPreset이 표시·파싱에 반영된다', () {
    for (final p in NumberFormatPreset.values) {
      final d = p.decimalSeparator;
      final g = p.groupingSeparator;
      test('${p.name}: BigInt 포맷', () {
        NumberFormatConfig.instance.applyPreset(p);
        expect(formatBigIntWithAppLanguageLocale(BigInt.parse('123456789012'), 8), '1${g}234${d}56789012');
        expect(formatBigIntWithAppLanguageLocale(BigInt.parse('100000000'), 8), '1');
        expect(formatBigIntWithAppLanguageLocale(BigInt.parse('-150000000'), 8), '-1${d}5');
      });
      test('${p.name}: toBtcDisplayString(canonical 입력)', () {
        NumberFormatConfig.instance.applyPreset(p);
        expect('1234.56789012'.toBtcDisplayString(), '1${g}234${d}5678 9012');
        expect('1234.5'.toBtcDisplayString(), '1${g}234${d}5');
        expect('1234567'.toBtcDisplayString(), '1${g}234${g}567');
        expect('0.00000001'.toBtcDisplayString(), '0${d}0000 0001');
        expect('not-a-number'.toBtcDisplayString(), 'not-a-number');
      });
      test('${p.name}: 표시 텍스트 → 파싱 왕복', () {
        NumberFormatConfig.instance.applyPreset(p);
        final shown = '1234.56789012'.toBtcDisplayString();
        expect(double.tryParse(normalizeNumTextForNumParsing(shown).replaceAll(' ', '')), 1234.56789012);
      });
    }
  });

  group('resolveAmountKeyInput', () {
    for (final p in NumberFormatPreset.values) {
      final d = p.decimalSeparator;
      final g = p.groupingSeparator;
      test('${p.name}: 삽입·삭제·무변화', () {
        NumberFormatConfig.instance.applyPreset(p);
        expect(resolveAmountKeyInput('1${g}234', '1${g}2345'), '5');
        expect(resolveAmountKeyInput('1${g}234', '1${g}234$d'), d);
        expect(resolveAmountKeyInput('1${g}234', '123'), '<');
        expect(resolveAmountKeyInput('1${g}234', '1${g}234'), isNull);
      });
      test('${p.name}: 자릿수가 늘며 천단위 구분자가 새로 끼어도 입력 키는 숫자 하나', () {
        NumberFormatConfig.instance.applyPreset(p);
        expect(resolveAmountKeyInput('999', '1${g}000'), '0');
      });
    }
  });

  group('BtcAmountInputFormatter', () {
    const f = BtcAmountInputFormatter();
    for (final p in NumberFormatPreset.values) {
      final d = p.decimalSeparator;
      final g = p.groupingSeparator;
      final alt = d == '.' ? ',' : '.';
      test('${p.name}: 숫자 입력 시 천단위 구분자 자동 삽입, 소수점은 프리셋 구분자', () {
        NumberFormatConfig.instance.applyPreset(p);
        expect(_typeKeys(f, '1234'), '1${g}234');
        expect(_typeKeys(f, '1234${d}5'), '1${g}234${d}5');
        expect(_typeKeys(f, '1234567'), '1${g}234${g}567');
      });
      test('${p.name}: 반대쪽 구분자 키는 소수점으로 변환, 두 번째 소수점은 거부', () {
        NumberFormatConfig.instance.applyPreset(p);
        expect(_typeKeys(f, '12${alt}5'), '12${d}5');
        expect(_typeKeys(f, '12${d}5$alt'), '12${d}5');
        expect(_typeKeys(f, '12${d}5$d'), '12${d}5');
      });
      test('${p.name}: 천단위 구분자 직접 입력은 거부 (반대 구분자와 같은 문자면 소수점으로 변환)', () {
        NumberFormatConfig.instance.applyPreset(p);
        // dot/comma 프리셋은 천단위 구분자가 곧 반대 구분자라 소수점 변환이 우선한다(의도된 설계).
        expect(_typeKeys(f, '1234$g'), g == alt ? '1${g}234$d' : '1${g}234');
      });
      test('${p.name}: 소수 9자리·2100만 초과·문자 입력은 거부', () {
        NumberFormatConfig.instance.applyPreset(p);
        expect(_typeKeys(f, '0${d}123456789'), '0${d}12345678');
        expect(_typeKeys(f, '21000001'), '2${g}100${g}000');
        expect(_typeKeys(f, '1a'), '1');
      });
      test('${p.name}: 소수점으로 시작하면 0 + 소수점', () {
        NumberFormatConfig.instance.applyPreset(p);
        expect(_typeKeys(f, d), '0$d');
      });
    }
  });

  group('FiatAmountInputFormatter / SatoshiAmountInputFormatter', () {
    for (final p in NumberFormatPreset.values) {
      final d = p.decimalSeparator;
      final g = p.groupingSeparator;
      test('${p.name}: fiat 2자리 소수', () {
        NumberFormatConfig.instance.applyPreset(p);
        const f = FiatAmountInputFormatter(decimalPlaces: 2);
        expect(_typeKeys(f, '1234${d}56'), '1${g}234${d}56');
        expect(_typeKeys(f, '1234${d}567'), '1${g}234${d}56');
      });
      test('${p.name}: fiat 소수 0자리(KRW)는 소수점 거부', () {
        NumberFormatConfig.instance.applyPreset(p);
        const f = FiatAmountInputFormatter(decimalPlaces: 0);
        expect(_typeKeys(f, '12$d'), '12');
      });
      test('${p.name}: sats 천단위', () {
        NumberFormatConfig.instance.applyPreset(p);
        expect(_typeKeys(const SatoshiAmountInputFormatter(), '1234567'), '1${g}234${g}567');
      });
    }
  });

  group('RateInputFormatter', () {
    const f = RateInputFormatter();
    for (final p in NumberFormatPreset.values) {
      final d = p.decimalSeparator;
      final alt = d == '.' ? ',' : '.';
      test('${p.name}: 소수점은 프리셋 구분자, 반대 구분자는 변환', () {
        NumberFormatConfig.instance.applyPreset(p);
        expect(_typeKeys(f, '12${d}5'), '12${d}5');
        expect(_typeKeys(f, '12${alt}5'), '12${d}5');
        expect(_typeKeys(f, '12${d}5$alt'), '12${d}5');
      });
      test('${p.name}: 소수 3자리 거부, 맨 앞 소수점은 0.', () {
        NumberFormatConfig.instance.applyPreset(p);
        expect(_typeKeys(f, '1${d}234'), '1${d}23');
        expect(_typeKeys(f, d), '0$d');
      });
    }
  });

  group('수수료율 텍스트는 canonical 그대로 파싱 (UtxoSplitViewModel.onFeeRateChanged 의도)', () {
    for (final p in NumberFormatPreset.values) {
      test('${p.name}: handleFeeRateChanged 결과를 double.tryParse하면 입력값과 같다', () {
        NumberFormatConfig.instance.applyPreset(p);
        final host = _FeeRateHost();
        String? updated;
        final tooLow = host.handleFeeRateChanged('12.5', (t) => updated = t);
        expect(tooLow, isFalse);
        expect(updated, '12.5');
        // 커밋이 고친 지점: 정규화 없이 파싱해야 12.5. (정규화하면 commaDecimal/frenchSpace에서 125 또는 12.5 아닌 값)
        expect(double.tryParse(updated!), 12.5);
      });
      test('${p.name}: 0.1 미만은 보정(true)하고 "0."을 돌려준다', () {
        NumberFormatConfig.instance.applyPreset(p);
        final host = _FeeRateHost();
        String? updated;
        expect(host.handleFeeRateChanged('0.05', (t) => updated = t), isTrue);
        expect(updated, '0.');
      });
    }
    test('removeTrailingDotInFeeRateText는 프리셋 소수점 구분자 기준', () {
      final host = _FeeRateHost();
      NumberFormatConfig.instance.applyPreset(NumberFormatPreset.commaDecimal);
      expect(host.removeTrailingDotInFeeRateText('12,'), '12');
      expect(host.removeTrailingDotInFeeRateText('12.'), '12.');
      NumberFormatConfig.instance.applyPreset(NumberFormatPreset.dotDecimal);
      expect(host.removeTrailingDotInFeeRateText('12.'), '12');
    });
  });
}
