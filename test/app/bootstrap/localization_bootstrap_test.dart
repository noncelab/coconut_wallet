import 'package:coconut_wallet/app/bootstrap/localization_bootstrap.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(setupPluralResolvers);
  tearDown(() => LocaleSettings.setLocaleSync(AppLocale.ko));

  // slang에 기본 규칙이 없는 언어(ko·th)는 등록하지 않으면 쓸 때마다 오류 로그를 남기고 영어식 규칙(0과 1을 따로)을 쓴다.
  // 문구만 봐서는 등록이 빠져도 모른다(태국어는 1일 때 문구와 여럿일 때 문구가 같다). 등록된 규칙을 직접 본다
  test('every locale has its own plural rule registered', () {
    for (final locale in AppLocale.values) {
      expect(locale.translations.$meta.cardinalResolver, isNotNull, reason: locale.languageCode);
    }
  });

  test('Thai, like Korean and Japanese, uses one wording for every count', () {
    for (final locale in [AppLocale.th, AppLocale.ko, AppLocale.ja]) {
      final resolve = locale.translations.$meta.cardinalResolver!;
      for (final n in [0, 1, 2, 5]) {
        expect(resolve(n, zero: 'ZERO', one: 'ONE', other: 'OTHER'), 'OTHER', reason: '${locale.languageCode} $n');
      }
    }
  });

  test('Thai texts with a count show the number', () {
    LocaleSettings.setLocaleSync(AppLocale.th);
    for (final n in [1, 5]) {
      expect(t.relative_time.minutes_ago(n: n), contains('$n'));
      expect(t.relative_time.hours_ago(n: n), contains('$n'));
      expect(t.relative_time.days_ago(n: n), contains('$n'));
    }
  });
}
