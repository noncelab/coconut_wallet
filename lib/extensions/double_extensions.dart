extension DoubleFormatting on double {
  String toTrimmedString() {
    // 정수로 딱 떨어지면 정수 부분만 반환
    if (this == toInt()) {
      return toInt().toString();
    }

    return toString();
  }
}

extension DoublePrecisionExtension on double {
  /// 소수점 아래 8자리에서 절삭 (반올림 안 함)
  double truncateTo8() {
    const factor = 100000000;
    return (this * factor).truncate() / factor;
  }
}

extension RoundTo8DigitsExtension on double {
  /// 소수점 8자리까지 반올림해서 double로 반환
  double roundTo8Digits() {
    return double.parse(toStringAsFixed(8));
  }
}
