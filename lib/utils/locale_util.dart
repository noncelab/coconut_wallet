import 'dart:ui';

/// 시스템 언어를 감지하여 적절한 언어 코드를 반환합니다.
/// 한글이면 'kr', 나머지는 'en'을 반환합니다.
String getSystemLanguageCode() {
  final Locale systemLocale = PlatformDispatcher.instance.locale;
  final String languageCode = systemLocale.languageCode.toLowerCase();

  // 한국어 감지 (ko, ko-KR, ko-KP 등)
  if (languageCode == 'ko') {
    return 'kr';
  } else if (languageCode == 'ja' || languageCode == 'jp') {
    return 'jp';
  }

  // 기본값은 영어
  return 'en';
}

/// 시스템 언어가 한국어인지 확인합니다.
bool isSystemLanguageKorean() {
  return getSystemLanguageCode() == 'kr';
}

/// 시스템 언어가 일본어인지 확인합니다.
bool isSystemLanguageJapanese() {
  return getSystemLanguageCode() == 'jp';
}
