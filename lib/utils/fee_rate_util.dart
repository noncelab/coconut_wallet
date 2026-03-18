class FeeRateUtils {
  static double ceilFeeRate(double feeRate) {
    return (feeRate * 100).roundToDouble() / 100;
  }
}
