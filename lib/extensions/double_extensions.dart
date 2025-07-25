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
