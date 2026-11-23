import 'package:coconut_wallet/constants/app_language.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/utils/locale_util.dart';

/// TranslationProvider가 빌드되기 전에 저장된 언어 설정을 적용합니다.
void applyPersistedLocale() {
  final languageCode = resolvePersistedLanguageCode();
  LocaleSettings.setLocaleSync(resolveAppLocale(languageCode));
}

void setupPluralResolvers() {
  LocaleSettings.setPluralResolverSync(
    language: AppLanguage.ko.code,
    cardinalResolver: (n, {zero, one, two, few, many, other}) => other ?? '',
  );

  LocaleSettings.setPluralResolverSync(
    language: AppLanguage.ja.code,
    cardinalResolver: (n, {zero, one, two, few, many, other}) => other ?? '',
  );

  LocaleSettings.setPluralResolverSync(
    language: AppLanguage.en.code,
    cardinalResolver: (n, {zero, one, two, few, many, other}) {
      if (n == 0 && zero != null) return zero;
      if (n == 1 && one != null) return one;
      return other ?? '';
    },
  );

  LocaleSettings.setPluralResolverSync(
    language: AppLanguage.es.code,
    cardinalResolver: (n, {zero, one, two, few, many, other}) {
      if (n == 1 && one != null) return one;
      return other ?? '';
    },
  );

  LocaleSettings.setPluralResolverSync(
    language: AppLanguage.de.code,
    cardinalResolver: (n, {zero, one, two, few, many, other}) {
      if (n == 1 && one != null) return one;
      return other ?? '';
    },
  );

  // 태국어는 복수형이 따로 없습니다. slang에는 태국어 기본 규칙이 없어 등록하지 않으면 오류 로그를 남기고 영어식 규칙을 씁니다.
  LocaleSettings.setPluralResolverSync(
    language: AppLanguage.th.code,
    cardinalResolver: (n, {zero, one, two, few, many, other}) => other ?? '',
  );
}
