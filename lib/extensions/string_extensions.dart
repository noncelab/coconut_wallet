import 'package:coconut_wallet/extensions/int_extensions.dart';
import 'package:coconut_wallet/utils/locale_util.dart';
import 'package:coconut_wallet/config/number_format_config.dart';
import 'package:coconut_wallet/utils/numeric_input_formatters.dart';
import 'package:intl/intl.dart';

extension StringCheck on String {
  /// CJK 문자(한글, 일본어, 한자 등)를 포함하는지 검사
  bool get containsCJK => RegExp(r'[\u3040-\u30FF\u3400-\u4DBF\u4E00-\u9FFF\uAC00-\uD7AF]').hasMatch(this);
}

extension StringFormatting on String {
  /// `.` 기준 BTC 문자열을 로케일 포맷으로 변환
  /// - 정수부: 천단위 구분자 삽입
  /// - 소수부: 4자리씩 공백 구분 (패딩 없음)
  /// - 소수점: 로케일 구분자로 교체
  String toBtcDisplayString({bool groupDecimalDigits = true}) {
    // String을 숫자로 변환할 수 없는 경우 원래 문자열 반환
    final number = toDoubleSafe();
    if (number == null) return this;

    try {
      // 소수점이 있는지 확인
      if (contains('.')) {
        List<String> parts = split('.');
        String integerPart = parts[0];
        String decimalPart = parts.length > 1 ? parts[1] : '';

        String formattedIntegerPart =
            integerPart == '-0'
                ? '-0'
                : formatIntWithGroupingSeparator(integerPart, NumberFormatConfig.instance.groupingSeparator);

        // 소수점 4자리가 넘어가는 경우 4자리씩 띄워서 처리 (옵션)
        if (groupDecimalDigits && decimalPart.length > 4) {
          decimalPart = "${decimalPart.substring(0, 4)} ${decimalPart.substring(4)}";
        }

        return '$formattedIntegerPart${NumberFormatConfig.instance.decimalSeparator}$decimalPart';
      } else {
        return int.parse(this).toThousandsSeparatedString();
      }
    } catch (e) {
      return this;
    }
  }
}

extension SafeNumberParsing on String {
  /// 로케일에 맞는 숫자 문자열을 안전하게 double로 파싱합니다.
  /// 쉼표/점 소수점 구분자 문제를 자동으로 처리합니다.
  double? toDoubleSafe() {
    return double.tryParse(normalizeNumTextForNumParsing(this));
  }

  /// 로케일에 맞는 숫자 문자열을 안전하게 num으로 파싱합니다.
  /// 쉼표/점 소수점 구분자 문제를 자동으로 처리합니다.
  num? toNumSafe() {
    return num.tryParse(normalizeNumTextForNumParsing(this));
  }

  /// 로케일에 맞는 숫자 문자열을 안전하게 int로 파싱합니다.
  /// 쉼표/점 소수점 구분자 문제를 자동으로 처리합니다.
  int? toIntSafe() {
    return int.tryParse(normalizeNumTextForNumParsing(this));
  }
}
