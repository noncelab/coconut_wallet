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
}

// TODO: double extension
String formatNumber(double number) {
  // 정수로 딱 떨어지면 정수형으로 출력
  if (number == number.toInt()) {
    return number.toInt().toString();
  }
  // 그렇지 않으면 double형 그대로 출력
  return number.toString();
}
