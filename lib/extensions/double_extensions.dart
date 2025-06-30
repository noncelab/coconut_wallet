extension DoubleFormatting on double {
  String toTrimmedString() {
    // 정수로 딱 떨어지면 정수 부분만 반환
    if (this == toInt()) {
      return toInt().toString();
    }

    return toString();
  }
}
