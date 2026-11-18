import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/screens/settings/fiat_bottom_sheet.dart';
import 'package:coconut_wallet/widgets/common/bottom_sheet/selectable_settings_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _Preferences extends Fake with ChangeNotifier implements PreferenceProvider {
  _Preferences(this.selectedFiat);

  @override
  FiatCode selectedFiat;
  final changes = <FiatCode>[];

  @override
  Future<void> changeFiat(FiatCode fiatCode) async {
    changes.add(fiatCode);
    selectedFiat = fiatCode;
    notifyListeners();
  }
}

void main() {
  setUp(() => LocaleSettings.setLocaleSync(AppLocale.ko));

  testWidgets('설정 통화 시트: 44개가 두 묶음으로 나오고, CoinGecko 통화를 누르면 앱 통화가 바뀐다', (tester) async {
    // 44줄이 한 화면에 다 들어오게 긴 화면에서 연다(스크롤 없이 모든 줄을 본다)
    tester.view
      ..physicalSize = const Size(400, 5000)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final preferences = _Preferences(FiatCode.KRW);
    await tester.pumpWidget(
      ChangeNotifierProvider<PreferenceProvider>.value(
        value: preferences,
        child: MaterialApp(
          theme: buildCoconutThemeData(),
          home: Scaffold(body: FiatBottomSheet(scrollController: ScrollController())),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final rows = tester.widgetList<SelectableSettingsRow>(find.byType(SelectableSettingsRow)).toList();
    expect(rows.map((row) => row.title).toList(), [for (final fiat in FiatCode.values) fiat.code]);
    expect(find.text(t.fiat_bottom_sheet.exchange_section), findsOneWidget);
    expect(find.text(t.fiat_bottom_sheet.coingecko_price), findsOneWidget);
    expect(rows.firstWhere((row) => row.title == 'KRW').subtitle, '대한민국 원 · ${t.fiat_bottom_sheet.krw_price}');
    expect(rows.firstWhere((row) => row.title == 'THB').subtitle, '태국 바트');
    expect(rows.where((row) => row.isSelected).map((row) => row.title), ['KRW']);

    await tester.tap(find.text('THB'));
    await tester.pumpAndSettle();
    expect(preferences.changes, [FiatCode.THB]);
    final after = tester.widgetList<SelectableSettingsRow>(find.byType(SelectableSettingsRow));
    expect(after.where((row) => row.isSelected).map((row) => row.title), ['THB']);
    expect(tester.takeException(), isNull);
  });

  test('통화 수: 전체 44, 거래소 4, CoinGecko 40', () {
    expect(FiatCode.values, hasLength(44));
    expect(FiatCode.values.where((fiat) => fiat.hasExchangeSource), hasLength(4));
    expect(FiatCode.values.where((fiat) => !fiat.hasExchangeSource), hasLength(40));
    expect(FiatCode.values.map((fiat) => fiat.code).toSet(), hasLength(44));
    expect(kFiatQuickAddAmounts.keys.toSet(), FiatCode.values.toSet());
  });

  test('통화 이름: 모든 언어에 44개 통화의 이름이 있다', () {
    final missing = <String>[];
    for (final locale in AppLocale.values) {
      LocaleSettings.setLocaleSync(locale);
      for (final fiat in FiatCode.values) {
        final name = t.fiat_names[fiat.code];
        if (name == null || name.trim().isEmpty) missing.add('${locale.languageCode}:${fiat.code}');
      }
    }
    LocaleSettings.setLocaleSync(AppLocale.ko);
    expect(missing, isEmpty);
  });
}
