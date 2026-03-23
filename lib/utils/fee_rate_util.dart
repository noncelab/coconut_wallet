class FeeRateUtils {
  static double roundToTwoDecimals(double feeRate) {
    return (feeRate * 100).roundToDouble() / 100;
  }
}
