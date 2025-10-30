class RecommendedFee {
  final int _fastestFee;
  final int _halfHourFee;
  final int _hourFee;
  final int _economyFee;
  final int _minimumFee;

  RecommendedFee(this._fastestFee, this._halfHourFee, this._hourFee, this._economyFee, this._minimumFee);

  int get fastestFee => _fastestFee;

  int get halfHourFee => _halfHourFee;

  int get hourFee => _hourFee;

  int get economyFee => _economyFee;

  int get minimumFee => _minimumFee;

  factory RecommendedFee.fromJson(Map<String, dynamic> json) {
    int _parseIntSafely(dynamic value, String fieldName) {
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

    try {
      return RecommendedFee(
        _parseIntSafely(json['fastestFee'], 'fastestFee'),
        _parseIntSafely(json['halfHourFee'], 'halfHourFee'),
        _parseIntSafely(json['hourFee'], 'hourFee'),
        _parseIntSafely(json['economyFee'], 'economyFee'),
        _parseIntSafely(json['minimumFee'], 'minimumFee'),
      );
    } catch (e) {
      throw FormatException('Failed to parse RecommendedFee: $e');
    }
  }
}
