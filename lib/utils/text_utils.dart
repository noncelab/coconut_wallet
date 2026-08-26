class TextUtils {
  /// 공백으로 구분된 각 단어 내부에 Unicode Word Joiner를 삽입합니다.
  ///
  /// 한글처럼 렌더러가 글자 단위 줄바꿈을 허용하는 문장에서 단어 중간이
  /// 끊기지 않고 공백 위치에서만 줄바꿈되도록 할 때 사용합니다.
  static String preventLineBreakInsideWords(String text) {
    return text.split(' ').map((word) => word.runes.map(String.fromCharCode).join('\u2060')).join(' ');
  }

  static String ellipsisIfLonger(String text, {int maxLength = 10}) {
    return text.length > maxLength ? '${text.substring(0, maxLength - 3)}...' : text;
  }

  static String truncate(String name, int maxLength, int leftValidLength, int rightValidLength) {
    if (name.length <= maxLength || leftValidLength + rightValidLength > maxLength) {
      return name;
    }

    return '${name.substring(0, leftValidLength)}...${name.substring(name.length - rightValidLength, name.length)}';
  }
}
