import 'dart:ui';

import 'package:coconut_wallet/constants/app_language.dart';
import 'package:coconut_wallet/constants/shared_pref_keys.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:intl/intl.dart';
import 'package:intl/number_symbols.dart';

String getNumberFormatLocaleName() {
  final locales = PlatformDispatcher.instance.locales;
  final locale = locales.isNotEmpty ? locales.first : PlatformDispatcher.instance.locale;

  return Intl.canonicalizedLocale(locale.toLanguageTag());
}

NumberSymbols getNumberFormatSymbols({String? localeName}) {
  return NumberFormat.decimalPattern(localeName ?? getNumberFormatLocaleName()).symbols;
}

String getNumberDecimalSeparator({String? localeName}) {
  return getNumberFormatSymbols(localeName: localeName).DECIMAL_SEP;
}

String getNumberGroupingSeparator({String? localeName}) {
  return getNumberFormatSymbols(localeName: localeName).GROUP_SEP;
}

/// 시스템 언어를 감지하여 앱 내부 언어 코드로 반환합니다.
String getSystemLanguageCode() {
  final Locale systemLocale = PlatformDispatcher.instance.locale;
  final String systemLanguageCode = systemLocale.languageCode.toLowerCase();

  return AppLanguage.fromCode(systemLanguageCode).code;
}

/// 시스템 언어가 한국어인지 확인합니다.
bool isSystemLanguageKorean() {
  return getSystemLanguageCode() == AppLanguage.ko.code;
}

/// 시스템 언어가 일본어인지 확인합니다.
bool isSystemLanguageJapanese() {
  return getSystemLanguageCode() == AppLanguage.ja.code;
}

/// v0.13.1까지 사용하던 앱 언어코드('kr', 'jp')를 ISO 639-1 언어 코드('ko', 'ja')로 마이그레이션합니다.
String migrateLanguageCode(String languageCode) {
  const Map<String, String> migrationMap = {'kr': 'ko', 'jp': 'ja'};
  return migrationMap[languageCode] ?? languageCode;
}

/// 언어 코드에 해당하는 AppLocale을 반환합니다.
AppLocale resolveAppLocale(String languageCode) {
  return switch (AppLanguage.fromCode(languageCode)) {
    AppLanguage.ko => AppLocale.ko,
    AppLanguage.en => AppLocale.en,
    AppLanguage.ja => AppLocale.ja,
    AppLanguage.es => AppLocale.es,
    AppLanguage.de => AppLocale.de,
  };
}

/// SharedPrefs에서 저장된 언어 코드를 읽어 반환합니다.
/// 저장된 값이 없으면 시스템 언어를 반환합니다.
String resolvePersistedLanguageCode() {
  final sharedPrefs = SharedPrefsRepository();
  if (sharedPrefs.isContainsKey(SharedPrefKeys.kLanguage)) {
    return migrateLanguageCode(sharedPrefs.getString(SharedPrefKeys.kLanguage));
  }
  return getSystemLanguageCode();
}
