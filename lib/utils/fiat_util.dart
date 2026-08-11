import 'package:coconut_wallet/config/number_format_config.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/extensions/int_extensions.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';

class FiatUtil {
  static int calculateFiatAmount(int satoshiAmount, int exchangeRate) {
    return (UnitUtil.convertSatoshiToBitcoin(satoshiAmount) * exchangeRate).toInt();
  }

  /// 통화 최소단위(minor unit, 예: cent) 정수를 통화별 표시 형식의 문자열로 변환한다.
  /// 예: USD 5025 -> "50.25", KRW 50000 -> "50,000"
  static String formatMinorUnits(int minorUnits, FiatCode fiatCode) {
    final decimalDigits = fiatCode.decimalDigits;
    if (decimalDigits == 0) {
      return minorUnits.toThousandsSeparatedString();
    }

    final divisor = fiatCode.minorUnitsPerWhole;
    final isNegative = minorUnits < 0;
    final absMinorUnits = minorUnits.abs();
    final wholePart = absMinorUnits ~/ divisor;
    final fractionPart = (absMinorUnits % divisor).toString().padLeft(decimalDigits, '0');
    final sign = isNegative ? '-' : '';

    return '$sign${wholePart.toThousandsSeparatedString()}${NumberFormatConfig.instance.decimalSeparator}$fractionPart';
  }
}
