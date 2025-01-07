class TextUtils {
  static String ellipsisIfLonger(String text, {int maxLength = 10}) {
    return text.length > maxLength
        ? '${text.substring(0, maxLength - 3)}...'
        : text;
  }

  static String truncateNameMax19(String name) {
    if (name.length <= 19) {
      return name;
    }

    return '${name.substring(0, 11)}...${name.substring(name.length - 8, name.length)}';
  }
}
