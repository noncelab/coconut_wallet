import 'dart:async';

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/constants/shared_pref_keys.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/view_model/settings/analytics_collection_setting_view_model.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:coconut_wallet/screens/settings/app_settings/analytics_collection_setting.dart';
import 'package:coconut_wallet/services/analytics_service.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _PendingAnalyticsService extends AnalyticsService {
  _PendingAnalyticsService() : super(null, false);

  final completion = Completer<void>();
  int calls = 0;

  @override
  Future<void> setCollectionEnabled(bool enabled) async {
    calls++;
    await completion.future;
  }
}

/// SDK 켜기/끄기를 원하는 방향만 실패시키는 가짜. 실제 Firebase로 아무것도 보내지 않는다.
class _FlakySdk extends Fake implements FirebaseAnalytics {
  bool? failing;
  Completer<void>? enableGate;
  final calls = <bool>[];

  @override
  Future<void> setAnalyticsCollectionEnabled(bool enabled) async {
    calls.add(enabled);
    if (enabled) await enableGate?.future;
    if (enabled == failing) throw StateError('SDK $enabled failed');
  }

  @override
  Future<void> setDefaultEventParameters(Map<String, Object?>? defaultParameters) async {}
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SharedPrefsRepository().init();
    LocaleSettings.setLocaleSync(AppLocale.ko);
  });

  Future<AnalyticsService> gatedService(_FlakySdk sdk) async {
    await SharedPrefsRepository().setBool(SharedPrefKeys.kAnalyticsCollectionEnabled, false);
    final service = AnalyticsService(
      sdk,
      false,
      commonParametersLoader: () async => const <String, Object>{'app_version': 'test'},
    );
    await service.initialize();
    sdk.enableGate = Completer<void>();
    return service;
  }

  Future<void> mount(
    WidgetTester tester,
    AnalyticsService service, {
    double textScale = 1,
    Widget body = const AnalyticsCollectionSetting(),
  }) async {
    await tester.pumpWidget(
      Provider<AnalyticsService>.value(
        value: service,
        child: TranslationProvider(
          child: MaterialApp(
            theme: buildCoconutThemeData(),
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
              child: Scaffold(body: body),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('defaults on, toggles both ways without a dialog and restores the saved choice', (tester) async {
    final service = AnalyticsService(null, false);
    await service.initialize();
    await mount(tester, service);
    expect(tester.widget<CoconutSwitch>(find.byType(CoconutSwitch)).isOn, isTrue);

    await tester.tap(find.byType(CoconutSwitch));
    await tester.pumpAndSettle();
    expect(tester.widget<CoconutSwitch>(find.byType(CoconutSwitch)).isOn, isFalse);
    expect(SharedPrefsRepository().getBool(SharedPrefKeys.kAnalyticsCollectionEnabled), isFalse);
    expect(find.byType(AlertDialog), findsNothing);

    final restored = AnalyticsService(null, false);
    await restored.initialize();
    await mount(tester, restored);
    expect(tester.widget<CoconutSwitch>(find.byType(CoconutSwitch)).isOn, isFalse);
    await tester.tap(find.byType(CoconutSwitch));
    await tester.pumpAndSettle();
    expect(SharedPrefsRepository().getBool(SharedPrefKeys.kAnalyticsCollectionEnabled), isTrue);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('updates the visible copy when the app language changes', (tester) async {
    final service = AnalyticsService(null, false);
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
  });

  for (final target in [true, false]) {
    testWidgets('failed ${target ? 'ON' : 'OFF'} keeps the switch and the same tap retries it', (tester) async {
      await SharedPrefsRepository().setBool(SharedPrefKeys.kAnalyticsCollectionEnabled, !target);
      final sdk = _FlakySdk();
      final service = AnalyticsService(
        sdk,
        false,
        commonParametersLoader: () async => const <String, Object>{'app_version': 'test'},
      );
      await service.initialize();
      await mount(tester, service);
      bool isOn() => tester.widget<CoconutSwitch>(find.byType(CoconutSwitch)).isOn;
      expect(isOn(), !target);

      sdk.failing = target;
      await tester.tap(find.byType(CoconutSwitch));
      await tester.pumpAndSettle();
      expect(find.text(t.settings_screen.analytics_collection_error), findsOneWidget);
      expect(isOn(), !target);
      expect(service.canCollect, isFalse);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();

      sdk.failing = null;
      sdk.calls.clear();
      await tester.tap(find.byType(CoconutSwitch));
      await tester.pumpAndSettle();
      expect(sdk.calls, [target]);
      expect(isOn(), target);
      expect(service.canCollect, target);
      expect(SharedPrefsRepository().getBool(SharedPrefKeys.kAnalyticsCollectionEnabled), target);
      expect(find.text(t.settings_screen.analytics_collection_error), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });
  }

  test('a second call while saving keeps the first call busy until it settles', () async {
    final sdk = _FlakySdk();
    final viewModel = AnalyticsCollectionSettingViewModel(await gatedService(sdk));

    final first = viewModel.setCollectionEnabled(true);
    expect(await viewModel.setCollectionEnabled(true), isTrue);
    expect(viewModel.isSaving, isTrue);

    sdk.enableGate!.complete();
    expect(await first, isTrue);
    expect(viewModel.isSaving, isFalse);
    expect(sdk.calls.where((enabled) => enabled), hasLength(1));
    viewModel.dispose();
  });

  testWidgets('leaving the screen while saving neither notifies a disposed row nor shows a toast', (tester) async {
    final sdk = _FlakySdk()..failing = true;
    final service = await gatedService(sdk);
    await mount(tester, service);
    await tester.tap(find.byType(CoconutSwitch));
    await tester.pump();

    await tester.pumpWidget(const SizedBox());
    sdk.enableGate!.complete();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text(t.settings_screen.analytics_collection_error), findsNothing);
    expect(service.isCollectionEnabled, isFalse);
  });

  testWidgets('a second settings row cannot start another change while one is pending', (tester) async {
    final sdk = _FlakySdk();
    final service = await gatedService(sdk);
    await mount(
      tester,
      service,
      body: const Column(children: [AnalyticsCollectionSetting(), AnalyticsCollectionSetting()]),
    );
    final switches = find.byType(CoconutSwitch);
    await tester.tap(switches.first);
    await tester.pump();

    await tester.tap(switches.last);
    await tester.pumpAndSettle();
    expect(find.text(t.settings_screen.analytics_collection_error), findsOneWidget);
    sdk.enableGate!.complete();
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    expect(sdk.calls.where((enabled) => enabled), hasLength(1));
    expect(tester.widgetList<CoconutSwitch>(switches).map((s) => s.isOn), [true, true]);
    await tester.pumpWidget(const SizedBox());
  });

  for (final locale in AppLocale.values) {
    testWidgets('renders ${locale.languageCode} on a narrow screen with large text', (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      LocaleSettings.setLocaleSync(locale);
      final service = AnalyticsService(null, false);
      await service.initialize();
      await mount(tester, service, textScale: 2);
      expect(find.text(t.settings_screen.analytics_collection), findsOneWidget);
      expect(find.text(t.settings_screen.analytics_collection_description), findsOneWidget);
      expect(tester.takeException(), isNull);
      final semantics = tester.ensureSemantics();
      expect(find.bySemanticsLabel(t.settings_screen.analytics_collection), findsWidgets);
      semantics.dispose();
      await tester.pumpWidget(const SizedBox());
    });
  }
}
