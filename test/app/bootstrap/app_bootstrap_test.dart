import 'dart:io';

import 'package:coconut_wallet/app/bootstrap/app_bootstrap.dart';
import 'package:coconut_wallet/constants/shared_pref_keys.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Analytics extends Fake implements FirebaseAnalytics {
  _Analytics(this.effects);
  final List<String> effects;

  @override
  Future<void> setAnalyticsCollectionEnabled(bool enabled) async => effects.add('sdk:$enabled');

  @override
  Future<void> setDefaultEventParameters(Map<String, Object?>? parameters) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

  late Directory documentsDirectory;

  setUp(() async {
    documentsDirectory = await Directory.systemTemp.createTemp('app_bootstrap_test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      pathProviderChannel,
      (call) async => call.method == 'getApplicationDocumentsDirectory' ? documentsDirectory.path : null,
    );
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      pathProviderChannel,
      null,
    );
    await documentsDirectory.delete(recursive: true);
  });

  test('deletes the debug log left by builds that had the log viewer', () async {
    final leftover = File('${documentsDirectory.path}/debug_log.txt')..writeAsStringSync('old log');

    await AppBootstrap.deleteLegacyDebugLog();

    expect(leftover.existsSync(), isFalse);
  });

  test('keeps other documents and does not fail when no debug log exists', () async {
    final other = File('${documentsDirectory.path}/keep.txt')..writeAsStringSync('keep');

    await AppBootstrap.deleteLegacyDebugLog();

    expect(other.existsSync(), isTrue);
  });

  for (final input in <({bool android, Object? choice, bool deferred})>[
    (android: true, choice: false, deferred: true),
    (android: true, choice: true, deferred: false),
    (android: true, choice: null, deferred: false),
    (android: false, choice: false, deferred: false),
    (android: true, choice: 'false', deferred: false),
    (android: true, choice: 0, deferred: false),
  ]) {
    test('analytics bootstrap android=${input.android} choice=${input.choice} defers=${input.deferred}', () async {
      SharedPreferences.setMockInitialValues({
        if (input.choice != null) SharedPrefKeys.kAnalyticsCollectionEnabled: input.choice!,
      });
      final preferences = SharedPrefsRepository();
      await preferences.init();
      final effects = <String>[];
      final result = await AppBootstrap.initializeAnalytics(
        useFirebase: true,
        isAndroid: input.android,
        preferences: preferences,
        initializeFirebase: () async => effects.add('core'),
        attachAnalytics: () async => effects.add('attach'),
        disableAnalyticsIfActive: () async => effects.add('reconcile'),
        setComponentsEnabled: (_) async {},
        analyticsFactory: () {
          effects.add('instance');
          return _Analytics(effects);
        },
      );
      expect(result.isFirebaseUsed, isTrue);
      expect(effects, input.android ? isEmpty : ['core', 'instance']);
      if (input.deferred) {
        await result.service.initialize();
        expect(effects, ['reconcile']);
        await result.service.setCollectionEnabled(true);
        expect(effects, ['reconcile', 'attach', 'core', 'instance', 'sdk:true']);
        expect(result.service.canCollect, isTrue);
      } else if (input.android) {
        await result.service.initialize();
        if (input.choice is String || input.choice is int) {
          expect(effects, ['reconcile']);
          expect(result.service.canCollect, isFalse);
          expect(result.service.collectionStatusListenable.value.hasError, isTrue);
        } else {
          expect(effects, ['attach', 'core', 'instance', 'sdk:false', 'sdk:true']);
          expect(result.service.canCollect, isTrue);
        }
      }
    });
  }

  test('bootstrap compile-disabled touches no native or Firebase callback', () async {
    SharedPreferences.setMockInitialValues({});
    await SharedPrefsRepository().init();
    final effects = <String>[];
    final result = await AppBootstrap.initializeAnalytics(
      useFirebase: false,
      isAndroid: true,
      initializeFirebase: () async => effects.add('core'),
      attachAnalytics: () async => effects.add('attach'),
      disableAnalyticsIfActive: () async => effects.add('reconcile'),
      setComponentsEnabled: (_) async => effects.add('components'),
      analyticsFactory: () {
        effects.add('instance');
        return _Analytics(effects);
      },
    );
    await result.service.initialize();
    await result.service.setCollectionEnabled(false);
    await result.service.setCollectionEnabled(true);
    expect(effects, isEmpty);
    expect(result.isFirebaseUsed, isFalse);
    expect(result.service.canCollect, isFalse);
  });

  test('normal bootstrap Core failure retains the existing disabled fail-closed result', () async {
    SharedPreferences.setMockInitialValues({});
    await SharedPrefsRepository().init();
    final result = await AppBootstrap.initializeAnalytics(
      useFirebase: true,
      isAndroid: false,
      initializeFirebase: () async => throw StateError('core failed'),
      analyticsFactory: () => throw StateError('must not create a backend'),
    );
    expect(result.isFirebaseUsed, isFalse);
    await result.service.initialize();
    expect(result.service.canCollect, isFalse);
  });

  test('normal Android engine still applies the choice if its idempotent attach channel fails', () async {
    SharedPreferences.setMockInitialValues({});
    await SharedPrefsRepository().init();
    final effects = <String>[];
    final result = await AppBootstrap.initializeAnalytics(
      useFirebase: true,
      isAndroid: true,
      attachAnalytics: () async => throw StateError('OS channel failed on an already registered engine'),
      setComponentsEnabled: (_) async {},
      initializeFirebase: () async => effects.add('core'),
      analyticsFactory: () => _Analytics(effects),
    );
    expect(result.isFirebaseUsed, isTrue);
    await result.service.initialize();
    expect(effects, ['core', 'sdk:false', 'sdk:true']);
    expect(result.service.canCollect, isTrue);
  });
}
