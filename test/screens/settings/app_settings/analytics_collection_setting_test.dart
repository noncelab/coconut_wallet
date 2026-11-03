import 'dart:async';
import 'dart:ui' show SemanticsAction;

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/constants/shared_pref_keys.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/view_model/settings/analytics_collection_setting_view_model.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:coconut_wallet/screens/settings/app_settings/analytics_collection_setting.dart';
import 'package:coconut_wallet/services/analytics_service.dart';
import 'package:coconut_wallet/widgets/common/buttons/button_group.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  Completer<void>? disableGate;
  bool failNextDisable = false;
  final calls = <bool>[];

  @override
  Future<void> setAnalyticsCollectionEnabled(bool enabled) async {
    calls.add(enabled);
    if (enabled) await enableGate?.future;
    if (!enabled) await disableGate?.future;
    if (!enabled && failNextDisable) {
      failNextDisable = false;
      throw StateError('one-shot disable failure');
    }
    if (enabled == failing) throw StateError('SDK $enabled failed');
  }

  @override
  Future<void> setDefaultEventParameters(Map<String, Object?>? defaultParameters) async {}
}

class _FailingOffPreferences extends Fake implements SharedPreferences {
  bool choice = true;
  bool failOff = true;

  @override
  bool containsKey(String key) => key == SharedPrefKeys.kAnalyticsCollectionEnabled;

  @override
  bool? getBool(String key) => key == SharedPrefKeys.kAnalyticsCollectionEnabled ? choice : null;

  @override
  Future<bool> setBool(String key, bool value) async {
    if (!value && failOff) return false;
    choice = value;
    return true;
  }
}

