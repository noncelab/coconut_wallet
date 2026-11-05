import 'dart:async';

import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/model/node/node_provider_state.dart';
import 'package:coconut_wallet/model/node/resync_progress.dart';
import 'package:coconut_wallet/model/node/wallet_fetch_progress.dart';
import 'package:coconut_wallet/model/node/wallet_update_info.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/node_provider/state/node_state_manager.dart';
import 'package:coconut_wallet/providers/node_provider/wallet_sync_watcher.dart';
import 'package:flutter_test/flutter_test.dart';

/// 실제 상태 관리자를 쓰는 노드. [replaceStateManager]는 재연결처럼 상태 관리자를 새로 만든다.
class _Node extends Fake implements NodeProvider {
  final _nodeEvents = StreamController<NodeSyncState>.broadcast();
  final _walletEvents = StreamController<Map<int, WalletUpdateInfo>>.broadcast();
  final _resyncEvents = StreamController<Map<int, ResyncProgress>>.broadcast();
  final _fetchEvents = StreamController<Map<int, WalletFetchProgress>>.broadcast();
  late NodeStateManager manager = _createManager();

  NodeStateManager _createManager() => NodeStateManager(() {}, _nodeEvents, _walletEvents, _resyncEvents, _fetchEvents);

  void replaceStateManager() => manager = _createManager();

  @override
  NodeProviderState get state => manager.state;
  @override
  Stream<NodeSyncState> get syncStateStream => _nodeEvents.stream;
  @override
  Stream<WalletUpdateInfo> getWalletStateStream(int walletId) =>
      _walletEvents.stream.where((wallets) => wallets.containsKey(walletId)).map((wallets) => wallets[walletId]!);
}

