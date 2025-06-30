import 'package:coconut_wallet/enums/currency_enums.dart';
import 'package:coconut_wallet/extensions/int_extensions.dart';
import 'package:coconut_wallet/providers/price_provider.dart';
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
String satoshiToBitcoinString(int satoshi, {bool forceEightDecimals = false}) {
  double toBitcoin = UnitUtil.satoshiToBitcoin(satoshi);

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

String formatNumber(double number) {
  // 정수로 딱 떨어지면 정수형으로 출력
  if (number == number.toInt()) {
    return number.toInt().toString();
  }
  // 그렇지 않으면 double형 그대로 출력
  return number.toString();
}

String formatBitcoinValue(int? amount, BitcoinUnit unit,
    {String defaultWhenNull = '',
    String defaultWhenZero = '',
    bool shouldCheckZero = false,
    bool withUnit = false}) {
  if (amount == null) return defaultWhenNull;
  if (shouldCheckZero && amount == 0) return defaultWhenZero;

  String amountText = unit == BitcoinUnit.btc
      ? satoshiToBitcoinString(amount)
      : amount.toThousandsSeparatedString();
  return withUnit ? "$amountText ${unit.symbol()}" : amountText;
}
