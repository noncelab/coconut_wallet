import 'dart:async';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/analytics/analytics_screen_names.dart';
import 'package:coconut_wallet/analytics/analytics_screen_observer.dart';
import 'package:coconut_wallet/analytics/analytics_wallet_type.dart';
import 'package:coconut_wallet/analytics/wallet_add_analytics.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:coconut_wallet/services/analytics_service.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _commonKeys = {'app_version', 'platform', 'platform_version', 'network_type'};

class _Receipt {
  _Receipt(this.name, this.effectiveKeys, this.parameters);

  final String name;
  final Set<String> effectiveKeys;
  final Map<String, Object> parameters;
}

class _AnalyticsFake extends Fake implements FirebaseAnalytics {
  _AnalyticsFake({this.defaultGate, this.failDefaults = false, this.failLogging = false});

  final Completer<void>? defaultGate;
  final bool failDefaults;
  final bool failLogging;
  final defaultsRequested = Completer<void>();
  final defaultsApplied = Completer<void>();
  final eventReceived = Completer<void>();
  final receipts = <_Receipt>[];
  final order = <String>[];
  final properties = <String, String>{};
  Map<String, Object?> _effectiveDefaults = {};
  int defaultCalls = 0;

  @override
  Future<void> setAnalyticsCollectionEnabled(bool enabled) async {}

  @override
  Future<void> setDefaultEventParameters(Map<String, Object?>? defaultParameters) async {
    defaultCalls++;
    defaultsRequested.complete();
    await defaultGate?.future;
    if (failDefaults) throw StateError('QA default initialization failure');
    _effectiveDefaults = {...?defaultParameters};
    order.add('defaults_applied');
    defaultsApplied.complete();
  }

  void _record(String name, Map<String, Object>? parameters) {
    if (failLogging) throw StateError('QA event delivery failure');
    order.add(name);
    receipts.add(_Receipt(name, {..._effectiveDefaults.keys, ...?parameters?.keys}, {...?parameters}));
    if (!eventReceived.isCompleted) eventReceived.complete();
  }

  @override
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
    AnalyticsCallOptions? callOptions,
  }) async {
    _record(name, parameters);
  }

  @override
  Future<void> logScreenView({
    String? screenClass,
    String? screenName,
    Map<String, Object>? parameters,
    AnalyticsCallOptions? callOptions,
  }) async {
    _record('screen_view', parameters);
  }

  @override
  Future<void> setUserProperty({
    required String name,
    required String? value,
    AnalyticsCallOptions? callOptions,
  }) async {
    if (value != null) properties[name] = value;
  }
}

class _InitialScreen extends StatefulWidget {
  const _InitialScreen();

  @override
  State<_InitialScreen> createState() => _InitialScreenState();
}

class _InitialScreenState extends State<_InitialScreen> {
  @override
  void initState() {
    super.initState();
    context.read<AnalyticsService>();
  }

  @override
  Widget build(BuildContext context) => const Text('QA');
}