void main() {
  late _Node node;
  late List<bool> changes;
  late WalletSyncWatcher watcher;

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  /// 평소 동기화가 실패해 전체 상태가 실패로 남은 지갑 (자동 재시도는 아직 시작 전)
  Future<void> failedWallet(int walletId) async {
    node.manager.initWalletUpdateStatus(walletId);
    node.manager.setWalletSyncQueueState(walletId, false, 80000000);
    node.manager.setWalletSyncQueueState(walletId, true, 80000000);
    node.manager.setWalletSyncQueueState(walletId, false, null);
    await settle();
    expect(node.state.nodeSyncState, NodeSyncState.failed);
  }

  /// ScriptSyncService._startRetry → runQueued와 같은 순서
  Future<void> startRetry() async {
    node.manager.setWalletRetrying(1, true);
    node.manager.setWalletSyncQueueState(1, true, 80000000);
    await settle();
    expect(node.state.nodeSyncState, NodeSyncState.failed, reason: '홈 상태는 재시도 중에도 실패로 둔다');
  }

  Future<void> finishRetry({required bool success}) async {
    node.manager.setWalletRetrying(1, false);
    node.manager.setWalletSyncQueueState(1, false, success ? 50000000 : null);
    await settle();
  }

  setUp(() {
    node = _Node();
    changes = [];
    watcher = WalletSyncWatcher(node, changes.add);
  });
  tearDown(() => watcher.dispose());

  for (final success in [false, true]) {
    for (final otherWalletFailed in [false, true]) {
      test('자동 재시도가 끝나면 대기 여부가 그대로여도 한 번 알려 코인을 다시 맞추게 한다 '
          '(성공=$success, 다른 지갑 실패=$otherWalletFailed)', () async {
        if (otherWalletFailed) await failedWallet(2);
        await failedWallet(1);
        watcher.watch(1);
        await startRetry();
        expect(watcher.isSyncing, isFalse, reason: '재시도 중에는 대기시키지 않는다(풀리지 않는 대기 방지)');
        expect(changes, isEmpty);

        await finishRetry(success: success);
        expect(watcher.isSyncing, isFalse);
        // 성공해 전체 상태가 완료로 바뀌면 전체 상태 알림이 지갑 알림보다 먼저 와서 true가 잠깐 낀다(기존 순서).
        // 중요한 건 끝이 false이고, 다시 맞추기(false 알림)가 한 번뿐인 것.
        expect(changes.last, isFalse, reason: '끝날 때 알려야 열린 화면이 바뀐 코인을 다시 읽는다');
        expect(changes.where((isSyncing) => !isSyncing), hasLength(1), reason: '다시 맞추기는 한 번');
      });
    }
  }

  test('평소 동기화는 끝날 때 한 번만 알린다', () async {
    node.manager.initWalletUpdateStatus(1);
    node.manager.setWalletSyncQueueState(1, false, 80000000);
    await settle();
    watcher.watch(1);
    node.manager.setWalletSyncQueueState(1, true, 80000000);
    await settle();
    expect(watcher.isSyncing, isTrue);
    node.manager.setWalletSyncQueueState(1, false, 50000000);
    await settle();
    expect(changes, [true, false]);
  });

  /// 동기화가 끝난 지갑 (전체 상태 완료)
  Future<void> syncedWallet(int walletId) async {
    node.manager.initWalletUpdateStatus(walletId);
    node.manager.setWalletSyncQueueState(walletId, false, 80000000);
    await settle();
  }

  int reloads() => changes.where((isSyncing) => !isSyncing).length;

  test('평소 동기화가 실패로 끝나 전체 상태가 실패로 바뀌어도 한 번만 다시 맞춘다', () async {
    await syncedWallet(1);
    expect(node.state.nodeSyncState, NodeSyncState.completed);
    watcher.watch(1);
    node.manager.setWalletSyncQueueState(1, true, 80000000);
    await settle();
    node.manager.setWalletSyncQueueState(1, false, null);
    await settle();
    expect(node.state.nodeSyncState, NodeSyncState.failed);
    expect(changes, [true, false]);
  });

  test('다른 지갑이 실패 중일 때 평소 동기화가 성공으로 끝나도 한 번만 다시 맞춘다', () async {
    await failedWallet(2);
    await syncedWallet(1);
    watcher.watch(1);
    node.manager.setWalletSyncQueueState(1, true, 80000000);
    await settle();
    node.manager.setWalletSyncQueueState(1, false, 50000000);
    await settle();
    expect(node.state.nodeSyncState, NodeSyncState.failed);
    expect(reloads(), 1);
    expect(changes.last, isFalse);
  });

  test('재시도 뒤에 붙은 푸시까지 실패로 끝나도 큐가 끝날 때 한 번만 다시 맞춘다', () async {
    await failedWallet(1);
    watcher.watch(1);
    await startRetry();
    node.manager.setWalletRetrying(1, false); // 재시도 작업의 finally, 큐는 뒤에 붙은 푸시로 계속 돈다
    await settle();
    node.manager.initWalletUpdateStatus(1); // 푸시 작업의 진행
    node.manager.addWalletSyncState(1, UpdateElement.balance);
    await settle();
    node.manager.setWalletSyncQueueState(1, false, null);
    await settle();
    expect(reloads(), 1);
    expect(changes.last, isFalse);
  });

  test('재시도 도중 다른 지갑 때문에 한 번 다시 맞췄어도, 재시도가 끝나면 마지막으로 또 맞춘다', () async {
    await failedWallet(2);
    await failedWallet(1);
    watcher.watch(1);
    await startRetry();
    // 다른 지갑의 동기화가 돌다 실패하면 전체 상태가 동기화 중 → 실패로 바뀌어 대기가 켜졌다 꺼진다(재시도 도중)
    node.manager.setWalletSyncQueueState(2, true, 80000000);
    await settle();
    node.manager.setWalletSyncQueueState(2, false, null);
    await settle();
    expect(changes, [true, false]);
    await finishRetry(success: false);
    expect(changes, [true, false, false], reason: '재시도가 끝난 뒤의 코인으로 다시 맞춘다');
  });

  test('재시도 중 연결이 닫혀 끝 알림이 오지 않아도 대기에 묶이지 않는다', () async {
    await failedWallet(1);
    watcher.watch(1);
    await startRetry();
    node.replaceStateManager();
    node.manager.setNodeSyncStateToSyncing();
    node.manager.setNodeSyncStateToFailed();
    await settle();
    expect(watcher.isSyncing, isFalse);
  });
}
