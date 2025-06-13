import 'package:decimal/decimal.dart';
import 'package:intl/intl.dart';

class UnitUtil {
  static double satoshiToBitcoin(int satoshi) {
    return double.parse(satoshiToBitcoinString(satoshi));
  }

  static String satoshiToBitcoinString(int satoshi) {
    return (satoshi / 100000000.0).toStringAsFixed(8);
  }

  /// 부동 소숫점 연산 시 오차가 발생할 수 있으므로 Decimal이용
  static int bitcoinToSatoshi(double bitcoin) {
    return (Decimal.parse(bitcoin.toString()) * Decimal.parse('100000000')).toDouble().toInt();
  }
}

/// 사용자 친화적 형식의 비트코인 단위의 잔액
///
/// @param satoshi 사토시 단위 잔액
/// @returns String 비트코인 단위 잔액 문자열 예) 00,000,000.0000 0000
String satoshiToBitcoinString(int satoshi, {bool showDecimals = false}) {
  double toBitcoin = UnitUtil.satoshiToBitcoin(satoshi);

  String bitcoinString;
  if (toBitcoin % 1 == 0) {
    bitcoinString = showDecimals ? toBitcoin.toStringAsFixed(8) : toBitcoin.toInt().toString();
  } else {
    bitcoinString = toBitcoin.toStringAsFixed(8); // Ensure it has 8 decimal places
  }

  // Split the integer and decimal parts
  List<String> parts = bitcoinString.split('.');
  String integerPart = parts[0];
  String decimalPart = parts.length > 1 ? parts[1] : '';

  final integerPartFormatted =
      integerPart == '-0' ? '-0' : addCommasToIntegerPart(double.parse(integerPart));

  // Group the decimal part into blocks of 4 digits
  final decimalPartGrouped =
      RegExp(r'.{1,4}').allMatches(decimalPart).map((match) => match.group(0)).join(' ');

  if (integerPartFormatted == '0' && decimalPartGrouped == '') {
    return '0';
  }

  String result = '$integerPartFormatted.$decimalPartGrouped';

  // Remove the trailing period if it exists
  if (result.endsWith('.')) {
    result = result.substring(0, result.length - 1);
  }

  return result;
}

extension NormalizeToFullCharacters on String {
  /// 정수형 BTC 단위도 소수점 자리에 0을 포함하여 반환합니다.
  String normalizeToFullCharacters() {
    // Step 1: 쉼표 제거
    String noCommas = replaceAll(',', '');

    // Step 2: 정수인지 확인
    if (!noCommas.contains('.')) {
      // 정수라면 ".0000 0000" 추가
      return "$noCommas.0000 0000";
    }

    return this;
  }
}

String addCommasToIntegerPart(double number) {
  // 정수 부분 추출
  String integerPart = number.toInt().toString();

  // 세 자리마다 콤마 추가
  RegExp regex = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
  integerPart = integerPart.replaceAllMapped(regex, (Match match) => '${match[1]},');

  return integerPart;
}

String trimZero(String numStr) {
  // 정수 부분에서 의미 없는 0을 제거합니다.
  numStr = numStr.replaceFirst(RegExp(r'^0+(?=[1-9])'), '');

  // 소수점 부분에서 의미 없는 0을 제거합니다.
  numStr = numStr.replaceAll(RegExp(r'0*$'), '');

  // 정수 부분이 소수점 이하가 되는 경우 앞에 0을 추가합니다.
  if (numStr.startsWith('.')) {
    numStr = '0$numStr';
  }

  // 소수점만 남은 경우, 0으로 만듭니다.
  if (numStr == '.' || numStr == "0.") {
    numStr = '0';
  }

  return numStr;
}

String formatNumber(double number) {
  // 정수로 딱 떨어지면 정수형으로 출력
  if (number == number.toInt()) {
    return number.toInt().toString();
  }
  // 그렇지 않으면 double형 그대로 출력
  return number.toString();
}

String addThousandsSeparator(String input) {
  if (input.isEmpty) return '';

  try {
    // 소수점이 있는지 확인
    if (input.contains('.')) {
      List<String> parts = input.split('.');
      String integerPart = parts[0];
      String decimalPart = parts.length > 1 ? parts[1] : '';

      final formatter = NumberFormat('#,###');
      String formattedInt = formatter.format(int.parse(integerPart));
      return '$formattedInt.$decimalPart';
    } else {
      final formatter = NumberFormat('#,###');
      return formatter.format(int.parse(input));
    }
  } catch (e) {
    return input;
  }
}