/// 저장된 수집 선택(기본 켜짐)을 적용하기 시작한 서비스. 로깅은 적용이 끝날 때까지 기다린다.
AnalyticsService _started(FirebaseAnalytics sdk) => AnalyticsService(sdk, false)..initialize();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SharedPrefsRepository().init();
    PackageInfo.setMockInitialValues(
      appName: 'QA',
      packageName: 'qa',
      version: '0.19.0',
      buildNumber: '1',
      buildSignature: '',
    );
    NetworkType.setNetworkType(NetworkType.regtest);
  });

  test('custom event and screen wait for delayed SDK defaults without losing common keys', () async {
    final gate = Completer<void>();
    addTearDown(() {
      if (!gate.isCompleted) gate.complete();
    });
    final sdk = _AnalyticsFake(defaultGate: gate);
    final service = _started(sdk);
    final event = service.logEvent(eventName: 'wallet_bulk_sync_completed');
    final screen = service.logScreenView(screenName: AnalyticsScreenNames.splash);
    await sdk.defaultsRequested.future;
    expect(sdk.receipts, isEmpty);
    gate.complete();
    await Future.wait([event, screen]);
    expect(sdk.defaultCalls, 1);
    expect(sdk.receipts, hasLength(2));
    expect(sdk.order.first, 'defaults_applied');
    for (final receipt in sdk.receipts) {
      expect(receipt.effectiveKeys.intersection(_commonKeys), _commonKeys);
    }
  });

  test('concurrent events and screens share one delayed SDK default application', () async {
    final gate = Completer<void>();
    addTearDown(() {
      if (!gate.isCompleted) gate.complete();
    });
    final sdk = _AnalyticsFake(defaultGate: gate);
    final service = _started(sdk);
    await sdk.defaultsRequested.future;
    final pending = [
      for (var i = 0; i < 4; i++) service.logEvent(eventName: 'wallet_bulk_sync_completed'),
      for (var i = 0; i < 4; i++) service.logScreenView(screenName: AnalyticsScreenNames.splash),
    ];
    await Future<void>.delayed(Duration.zero);
    expect(sdk.receipts, isEmpty);
    gate.complete();
    await Future.wait(pending);
    expect(sdk.defaultCalls, 1);
    expect(sdk.receipts, hasLength(8));
    expect(sdk.order.first, 'defaults_applied');
    for (final receipt in sdk.receipts) {
      expect(receipt.effectiveKeys.intersection(_commonKeys), _commonKeys);
    }
  });

  test('an immediate first event waits even when PackageInfo is cached', () async {
    final sdk = _AnalyticsFake();
    final service = _started(sdk);
    await service.logEvent(eventName: 'wallet_bulk_sync_completed');
    expect(sdk.order, ['defaults_applied', 'wallet_bulk_sync_completed']);
    expect(sdk.receipts.single.effectiveKeys, _commonKeys);
  });

  test('typed event keeps boolean normalization while initialization is pending', () async {
    final gate = Completer<void>();
    addTearDown(() {
      if (!gate.isCompleted) gate.complete();
    });
    final sdk = _AnalyticsFake(defaultGate: gate);
    final service = _started(sdk);
    service.logWalletAddSyncCompleted(AnalyticsWalletType.hotWallet, hasHistory: true);
    await sdk.defaultsRequested.future;
    expect(sdk.receipts, isEmpty);
    gate.complete();
    await sdk.eventReceived.future;
    expect(sdk.receipts.single.parameters, {'wallet_type': 'hotWallet', 'has_history': 'true'});
    expect(sdk.receipts.single.effectiveKeys.intersection(_commonKeys), _commonKeys);
  });

  test('SDK default failure does not prevent current or subsequent event delivery', () async {
    final sdk = _AnalyticsFake(failDefaults: true);
    final service = _started(sdk);
    await Future.wait([
      service.logEvent(eventName: 'wallet_bulk_sync_completed'),
      service.logScreenView(screenName: AnalyticsScreenNames.splash),
    ]);
    await service.logEvent(eventName: 'wallet_bulk_sync_completed');
    expect(sdk.defaultCalls, 1);
    expect(sdk.receipts, hasLength(3));
  });

  test('SDK logging errors remain swallowed after successful initialization', () async {
    final sdk = _AnalyticsFake(failLogging: true);
    final service = _started(sdk);
    await service.logEvent(eventName: 'wallet_bulk_sync_completed');
    await service.logScreenView(screenName: AnalyticsScreenNames.splash);
    expect(sdk.defaultCalls, 1);
    expect(sdk.receipts, isEmpty);
  });

  test('disabled analytics skips initialization and all logging', () async {
    final sdk = _AnalyticsFake();
    final service = AnalyticsService(sdk, true);
    await service.logEvent(eventName: 'wallet_bulk_sync_completed');
    await service.logScreenView(screenName: AnalyticsScreenNames.splash);
    await service.setUserProperty(name: 'user_cohort', value: 'dormant');
    expect(sdk.defaultCalls, 0);
    expect(sdk.receipts, isEmpty);
    expect(sdk.properties, isEmpty);
  });

  test('null SDK remains a completed no-op without blocking callers', () async {
    final service = AnalyticsService(null, false);
    await service.logEvent(eventName: 'wallet_bulk_sync_completed');
    await service.logScreenView(screenName: AnalyticsScreenNames.splash);
    await service.setUserProperty(name: 'user_cohort', value: 'dormant');
  });

  // 수집 선택이 적용되기 전에는 사용자 속성도 보내지 않는다(PR #736 동의 게이트).
  test('user properties wait for the startup collection choice before sending', () async {
    final gate = Completer<void>();
    addTearDown(() {
      if (!gate.isCompleted) gate.complete();
    });
    final sdk = _AnalyticsFake(defaultGate: gate);
    final service = _started(sdk);
    await sdk.defaultsRequested.future;
    final property = service.setUserProperty(name: 'user_cohort', value: 'dormant');
    await Future<void>.delayed(Duration.zero);
    expect(sdk.properties, isEmpty);
    gate.complete();
    await property;
    expect(sdk.properties, {'user_cohort': 'dormant'});
  });

  testWidgets('first frame Navigator context reads its Provider and queues the splash without a drop', (tester) async {
    final gate = Completer<void>();
    addTearDown(() {
      if (!gate.isCompleted) gate.complete();
    });
    final sdk = _AnalyticsFake(defaultGate: gate);
    final key = GlobalKey<NavigatorState>();
    AnalyticsService? screenService;
    var callbacks = 0;
    final observer = AnalyticsScreenObserver(
      nameExtractor: (_) => AnalyticsScreenNames.splash,
      logScreenView: (name) {
        callbacks++;
        final navigatorContext = key.currentContext;
        expect(navigatorContext, isNotNull);
        expect(navigatorContext!.mounted, isTrue);
        screenService = navigatorContext.read<AnalyticsService>();
        screenService!.logScreenView(screenName: name);
      },
    );
    late AnalyticsService providedService;
    await tester.pumpWidget(
      Provider<AnalyticsService>(
        create: (_) => providedService = _started(sdk),
        child: CupertinoApp(navigatorKey: key, navigatorObservers: [observer], home: const _InitialScreen()),
      ),
    );
    expect(find.text('QA'), findsOneWidget);
    expect(callbacks, 1);
    expect(screenService, same(providedService));
    expect(sdk.receipts, isEmpty);
    gate.complete();
    await tester.pump();
    expect(sdk.receipts.single.name, 'screen_view');
    expect(sdk.receipts.single.effectiveKeys, _commonKeys);
    expect(callbacks, 1);
  });
}
