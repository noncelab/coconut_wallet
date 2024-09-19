import 'package:coconut_lib/coconut_lib.dart';

class FiatUtil {
  static int calculateFiatAmount(int satoshiAmount, int exchangeRate) {
    return (UnitUtil.satoshiToBitcoin(satoshiAmount) * exchangeRate).toInt();
  }
}
