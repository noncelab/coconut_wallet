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
  bool isContainsKey(String key) => values.containsKey(key);
  @override
  Future<bool> setStringAndConfirm(String key, String value) async {
    await fiatWrite.future;
    values[key] = value;
    return true;
  }

  @override
  Future<bool> setBoolAndConfirm(String key, bool value) async {
    values[key] = value;
    return true;
  }
}

/// 통화 쓰기만 기기 저장소가 거절(false)하는 SharedPreferences. 나머지는 실제 mock 저장소로 넘긴다.
class _RefusingFiatWrites extends Fake implements SharedPreferences {
  _RefusingFiatWrites(this._inner);

  final SharedPreferences _inner;

  @override
  Future<bool> setString(String key, String value) {
    if (key == SharedPrefKeys.kSelectedFiat) return Future.value(false);
    return _inner.setString(key, value);
  }

  @override
  Future<bool> setBool(String key, bool value) => _inner.setBool(key, value);
  @override
  String? getString(String key) => _inner.getString(key);
  @override
  bool? getBool(String key) => _inner.getBool(key);
  @override
  bool containsKey(String key) => _inner.containsKey(key);
}

void main() {
  Future<SharedPrefsRepository> prefsWith(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    // ignore: deprecated_member_use_from_same_package
    return SharedPrefsRepository()..setSharedPreferencesForTest(await SharedPreferences.getInstance());
  }

  /// 정한 통화를 돌려주고, 미뤄 둔 저장이 끝날 때까지 기다린다.
  Future<FiatCode> resolve(
    SharedPrefsRepository prefs,
    Locale systemLocale,
    String appLanguage, {
    String? iosRegionCode,
    String timeZoneName = 'UTC',
  }) async {
    final fiat = PreferenceProvider.resolveInitialFiat(
      prefs,
      iosRegionCode: iosRegionCode,
      systemLocale: systemLocale,
      appLanguage: appLanguage,
      timeZoneName: timeZoneName,
    );
    await Future<void>.delayed(Duration.zero);
    return fiat;
  }

  /// 기기 locale·시간대를 고정해 만들고, feature_search_navigation_test처럼 테스트가 끝나면 정리한다.
  Future<PreferenceProvider> createProvider({
    String? iosRegionCode,
    Locale systemLocale = const Locale('en', 'US'),
    String timeZoneName = 'UTC',
  }) async {
    final electrum = ElectrumServerProvider();
    final explorer = BlockExplorerProvider();
    final provider = PreferenceProvider(
      _WalletPreferences(),
      electrum,
      explorer,
      iosRegionCode: iosRegionCode,
      systemLocale: systemLocale,
      timeZoneName: timeZoneName,
    );
    addTearDown(() {
      provider.dispose();
      electrum.dispose();
      explorer.dispose();
      NumberFormatConfig.instance.applyPreset(NumberFormatPreset.dotDecimal);
      LocaleSettings.setLocaleSync(AppLocale.ko);
    });
    // 생성자가 미뤄 둔 저장과 CCOS 상태 읽기를 끝낸 뒤에 확인하고 정리한다.
    await Future<void>.delayed(Duration.zero);
    return provider;
  }

  String savedFiat(SharedPrefsRepository prefs) => prefs.getString(SharedPrefKeys.kSelectedFiat);
  bool isChecked(SharedPrefsRepository prefs) => prefs.getBool(SharedPrefKeys.kHasCheckedRegionDefaultFiat);

  group('새 설치: 저장된 통화가 없으면 지역(없으면 앱 언어)으로 정해 저장한다', () {
    final cases = [
      (const Locale('ko', 'KR'), 'ko', FiatCode.KRW),
      (const Locale('ja', 'JP'), 'ja', FiatCode.JPY),
      (const Locale('de', 'DE'), 'de', FiatCode.EUR),
      (const Locale('en', 'IN'), 'en', FiatCode.INR),
      (const Locale('th', 'TH'), 'en', FiatCode.THB), // 앱 언어가 없는 지역도 지역의 통화
      (const Locale('ar', 'EG'), 'en', FiatCode.USD), // 지원하지 않는 통화의 지역
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
      expect(await resolve(prefs, const Locale('en', 'IN'), 'en'), FiatCode.INR);
      expect(isChecked(prefs), isTrue);

      await prefs.setString(SharedPrefKeys.kSelectedFiat, FiatCode.KRW.code);

      expect(await resolve(prefs, const Locale('en', 'IN'), 'en'), FiatCode.KRW);
      expect(savedFiat(prefs), FiatCode.KRW.code);
    });
  });

  group('기존 설치: 저장된 KRW는 지역이 KR이 아니고 앱 언어도 ko가 아닐 때만 한 번 바로잡는다', () {
    final cases = [
      (const Locale('en', 'IN'), 'en', FiatCode.INR),
      (const Locale('th', 'TH'), 'en', FiatCode.THB), // 태국: 예전처럼 USD가 아니라 바트로 바로잡는다
      (const Locale('ar', 'EG'), 'en', FiatCode.USD),
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

  group('iOS는 지역 설정을 먼저 쓴다', () {
    test('지역 설정 DE, 언어 English(US) → 새 설치는 EUR', () async {
      final prefs = await prefsWith({});

      expect(await resolve(prefs, const Locale('en', 'US'), 'en', iosRegionCode: 'DE'), FiatCode.EUR);
      expect(savedFiat(prefs), FiatCode.EUR.code);
    });

    test('지역 설정 DE, 언어 English(US) → 저장된 KRW도 EUR로 바로잡는다', () async {
      final prefs = await prefsWith({SharedPrefKeys.kSelectedFiat: FiatCode.KRW.code});

      expect(await resolve(prefs, const Locale('en', 'US'), 'en', iosRegionCode: 'DE'), FiatCode.EUR);
    });

    test('지역 설정 KR이면 언어의 지역이 US여도 KRW를 지킨다', () async {
      final prefs = await prefsWith({SharedPrefKeys.kSelectedFiat: FiatCode.KRW.code});

      expect(await resolve(prefs, const Locale('en', 'US'), 'en', iosRegionCode: 'KR'), FiatCode.KRW);
      expect(savedFiat(prefs), FiatCode.KRW.code);
    });

    test('지역 설정이 없으면(Android 포함) 지금처럼 첫 번째 선호 locale의 지역을 쓴다', () async {
      final cases = [(null, const Locale('ja', 'JP'), FiatCode.JPY), ('', const Locale('en', 'US'), FiatCode.USD)];
      for (final (iosRegionCode, locale, expected) in cases) {
        final prefs = await prefsWith({});

        expect(await resolve(prefs, locale, locale.languageCode, iosRegionCode: iosRegionCode), expected);
      }
    });

    test('지역 설정도 locale 지역도 없으면 앱 언어로 정한다', () async {
      final prefs = await prefsWith({});

      expect(await resolve(prefs, const Locale('ja'), 'ja', iosRegionCode: null), FiatCode.JPY);
    });
  });

  group('기기 시간대가 한국(KST)이면 KRW', () {
    test('KST, 지역 US, 언어 en → 새 설치는 KRW', () async {
      final prefs = await prefsWith({});

      expect(await resolve(prefs, const Locale('en', 'US'), 'en', timeZoneName: 'KST'), FiatCode.KRW);
      expect(savedFiat(prefs), FiatCode.KRW.code);
    });

    test('KST, 지역 US, 언어 en → 저장된 KRW를 바로잡지 않는다', () async {
      final prefs = await prefsWith({SharedPrefKeys.kSelectedFiat: FiatCode.KRW.code});

      expect(await resolve(prefs, const Locale('en', 'US'), 'en', timeZoneName: 'KST'), FiatCode.KRW);
      expect(savedFiat(prefs), FiatCode.KRW.code);
      expect(isChecked(prefs), isTrue);
    });

    test('iOS 지역 설정 DE보다도 KST가 먼저다', () async {
      final prefs = await prefsWith({});

      expect(
        await resolve(prefs, const Locale('en', 'US'), 'en', iosRegionCode: 'DE', timeZoneName: 'KST'),
        FiatCode.KRW,
      );
    });

    test('KST여도 KRW가 아닌 저장값은 그대로 둔다', () async {
      final prefs = await prefsWith({SharedPrefKeys.kSelectedFiat: FiatCode.USD.code});

      expect(await resolve(prefs, const Locale('en', 'US'), 'en', timeZoneName: 'KST'), FiatCode.USD);
    });

    test('같은 UTC+9여도 KST가 아니면 지역대로 정한다', () async {
      final cases = [
        (const Locale('ja', 'JP'), 'ja', 'JST', FiatCode.JPY),
        (const Locale('en', 'PW'), 'en', '+09', FiatCode.USD), // Pacific/Palau
        (const Locale('id', 'ID'), 'en', 'WIT', FiatCode.IDR), // Asia/Jayapura
      ];
      for (final (locale, appLanguage, timeZoneName, expected) in cases) {
        final prefs = await prefsWith({});

        expect(await resolve(prefs, locale, appLanguage, timeZoneName: timeZoneName), expected);
      }
    });
  });

  group('통화 선택 이전 버전 설치(지갑 수 기록은 있고 통화는 없음)는 저장된 KRW로 본다', () {
    final cases = [
      (const Locale('en', 'US'), 'ko', FiatCode.KRW), // 앱 언어 ko → 유지(새 설치라면 USD)
      (const Locale('en', 'KR'), 'en', FiatCode.KRW), // 지역 KR → 유지
      (const Locale('en', 'IN'), 'en', FiatCode.INR), // 지역의 통화로 바로잡는다
    ];
    for (final (locale, appLanguage, expected) in cases) {
      test('$locale, 앱 언어 $appLanguage → ${expected.code}', () async {
        final prefs = await prefsWith({SharedPrefKeys.kWalletCount: 2});

        expect(await resolve(prefs, locale, appLanguage), expected);
        expect(savedFiat(prefs), expected.code);
        expect(isChecked(prefs), isTrue);
      });
    }

    test('지갑 수 기록이 없으면 새 설치로 본다', () async {
      final prefs = await prefsWith({});

      expect(await resolve(prefs, const Locale('en', 'US'), 'ko'), FiatCode.USD);
    });
  });

  group('저장 순서', () {
    test('통화 저장이 끝난 뒤에만 확인 플래그를 남긴다', () async {
      final prefs = _SlowPrefs({});

      expect(await resolve(prefs, const Locale('en', 'US'), 'en'), FiatCode.USD);
      expect(prefs.values[SharedPrefKeys.kHasCheckedRegionDefaultFiat], isNull);

      prefs.fiatWrite.complete();
      await Future<void>.delayed(Duration.zero);
      expect(prefs.values[SharedPrefKeys.kSelectedFiat], FiatCode.USD.code);
      expect(prefs.values[SharedPrefKeys.kHasCheckedRegionDefaultFiat], isTrue);
    });

    test('통화 저장이 실패하면 플래그를 남기지 않고, 다음 실행에서 같은 보정을 다시 한다', () async {
      final prefs = _SlowPrefs({SharedPrefKeys.kSelectedFiat: FiatCode.KRW.code});

      expect(await resolve(prefs, const Locale('en', 'US'), 'en'), FiatCode.USD);
      prefs.fiatWrite.completeError(StateError('저장 실패'));
      await Future<void>.delayed(Duration.zero);
      expect(prefs.values[SharedPrefKeys.kSelectedFiat], FiatCode.KRW.code);
      expect(prefs.values[SharedPrefKeys.kHasCheckedRegionDefaultFiat], isNull);

      final nextLaunch = _SlowPrefs(prefs.values)..fiatWrite.complete();
      expect(await resolve(nextLaunch, const Locale('en', 'US'), 'en'), FiatCode.USD);
      expect(nextLaunch.values[SharedPrefKeys.kSelectedFiat], FiatCode.USD.code);
      expect(nextLaunch.values[SharedPrefKeys.kHasCheckedRegionDefaultFiat], isTrue);
    });

    test('지역 KR이나 KST로 KRW를 지킬 때는 통화를 다시 쓰지 않고 확인 플래그만 남긴다', () async {
      final cases = [(const Locale('en', 'KR'), 'UTC'), (const Locale('en', 'US'), 'KST')];
      for (final (locale, timeZoneName) in cases) {
        // 통화 저장은 끝나지 않으므로, 통화를 다시 썼다면 플래그도 남지 않는다.
        final prefs = _SlowPrefs({SharedPrefKeys.kSelectedFiat: FiatCode.KRW.code});

        expect(await resolve(prefs, locale, 'en', timeZoneName: timeZoneName), FiatCode.KRW);
        expect(prefs.values[SharedPrefKeys.kHasCheckedRegionDefaultFiat], isTrue);
      }
    });

    test('기기 저장소가 통화 저장을 거절(false)하면 플래그를 남기지 않는다: 시작할 때', () async {
      final prefs = await prefsWith({SharedPrefKeys.kSelectedFiat: FiatCode.KRW.code});
      // ignore: deprecated_member_use_from_same_package
      prefs.setSharedPreferencesForTest(_RefusingFiatWrites(prefs.sharedPrefs));

      expect(await resolve(prefs, const Locale('en', 'US'), 'en'), FiatCode.USD);
      expect(savedFiat(prefs), FiatCode.KRW.code);
      expect(isChecked(prefs), isFalse);
    });

    test('기기 저장소가 통화 저장을 거절(false)하면 플래그를 남기지 않는다: 설정에서 고를 때', () async {
      final prefs = await prefsWith({
        SharedPrefKeys.kSelectedFiat: FiatCode.USD.code,
        SharedPrefKeys.kLanguage: 'en',
        SharedPrefKeys.kNumberFormatPreset: NumberFormatPreset.dotDecimal.name,
      });
      final provider = await createProvider();
      await prefs.deleteSharedPrefsWithKey(SharedPrefKeys.kHasCheckedRegionDefaultFiat);
      // ignore: deprecated_member_use_from_same_package
      prefs.setSharedPreferencesForTest(_RefusingFiatWrites(prefs.sharedPrefs));

      await provider.changeFiat(FiatCode.KRW);

      expect(isChecked(prefs), isFalse);
      expect(savedFiat(prefs), FiatCode.USD.code);
    });

    test('설정에서 고른 통화는 플래그를 남겨, 앞서 플래그 저장이 실패했어도 보정이 바꾸지 않는다', () async {
      final prefs = await prefsWith({
        SharedPrefKeys.kSelectedFiat: FiatCode.USD.code,
        SharedPrefKeys.kLanguage: 'en',
        SharedPrefKeys.kNumberFormatPreset: NumberFormatPreset.dotDecimal.name,
      });
      final provider = await createProvider();
      await prefs.deleteSharedPrefsWithKey(SharedPrefKeys.kHasCheckedRegionDefaultFiat);

      await provider.changeFiat(FiatCode.KRW);

      expect(isChecked(prefs), isTrue);
      expect(await resolve(prefs, const Locale('en', 'US'), 'en'), FiatCode.KRW);
      expect(savedFiat(prefs), FiatCode.KRW.code);
    });
  });

  group('생성자', () {
    test('앱 언어를 정한 뒤(예전 코드 kr → ko) 통화를 확인하므로 KRW를 유지한다', () async {
      final prefs = await prefsWith({
        SharedPrefKeys.kSelectedFiat: FiatCode.KRW.code,
        SharedPrefKeys.kLanguage: 'kr',
        SharedPrefKeys.kNumberFormatPreset: NumberFormatPreset.dotDecimal.name,
      });

      final provider = await createProvider(systemLocale: const Locale('en', 'US'), timeZoneName: 'UTC');

      expect(provider.language, 'ko');
      expect(provider.selectedFiat, FiatCode.KRW);
      expect(savedFiat(prefs), FiatCode.KRW.code);
      expect(isChecked(prefs), isTrue);
    });

    test('받은 iOS 지역 설정과 시간대를 통화 결정에 넘긴다', () async {
      final cases = [('UTC', FiatCode.EUR), ('KST', FiatCode.KRW)];
      for (final (timeZoneName, expected) in cases) {
        final prefs = await prefsWith({
          SharedPrefKeys.kLanguage: 'en',
          SharedPrefKeys.kNumberFormatPreset: NumberFormatPreset.dotDecimal.name,
        });

        final provider = await createProvider(
          iosRegionCode: 'DE',
          systemLocale: const Locale('en', 'US'),
          timeZoneName: timeZoneName,
        );

        expect(provider.selectedFiat, expected);
        expect(savedFiat(prefs), expected.code);
      }
    });
  });

  test('비밀번호 초기화(keysToReset)는 통화와 확인 플래그를 지우지 않는다', () {
    expect(SharedPrefKeys.keysToReset, isNot(contains(SharedPrefKeys.kSelectedFiat)));
    expect(SharedPrefKeys.keysToReset, isNot(contains(SharedPrefKeys.kHasCheckedRegionDefaultFiat)));
  });
}
