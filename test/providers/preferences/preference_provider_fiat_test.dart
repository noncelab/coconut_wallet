import 'dart:ui' show Locale;

import 'package:coconut_wallet/constants/shared_pref_keys.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<SharedPrefsRepository> prefsWith(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    // ignore: deprecated_member_use_from_same_package
    return SharedPrefsRepository()..setSharedPreferencesForTest(await SharedPreferences.getInstance());
  }

  String savedFiat(SharedPrefsRepository prefs) => prefs.getString(SharedPrefKeys.kSelectedFiat);

  group('새 설치: 저장된 통화가 없으면 지역(없으면 앱 언어)으로 정해 저장한다', () {
    final cases = [
      (const Locale('ko', 'KR'), 'ko', FiatCode.KRW),
      (const Locale('ja', 'JP'), 'ja', FiatCode.JPY),
      (const Locale('de', 'DE'), 'de', FiatCode.EUR),
      (const Locale('en', 'IN'), 'en', FiatCode.USD),
      (const Locale('en', 'US'), 'en', FiatCode.USD),
      (const Locale('ko'), 'ko', FiatCode.KRW),
      (const Locale('ja'), 'ja', FiatCode.JPY),
      (const Locale('en'), 'en', FiatCode.USD),
    ];
    for (final (locale, appLanguage, expected) in cases) {
      test('$locale, 앱 언어 $appLanguage → ${expected.code}', () async {
        final prefs = await prefsWith({});

        expect(PreferenceProvider.initializeFiat(prefs, locale, appLanguage), expected);
        expect(savedFiat(prefs), expected.code);
      });
    }
  });

  test('저장된 통화는 그대로 둔다', () async {
    final saved = [
      (FiatCode.KRW, const Locale('en', 'IN'), 'en'),
      (FiatCode.USD, const Locale('en', 'IN'), 'en'),
      (FiatCode.EUR, const Locale('ko', 'KR'), 'ko'),
      (FiatCode.JPY, const Locale('en', 'US'), 'en'),
    ];
    for (final (fiat, locale, appLanguage) in saved) {
      final prefs = await prefsWith({SharedPrefKeys.kSelectedFiat: fiat.code});

      expect(PreferenceProvider.initializeFiat(prefs, locale, appLanguage), fiat);
      expect(savedFiat(prefs), fiat.code);
    }
  });
}
