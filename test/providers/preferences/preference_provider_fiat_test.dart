import 'dart:async';
import 'dart:ui' show Locale;

import 'package:coconut_wallet/config/number_format_config.dart';
import 'package:coconut_wallet/constants/shared_pref_keys.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/enums/number_format_preset.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/preferences/block_explorer_provider.dart';
import 'package:coconut_wallet/providers/preferences/electrum_server_provider.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/repository/realm/wallet_preferences_repository.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _WalletPreferences extends Fake implements WalletPreferencesRepository {
  @override
  bool hasWalletPreferences() => false;
  @override
  List<int> getWalletOrder() => [];
  @override
  List<int> getFavoriteWalletIds() => [];
  @override
  List<int> getExcludedWalletIds() => [];
}

/// 통화 저장이 언제 끝날지 테스트가 정한다.
class _SlowPrefs extends Fake implements SharedPrefsRepository {
  _SlowPrefs(this.values);

  final Map<String, Object> values;
  final fiatWrite = Completer<void>();

  @override
  String getString(String key) => values[key] as String? ?? '';
  @override
  bool getBool(String key) => values[key] as bool? ?? false;
  @override
  Future setString(String key, String value) async {
    await fiatWrite.future;
    values[key] = value;
  }

  @override
  Future setBool(String key, bool value) async => values[key] = value;
}

