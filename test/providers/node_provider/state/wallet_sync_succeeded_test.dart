import 'dart:async';

import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/model/node/resync_progress.dart';
import 'package:coconut_wallet/model/node/wallet_fetch_progress.dart';
import 'package:coconut_wallet/model/node/wallet_update_info.dart';
import 'package:coconut_wallet/providers/node_provider/state/node_state_manager.dart';
import 'package:flutter_test/flutter_test.dart';

/// 목표 합계가 같은 계정 지갑의 잔액을 믿을지 정하는 지갑별 판정(B1-a). 지갑별 시각은 앱에 없어 상태만 본다.
void main() {
  late NodeStateManager state;
  late StreamController<NodeSyncState> nodeEvents;
  late StreamController<Map<int, WalletUpdateInfo>> walletEvents;
  late StreamController<Map<int, ResyncProgress>> resyncEvents;
  late StreamController<Map<int, WalletFetchProgress>> fetchEvents;

  setUp(() {
    nodeEvents = StreamController.broadcast();
    walletEvents = StreamController.broadcast();
    resyncEvents = StreamController.broadcast();
    fetchEvents = StreamController.broadcast();
    state = NodeStateManager(() {}, nodeEvents, walletEvents, resyncEvents, fetchEvents);
  });
  tearDown(() async {
    await Future.wait([nodeEvents.close(), walletEvents.close(), resyncEvents.close(), fetchEvents.close()]);
  });

  bool synced(int id, {bool connected = true}) =>
      isWalletSyncSucceeded(state.state.registeredWallets[id], isConnected: connected);

  test('a wallet counts as synced only after its queue finishes, and not while disconnected', () {
    state.initWalletUpdateStatus(1);
    expect(synced(1), isFalse);
    state.setWalletSyncQueueState(1, true, 100000);
    expect(synced(1), isFalse);
    state.setWalletSyncQueueState(1, false, 99000);
    expect(synced(1), isTrue);
    expect(synced(1, connected: false), isFalse);
  });

  test('a failed queue keeps the old snapshot but is not synced; the next successful queue clears the hold', () {
    state.initWalletUpdateStatus(1);
    state.setWalletSyncQueueState(1, true, 100000);
    state.setWalletSyncQueueState(1, false, 99000);
    state.setWalletSyncQueueState(1, true, 99000);
    // 실패: 스냅샷 없이 끝나면 옛 스냅샷이 남는다. 스냅샷이 있다고 성공은 아니다
    state.setWalletSyncQueueState(1, false, null);
    expect(state.state.registeredWallets[1]!.balanceSnapshot, 99000);
    expect(synced(1), isFalse);
    // 다시 연결돼 대기열이 성공으로 끝나면 대기가 풀린다
    state.setWalletSyncQueueState(1, true, 99000);
    state.setWalletSyncQueueState(1, false, 98000);
    expect(synced(1), isTrue);
  });
}
