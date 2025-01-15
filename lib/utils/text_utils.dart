class TextUtils {
  static String ellipsisIfLonger(String text, {int maxLength = 10}) {
    return text.length > maxLength
        ? '${text.substring(0, maxLength - 3)}...'
        : text;
  }

  static String truncate(
      String name, int maxLength, int leftValidLength, int rightValidLength) {
    if (name.length <= maxLength ||
        leftValidLength + rightValidLength >= maxLength) {
      return name;
    }

    return '${name.substring(0, leftValidLength)}...${name.substring(name.length - rightValidLength, name.length)}';
  }
}
