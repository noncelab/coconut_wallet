import 'package:coconut_wallet/extensions/int_extensions.dart';
import 'package:decimal/decimal.dart';

class UnitUtil {
  static double convertSatoshiToBitcoin(int satoshi) {
    return double.parse(convertSatoshiToBitcoinString(satoshi));
  }

  static String convertSatoshiToBitcoinString(int satoshi) {
    return (satoshi / 100000000.0).toStringAsFixed(8);
  }

  /// 부동 소숫점 연산 시 오차가 발생할 수 있으므로 Decimal이용
  static int convertBitcoinToSatoshi(double bitcoin) {
    return (Decimal.parse(bitcoin.toString()) * Decimal.parse('100000000')).toDouble().toInt();
  }
}

class BalanceFormatUtil {
  /// 사용자 친화적 형식의 비트코인 잔액 보이기
  /// balance_format_util_test.dart 참고
  static String formatSatoshiToReadableBitcoin(int satoshi, {bool forceEightDecimals = false}) {
    double toBitcoin = UnitUtil.convertSatoshiToBitcoin(satoshi);

    String bitcoinString;
    if (toBitcoin % 1 == 0) {
      bitcoinString =
          forceEightDecimals ? toBitcoin.toStringAsFixed(8) : toBitcoin.toInt().toString();
    } else {
      bitcoinString = toBitcoin.toStringAsFixed(8);
      if (!forceEightDecimals) {
        bitcoinString = bitcoinString.replaceFirst(RegExp(r'0+$'), '');
      }
    }

    // Split the integer and decimal parts
    List<String> parts = bitcoinString.split('.');
    String integerPart = parts[0];
    String decimalPart = parts.length > 1 ? parts[1] : '';

    final integerPartFormatted =
        integerPart == '-0' ? '-0' : int.parse(integerPart).toThousandsSeparatedString();

    String decimalPartGrouped = '';
    if (decimalPart.isNotEmpty) {
      if (decimalPart.length <= 4) {
        decimalPartGrouped = decimalPart;
      } else {
        decimalPart = decimalPart.padRight(8, '0');
        // Group the decimal part into blocks of 4 digits
        decimalPartGrouped =
            RegExp(r'.{1,4}').allMatches(decimalPart).map((match) => match.group(0)).join(' ');
      }
    }

    if (integerPartFormatted == '0' && decimalPartGrouped == '') {
      return '0';
    }

    return decimalPartGrouped.isNotEmpty
        ? '$integerPartFormatted.$decimalPartGrouped'
        : integerPartFormatted;
  }

  /// 소수점 4번째 자리까지만 고려하여 뒤의 불필요한 0들을 제거
  static String formatBitcoinStringToReadableBitcoin(String bitcoinString) {
    // 소수점을 기준으로 정수부와 소수부 분리
    List<String> parts = bitcoinString.split('.');
    if (parts.length != 2) return bitcoinString; // 소수점이 없으면 그대로 반환

    String integerPart = parts[0];
    String decimalPart = parts[1];

    // 소수부가 8자리보다 짧으면 패딩
    if (decimalPart.length < 8) {
      decimalPart = decimalPart.padRight(8, '0');
    }

    // 앞 4자리와 뒤 4자리 분리
    String firstFour = decimalPart.substring(0, 4);
    String lastFour = decimalPart.substring(4, 8);

    // 뒤 4자리가 모두 0이면 앞 4자리만 사용
    if (lastFour == '0000') {
      // 앞 4자리에서 끝의 0들 제거
      String trimmedFirstFour = firstFour.replaceAll(RegExp(r'0*$'), '');
      return trimmedFirstFour.isEmpty ? integerPart : '$integerPart.$trimmedFirstFour';
    } else {
      // 뒤 4자리에 0이 아닌 숫자가 있는 경우
      // 5번째 자리부터 7번째 자리까지 0이 아닌 숫자가 있으면 8번째 자리까지 0으로 채움
      String resultDecimal = firstFour + lastFour;

      // 5번째 자리부터 7번째 자리까지 확인 (인덱스 4, 5, 6)
      bool hasNonZeroInMiddle = false;
      for (int i = 4; i <= 6 && i < resultDecimal.length; i++) {
        if (resultDecimal[i] != '0') {
          hasNonZeroInMiddle = true;
          break;
        }
      }

      if (hasNonZeroInMiddle) {
        // 5-7번째 자리에 0이 아닌 숫자가 있으면 8번째 자리까지 0으로 채움
        resultDecimal = resultDecimal.padRight(8, '0');
        // 5-7번째 자리에 0이 아닌 숫자가 있으면 끝의 0을 제거하지 않고 그대로 반환
        return '$integerPart.$resultDecimal';
      }

      // 5-7번째 자리가 모두 0인 경우에만 끝의 불필요한 0들 제거
      String trimmedDecimal = resultDecimal.replaceAll(RegExp(r'0*$'), '');
      return trimmedDecimal.isEmpty ? integerPart : '$integerPart.$trimmedDecimal';
    }
  }
}
