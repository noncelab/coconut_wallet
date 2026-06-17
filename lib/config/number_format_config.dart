import 'package:coconut_wallet/utils/locale_util.dart';

/// 앱 전역 숫자 포맷 설정 (싱글톤)
///
/// PreferenceProvider에서 언어 설정 시 [update]를 호출하여 초기화합니다.
/// 이후 앱 어디서든 [NumberFormatConfig.instance]로 접근합니다.
class NumberFormatConfig {
  NumberFormatConfig._();

  static final NumberFormatConfig instance = NumberFormatConfig._();

  String decimalSeparator = '.';
  String groupingSeparator = ',';

  void update(String appLanguageCode) {
    decimalSeparator = getDecimalSeparatorForAppLanguage(appLanguageCode);
    groupingSeparator = getGroupingSeparatorForAppLanguage(appLanguageCode);
  }
}

/// 앱 언어 코드를 intl 로케일 코드로 매핑
const Map<String, String> _appLanguageToIntlLocale = {'kr': 'ko', 'en': 'en', 'jp': 'ja', 'es': 'es'};

/// 앱 설정 언어 기반 소수점 구분자 반환 (기본값: '.')
String getDecimalSeparatorForAppLanguage(String appLanguageCode) {
  final intlLocale = _appLanguageToIntlLocale[appLanguageCode] ?? 'en';
  return getNumberDecimalSeparator(localeName: intlLocale);
}

/// 앱 설정 언어 기반 천 단위 구분자 반환 (기본값: ',')
String getGroupingSeparatorForAppLanguage(String appLanguageCode) {
  final intlLocale = _appLanguageToIntlLocale[appLanguageCode] ?? 'en';
  return getNumberGroupingSeparator(localeName: intlLocale);
}

String normalizeNumTextForNumParsing(String text) {
  final groupingSeparator = NumberFormatConfig.instance.groupingSeparator;
  final decimalSeparator = NumberFormatConfig.instance.decimalSeparator;

  return text.trim().replaceAll(groupingSeparator, '').replaceAll(decimalSeparator, '.');
}

/// 앱 설정 언어 기반 천 단위/소수점 구분자를 사용하여 BigInt 포맷팅
/// 예: value=BigInt.parse('10000000001'), decimalPlaces=8 → '1,000.00000001' (trailing zeros 제거)
String formatBigIntWithAppLanguageLocale(BigInt value, int decimalPlaces, String appLanguageCode) {
  final decimalSep = NumberFormatConfig.instance.decimalSeparator;
  final groupSep = NumberFormatConfig.instance.groupingSeparator;

  final isNegative = value.isNegative;
  final absValue = value.abs().toString().padLeft(decimalPlaces + 1, '0');

  final integerLen = absValue.length - decimalPlaces;
  final integerPart = absValue.substring(0, integerLen);
  var fractionalPart = absValue.substring(integerLen).replaceAll(RegExp(r'0+$'), '');

  final formattedInteger = _addGroupingSeparators(integerPart, groupSep);
  final result = fractionalPart.isEmpty ? formattedInteger : '$formattedInteger$decimalSep$fractionalPart';

  return isNegative ? '-$result' : result;
}

String _addGroupingSeparators(String integerPart, String groupSep) {
  if (integerPart.length <= 3) return integerPart;

  final buffer = StringBuffer();
  for (var i = 0; i < integerPart.length; i++) {
    if (i > 0 && (integerPart.length - i) % 3 == 0) {
      buffer.write(groupSep);
    }
    buffer.write(integerPart[i]);
  }
  return buffer.toString();
}
