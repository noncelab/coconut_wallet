// ignore_for_file: deprecated_member_use_from_same_package

import 'dart:async';

import 'package:coconut_wallet/app/bootstrap/app_bootstrap.dart';
import 'package:coconut_wallet/constants/shared_pref_keys.dart';
import 'package:coconut_wallet/providers/view_model/settings/analytics_collection_setting_view_model.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:coconut_wallet/services/analytics_service.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Preferences extends Fake implements SharedPreferences {
  _Preferences(this.inner, this.effects);
  final SharedPreferences inner;
  final List<String> effects;
  bool failOnSave = false;
  bool failOffSave = false;

  @override
  Object? get(String key) => inner.get(key);
  @override
  bool? getBool(String key) => inner.getBool(key);
  @override
  bool containsKey(String key) => inner.containsKey(key);
  @override
  Future<bool> setBool(String key, bool value) async {
    effects.add('save:$value');
    return (value && failOnSave) || (!value && failOffSave) ? false : inner.setBool(key, value);
  }
}

class _Backend extends Fake implements FirebaseAnalytics {
  _Backend(this.effects);
  final List<String> effects;
  int falseFailures = 0;
  int trueFailures = 0;

  @override
  Future<void> setAnalyticsCollectionEnabled(bool enabled) async {
    effects.add('sdk:$enabled');
    if (enabled && trueFailures != 0) {
      trueFailures--;
      throw PlatformException(code: 'SDK_TRUE_FAILED');
    }
    if (!enabled && falseFailures != 0) {
      falseFailures--;
      throw PlatformException(code: 'SDK_FALSE_FAILED');
    }
  }

  @override
  Future<void> setDefaultEventParameters(Map<String, Object?>? parameters) async {}

