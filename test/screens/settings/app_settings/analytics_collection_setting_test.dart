import 'dart:async';

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/constants/shared_pref_keys.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:coconut_wallet/screens/settings/app_settings/analytics_collection_setting.dart';
import 'package:coconut_wallet/services/analytics_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _PendingAnalyticsService extends AnalyticsService {
  _PendingAnalyticsService() : super(null);

  final completion = Completer<void>();
  int calls = 0;
  bool updating = false;

  @override
  bool get isUpdating => updating;

  @override
  Future<void> setCollectionEnabled(bool enabled) async {
    calls++;
    updating = true;
    notifyListeners();
    try {
      await completion.future;
    } finally {
      updating = false;
      notifyListeners();
    }
  }
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SharedPrefsRepository().init();
    LocaleSettings.setLocaleSync(AppLocale.ko);
  });

  Future<void> mount(WidgetTester tester, AnalyticsService service, {double textScale = 1}) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<AnalyticsService>.value(
        value: service,
        child: TranslationProvider(
          child: MaterialApp(
            theme: buildCoconutThemeData(),
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
              child: const Scaffold(body: AnalyticsCollectionSetting()),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('defaults on, toggles both ways without a dialog and restores the saved choice', (tester) async {
    final service = AnalyticsService(null);
    await service.initialize();
    await mount(tester, service);
    expect(tester.widget<CoconutSwitch>(find.byType(CoconutSwitch)).isOn, isTrue);

    await tester.tap(find.byType(CoconutSwitch));
    await tester.pumpAndSettle();
    expect(tester.widget<CoconutSwitch>(find.byType(CoconutSwitch)).isOn, isFalse);
    expect(SharedPrefsRepository().getBool(SharedPrefKeys.kAnalyticsCollectionEnabled), isFalse);
    expect(find.byType(AlertDialog), findsNothing);

    final restored = AnalyticsService(null);
    await restored.initialize();
    await mount(tester, restored);
    expect(tester.widget<CoconutSwitch>(find.byType(CoconutSwitch)).isOn, isFalse);
    await tester.tap(find.byType(CoconutSwitch));
    await tester.pumpAndSettle();
    expect(SharedPrefsRepository().getBool(SharedPrefKeys.kAnalyticsCollectionEnabled), isTrue);
    await tester.pumpWidget(const SizedBox());
    service.dispose();
    restored.dispose();
  });

  testWidgets('updates the visible copy when the app language changes', (tester) async {
    final service = AnalyticsService(null);
    await service.initialize();
    await mount(tester, service);
    expect(find.text('앱 사용 익명 통계 수집'), findsOneWidget);

    LocaleSettings.setLocaleSync(AppLocale.en);
    await tester.pumpAndSettle();
    expect(find.text('Anonymous app usage statistics'), findsOneWidget);
    expect(find.text('앱 사용 익명 통계 수집'), findsNothing);

    LocaleSettings.setLocaleSync(AppLocale.ko);
    await tester.pumpAndSettle();
    expect(find.text('앱 사용 익명 통계 수집'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    service.dispose();
  });

  testWidgets('blocks repeated taps while saving and reports failure without a consent dialog', (tester) async {
    final service = _PendingAnalyticsService();
    await mount(tester, service);
    await tester.tap(find.byType(CoconutSwitch));
    await tester.pump();
    expect(service.calls, 1);
    await tester.tapAt(tester.getCenter(find.byType(CoconutSwitch)));
    await tester.pump();
    expect(service.calls, 1);
    service.completion.completeError(StateError('test failure'));
    await tester.pumpAndSettle();
    expect(find.text(t.settings_screen.analytics_collection_error), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CoconutSwitch));
    await tester.pumpAndSettle();
    expect(service.calls, 2);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    service.dispose();
  });

  for (final locale in AppLocale.values) {
    testWidgets('renders ${locale.languageCode} on a narrow screen with large text', (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      LocaleSettings.setLocaleSync(locale);
      final service = AnalyticsService(null);
      await service.initialize();
      await mount(tester, service, textScale: 2);
      expect(find.text(t.settings_screen.analytics_collection), findsOneWidget);
      expect(find.text(t.settings_screen.analytics_collection_description), findsOneWidget);
      expect(tester.takeException(), isNull);
      final semantics = tester.ensureSemantics();
      expect(find.bySemanticsLabel(t.settings_screen.analytics_collection), findsWidgets);
      semantics.dispose();
      await tester.pumpWidget(const SizedBox());
      service.dispose();
    });
  }
}
