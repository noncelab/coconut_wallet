import 'dart:async';

import 'package:coconut_wallet/analytics/hot_wallet_usage_tracker.dart';
import 'package:coconut_wallet/constants/shared_pref_keys.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/wallet/hot_wallet_metadata.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:coconut_wallet/services/analytics_service.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeWallet extends WalletItemBase {
  _FakeWallet(int id, {bool isHot = true})
    : hotWalletMetadata =
          isHot
              ? HotWalletMetadata(
                walletId: id,
                secureStorageKey: '',
                masterFingerprint: '',
                derivationPath: '',
                accountIndex: 0,
                backupVerified: false,
                enterPassphraseWhenSigning: false,
                createdAt: DateTime(2026, 1, 1),
              )
              : null,
      super(
        id: id,
        name: 'wallet $id',
        colorIndex: 0,
        iconIndex: 0,
        descriptor: '',
        walletType: WalletType.singleSignature,
        walletImportSource: WalletImportSource.coconutVault,
      );

  @override
  final HotWalletMetadata? hotWalletMetadata;
}

class _ControlledSdk extends Fake implements FirebaseAnalytics {
  final List<(String, String)> properties = [];
  Completer<void>? propertyGate;
  bool failProperty = false;
  int propertyCalls = 0;

  @override
  Future<void> setAnalyticsCollectionEnabled(bool enabled) async {}

  @override
  Future<void> setDefaultEventParameters(Map<String, Object?>? defaultParameters) async {}

  @override
  Future<void> setUserProperty({
    required String name,
    required String? value,
    AnalyticsCallOptions? callOptions,
  }) async {
    propertyCalls++;
    await propertyGate?.future;
    if (failProperty) throw StateError('SDK property failed');
    if (value != null) properties.add((name, value));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StreamController<NodeSyncState> syncState;
  late ValueNotifier<List<WalletItemBase>> walletList;
  late Set<int> walletsWithHistory;
  late _ControlledSdk sdk;
  late AnalyticsService analytics;
  late HotWalletUsageTracker tracker;

  Future<void> completeSync() async {
    syncState.add(NodeSyncState.completed);
    await Future<void>.delayed(Duration.zero);
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SharedPrefsRepository().init();
    syncState = StreamController<NodeSyncState>.broadcast();
    walletList = ValueNotifier([]);
    walletsWithHistory = {};
    sdk = _ControlledSdk();
    analytics = AnalyticsService(sdk, false, commonParametersLoader: () async => const {});
    await analytics.initialize();
    tracker = HotWalletUsageTracker(
      syncStateStream: syncState.stream,
      walletItemList: walletList,
      hasTransactionHistory: walletsWithHistory.contains,
      analyticsService: analytics,
    );
  });

  tearDown(() async {
    tracker.dispose();
    await syncState.close();
    walletList.dispose();
  });

  test('sends nothing before the first sync completes', () async {
    walletList.value = [_FakeWallet(1)];
    walletsWithHistory.add(1);
    syncState.add(NodeSyncState.syncing);
    await Future<void>.delayed(Duration.zero);

    expect(sdk.properties, isEmpty);
  });

  test('never sends false and sends true once a hot wallet has a transaction', () async {
    walletList.value = [_FakeWallet(1)];
    await completeSync();
    expect(sdk.properties, isEmpty);

    walletsWithHistory.add(1);
    await completeSync();
    await completeSync();

    expect(sdk.properties, [('hot_wallet_in_use', 'true')]);
  });

  test('ignores watch-only wallets with history', () async {
    walletList.value = [_FakeWallet(2, isHot: false)];
    walletsWithHistory.add(2);
    await completeSync();

    expect(sdk.properties, isEmpty);
  });

  test('does not send anything when the used hot wallet is removed later', () async {
    walletList.value = [_FakeWallet(3)];
    walletsWithHistory.add(3);
    await completeSync();

    walletList.value = [];
    walletsWithHistory.clear();
    await completeSync();

    expect(sdk.properties, [('hot_wallet_in_use', 'true')]);
  });