  @override
  Future<void> logScreenView({
    String? screenClass,
    String? screenName,
    Map<String, Object>? parameters,
    AnalyticsCallOptions? callOptions,
  }) async {
    effects.add('screen:$screenName');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const os = MethodChannel('onl.coconut.wallet/os');
  late List<String> effects;
  late SharedPrefsRepository preferences;
  late _Preferences storage;
  late _Backend backend;
  late Map<bool, int> componentFailures;
  late int nativeFalseFailures;
  late bool coreFails;
  late Completer<void>? componentWait;
  late Completer<void>? coreWait;

  Future<void> savedChoice(bool enabled) async {
    SharedPreferences.setMockInitialValues({SharedPrefKeys.kAnalyticsCollectionEnabled: enabled});
    storage = _Preferences(await SharedPreferences.getInstance(), effects);
    preferences = SharedPrefsRepository()..setSharedPreferencesForTest(storage);
  }

  setUp(() async {
    effects = [];
    backend = _Backend(effects);
    componentFailures = {true: 0, false: 0};
    nativeFalseFailures = 0;
    coreFails = false;
    componentWait = null;
    coreWait = null;
    await savedChoice(false);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(os, (call) async {
      expect(call.method, 'setAnalyticsComponentsEnabled');
      final enabled = call.arguments as bool;
      effects.add('components:$enabled');
      await componentWait?.future;
      if (componentFailures[enabled] != 0) {
        componentFailures[enabled] = componentFailures[enabled]! - 1;
        throw PlatformException(code: 'COMPONENTS_FAILED');
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(os, null);
  });

  Future<({AnalyticsService service, bool isFirebaseUsed})> bootstrap({
    bool android = true,
    bool enabled = true,
  }) async {
    final result = await AppBootstrap.initializeAnalytics(
      useFirebase: enabled,
      isAndroid: android,
      preferences: preferences,
      attachAnalytics: () async => effects.add('attach'),
      initializeFirebase: () async {
        effects.add('core');
        await coreWait?.future;
        if (coreFails) throw StateError('Core failed after the native SDK was attached');
      },
      disableAnalyticsIfActive: () async {
        effects.add('native:false');
        if (nativeFalseFailures != 0) {
          nativeFalseFailures--;
          throw PlatformException(code: 'NATIVE_FALSE_FAILED');
        }
      },
      analyticsFactory: () {
        effects.add('factory');
        return backend;
      },
    );
    return result;
  }

  test('Android Core failure retains the native disable callback for an explicit OFF', () async {
    await savedChoice(true);
    coreFails = true;
    final result = await bootstrap();
    await result.service.initialize();
    effects.clear();

    await result.service.setCollectionEnabled(false);

    expect(effects, contains('native:false'));
    expect(result.isFirebaseUsed, isTrue);
    expect(preferences.getBool(SharedPrefKeys.kAnalyticsCollectionEnabled), isFalse);
    expect(result.service.isCollectionEnabled, isFalse);
    expect(result.service.canCollect, isFalse);
  });

  test('normal Android initializes Core once and logging waits for its service initialization', () async {
    await savedChoice(true);
    final result = await bootstrap();
    expect(effects, isEmpty);
    coreWait = Completer<void>();
    final initializing = result.service.initialize();
    final logging = result.service.logScreenView(screenName: 'home');
    await Future<void>.delayed(Duration.zero);
    expect(effects, ['components:true', 'attach', 'core']);
    expect(result.service.canCollect, isFalse);
    coreWait!.complete();
    await Future.wait([initializing, logging]);
    expect(effects, ['components:true', 'attach', 'core', 'factory', 'sdk:false', 'sdk:true', 'screen:home']);
    expect(effects.where((e) => e == 'core'), hasLength(1));
  });

  test('saved ON plus Core failure disables both in-session and keeps a neutral saved-ON error', () async {
    await savedChoice(true);
    coreFails = true;
    final result = await bootstrap();
    await result.service.initialize();
    expect(effects, ['components:true', 'attach', 'core', 'components:false', 'native:false']);
    expect(preferences.getBool(SharedPrefKeys.kAnalyticsCollectionEnabled), isTrue);
    expect(result.service.isCollectionEnabled, isTrue);
    expect(result.service.canCollect, isFalse);
    expect(result.service.collectionStatusListenable.value, (isUpdating: false, disablePending: false, hasError: true));
    effects.clear();
    await expectLater(result.service.setCollectionEnabled(true), throwsStateError);
    expect(effects, ['components:true', 'attach', 'core', 'components:false', 'native:false']);
    expect(result.service.collectionStatusListenable.value.hasError, isTrue);
    expect(result.service.collectionStatusListenable.value.disablePending, isFalse);
  });

  test('reapplying saved ON after SDK failure keeps the neutral error if enabling fails again', () async {
    await savedChoice(true);
    backend.trueFailures = 2;
    final result = await bootstrap();
    await result.service.initialize();
    effects.clear();
    await expectLater(result.service.setCollectionEnabled(true), throwsA(isA<PlatformException>()));
    expect(effects, ['components:true', 'sdk:true', 'components:false', 'sdk:false']);
    expect(preferences.getBool(SharedPrefKeys.kAnalyticsCollectionEnabled), isTrue);
    expect(result.service.isCollectionEnabled, isTrue);
    expect(result.service.canCollect, isFalse);
    expect(result.service.collectionStatusListenable.value, (isUpdating: false, disablePending: false, hasError: true));
  });

  test('cold OFF reconciles components and native state without activation', () async {
    final result = await bootstrap();
    await result.service.initialize();
    expect(effects, ['components:false', 'native:false']);
    expect(result.service.collectionStatusListenable.value.disablePending, isFalse);
    expect(result.service.canCollect, isFalse);
  });

  for (final failures in [(gate: 2, native: 0), (gate: 0, native: 2), (gate: 2, native: 2)]) {
    test('OFF startup independently attempts both barriers, gate=${failures.gate} native=${failures.native}', () async {
      componentFailures[false] = failures.gate;
      nativeFalseFailures = failures.native;
      final result = await bootstrap();
      await result.service.initialize();
      expect(effects, ['components:false', 'native:false', 'components:false', 'native:false']);
      expect(result.service.collectionStatusListenable.value.disablePending, isTrue);
      expect(result.service.isCollectionEnabled, isFalse);
      effects.clear();
      await result.service.setCollectionEnabled(false);
      expect(effects, ['components:false', 'save:false', 'native:false']);
      expect(result.service.collectionStatusListenable.value.hasError, isFalse);
      expect(result.service.canCollect, isFalse);
    });
  }

  test('one-shot component startup failure recovers without pending or activation', () async {
    componentFailures[false] = 1;
    final result = await bootstrap();
    await result.service.initialize();
    expect(effects, ['components:false', 'native:false', 'components:false', 'native:false']);
    expect(result.service.collectionStatusListenable.value.hasError, isFalse);
  });

  test('ON startup component failure is neutral and still disables any existing native SDK', () async {
    await savedChoice(true);
    componentFailures[true] = 1;
    final result = await bootstrap();
    await result.service.initialize();
    expect(effects, ['components:true', 'components:false', 'native:false']);
    expect(result.service.isCollectionEnabled, isTrue);
    expect(result.service.canCollect, isFalse);
    expect(result.service.collectionStatusListenable.value.hasError, isTrue);
    expect(result.service.collectionStatusListenable.value.disablePending, isFalse);
  });

  test(
    'explicit OFF saves and publishes refusal despite two component failures and attempts SDK false twice',
    () async {
      await savedChoice(true);
      final result = await bootstrap();
      await result.service.initialize();
      effects.clear();
      componentFailures[false] = 2;
      await expectLater(result.service.setCollectionEnabled(false), throwsA(isA<PlatformException>()));
      expect(effects, ['components:false', 'save:false', 'sdk:false', 'components:false', 'sdk:false']);
      expect(preferences.getBool(SharedPrefKeys.kAnalyticsCollectionEnabled), isFalse);
      expect(result.service.isCollectionEnabled, isFalse);
      expect(result.service.collectionStatusListenable.value.disablePending, isTrue);
      expect(result.service.canCollect, isFalse);
    },
  );

  test('one-shot explicit OFF gate failure recovers with no false application error', () async {
    await savedChoice(true);
    final result = await bootstrap();
    await result.service.initialize();
    effects.clear();
    componentFailures[false] = 1;
    await result.service.setCollectionEnabled(false);
    expect(effects, ['components:false', 'save:false', 'sdk:false', 'components:false', 'sdk:false']);
    expect(result.service.collectionStatusListenable.value.hasError, isFalse);
    expect(result.service.isCollectionEnabled, isFalse);
  });

  test('ON storage failure restores BOTH barriers while preserving the saved OFF', () async {
    final result = await bootstrap();
    await result.service.initialize();
    effects.clear();
    storage.failOnSave = true;
    await expectLater(result.service.setCollectionEnabled(true), throwsStateError);
    expect(effects, [
      'components:true',
      'attach',
      'core',
      'factory',
      'sdk:true',
      'save:true',
      'components:false',
      'sdk:false',
    ]);
    expect(result.service.isCollectionEnabled, isFalse);
    expect(result.service.canCollect, isFalse);
  });

  test('OFF storage failure still attempts both barriers and safely retries the unsaved refusal', () async {
    await savedChoice(true);
    final result = await bootstrap();
    await result.service.initialize();
    effects.clear();
    storage.failOffSave = true;
    componentFailures[false] = 2;
    await expectLater(result.service.setCollectionEnabled(false), throwsStateError);
    expect(effects, ['components:false', 'save:false', 'components:false', 'sdk:false']);
    expect(preferences.getBool(SharedPrefKeys.kAnalyticsCollectionEnabled), isTrue);
    expect(result.service.isCollectionEnabled, isTrue);
    expect(result.service.canCollect, isFalse);
    expect(result.service.collectionStatusListenable.value.disablePending, isTrue);
    effects.clear();
    storage.failOffSave = false;
    await result.service.setCollectionEnabled(false);
    expect(effects, ['components:false', 'save:false', 'sdk:false']);
    expect(result.service.isCollectionEnabled, isFalse);
    expect(result.service.collectionStatusListenable.value.hasError, isFalse);
  });

  test('an async component gate serializes requests before activation or storage', () async {
    final result = await bootstrap();
    await result.service.initialize();
    effects.clear();
    componentWait = Completer<void>();
    final model = AnalyticsCollectionSettingViewModel(result.service);
    addTearDown(model.dispose);
    final first = model.setCollectionEnabled(true);
    try {
      await Future<void>.delayed(Duration.zero);
      expect(model.isSaving, isTrue);
      expect(await model.setCollectionEnabled(false), isTrue);
      await expectLater(result.service.setCollectionEnabled(false), throwsStateError);
      expect(effects, ['components:true']);
    } finally {
      componentWait!.complete();
      await first;
    }
    expect(result.service.canCollect, isTrue);
  });

  test('compile-disabled makes no component or SDK callbacks', () async {
    final result = await bootstrap(enabled: false);
    await result.service.initialize();
    await result.service.setCollectionEnabled(true);
    await result.service.setCollectionEnabled(false);
    expect(effects, ['save:true', 'save:false']);
    expect(result.isFirebaseUsed, isFalse);
  });

  test('iOS keeps its eager backend and never calls the Android component gate', () async {
    final result = await bootstrap(android: false);
    expect(effects, ['core', 'factory']);
    await result.service.initialize();
    await result.service.setCollectionEnabled(true);
    await result.service.setCollectionEnabled(false);
    expect(effects.where((e) => e.startsWith('components:') || e == 'attach' || e == 'native:false'), isEmpty);
  });
}