void main() {
  setUpAll(() async {
    for (final family in ['Pretendard', 'SpaceGrotesk']) {
      await (FontLoader(family)
            ..addFont(rootBundle.load('assets/fonts/$family-Regular.ttf'))
            ..addFont(rootBundle.load('assets/fonts/$family-Bold.ttf')))
          .load();
    }
  });

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

  testWidgets('deferred native failure stays OFF across reentry and retries false without activation', (tester) async {
    await SharedPrefsRepository().setAnalyticsCollectionEnabled(false);
    var failDisable = true;
    var activations = 0;
    var disables = 0;
    final service = AnalyticsService(
      null,
      false,
      deferredBackend: DeferredAnalyticsBackend(
        activate: () async {
          activations++;
          return _FlakySdk();
        },
        disableIfActive: () async {
          disables++;
          if (failDisable) throw StateError('native process is still active');
        },
      ),
    );
    await service.initialize();
    await mount(tester, service);
    await tester.pumpAndSettle();
    expect(tester.widget<CoconutSwitch>(find.byType(CoconutSwitch)).isOn, isFalse);
    expect(find.text('끄기 재시도'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await mount(tester, service);
    await tester.pumpAndSettle();
    expect(find.text('끄기 재시도'), findsOneWidget);
    failDisable = false;
    await tester.tap(find.text('끄기 재시도'));
    await tester.pumpAndSettle();
    expect(activations, 0);
    expect(disables, 3);
    expect(service.canCollect, isFalse);
    expect(find.text('끄기 재시도'), findsNothing);
    expect(tester.widget<CoconutSwitch>(find.byType(CoconutSwitch)).isOn, isFalse);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('component failure before OFF storage survives disposal and exposes only a safe false retry', (
    tester,
  ) async {
    final sdk = _FlakySdk();
    final gateWait = Completer<void>();
    var failComponents = false;
    var offAttempts = 0;
    final service = AnalyticsService(
      sdk,
      false,
      commonParametersLoader: () async => const <String, Object>{},
      setComponentsEnabled: (enabled) async {
        if (enabled) return;
        offAttempts++;
        if (offAttempts == 1) await gateWait.future;
        if (failComponents) throw StateError('PM refused component update');
      },
    );
    await service.initialize();
    sdk.calls.clear();
    failComponents = true;
    await mount(tester, service);
    await tester.tap(find.byType(CoconutSwitch));
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    await mount(tester, service);
    final pointer = find.ancestor(of: find.byType(CoconutSwitch), matching: find.byType(IgnorePointer)).first;
    expect(tester.widget<IgnorePointer>(pointer).ignoring, isTrue);
    gateWait.complete();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(sdk.calls, [false, false]);
    expect(SharedPrefsRepository().getBool(SharedPrefKeys.kAnalyticsCollectionEnabled), isFalse);
    expect(tester.widget<CoconutSwitch>(find.byType(CoconutSwitch)).isOn, isFalse);
    expect(find.text('끄기 재시도'), findsOneWidget);
    failComponents = false;
    sdk.calls.clear();
    await tester.tap(find.text('끄기 재시도'));
    await tester.pumpAndSettle();
    expect(sdk.calls, [false]);
    expect(offAttempts, 3);
    expect(find.text('끄기 재시도'), findsNothing);
    expect(service.canCollect, isFalse);
    await tester.pumpWidget(const SizedBox());
  });

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
    testWidgets('failed ${target ? 'ON' : 'OFF'} shows the saved choice and retries the explicit target', (
      tester,
    ) async {
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
      expect(isOn(), isFalse);
      expect(service.canCollect, isFalse);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();

      sdk.failing = null;
      sdk.calls.clear();
      await tester.tap(target ? find.byType(CoconutSwitch) : find.text('끄기 재시도'));
      await tester.pumpAndSettle();
      expect(sdk.calls, [target]);
      expect(isOn(), target);
      expect(service.canCollect, target);
      expect(SharedPrefsRepository().getBool(SharedPrefKeys.kAnalyticsCollectionEnabled), target);
      expect(find.text(t.settings_screen.analytics_collection_error), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('saved OFF and its explicit disable retry survive leaving and re-entering settings', (tester) async {
    final sdk = _FlakySdk();
    final service = AnalyticsService(
      sdk,
      false,
      commonParametersLoader: () async => const <String, Object>{'app_version': 'test'},
    );
    await service.initialize();
    sdk.failing = false;
    await expectLater(service.setCollectionEnabled(false), throwsStateError);

    await mount(tester, service);
    expect(find.text('끄기 재시도'), findsOneWidget);
    expect(tester.widget<CoconutSwitch>(find.byType(CoconutSwitch)).isOn, isFalse);
    await tester.pumpWidget(const SizedBox());
    await mount(tester, service);
    expect(find.text('끄기 재시도'), findsOneWidget);

    sdk.failing = null;
    sdk.calls.clear();
    await tester.tap(find.text('끄기 재시도'));
    await tester.pumpAndSettle();
    expect(sdk.calls, [false]);
    expect(find.text('끄기 재시도'), findsNothing);
    expect(tester.widget<CoconutSwitch>(find.byType(CoconutSwitch)).isOn, isFalse);
    expect(SharedPrefsRepository().getBool(SharedPrefKeys.kAnalyticsCollectionEnabled), isFalse);
    expect(service.canCollect, isFalse);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('re-entering settings while saving keeps the new row disabled', (tester) async {
    final sdk = _FlakySdk();
    final service = await gatedService(sdk);
    await mount(tester, service);
    await tester.tap(find.byType(CoconutSwitch));
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    await mount(tester, service);

    final pointer = find.ancestor(of: find.byType(CoconutSwitch), matching: find.byType(IgnorePointer)).first;
    expect(tester.widget<IgnorePointer>(pointer).ignoring, isTrue);
    await tester.tapAt(tester.getCenter(find.byType(CoconutSwitch)));
    await tester.pump();
    expect(find.text(t.settings_screen.analytics_collection_error), findsNothing);
    sdk.enableGate!.complete();
    await tester.pumpAndSettle();
    expect(sdk.calls.where((enabled) => enabled), [true]);
    expect(tester.widget<CoconutSwitch>(find.byType(CoconutSwitch)).isOn, isTrue);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('repeated disable retries and switch taps cannot turn collection on during the retry', (tester) async {
    final sdk = _FlakySdk();
    final service = AnalyticsService(
      sdk,
      false,
      commonParametersLoader: () async => const <String, Object>{'app_version': 'test'},
    );
    await service.initialize();
    sdk.failing = false;
    await expectLater(service.setCollectionEnabled(false), throwsStateError);
    await mount(tester, service);
    sdk.failing = null;
    sdk.disableGate = Completer<void>();
    sdk.calls.clear();

    await tester.tap(find.text('끄기 재시도'));
    await tester.pump();
    await tester.tapAt(tester.getCenter(find.text('끄기 재시도')));
    await tester.tapAt(tester.getCenter(find.byType(CoconutSwitch)));
    await tester.pump();
    expect(sdk.calls, [false]);
    expect(service.collectionStatusListenable.value.isUpdating, isTrue);
    expect(SharedPrefsRepository().getBool(SharedPrefKeys.kAnalyticsCollectionEnabled), isFalse);
    sdk.disableGate!.complete();
    await tester.pumpAndSettle();

    expect(sdk.calls, [false]);
    expect(tester.widget<CoconutSwitch>(find.byType(CoconutSwitch)).isOn, isFalse);
    expect(find.text('끄기 재시도'), findsNothing);
    expect(find.text(t.settings_screen.analytics_collection_error), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('pending saved OFF locks the switch so a mistaken retry cannot opt in', (tester) async {
    final sdk = _FlakySdk();
    final service = AnalyticsService(
      sdk,
      false,
      commonParametersLoader: () async => const <String, Object>{'app_version': 'test'},
    );
    await service.initialize();
    sdk.failing = false;
    await expectLater(service.setCollectionEnabled(false), throwsStateError);
    await mount(tester, service);
    sdk.calls.clear();

    await tester.tapAt(tester.getCenter(find.byType(CoconutSwitch)));
    await tester.pumpAndSettle();

    expect(sdk.calls, isEmpty);
    expect(SharedPrefsRepository().getBool(SharedPrefKeys.kAnalyticsCollectionEnabled), isFalse);
    expect(tester.widget<CoconutSwitch>(find.byType(CoconutSwitch)).isOn, isFalse);
    expect(find.text('끄기 재시도'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a recovered OFF failure has no retry toast beside the unlocked OFF switch', (tester) async {
    final sdk = _FlakySdk();
    final service = AnalyticsService(
      sdk,
      false,
      commonParametersLoader: () async => const <String, Object>{'app_version': 'test'},
    );
    await service.initialize();
    await mount(tester, service);
    sdk.failNextDisable = true;

    await tester.tap(find.byType(CoconutSwitch));
    await tester.pumpAndSettle();

    expect(find.text(t.settings_screen.analytics_collection_error), findsNothing);
    expect(find.text('끄기 재시도'), findsNothing);
    expect(tester.widget<CoconutSwitch>(find.byType(CoconutSwitch)).isOn, isFalse);
    expect(SharedPrefsRepository().getBool(SharedPrefKeys.kAnalyticsCollectionEnabled), isFalse);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('startup saved ON failure shows a neutral error without a turn-off retry or switch lock', (tester) async {
    final sdk = _FlakySdk()..failing = false;
    final service = AnalyticsService(sdk, false);
    await service.initialize();
    await mount(tester, service);

    expect(tester.widget<CoconutSwitch>(find.byType(CoconutSwitch)).isOn, isTrue);
    expect(find.text(t.settings_screen.analytics_collection_apply_error), findsOneWidget);
    expect(find.text('끄기 재시도'), findsNothing);
    final pointer = find.ancestor(of: find.byType(CoconutSwitch), matching: find.byType(IgnorePointer)).first;
    expect(tester.widget<IgnorePointer>(pointer).ignoring, isFalse);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('OFF storage failure shows saved ON and a switch tap safely retries OFF', (tester) async {
    final preferences = _FailingOffPreferences();
    // ignore: deprecated_member_use_from_same_package
    SharedPrefsRepository().setSharedPreferencesForTest(preferences);
    final service = AnalyticsService(null, true);
    await service.initialize();
    await mount(tester, service);

    await tester.tap(find.byType(CoconutSwitch));
    await tester.pumpAndSettle();
    expect(tester.widget<CoconutSwitch>(find.byType(CoconutSwitch)).isOn, isTrue);
    expect(preferences.choice, isTrue);
    expect(find.text('끄기 재시도'), findsOneWidget);
    expect(service.canCollect, isFalse);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    preferences.failOff = false;
    await tester.tap(find.byType(CoconutSwitch));
    await tester.pumpAndSettle();
    expect(preferences.choice, isFalse);
    expect(tester.widget<CoconutSwitch>(find.byType(CoconutSwitch)).isOn, isFalse);
    expect(find.text('끄기 재시도'), findsNothing);
    expect(service.canCollect, isFalse);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('leaving during failed disable preserves its saved OFF and retry without a disposed notification', (
    tester,
  ) async {
    final sdk = _FlakySdk();
    final service = AnalyticsService(
      sdk,
      false,
      commonParametersLoader: () async => const <String, Object>{'app_version': 'test'},
    );
    await service.initialize();
    sdk.disableGate = Completer<void>();
    sdk.failing = false;
    await mount(tester, service);
    await tester.tap(find.byType(CoconutSwitch));
    await tester.pump();
    expect(tester.widget<CoconutSwitch>(find.byType(CoconutSwitch)).isOn, isFalse);
    await tester.pumpWidget(const SizedBox());
    sdk.disableGate!.complete();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await mount(tester, service);
    expect(tester.widget<CoconutSwitch>(find.byType(CoconutSwitch)).isOn, isFalse);
    expect(find.text('끄기 재시도'), findsOneWidget);
    expect(find.text(t.settings_screen.analytics_collection_error), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  for (final locale in AppLocale.values) {
    testWidgets('persistent disable error and retry remain readable in ${locale.languageCode} at 320px x2', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      LocaleSettings.setLocaleSync(locale);
      final sdk = _FlakySdk()..failing = false;
      await SharedPrefsRepository().setBool(SharedPrefKeys.kAnalyticsCollectionEnabled, false);
      final service = AnalyticsService(sdk, false);
      await service.initialize();

      await mount(tester, service, textScale: 2);

      expect(tester.takeException(), isNull);
      expect(find.text(t.settings_screen.analytics_collection_apply_error), findsOneWidget);
      final retry = find.text(t.settings_screen.analytics_collection_retry_disable);
      expect(retry, findsOneWidget);
      expect(tester.getRect(retry).right, lessThanOrEqualTo(300));
      final semantics = tester.ensureSemantics();
      expect(tester.getSemantics(retry).getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      semantics.dispose();
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

  test('a stale ON action is ignored while saved OFF is pending without requiring a widget rebuild', () async {
    final sdk = _FlakySdk();
    final service = await gatedService(sdk);
    sdk.enableGate = null;
    sdk.failing = false;
    await expectLater(service.setCollectionEnabled(false), throwsStateError);
    final viewModel = AnalyticsCollectionSettingViewModel(service);
    sdk.failing = null;
    sdk.calls.clear();

    expect(await viewModel.setCollectionEnabled(true), isTrue);

    expect(sdk.calls, isEmpty);
    expect(SharedPrefsRepository().getBool(SharedPrefKeys.kAnalyticsCollectionEnabled), isFalse);
    expect(viewModel.disablePending, isTrue);
    expect(await viewModel.setCollectionEnabled(false), isTrue);
    expect(viewModel.disablePending, isFalse);
    expect(await viewModel.setCollectionEnabled(true), isTrue);
    expect(sdk.calls, [false, true]);
    expect(SharedPrefsRepository().getBool(SharedPrefKeys.kAnalyticsCollectionEnabled), isTrue);
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

    await tester.tapAt(tester.getCenter(switches.last));
    await tester.pumpAndSettle();
    expect(find.text(t.settings_screen.analytics_collection_error), findsNothing);
    sdk.enableGate!.complete();
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    expect(sdk.calls.where((enabled) => enabled), hasLength(1));
    expect(tester.widgetList<CoconutSwitch>(switches).map((s) => s.isOn), [true, true]);
    await tester.pumpWidget(const SizedBox());
  });

  // SingleButton의 기본 FittedBox는 긴 문구를 줄여 2배 글씨에서도 7px대로 그렸다. 이 행은 줄바꿈해 요청한 크기를 지킨다.
  for (final locale in AppLocale.values) {
    for (final width in [320.0, 390.0]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('keeps ${locale.languageCode} copy at the requested size: ${width.toInt()}px x$scale', (
          tester,
        ) async {
          tester.view.physicalSize = Size(width, 800);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          LocaleSettings.setLocaleSync(locale);
          final service = AnalyticsService(null, false);
          await service.initialize();
          await mount(
            tester,
            service,
            textScale: scale,
            body: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: ButtonGroup(buttons: [AnalyticsCollectionSetting()]),
            ),
          );
          expect(tester.takeException(), isNull);

          final switchRect = tester.getRect(find.byType(CoconutSwitch));
          expect(switchRect.right, lessThanOrEqualTo(width - 16));
          for (final (text, fontSize) in [
            (t.settings_screen.analytics_collection, 14.0),
            (t.settings_screen.analytics_collection_description, 12.0),
          ]) {
            final painted = tester.getRect(find.text(text));
            final paintedFont = fontSize * scale * painted.width / tester.getSize(find.text(text)).width;
            expect(paintedFont, greaterThanOrEqualTo(fontSize * scale - .01), reason: text);
            expect(painted.right, lessThanOrEqualTo(switchRect.left), reason: text);
          }

          final semantics = tester.ensureSemantics();
          expect(find.bySemanticsLabel(t.settings_screen.analytics_collection), findsWidgets);
          semantics.dispose();
          await tester.pumpWidget(const SizedBox());
        });
      }
    }
  }
}
