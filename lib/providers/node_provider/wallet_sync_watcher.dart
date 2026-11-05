import 'dart:async';

import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/model/node/wallet_update_info.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';

/// 지갑 하나의 업데이트 상태를 구독하고 바뀔 때만 알림 (다른 지갑의 업데이트와는 무관)
class WalletSyncWatcher {
  final NodeProvider _nodeProvider;
  final void Function(bool isSyncing) _onChanged;
  late final StreamSubscription<NodeSyncState> _nodeSyncStateSubscription;
  StreamSubscription<WalletUpdateInfo>? _walletUpdateSubscription;
  late NodeSyncState _nodeSyncState;
  int? _walletId;
  WalletUpdateInfo? _walletUpdateInfo;
  bool _wasQueued = false;
  bool _isSyncing = false;
  bool _isWatching = false;
  bool _isDisposed = false;

  bool get isSyncing => _isSyncing;

  WalletSyncWatcher(this._nodeProvider, this._onChanged) {
    _nodeSyncState = _nodeProvider.state.nodeSyncState;
    _nodeSyncStateSubscription = _nodeProvider.syncStateStream.listen((nodeSyncState) {
      _nodeSyncState = nodeSyncState;
      _update();
    });
  }

  /// 구독할 지갑을 정하거나 바꿈 (상태는 바로 반영하고 알리지 않음)
  void watch(int walletId) {
    _walletUpdateSubscription?.cancel();
    _isWatching = true;
    _walletId = walletId;
    _walletUpdateInfo = _nodeProvider.state.registeredWallets[walletId];
    _wasQueued = _walletUpdateInfo?.isSyncQueued ?? false;
    _isSyncing = calculateWalletSyncing(_walletUpdateInfo, _nodeSyncState);
    _walletUpdateSubscription = _nodeProvider.getWalletStateStream(walletId).listen((walletUpdateInfo) {
      _walletUpdateInfo = walletUpdateInfo;
      _update();
    });
  }

  /// 이 지갑의 동기화 큐가 끝나면(실패로 끝나도) 대기 여부가 그대로여도 한 번 알려, 열린 화면이 바뀐 코인을 다시 맞추게
  /// 한다. 자동 재시도는 전체 상태를 실패로 둔 채 돌아서 대기 여부가 바뀌지 않기 때문. 대기 판단은 표시 기준
  /// ([calculateWalletSyncing]) 그대로라 재시도 때문에 새로 대기시키지는 않는다(큐 표시로 대기시키면 연결이 닫히거나
  /// 작업이 버려졌을 때 풀리지 않을 수 있음). 쓴 코인은 전송 전 확인과 예약이 막는다.
  /// 큐가 끝나는 한 번의 상태 변경은 전체 상태 알림이 지갑 알림보다 먼저 오므로, 큐 표시는 지금 상태에서 읽어 먼저 온
  /// 알림이 끝을 한 번만 처리하게 한다(대기 판단 자체는 그대로).
  void _update() {
    if (_isDisposed || !_isWatching) return;
    final isQueued = (_nodeProvider.state.registeredWallets[_walletId] ?? _walletUpdateInfo)?.isSyncQueued ?? false;
    final queueFinished = _wasQueued && !isQueued;
    _wasQueued = isQueued;
    final isSyncing = calculateWalletSyncing(_walletUpdateInfo, _nodeSyncState);
    if (isSyncing == _isSyncing && !(queueFinished && !isSyncing)) return;
    _isSyncing = isSyncing;
    _onChanged(isSyncing);
  }

  void dispose() {
    _isDisposed = true;
    _nodeSyncStateSubscription.cancel();
    _walletUpdateSubscription?.cancel();
  }
}
