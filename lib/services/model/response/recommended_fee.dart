class RecommendedFee {
  final int _fastestFee;
  final int _halfHourFee;
  final int _hourFee;
  final int _economyFee;
  final double _minimumFee;

  RecommendedFee(
      this._fastestFee, this._halfHourFee, this._hourFee, this._economyFee, this._minimumFee);

  int get fastestFee => _fastestFee;

  int get halfHourFee => _halfHourFee;

  int get hourFee => _hourFee;

  int get economyFee => _economyFee;

  double get minimumFee => _minimumFee; // double 반환

  factory RecommendedFee.fromJson(Map<String, dynamic> json) {
    int parseIntSafely(dynamic value, String fieldName) {
      if (value == null) {
        throw FormatException('$fieldName is null');
      }
      if (value is int) {
        return value;
      }
      if (value is String) {
        return int.parse(value);
      }
      throw FormatException('$fieldName has invalid type: ${value.runtimeType}');
    }

    double parseDoubleSafely(dynamic value, String fieldName) {
      if (value == null) {
        throw FormatException('$fieldName is null');
      }
      if (value is double) {
        return value;
      }
      if (value is int) {
        return value.toDouble();
      }
      if (value is String) {
        return double.parse(value);
      }
      throw FormatException('$fieldName has invalid type: ${value.runtimeType}');
    }

    try {
      return RecommendedFee(
        parseIntSafely(json['fastestFee'], 'fastestFee'),
        parseIntSafely(json['halfHourFee'], 'halfHourFee'),
        parseIntSafely(json['hourFee'], 'hourFee'),
        parseIntSafely(json['economyFee'], 'economyFee'),
        parseDoubleSafely(json['minimumFee'], 'minimumFee'),
      );
    } catch (e) {
      throw FormatException('Failed to parse RecommendedFee: $e');
    }
  }
}
