import 'package:coconut_wallet/ccos/ccos_feature_runtime.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/screens/settings/theme_bottom_sheet.dart';
import 'package:coconut_wallet/widgets/common/bottom_sheet/deletable_settings_row.dart';
import 'package:coconut_wallet/widgets/common/bottom_sheet/selectable_settings_row.dart';
import 'package:coconut_wallet/widgets/common/overlays/common_bottom_sheets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _Preferences extends Fake with ChangeNotifier implements PreferenceProvider {
  bool activated = false;

  @override
  CoconutThemeVariant themeVariant = CoconutThemeVariant.dark;

  @override
  bool get shouldShowOpenStoreIntroCard => !activated;

  @override
  CcosFeatureAvailability getCcosFeatureAvailability(String id) => CcosFeatureAvailability(
    featureId: id,
    isVisible: activated,
    isActivated: activated,
    isEntitled: true,
    isAvailable: activated,
  );

  @override
  Future<void> changeThemeVariant(CoconutThemeVariant variant) async {
    themeVariant = variant;
    notifyListeners();
  }

  void activateTheme() {
    activated = true;
    notifyListeners();
  }
}

Future<_Preferences> _openSheet(WidgetTester tester, Size size, double bottom, {double scale = 1}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  LocaleSettings.setLocaleSync(AppLocale.ko);
  final preferences = _Preferences();
  await tester.pumpWidget(
    ChangeNotifierProvider<PreferenceProvider>.value(
      value: preferences,
      child: MaterialApp(
        theme: buildCoconutThemeData(),
        builder:
            (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                padding: EdgeInsets.only(bottom: bottom),
                viewPadding: EdgeInsets.only(bottom: bottom),
                textScaler: TextScaler.linear(scale),
              ),
              child: child!,
            ),
        home: Scaffold(
          body: Builder(
            builder:
                (context) => TextButton(
                  onPressed:
                      () => CommonBottomSheets.showBottomSheet_100(
                        context: context,
                        screenName: 'theme-layout-test',
                        isDismissible: true,
                        backgroundColor: Colors.transparent,
                        child: const ThemeBottomSheet(),
                      ),
                  child: const Text('Open'),
                ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
  return preferences;
}

void _expectBottomGap(WidgetTester tester, Finder lastRow, double bottom) {
  final sheet = tester.getRect(find.byType(ThemeBottomSheet));
  final row = tester.getRect(lastRow);
  expect(sheet.bottom - row.bottom, closeTo(bottom + 16, 0.1));
  expect(row.top, greaterThanOrEqualTo(sheet.top));
  expect(tester.takeException(), isNull);
}

void main() {
  setUpAll(() async {
    final font = FontLoader('Pretendard')..addFont(rootBundle.load('assets/fonts/Pretendard-Regular.ttf'));
    await font.load();
  });

  for (final size in [const Size(344, 882), const Size(414, 896)]) {
    testWidgets('sheet fits intro and dynamically fits three themes at ${size.width}', (tester) async {
      final bottom = size.width == 344 ? 24.0 : 34.0;
      final preferences = await _openSheet(tester, size, bottom);
      final lightRow = find.ancestor(of: find.text(t.theme_light), matching: find.byType(SelectableSettingsRow));
      _expectBottomGap(tester, lightRow, bottom);
      await tester.tap(lightRow);
      await tester.pump();
      expect(preferences.themeVariant, CoconutThemeVariant.light);
      final introHeight = tester.getSize(find.byType(ThemeBottomSheet)).height;

      preferences.activateTheme();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      final coconutRow = find.byType(DeletableSettingsRow);
      _expectBottomGap(tester, coconutRow, bottom);
      expect(tester.getSize(find.byType(ThemeBottomSheet)).height, lessThan(introHeight));
      await tester.tap(coconutRow);
      await tester.pump();
      expect(preferences.themeVariant, CoconutThemeVariant.coconutTheme);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('short viewport and large text keep the final theme reachable by scrolling', (tester) async {
    final preferences = await _openSheet(tester, const Size(320, 400), 24, scale: 1.6);
    final scrollable = tester.state<ScrollableState>(
      find.descendant(of: find.byType(ListView), matching: find.byType(Scrollable)),
    );
    expect(scrollable.position.maxScrollExtent, greaterThan(0));
    await tester.drag(find.byType(ListView), const Offset(0, -1000));
    await tester.pump(const Duration(seconds: 1));
    final lightRow = find.ancestor(of: find.text(t.theme_light), matching: find.byType(SelectableSettingsRow));
    _expectBottomGap(tester, lightRow, 24);
    await tester.tap(lightRow);
    await tester.pump();
    expect(preferences.themeVariant, CoconutThemeVariant.light);
    await tester.pumpWidget(const SizedBox());
  });
}
