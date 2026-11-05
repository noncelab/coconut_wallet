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
  WalletUpdateInfo? _walletUpdateInfo;
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
    _walletUpdateInfo = _nodeProvider.state.registeredWallets[walletId];
    _isSyncing = calculateWalletSyncing(_walletUpdateInfo, _nodeSyncState);
    _walletUpdateSubscription = _nodeProvider.getWalletStateStream(walletId).listen((walletUpdateInfo) {
      final queueFinished = (_walletUpdateInfo?.isSyncQueued ?? false) && !walletUpdateInfo.isSyncQueued;
      _walletUpdateInfo = walletUpdateInfo;
      _update(queueFinished: queueFinished);
    });
  }

  /// [queueFinished]: 이 지갑의 동기화 큐가 끝남(실패로 끝나도). 자동 재시도는 전체 상태를 실패로 둔 채 돌아서 대기
  /// 여부가 바뀌지 않으므로, 그때도 끝났다고 알려 열린 화면이 바뀐 코인을 다시 맞추게 한다. 재시도 중에 대기시키지는
  /// 않는다(연결이 닫히거나 작업이 버려지면 대기가 풀리지 않을 수 있음). 쓴 코인은 전송 전 확인과 예약이 막는다.
  void _update({bool queueFinished = false}) {
    if (_isDisposed || !_isWatching) return;
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
