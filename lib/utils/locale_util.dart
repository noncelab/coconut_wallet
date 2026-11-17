import 'dart:ui';

import 'package:coconut_wallet/constants/app_language.dart';
import 'package:coconut_wallet/constants/shared_pref_keys.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';

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

/// 유로를 쓰는 지역의 ISO 3166-1 alpha-2 코드.
/// XK(코소보)는 사용자 지정 코드, EA·IC는 예외 예약 코드지만 CLDR와 기기가 지역 코드로 씁니다.
/// 출처
/// - 유로존 회원국: https://european-union.europa.eu/institutions-law-budget/euro/countries-using-euro_en (2026-01-12 갱신)
/// - EU 밖 유로 사용처와 프랑스 최외곽 지역: https://economy-finance.ec.europa.eu/euro/use-euro/euro-outside-euro-area_en
/// - 그 밖의 영토(AX·MF·TF·EA·IC): Unicode CLDR common/supplemental/supplementalData.xml의 currencyData
const Set<String> _euroRegionCodes = {
  // 유로존 21개 회원국. 불가리아는 2026-01-01에 가입했습니다.
  'AT', 'BE', 'BG', 'CY', 'DE', 'EE', 'ES', 'FI', 'FR', 'GR', 'HR',
  'IE', 'IT', 'LT', 'LU', 'LV', 'MT', 'NL', 'PT', 'SI', 'SK',
  // EU 회원국 영토지만 지역 코드가 따로 있는 곳: 핀란드 올란드, 프랑스 최외곽 지역, 스페인 세우타·멜리야와 카나리아 제도
  'AX', 'GF', 'GP', 'MQ', 'RE', 'YT', 'MF', 'EA', 'IC',
  // EU 회원국이 아닌 유로 사용처: EU와 통화 협정(MC·SM·VA·AD), 프랑스 해외 영토(BL·PM·TF), 협정 없이 사용(ME·XK)
  'MC', 'SM', 'VA', 'AD', 'BL', 'PM', 'TF', 'ME', 'XK',
};

/// 거래소 시세가 없는 통화(CoinGecko)를 기본 통화로 쓰는 지역의 ISO 3166-1 alpha-2 코드.
/// 지역마다 CLDR의 주 통화(끝나지 않은 첫 법정 통화)를 보고 FiatCode에 있는 통화만 골라 만들었습니다.
/// 지역의 주 통화를 지원하지 않으면 USD를 씁니다(예: 이집트 EGP, 부탄 BTN, 나미비아 NAD).
/// 출처: CLDR 49 `cldr-core/supplemental/currencyData.json` (https://github.com/unicode-org/cldr-json, 2026-11-12)
const Map<FiatCode, List<String>> _localFiatRegions = {
  FiatCode.AED: ['AE'],
  FiatCode.ARS: ['AR'],
  FiatCode.AUD: ['AU', 'CC', 'CX', 'HM', 'KI', 'NF', 'NR', 'TV'],
  FiatCode.BDT: ['BD'],
  FiatCode.BHD: ['BH'],
  FiatCode.BMD: ['BM'],
  FiatCode.BRL: ['BR'],
  FiatCode.CAD: ['CA'],
  FiatCode.CHF: ['CH', 'LI'],
  FiatCode.CLP: ['CL'],
  FiatCode.CZK: ['CZ'],
  FiatCode.DKK: ['DK', 'FO', 'GL'],
  FiatCode.GBP: ['GB', 'GG', 'GS', 'IM', 'JE', 'TA'],
  FiatCode.GEL: ['GE'],
  FiatCode.HKD: ['HK'],
  FiatCode.HUF: ['HU'],
  FiatCode.IDR: ['ID'],
  FiatCode.ILS: ['IL', 'PS'],
  FiatCode.INR: ['IN'],
  FiatCode.KWD: ['KW'],
  FiatCode.LKR: ['LK'],
  FiatCode.MMK: ['MM'],
  FiatCode.MXN: ['MX'],
  FiatCode.MYR: ['MY'],
  FiatCode.NGN: ['NG'],
  FiatCode.NOK: ['BV', 'NO', 'SJ'],
  FiatCode.NZD: ['CK', 'NU', 'NZ', 'PN', 'TK'],
  FiatCode.PHP: ['PH'],
  FiatCode.PKR: ['PK'],
  FiatCode.PLN: ['PL'],
  FiatCode.RUB: ['RU'],
  FiatCode.SAR: ['SA'],
  FiatCode.SEK: ['SE'],
  FiatCode.SGD: ['SG'],
  FiatCode.THB: ['TH'],
  FiatCode.TRY: ['TR'],
  FiatCode.TWD: ['TW'],
  FiatCode.UAH: ['UA'],
  FiatCode.VND: ['VN'],
  FiatCode.ZAR: ['LS', 'ZA'],
};

/// 기본 통화를 locale로 정합니다. 지역(countryCode)을 먼저 보고, 지역이 없으면 언어로 정합니다.
/// 지역: KR→KRW, JP→JPY, 유로 사용 지역→EUR, 지원하는 그 지역의 통화(TH→THB 등), 그 밖→USD
/// 언어: ko→KRW, ja→JPY, de→EUR, 그 밖→USD
FiatCode defaultFiatForLocale(Locale locale) {
  final region = locale.countryCode?.toUpperCase() ?? '';
  if (region.isEmpty) {
    return switch (AppLanguage.fromCode(locale.languageCode.toLowerCase())) {
      AppLanguage.ko => FiatCode.KRW,
      AppLanguage.ja => FiatCode.JPY,
      AppLanguage.de => FiatCode.EUR,
      AppLanguage.en || AppLanguage.es => FiatCode.USD,
    };
  }
  return switch (region) {
    'KR' => FiatCode.KRW,
    'JP' => FiatCode.JPY,
    _ when _euroRegionCodes.contains(region) => FiatCode.EUR,
    _ => FiatCode.values.firstWhere(
      (fiat) => _localFiatRegions[fiat]?.contains(region) ?? false,
      orElse: () => FiatCode.USD,
    ),
  };
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
