class TextUtils {
  static String ellipsisIfLonger(String text, {int maxLength = 10}) {
    text = text.replaceAll('\n', ' ');
    return text.length > maxLength
        ? '${text.substring(0, maxLength - 3)}...'
        : text;
  }

  static String replaceNewlineWithSpace(String text) {
    return text.replaceAll('\n', ' ');
  }
}
