// ignore_for_file: deprecated_member_use_from_same_package

import 'dart:async';

import 'package:coconut_wallet/constants/shared_pref_keys.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:coconut_wallet/services/analytics_service.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockFirebaseAnalytics extends Mock implements FirebaseAnalytics {
  @override
  Future<void> setAnalyticsCollectionEnabled(bool enabled) =>
      super.noSuchMethod(
            Invocation.method(#setAnalyticsCollectionEnabled, [enabled]),
            returnValue: Future<void>.value(),
          )
          as Future<void>;

  @override
  Future<void> setDefaultEventParameters(Map<String, Object?>? defaultParameters) =>
      super.noSuchMethod(
            Invocation.method(#setDefaultEventParameters, [defaultParameters]),
            returnValue: Future<void>.value(),
          )
          as Future<void>;

  @override
  Future<void> logEvent({required String name, Map<String, Object>? parameters, AnalyticsCallOptions? callOptions}) =>
      super.noSuchMethod(
            Invocation.method(#logEvent, [], {#name: name, #parameters: parameters, #callOptions: callOptions}),
            returnValue: Future<void>.value(),
          )
          as Future<void>;

  @override
  Future<void> logScreenView({
    String? screenClass,
    String? screenName,
    Map<String, Object>? parameters,
    AnalyticsCallOptions? callOptions,
  }) =>
      super.noSuchMethod(
            Invocation.method(#logScreenView, [], {
              #screenClass: screenClass,
              #screenName: screenName,
              #parameters: parameters,
              #callOptions: callOptions,
            }),
            returnValue: Future<void>.value(),
          )
          as Future<void>;

  @override
  Future<void> setUserProperty({required String name, required String? value, AnalyticsCallOptions? callOptions}) =>
      super.noSuchMethod(
            Invocation.method(#setUserProperty, [], {#name: name, #value: value, #callOptions: callOptions}),
            returnValue: Future<void>.value(),
          )
          as Future<void>;
}

class FailingSharedPreferences extends Mock implements SharedPreferences {
  @override
  bool containsKey(String key) =>
      super.noSuchMethod(Invocation.method(#containsKey, [key]), returnValue: false) as bool;

  @override
  Future<bool> setBool(String key, bool value) =>
      super.noSuchMethod(Invocation.method(#setBool, [key, value]), returnValue: Future<bool>.value(false))
          as Future<bool>;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPrefsRepository repository;
  late MockFirebaseAnalytics analytics;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repository = SharedPrefsRepository()..setSharedPreferencesForTest(await SharedPreferences.getInstance());
    analytics = MockFirebaseAnalytics();
    when(analytics.setAnalyticsCollectionEnabled(false)).thenAnswer((_) async {});
    when(analytics.setAnalyticsCollectionEnabled(true)).thenAnswer((_) async {});
    when(analytics.setDefaultEventParameters({'app_version': 'test'})).thenAnswer((_) async {});
    when(analytics.logEvent(name: 'blocked', parameters: const <String, Object>{})).thenAnswer((_) async {});
  });

  AnalyticsService service() => AnalyticsService(
    analytics,
    sharedPrefs: repository,
    commonParametersLoader: () async => const <String, Object>{'app_version': 'test'},
  );

  test('defaults collection on when the preference is missing', () async {
    final subject = service();

    await subject.initialize();

    expect(subject.isCollectionEnabled, isTrue);
    expect(subject.canCollect, isTrue);
    verify(analytics.setAnalyticsCollectionEnabled(true)).called(1);
  });

  test('restores an opted-out preference without initializing defaults', () async {
    await repository.setBool(SharedPrefKeys.kAnalyticsCollectionEnabled, false);
    final subject = service();

    await subject.initialize();

    expect(subject.isCollectionEnabled, isFalse);
    expect(subject.canCollect, isFalse);
    verify(analytics.setAnalyticsCollectionEnabled(false)).called(1);
    verifyNever(analytics.setDefaultEventParameters({'app_version': 'test'}));
  });

  test('restores an opted-in preference', () async {
    await repository.setBool(SharedPrefKeys.kAnalyticsCollectionEnabled, true);
    final subject = service();

    await subject.initialize();

    expect(subject.canCollect, isTrue);
    verify(analytics.setDefaultEventParameters({'app_version': 'test'})).called(1);
  });

  test('opt out blocks events immediately and persists before awaiting SDK disable', () async {
    final subject = service();
    await subject.initialize();
    final disableCompleter = Completer<void>();
    when(analytics.setAnalyticsCollectionEnabled(false)).thenAnswer((_) => disableCompleter.future);

    final update = subject.setCollectionEnabled(false);
    await subject.logEvent(eventName: 'blocked');
    await subject.logScreenView(screenName: 'blocked-screen');
    await subject.setUserProperty(name: 'blocked-property', value: 'blocked-value');

    expect(subject.canCollect, isFalse);
    expect(subject.isUpdating, isTrue);
    verifyNever(analytics.logEvent(name: 'blocked', parameters: anyNamed('parameters')));
    verifyNever(analytics.logScreenView(screenName: 'blocked-screen'));
    verifyNever(analytics.setUserProperty(name: 'blocked-property', value: 'blocked-value'));
    expect(repository.isContainsKey(SharedPrefKeys.kAnalyticsCollectionEnabled), isTrue);
    expect(repository.getBool(SharedPrefKeys.kAnalyticsCollectionEnabled), isFalse);
    disableCompleter.complete();
    await update;
    expect(repository.getBool(SharedPrefKeys.kAnalyticsCollectionEnabled), isFalse);
  });

  test('opt in does not permit events until SDK setup succeeds', () async {
    await repository.setBool(SharedPrefKeys.kAnalyticsCollectionEnabled, false);
    final setupCompleter = Completer<void>();
    when(analytics.setDefaultEventParameters({'app_version': 'test'})).thenAnswer((_) => setupCompleter.future);
    final subject = service();
    await subject.initialize();

    final update = subject.setCollectionEnabled(true);
    await subject.logEvent(eventName: 'blocked');

    expect(subject.canCollect, isFalse);
    verifyNever(analytics.logEvent(name: 'blocked', parameters: anyNamed('parameters')));
    setupCompleter.complete();
    await update;
    expect(subject.canCollect, isTrue);
    await subject.logEvent(eventName: 'blocked');
    verify(analytics.logEvent(name: 'blocked', parameters: const <String, Object>{})).called(1);
  });

  test('backend unavailable still saves the user choice but cannot collect', () async {
    final subject = AnalyticsService(null, sharedPrefs: repository);
    await subject.initialize();

    await subject.setCollectionEnabled(false);

    expect(subject.isCollectionEnabled, isFalse);
    expect(subject.canCollect, isFalse);
    expect(repository.getBool(SharedPrefKeys.kAnalyticsCollectionEnabled), isFalse);
  });

  test('a storage write returning false makes the update fail', () async {
    final failingPreferences = FailingSharedPreferences();
    when(failingPreferences.containsKey(SharedPrefKeys.kAnalyticsCollectionEnabled)).thenReturn(false);
    when(failingPreferences.setBool(SharedPrefKeys.kAnalyticsCollectionEnabled, false)).thenAnswer((_) async => false);
    final failingRepository = SharedPrefsRepository()..setSharedPreferencesForTest(failingPreferences);
    final subject = AnalyticsService(null, sharedPrefs: failingRepository);
    await subject.initialize();

    await expectLater(subject.setCollectionEnabled(false), throwsA(isA<StateError>()));
    expect(subject.isUpdating, isFalse);
    expect(subject.isCollectionEnabled, isTrue);
    expect(subject.canCollect, isFalse);
  });

  test('startup setup failure stays fail closed without blocking startup', () async {
    when(analytics.setDefaultEventParameters({'app_version': 'test'})).thenThrow(StateError('setup failed'));
    final subject = service();

    await subject.initialize();

    expect(subject.isCollectionEnabled, isTrue);
    expect(subject.canCollect, isFalse);
    expect(subject.isUpdating, isFalse);
    verifyNever(analytics.setAnalyticsCollectionEnabled(true));
  });

  test('failed SDK enable keeps the committed choice but remains retryable and fail closed', () async {
    await repository.setBool(SharedPrefKeys.kAnalyticsCollectionEnabled, false);
    final subject = service();
    await subject.initialize();
    when(analytics.setAnalyticsCollectionEnabled(true)).thenThrow(StateError('enable failed'));

    await expectLater(subject.setCollectionEnabled(true), throwsA(isA<StateError>()));

    expect(subject.isCollectionEnabled, isTrue);
    expect(subject.canCollect, isFalse);
    expect(repository.getBool(SharedPrefKeys.kAnalyticsCollectionEnabled), isTrue);

    when(analytics.setAnalyticsCollectionEnabled(true)).thenAnswer((_) async {});
    await subject.setCollectionEnabled(true);
    expect(subject.canCollect, isTrue);
  });

  test('failed SDK disable persists opt-out across restart and permits a retry', () async {
    final subject = service();
    await subject.initialize();
    when(analytics.setAnalyticsCollectionEnabled(false)).thenThrow(StateError('disable failed'));

    await expectLater(subject.setCollectionEnabled(false), throwsA(isA<StateError>()));

    expect(subject.isCollectionEnabled, isFalse);
    expect(subject.canCollect, isFalse);
    expect(repository.getBool(SharedPrefKeys.kAnalyticsCollectionEnabled), isFalse);
    final restarted = service();
    await restarted.initialize();
    expect(restarted.isCollectionEnabled, isFalse);
    expect(restarted.canCollect, isFalse);
    when(analytics.setAnalyticsCollectionEnabled(false)).thenAnswer((_) async {});
    clearInteractions(analytics);
    await subject.setCollectionEnabled(false);
    verify(analytics.setAnalyticsCollectionEnabled(false)).called(1);
    expect(subject.isCollectionEnabled, isFalse);
    expect(repository.getBool(SharedPrefKeys.kAnalyticsCollectionEnabled), isFalse);
  });

  test('password reset does not clear the analytics collection choice', () {
    expect(SharedPrefKeys.keysToReset, isNot(contains(SharedPrefKeys.kAnalyticsCollectionEnabled)));
  });

  test('concurrent toggles are rejected while an update is in progress', () async {
    final subject = service();
    await subject.initialize();
    final disableCompleter = Completer<void>();
    when(analytics.setAnalyticsCollectionEnabled(false)).thenAnswer((_) => disableCompleter.future);

    final first = subject.setCollectionEnabled(false);

    await expectLater(subject.setCollectionEnabled(true), throwsA(isA<StateError>()));
    disableCompleter.complete();
    await first;
    expect(subject.isCollectionEnabled, isFalse);
  });

  test('a toggle cannot race startup initialization', () async {
    final initializationCompleter = Completer<void>();
    when(analytics.setAnalyticsCollectionEnabled(true)).thenAnswer((_) => initializationCompleter.future);
    final subject = service();

    final initialization = subject.initialize();

    await expectLater(subject.setCollectionEnabled(false), throwsA(isA<StateError>()));
    initializationCompleter.complete();
    await initialization;
    expect(subject.canCollect, isTrue);
  });

  test('startup, toggles and restored choices never log collection transition events', () async {
    final subject = service();
    await subject.initialize();
    await subject.setCollectionEnabled(false);
    await subject.setCollectionEnabled(false);
    final restoredOff = service();
    await restoredOff.initialize();
    expect(restoredOff.isCollectionEnabled, isFalse);
    expect(restoredOff.canCollect, isFalse);

    await restoredOff.setCollectionEnabled(true);
    await restoredOff.setCollectionEnabled(true);
    final restoredOn = service();
    await restoredOn.initialize();
    expect(restoredOn.isCollectionEnabled, isTrue);
    expect(restoredOn.canCollect, isTrue);
    verifyNever(analytics.logEvent(name: 'analytics_collection_enabled'));
    verifyNever(analytics.logEvent(name: 'analytics_collection_disabled'));
  });

  test('failed SDK transitions and retries never log collection transition events', () async {
    final subject = service();
    await subject.initialize();
    when(analytics.setAnalyticsCollectionEnabled(false)).thenThrow(StateError('disable failed'));
    await expectLater(subject.setCollectionEnabled(false), throwsStateError);
    when(analytics.setAnalyticsCollectionEnabled(false)).thenAnswer((_) async {});
    await subject.setCollectionEnabled(false);
    expect(subject.canCollect, isFalse);

    when(analytics.setAnalyticsCollectionEnabled(true)).thenThrow(StateError('enable failed'));
    await expectLater(subject.setCollectionEnabled(true), throwsStateError);
    when(analytics.setAnalyticsCollectionEnabled(true)).thenAnswer((_) async {});
    await subject.setCollectionEnabled(true);
    expect(subject.canCollect, isTrue);
    verifyNever(analytics.logEvent(name: 'analytics_collection_enabled'));
    verifyNever(analytics.logEvent(name: 'analytics_collection_disabled'));
  });

  test('failed OFF persistence disables collection without recording a committed choice', () async {
    final failingPreferences = FailingSharedPreferences();
    when(failingPreferences.containsKey(SharedPrefKeys.kAnalyticsCollectionEnabled)).thenReturn(false);
    when(failingPreferences.setBool(SharedPrefKeys.kAnalyticsCollectionEnabled, false)).thenAnswer((_) async => false);
    final failingRepository = SharedPrefsRepository()..setSharedPreferencesForTest(failingPreferences);
    final subject = AnalyticsService(
      analytics,
      sharedPrefs: failingRepository,
      commonParametersLoader: () async => const <String, Object>{'app_version': 'test'},
    );
    await subject.initialize();
    expect(subject.canCollect, isTrue);

    await expectLater(subject.setCollectionEnabled(false), throwsStateError);

    verifyNever(analytics.logEvent(name: 'analytics_collection_enabled'));
    verifyNever(analytics.logEvent(name: 'analytics_collection_disabled'));
    expect(subject.canCollect, isFalse);
    expect(subject.isUpdating, isFalse);
  });
}
