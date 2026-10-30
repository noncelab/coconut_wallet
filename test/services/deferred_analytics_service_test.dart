// ignore_for_file: deprecated_member_use_from_same_package

import 'dart:async';

import 'package:coconut_wallet/constants/shared_pref_keys.dart';
import 'package:coconut_wallet/providers/view_model/settings/analytics_collection_setting_view_model.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:coconut_wallet/services/analytics_service.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Sdk extends Fake implements FirebaseAnalytics {
  _Sdk(this.effects, this.preferences);
  final List<String> effects;
  final SharedPrefsRepository preferences;

  @override
  Future<void> setAnalyticsCollectionEnabled(bool enabled) async {
    if (enabled) expect(preferences.sharedPrefs.get(SharedPrefKeys.kAnalyticsCollectionEnabled), isFalse);
    effects.add('sdk:$enabled');
  }

  @override
  Future<void> setDefaultEventParameters(Map<String, Object?>? parameters) async => effects.add('defaults');
}

class _FailOnWrite extends Fake implements SharedPreferences {
  _FailOnWrite(this.delegate);
  final SharedPreferences delegate;

  @override
  Object? get(String key) => delegate.get(key);

  @override
  bool? getBool(String key) => delegate.getBool(key);

  @override
  bool containsKey(String key) => delegate.containsKey(key);

  @override
  Future<bool> setBool(String key, bool value) async => value ? false : delegate.setBool(key, value);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SharedPrefsRepository preferences;
  late List<String> effects;
  late _Sdk sdk;
  late bool activationFails;
  late bool rollbackFails;
  late Completer<void>? activationGate;

  setUp(() async {
    SharedPreferences.setMockInitialValues({SharedPrefKeys.kAnalyticsCollectionEnabled: false});
    preferences = SharedPrefsRepository()..setSharedPreferencesForTest(await SharedPreferences.getInstance());
    effects = [];
    sdk = _Sdk(effects, preferences);
    activationFails = false;
    rollbackFails = false;
    activationGate = null;
  });

  AnalyticsService service({bool compileDisabled = false}) => AnalyticsService(
    null,
    compileDisabled,
    sharedPrefs: preferences,
    commonParametersLoader: () async => const {},
    deferredBackend: DeferredAnalyticsBackend(
      activate: () async {
        effects.add('activate');
        await activationGate?.future;
        if (activationFails) throw StateError('Core failed after native attachment');
        return sdk;
      },
      disableIfActive: () async {
        effects.add('reconcile');
        if (rollbackFails) throw StateError('native rollback failed');
      },
    ),
  );

  test('untouched deferred OFF startup reconciles once without creating a backend', () async {
    final subject = service();
    await subject.initialize();

    expect(effects, ['reconcile']);
    expect(subject.isCollectionEnabled, isFalse);
    expect(subject.canCollect, isFalse);
    expect(subject.collectionStatusListenable.value, (isUpdating: false, disablePending: false, hasError: false));
    effects.clear();
    await subject.setCollectionEnabled(false);
    expect(effects, isEmpty);
  });

  test('startup reconciliation failure stays OFF and pending until an explicit false retry', () async {
    rollbackFails = true;
    final subject = service();
    await subject.initialize();

    expect(effects, ['reconcile', 'reconcile']);
    expect(subject.isCollectionEnabled, isFalse);
    expect(subject.collectionStatusListenable.value.disablePending, isTrue);
    expect(subject.canCollect, isFalse);
    effects.clear();
    rollbackFails = false;
    await subject.setCollectionEnabled(false);
    expect(effects, ['reconcile']);
    expect(subject.collectionStatusListenable.value.disablePending, isFalse);
  });

  test('a new Dart service reconciles the existing native process instead of assuming inactivity', () async {
    final first = service();
    await first.initialize();
    effects.clear();
    rollbackFails = true; // Native SDK from a previous engine is still active and cannot be disabled.
    final recreated = service();
    await recreated.initialize();

    expect(effects, ['reconcile', 'reconcile']);
    expect(recreated.collectionStatusListenable.value.disablePending, isTrue);
    rollbackFails = false;
    await recreated.setCollectionEnabled(false);
    expect(recreated.collectionStatusListenable.value.hasError, isFalse);
  });

