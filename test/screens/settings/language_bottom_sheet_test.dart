import 'dart:async';

import 'package:coconut_wallet/config/number_format_config.dart';
import 'package:coconut_wallet/constants/shared_pref_keys.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/enums/number_format_preset.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/feature/feature_navigation_target.dart';
import 'package:coconut_wallet/providers/auth_provider.dart';
import 'package:coconut_wallet/providers/preferences/block_explorer_provider.dart';
import 'package:coconut_wallet/providers/preferences/electrum_server_provider.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/repository/realm/wallet_preferences_repository.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:coconut_wallet/screens/settings/app_settings/app_settings_screen.dart';
import 'package:coconut_wallet/screens/settings/language_bottom_sheet.dart';
import 'package:coconut_wallet/services/analytics_service.dart';
import 'package:coconut_wallet/widgets/common/bottom_sheet/selectable_settings_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
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

class _Auth extends ChangeNotifier implements AuthProvider {
  @override
  bool get isSetPin => false;
  @override
  bool get canCheckBiometrics => false;
  @override
  bool get isSetBiometrics => false;
  @override
  Future<bool> isDevicePasscodeSet() async => true;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late SharedPrefsRepository prefs;

  /// 저장된 언어가 [language]인 실제 PreferenceProvider. 통화와 숫자 형식은 저장값을 둬서 언어만 본다.
  Future<PreferenceProvider> createProvider(String language) async {
    SharedPreferences.setMockInitialValues({
      SharedPrefKeys.kLanguage: language,
      SharedPrefKeys.kSelectedFiat: FiatCode.KRW.code,
      SharedPrefKeys.kHasCheckedRegionDefaultFiat: true,
      SharedPrefKeys.kNumberFormatPreset: NumberFormatPreset.dotDecimal.name,
    });
    // ignore: deprecated_member_use_from_same_package
    prefs = SharedPrefsRepository()..setSharedPreferencesForTest(await SharedPreferences.getInstance());
    final electrum = ElectrumServerProvider();
    final explorer = BlockExplorerProvider();
    final provider = PreferenceProvider(
      _WalletPreferences(),
      electrum,
      explorer,
      systemLocale: const Locale('ko', 'KR'),
      timeZoneName: 'KST',
    );
    addTearDown(() {
      provider.dispose();
      electrum.dispose();
      explorer.dispose();
      NumberFormatConfig.instance.applyPreset(NumberFormatPreset.dotDecimal);
      LocaleSettings.setLocaleSync(AppLocale.ko);
    });
    return provider;
  }

  /// 설정 화면이 여는 것과 같은 경로(`AppSettingsScreen.open`)로 언어 시트를 연다.
  Future<void> openSheet(
    WidgetTester tester,
    PreferenceProvider provider, {
    Size size = const Size(390, 844),
    double scale = 1,
  }) async {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ChangeNotifierProvider<PreferenceProvider>.value(
        value: provider,
        child: MaterialApp(
          theme: buildCoconutThemeData(),
          builder:
              (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
          home: Scaffold(
            body: Builder(
              builder:
                  (context) => TextButton(
                    onPressed: () => unawaited(AppSettingsScreen.open(context, AppSettingsTarget.language)),
                    child: const Text('open'),
                  ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(LanguageBottomSheet), findsOneWidget);
  }

  List<SelectableSettingsRow> rows(WidgetTester tester) =>
      tester.widgetList<SelectableSettingsRow>(find.byType(SelectableSettingsRow, skipOffstage: false)).toList();

  testWidgets('언어 시트: 여섯 언어가 자기 말 이름으로 나오고 태국어가 맨 끝이다', (tester) async {
    final provider = await createProvider('ko');
    // 여섯 줄이 스크롤 없이 다 들어오는 긴 화면에서 연다
    await openSheet(tester, provider, size: const Size(390, 1600));

    expect(rows(tester).map((row) => row.title).toList(), ['한국어', 'English', '日本語', 'Español', 'Deutsch', 'ไทย']);
    expect(rows(tester).where((row) => row.isSelected).map((row) => row.title), ['한국어']);
  });

  testWidgets('ไทย를 누르면 앱 언어와 번역이 태국어로 바뀌고 저장된다', (tester) async {
    final provider = await createProvider('ko');
    await openSheet(tester, provider, size: const Size(390, 1600));

    await tester.tap(find.text('ไทย'));
    await tester.pumpAndSettle();

    expect(provider.language, 'th');
    expect(LocaleSettings.currentLocale, AppLocale.th);
    expect(prefs.getString(SharedPrefKeys.kLanguage), 'th');
    expect(rows(tester).where((row) => row.isSelected).map((row) => row.title), ['ไทย']);
    // 통화와 숫자 형식은 언어를 따라 바뀌지 않는다
    expect(provider.selectedFiat, FiatCode.KRW);
    expect(provider.numberFormatPreset, NumberFormatPreset.dotDecimal);
    expect(tester.takeException(), isNull);
  });

  // 시트 높이는 화면의 0.6이라 작은 화면에서 글자를 키우면 여섯 줄이 다 들어오지 않는다. 마지막 줄까지 내려가 눌려야 한다
  for (final scale in [1.0, 2.0]) {
    testWidgets('320×568, 글자 ${scale}x: 마지막 줄 ไทย까지 스크롤해서 고를 수 있다', (tester) async {
      final provider = await createProvider('ko');
      await openSheet(tester, provider, size: const Size(320, 568), scale: scale);

      final thai = find.text('ไทย');
      await tester.scrollUntilVisible(
        thai,
        60,
        scrollable: find.descendant(of: find.byType(LanguageBottomSheet), matching: find.byType(Scrollable)),
      );
      await tester.pumpAndSettle();
      final row = tester.getRect(find.ancestor(of: thai, matching: find.byType(SelectableSettingsRow)));
      expect(row.top, greaterThanOrEqualTo(568 * 0.4 - 0.5), reason: '시트 안');
      expect(row.bottom, lessThanOrEqualTo(568 + 0.5), reason: '화면 안');

      await tester.tap(thai);
      await tester.pumpAndSettle();

      expect(provider.language, 'th');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('설정 화면의 언어 줄은 지금 언어의 이름을 보여 준다: 태국어면 ไทย', (tester) async {
    final provider = await createProvider('th');
    tester.view
      ..physicalSize = const Size(390, 3000)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<PreferenceProvider>.value(value: provider),
          ChangeNotifierProvider<AuthProvider>.value(value: _Auth()),
          Provider<AnalyticsService>(create: (_) => AnalyticsService(null, true)),
        ],
        child: MaterialApp(theme: buildCoconutThemeData(), home: const AppSettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(LocaleSettings.currentLocale, AppLocale.th);
    expect(find.text(t.settings_screen.language), findsOneWidget);
    expect(find.text('ไทย'), findsOneWidget);
  });
}
