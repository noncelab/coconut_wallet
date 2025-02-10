import 'package:coconut_wallet/utils/balance_format_util.dart';

class FiatUtil {
  static int calculateFiatAmount(int satoshiAmount, int exchangeRate) {
    return (UnitUtil.satoshiToBitcoin(satoshiAmount) * exchangeRate).toInt();
  }
}
