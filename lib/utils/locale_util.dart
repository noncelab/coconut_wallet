import 'dart:ui';

import 'package:coconut_wallet/constants/app_language.dart';
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

/// 시스템 언어를 감지하여 적절한 언어 코드를 반환합니다.
String getSystemLanguageCode() {
  final Locale systemLocale = PlatformDispatcher.instance.locale;
  final String languageCode = systemLocale.languageCode.toLowerCase();

  switch (languageCode) {
    case 'ko':
      return AppLanguage.kr.code;
    case 'ja':
    case 'jp':
      return AppLanguage.jp.code;
    case 'es':
      return AppLanguage.es.code;
    default:
      return AppLanguage.en.code;
  }
}

/// 시스템 언어가 한국어인지 확인합니다.
bool isSystemLanguageKorean() {
  return getSystemLanguageCode() == AppLanguage.kr.code;
}

/// 시스템 언어가 일본어인지 확인합니다.
bool isSystemLanguageJapanese() {
  return getSystemLanguageCode() == AppLanguage.jp.code;
}
