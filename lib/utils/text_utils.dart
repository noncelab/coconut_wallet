class TextUtils {
  static String ellipsisIfLonger(String text, {int maxLength = 10}) {
    return text.length > maxLength
        ? '${text.substring(0, maxLength - 3)}...'
        : text;
  }
}
