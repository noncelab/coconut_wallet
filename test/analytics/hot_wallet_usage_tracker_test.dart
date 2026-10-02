import 'dart:async';

import 'package:coconut_wallet/analytics/hot_wallet_usage_tracker.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/wallet/hot_wallet_metadata.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/services/analytics_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

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

class _RecordingAnalyticsService extends AnalyticsService {
  _RecordingAnalyticsService() : super(null, true);

  final List<(String, String)> properties = [];

  @override
  Future<void> setUserProperty({required String name, required String value}) async {
    properties.add((name, value));
  }
}

void main() {
  late StreamController<NodeSyncState> syncState;
  late ValueNotifier<List<WalletItemBase>> walletList;
  late Set<int> walletsWithHistory;
  late _RecordingAnalyticsService analytics;
  late HotWalletUsageTracker tracker;

  Future<void> completeSync() async {
    syncState.add(NodeSyncState.completed);
    await Future<void>.delayed(Duration.zero);
  }

  setUp(() {
    syncState = StreamController<NodeSyncState>.broadcast();
    walletList = ValueNotifier([]);
    walletsWithHistory = {};
    analytics = _RecordingAnalyticsService();
    tracker = HotWalletUsageTracker(
      syncStateStream: syncState.stream,
      walletItemList: walletList,
      hasTransactionHistory: walletsWithHistory.contains,
      analyticsService: analytics,
    );
  });

  tearDown(() {
    tracker.dispose();
    syncState.close();
  });

  test('sends nothing before the first sync completes', () async {
    walletList.value = [_FakeWallet(1)];
    walletsWithHistory.add(1);
    syncState.add(NodeSyncState.syncing);
    await Future<void>.delayed(Duration.zero);

    expect(analytics.properties, isEmpty);
  });

  test('never sends false and sends true once a hot wallet has a transaction', () async {
    walletList.value = [_FakeWallet(1)];
    await completeSync();
    expect(analytics.properties, isEmpty);

    walletsWithHistory.add(1);
    await completeSync();
    await completeSync();

    expect(analytics.properties, [('hot_wallet_in_use', 'true')]);
  });

  test('ignores watch-only wallets with history', () async {
    walletList.value = [_FakeWallet(2, isHot: false)];
    walletsWithHistory.add(2);
    await completeSync();

    expect(analytics.properties, isEmpty);
  });

  test('does not send anything when the used hot wallet is removed later', () async {
    walletList.value = [_FakeWallet(3)];
    walletsWithHistory.add(3);
    await completeSync();

    walletList.value = [];
    walletsWithHistory.clear();
    await completeSync();

    expect(analytics.properties, [('hot_wallet_in_use', 'true')]);
  });
}