void main() {
  Future<SharedPrefsRepository> prefsWith(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    // ignore: deprecated_member_use_from_same_package
    return SharedPrefsRepository()..setSharedPreferencesForTest(await SharedPreferences.getInstance());
  }

  /// 정한 통화를 돌려주고, 미뤄 둔 저장이 끝날 때까지 기다린다.
  Future<FiatCode> resolve(SharedPrefsRepository prefs, Locale systemLocale, String appLanguage) async {
    final fiat = PreferenceProvider.resolveInitialFiat(prefs, systemLocale: systemLocale, appLanguage: appLanguage);
    await Future<void>.delayed(Duration.zero);
    return fiat;
  }

  String savedFiat(SharedPrefsRepository prefs) => prefs.getString(SharedPrefKeys.kSelectedFiat);
  bool isChecked(SharedPrefsRepository prefs) => prefs.getBool(SharedPrefKeys.kHasCheckedRegionDefaultFiat);

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

        expect(await resolve(prefs, locale, appLanguage), expected);
        expect(savedFiat(prefs), expected.code);
        expect(isChecked(prefs), isTrue);
      });
    }

    test('플래그를 남겨서 나중에 직접 고른 KRW를 다시 바꾸지 않는다', () async {
      final prefs = await prefsWith({});
      expect(await resolve(prefs, const Locale('en', 'IN'), 'en'), FiatCode.USD);
      expect(isChecked(prefs), isTrue);

      await prefs.setString(SharedPrefKeys.kSelectedFiat, FiatCode.KRW.code);

      expect(await resolve(prefs, const Locale('en', 'IN'), 'en'), FiatCode.KRW);
      expect(savedFiat(prefs), FiatCode.KRW.code);
    });
  });

  group('기존 설치: 저장된 KRW는 지역이 KR이 아니고 앱 언어도 ko가 아닐 때만 한 번 바로잡는다', () {
    final cases = [
      (const Locale('en', 'IN'), 'en', FiatCode.USD),
      (const Locale('de', 'DE'), 'de', FiatCode.EUR),
      (const Locale('ja'), 'ja', FiatCode.JPY), // 지역이 없으면 앱 언어로 정한다
      (const Locale('en', 'KR'), 'en', FiatCode.KRW), // 지역 KR이면 유지
      (const Locale('ko'), 'ko', FiatCode.KRW), // 지역 없음 + 앱 언어 ko면 유지
      (const Locale('en', 'US'), 'ko', FiatCode.KRW), // 기기 언어가 아니라 앱 언어 ko를 본다
    ];
    for (final (locale, appLanguage, expected) in cases) {
      test('KRW, $locale, 앱 언어 $appLanguage → ${expected.code}', () async {
        final prefs = await prefsWith({SharedPrefKeys.kSelectedFiat: FiatCode.KRW.code});

        expect(await resolve(prefs, locale, appLanguage), expected);
        expect(savedFiat(prefs), expected.code);
        expect(isChecked(prefs), isTrue);
      });
    }

    test('KRW가 아닌 저장값은 그대로 둔다', () async {
      final saved = [
        (FiatCode.USD, const Locale('en', 'IN'), 'en'),
        (FiatCode.EUR, const Locale('ko', 'KR'), 'ko'),
        (FiatCode.JPY, const Locale('en', 'US'), 'en'),
      ];
      for (final (fiat, locale, appLanguage) in saved) {
        final prefs = await prefsWith({SharedPrefKeys.kSelectedFiat: fiat.code});

        expect(await resolve(prefs, locale, appLanguage), fiat);
        expect(savedFiat(prefs), fiat.code);
        expect(isChecked(prefs), isTrue);
      }
    });

    test('플래그가 이미 있으면 KRW도 바꾸지 않는다', () async {
      final prefs = await prefsWith({
        SharedPrefKeys.kSelectedFiat: FiatCode.KRW.code,
        SharedPrefKeys.kHasCheckedRegionDefaultFiat: true,
      });

      expect(await resolve(prefs, const Locale('en', 'IN'), 'en'), FiatCode.KRW);
      expect(savedFiat(prefs), FiatCode.KRW.code);
    });
  });

  group('저장 순서', () {
    test('통화 저장이 끝난 뒤에만 확인 플래그를 남긴다', () async {
      final prefs = _SlowPrefs({});

      expect(await resolve(prefs, const Locale('en', 'IN'), 'en'), FiatCode.USD);
      expect(prefs.values[SharedPrefKeys.kHasCheckedRegionDefaultFiat], isNull);

      prefs.fiatWrite.complete();
      await Future<void>.delayed(Duration.zero);
      expect(prefs.values[SharedPrefKeys.kSelectedFiat], FiatCode.USD.code);
      expect(prefs.values[SharedPrefKeys.kHasCheckedRegionDefaultFiat], isTrue);
    });

    test('통화 저장이 실패하면 플래그를 남기지 않고, 다음 실행에서 같은 보정을 다시 한다', () async {
      final prefs = _SlowPrefs({SharedPrefKeys.kSelectedFiat: FiatCode.KRW.code});

      expect(await resolve(prefs, const Locale('en', 'IN'), 'en'), FiatCode.USD);
      prefs.fiatWrite.completeError(StateError('저장 실패'));
      await Future<void>.delayed(Duration.zero);
      expect(prefs.values[SharedPrefKeys.kSelectedFiat], FiatCode.KRW.code);
      expect(prefs.values[SharedPrefKeys.kHasCheckedRegionDefaultFiat], isNull);

      final nextLaunch = _SlowPrefs(prefs.values)..fiatWrite.complete();
      expect(await resolve(nextLaunch, const Locale('en', 'IN'), 'en'), FiatCode.USD);
      expect(nextLaunch.values[SharedPrefKeys.kSelectedFiat], FiatCode.USD.code);
      expect(nextLaunch.values[SharedPrefKeys.kHasCheckedRegionDefaultFiat], isTrue);
    });

    test('설정에서 고른 통화는 플래그를 남겨, 앞서 플래그 저장이 실패했어도 보정이 바꾸지 않는다', () async {
      final prefs = await prefsWith({
        SharedPrefKeys.kSelectedFiat: FiatCode.USD.code,
        SharedPrefKeys.kLanguage: 'en',
        SharedPrefKeys.kNumberFormatPreset: NumberFormatPreset.dotDecimal.name,
      });
      final electrum = ElectrumServerProvider();
      final explorer = BlockExplorerProvider();
      final provider = PreferenceProvider(_WalletPreferences(), electrum, explorer);
      addTearDown(() {
        provider.dispose();
        electrum.dispose();
        explorer.dispose();
        NumberFormatConfig.instance.applyPreset(NumberFormatPreset.dotDecimal);
        LocaleSettings.setLocaleSync(AppLocale.ko);
      });
      await Future<void>.delayed(Duration.zero);
      await prefs.deleteSharedPrefsWithKey(SharedPrefKeys.kHasCheckedRegionDefaultFiat);

      await provider.changeFiat(FiatCode.KRW);

      expect(isChecked(prefs), isTrue);
      expect(await resolve(prefs, const Locale('en', 'IN'), 'en'), FiatCode.KRW);
      expect(savedFiat(prefs), FiatCode.KRW.code);
    });
  });

  test('생성자는 앱 언어를 정한 뒤(예전 코드 kr → ko) 통화를 확인하므로 KRW를 유지한다', () async {
    final prefs = await prefsWith({SharedPrefKeys.kSelectedFiat: FiatCode.KRW.code, SharedPrefKeys.kLanguage: 'kr'});

    final provider = PreferenceProvider(_WalletPreferences(), ElectrumServerProvider(), BlockExplorerProvider());

    expect(provider.language, 'ko');
    expect(provider.selectedFiat, FiatCode.KRW);
    expect(savedFiat(prefs), FiatCode.KRW.code);
    expect(isChecked(prefs), isTrue);
  });
}