  test('ON activates once, configures and enables before saving; later OFF/ON reuses the backend', () async {
    final subject = service();
    await subject.initialize();
    effects.clear();
    await subject.setCollectionEnabled(true);

    expect(effects, ['activate', 'defaults', 'sdk:true']);
    expect(preferences.getBool(SharedPrefKeys.kAnalyticsCollectionEnabled), isTrue);
    expect(subject.canCollect, isTrue);
    effects.clear();
    await subject.setCollectionEnabled(false);
    await subject.setCollectionEnabled(true);
    expect(effects, ['sdk:false', 'defaults', 'sdk:true']);
  });

  test('activation failure after native attachment rolls back even without a returned backend', () async {
    final subject = service();
    await subject.initialize();
    effects.clear();
    activationFails = true;
    await expectLater(subject.setCollectionEnabled(true), throwsStateError);

    expect(effects, ['activate', 'reconcile']);
    expect(preferences.getBool(SharedPrefKeys.kAnalyticsCollectionEnabled), isFalse);
    expect(subject.canCollect, isFalse);
    expect(subject.collectionStatusListenable.value.hasError, isFalse);
    expect(subject.collectionStatusListenable.value.disablePending, isFalse);
  });

  test('failed partial-activation rollback locks OFF; false retry never activates and permits later ON', () async {
    final subject = service();
    await subject.initialize();
    effects.clear();
    activationFails = true;
    rollbackFails = true;
    await expectLater(subject.setCollectionEnabled(true), throwsStateError);
    final model = AnalyticsCollectionSettingViewModel(subject);
    addTearDown(model.dispose);
    expect(model.disablePending, isTrue);
    expect(await model.setCollectionEnabled(true), isTrue);
    expect(effects, ['activate', 'reconcile']);
    effects.clear();
    rollbackFails = false;
    expect(await model.setCollectionEnabled(false), isTrue);
    expect(effects, ['reconcile']);
    expect(model.disablePending, isFalse);
    activationFails = false;
    effects.clear();
    await model.setCollectionEnabled(true);
    expect(effects, ['activate', 'defaults', 'sdk:true']);
    expect(subject.canCollect, isTrue);
  });

  test('an unsuccessful activation is retried rather than memoizing the failed future', () async {
    final subject = service();
    await subject.initialize();
    effects.clear();
    activationFails = true;
    await expectLater(subject.setCollectionEnabled(true), throwsStateError);
    activationFails = false;
    await subject.setCollectionEnabled(true);
    expect(effects, ['activate', 'reconcile', 'activate', 'defaults', 'sdk:true']);
  });

  test('concurrent requests remain serialized throughout asynchronous activation', () async {
    final subject = service();
    await subject.initialize();
    effects.clear();
    activationGate = Completer<void>();
    final model = AnalyticsCollectionSettingViewModel(subject);
    addTearDown(model.dispose);
    final first = model.setCollectionEnabled(true);
    expect(model.isSaving, isTrue);
    expect(await model.setCollectionEnabled(false), isTrue);
    await expectLater(subject.setCollectionEnabled(false), throwsStateError);
    expect(effects, ['activate']);
    activationGate!.complete();
    expect(await first, isTrue);
    expect(subject.canCollect, isTrue);
  });

  test('ON storage failure after activation disables the real returned backend', () async {
    preferences.setSharedPreferencesForTest(_FailOnWrite(preferences.sharedPrefs));
    final subject = service();
    await subject.initialize();
    effects.clear();
    await expectLater(subject.setCollectionEnabled(true), throwsStateError);

    expect(effects, ['activate', 'defaults', 'sdk:true', 'sdk:false']);
    expect(subject.isCollectionEnabled, isFalse);
    expect(subject.canCollect, isFalse);
    expect(subject.collectionStatusListenable.value.disablePending, isFalse);
  });

  test('compile-disabled ignores the deferred pair and only persists the choice', () async {
    final subject = service(compileDisabled: true);
    await subject.initialize();
    await subject.setCollectionEnabled(true);
    await subject.setCollectionEnabled(false);
    expect(effects, isEmpty);
    expect(subject.canCollect, isFalse);
    expect(preferences.getBool(SharedPrefKeys.kAnalyticsCollectionEnabled), isFalse);
  });
}
