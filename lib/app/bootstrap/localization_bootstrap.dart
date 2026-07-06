import 'package:coconut_wallet/constants/app_language.dart';
import 'package:coconut_wallet/localization/strings.g.dart';

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
}
