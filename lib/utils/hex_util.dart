bool isHexString(String value) {
  if (!value.length.isEven) return false;
  for (int i = 0; i < value.length; i += 2) {
    final byteStr = value.substring(i, i + 2);
    try {
      int.parse(byteStr, radix: 16);
    } catch (_) {
      return false;
    }
  }
  return true;
}
