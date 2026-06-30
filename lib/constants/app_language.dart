/// 앱 내부에서 사용하는 언어 코드
///
/// ISO 639-1 표준 언어 코드를 사용합니다.
enum AppLanguage {
  ko,
  en,
  ja,
  es,
  de;

  /// 앱 내부 언어 코드 (예: ko, en, ja, es, de)
  String get code => name;

  static AppLanguage fromCode(String code) => values.firstWhere((e) => e.code == code, orElse: () => en);

  /// 영어와 같은 어순(SVO)을 사용하는 언어인지 여부
  bool get hasEnglishWordOrder => this == AppLanguage.en || this == AppLanguage.es || this == AppLanguage.de;

  /// 용어집(glossary) 메뉴를 제공하는 언어인지 여부
  bool get supportsGlossary => this == AppLanguage.ko || this == AppLanguage.ja;
}