  test('an OFF sync does not prevent a new ON sync from setting the property', () async {
    await SharedPrefsRepository().setBool(SharedPrefKeys.kAnalyticsCollectionEnabled, false);
    await analytics.initialize();
    walletList.value = [_FakeWallet(1)];
    walletsWithHistory.add(1);

    await completeSync();
    expect(sdk.propertyCalls, 0);

    await analytics.setCollectionEnabled(true);
    expect(sdk.propertyCalls, 0);
    await completeSync();
    await completeSync();
    expect(sdk.properties, [('hot_wallet_in_use', 'true')]);
  });

  test('ON evaluates the current wallets on a new sync without replaying OFF usage', () async {
    await analytics.setCollectionEnabled(false);
    walletList.value = [_FakeWallet(1)];
    walletsWithHistory.add(1);
    await completeSync();
    walletList.value = [];
    walletsWithHistory.clear();

    await analytics.setCollectionEnabled(true);
    await completeSync();
    expect(sdk.propertyCalls, 0);
  });

  test('a failed SDK property call retries only on a new completed sync', () async {
    walletList.value = [_FakeWallet(1)];
    walletsWithHistory.add(1);
    sdk.failProperty = true;
    await completeSync();
    expect(sdk.properties, isEmpty);
    expect(sdk.propertyCalls, 1);

    sdk.failProperty = false;
    await Future<void>.delayed(Duration.zero);
    expect(sdk.propertyCalls, 1);
    await completeSync();
    await completeSync();
    expect(sdk.properties, [('hot_wallet_in_use', 'true')]);
    expect(sdk.propertyCalls, 2);
  });

  test('overlapping syncs make only one SDK property call while it is pending', () async {
    walletList.value = [_FakeWallet(1)];
    walletsWithHistory.add(1);
    sdk.propertyGate = Completer<void>();
    await completeSync();
    await completeSync();
    expect(sdk.propertyCalls, 1);
    expect(sdk.properties, isEmpty);

    sdk.propertyGate!.complete();
    await completeSync();
    expect(sdk.propertyCalls, 1);
    expect(sdk.properties, [('hot_wallet_in_use', 'true')]);
  });

  test('dispose stops new syncs and a pending failure does not schedule a retry', () async {
    walletList.value = [_FakeWallet(1)];
    walletsWithHistory.add(1);
    sdk.propertyGate = Completer<void>();
    sdk.failProperty = true;
    await completeSync();
    tracker.dispose();
    sdk.propertyGate!.complete();
    await completeSync();
    sdk.failProperty = false;
    await completeSync();
    expect(sdk.propertyCalls, 1);
    expect(sdk.properties, isEmpty);
  });

  test('deferred OFF does not latch usage; explicit ON and a new sync send exactly once', () async {
    tracker.dispose();
    await SharedPrefsRepository().setAnalyticsCollectionEnabled(false);
    var activations = 0;
    analytics = AnalyticsService(
      null,
      false,
      commonParametersLoader: () async => const {},
      deferredBackend: DeferredAnalyticsBackend(
        activate: () async {
          activations++;
          return sdk;
        },
        disableIfActive: () async {},
      ),
    );
    await analytics.initialize();
    tracker = HotWalletUsageTracker(
      syncStateStream: syncState.stream,
      walletItemList: walletList,
      hasTransactionHistory: walletsWithHistory.contains,
      analyticsService: analytics,
    );
    walletList.value = [_FakeWallet(1)];
    walletsWithHistory.add(1);
    await completeSync();
    expect(sdk.propertyCalls, 0);
    expect(activations, 0);
    await analytics.setCollectionEnabled(true);
    expect(sdk.propertyCalls, 0);
    expect(activations, 1);
    await completeSync();
    await completeSync();
    expect(sdk.properties, [('hot_wallet_in_use', 'true')]);
    expect(sdk.propertyCalls, 1);
  });
}
