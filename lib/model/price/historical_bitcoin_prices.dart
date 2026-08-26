class HistoricalBitcoinPrices {
  final double previousDayClose;
  final double sevenDaysAgoClose;
  final double thirtyDaysAgoClose;

  const HistoricalBitcoinPrices({
    required this.previousDayClose,
    required this.sevenDaysAgoClose,
    required this.thirtyDaysAgoClose,
  });
}
