import 'package:coconut_wallet/config/number_format_config.dart';
import 'package:coconut_wallet/utils/numeric_input_formatters.dart';

extension NumberFormatting on num {
  /// 숫자를 로케일에 맞는 표시 형식의 문자열로 변환합니다.
  /// - 천 단위 구분자 적용
  /// - 소수점 구분자를 로케일 설정에 맞게 변환
  /// - trailing zeros 제거 (기본값)
  /// - 소수점 4자리씩 공백으로 구분 (옵션, 기본값 false)
  String toLocaleString({bool trimTrailingZeros = true, int? maxDecimalPlaces, bool groupDecimalDigits = false}) {
    final decimalSep = NumberFormatConfig.instance.decimalSeparator;
    final groupingSep = NumberFormatConfig.instance.groupingSeparator;

    final str = toString();
    final parts = str.split('.');

    // 정수 부분에 천단위 구분자 적용
    final integerPart = parts[0];
    final formattedInteger = formatIntWithGroupingSeparator(integerPart, groupingSep);

    if (parts.length == 1) {
      return formattedInteger;
    }

    // 소수점 부분 처리
    var decimalPart = parts[1];

    // 소수점 최대 자릿수 제한
    if (maxDecimalPlaces != null && decimalPart.length > maxDecimalPlaces) {
      decimalPart = decimalPart.substring(0, maxDecimalPlaces);
    }

    if (trimTrailingZeros) {
      decimalPart = decimalPart.replaceAll(RegExp(r'0+$'), '');
    }

    if (decimalPart.isEmpty) {
      return formattedInteger;
    }

    // 소수점 4자리씩 공백으로 구분
    if (groupDecimalDigits) {
      final chunks = <String>[];
      for (var i = 0; i < decimalPart.length; i += 4) {
        chunks.add(decimalPart.substring(i, (i + 4).clamp(0, decimalPart.length)));
      }
      decimalPart = chunks.join(' ');
    }

    return '$formattedInteger$decimalSep$decimalPart';
  }
}
