class RecommendedFee {
  final double? _fastestFee;
  final double? _halfHourFee;
  final double? _hourFee;
  final double? _economyFee;
  final double? _minimumFee;

  RecommendedFee(this._fastestFee, this._halfHourFee, this._hourFee, this._economyFee, this._minimumFee);

  double? get fastestFee => _fastestFee;

  double? get halfHourFee => _halfHourFee;

  double? get hourFee => _hourFee;

  double? get economyFee => _economyFee;

  double? get minimumFee => _minimumFee;

  // 소수점 2자리부터 버림
  static double truncateTo2Decimals(double value) {
    return (value * 100).truncateToDouble() / 100;
  }

  static double? parseAndTruncate(dynamic value) {
    if (value == null) return null;
    if (value is int) return truncateTo2Decimals(value.toDouble());
    if (value is double) return truncateTo2Decimals(value);
    if (value is String) return truncateTo2Decimals(double.parse(value));
    return null;
  }

  factory RecommendedFee.fromJson(Map<String, dynamic> json) {
    return RecommendedFee(
      parseAndTruncate(json['fastestFee']),
      parseAndTruncate(json['halfHourFee']),
      parseAndTruncate(json['hourFee']),
      parseAndTruncate(json['economyFee']),
      parseAndTruncate(json['minimumFee']),
    );
  }
}
