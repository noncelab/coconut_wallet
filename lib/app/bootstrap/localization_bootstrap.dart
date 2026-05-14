import 'package:coconut_wallet/localization/strings.g.dart';

void setupPluralResolvers() {
  LocaleSettings.setPluralResolverSync(
    language: 'kr',
    cardinalResolver: (n, {zero, one, two, few, many, other}) => other ?? '',
  );

  LocaleSettings.setPluralResolverSync(
    language: 'jp',
    cardinalResolver: (n, {zero, one, two, few, many, other}) => other ?? '',
  );

  LocaleSettings.setPluralResolverSync(
    language: 'en',
    cardinalResolver: (n, {zero, one, two, few, many, other}) {
      if (n == 0 && zero != null) return zero;
      if (n == 1 && one != null) return one;
      return other ?? '';
    },
  );

  LocaleSettings.setPluralResolverSync(
    language: 'es',
    cardinalResolver: (n, {zero, one, two, few, many, other}) {
      if (n == 1 && one != null) return one;
      return other ?? '';
    },
  );
}
