/// 앱 내부에서 사용하는 언어 코드
///
/// 현재는 [kr, en, jp, es, de] 형태로 저장되지만,
/// 실제 ISO 639-1 언어 코드와는 차이가 있습니다.
/// intl 로케일 매핑을 위해 [intlLocale]을 함께 관리합니다.
enum AppLanguage {
  kr('kr', 'ko'),
  en('en', 'en'),
  jp('jp', 'ja'),
  es('es', 'es'),
  de('de', 'de');

  const AppLanguage(this.code, this.intlLocale);

  /// 앱 내부 언어 코드 (예: kr, en, jp, es, de)
  final String code;

  /// intl NumberFormat 등에 전달할 로케일 코드 (예: ko, en, ja, es, de)
  final String intlLocale;

  static AppLanguage fromCode(String code) => values.firstWhere((e) => e.code == code, orElse: () => en);
}
