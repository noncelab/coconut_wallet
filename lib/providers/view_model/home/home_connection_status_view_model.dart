import 'dart:async';

import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:flutter/foundation.dart';

const kHomeErrorDisplayDelayDuration = Duration(seconds: 5);
const kHomeReconnectedNoticeDuration = Duration(seconds: 2);

/// 새 홈 App Bar 왼쪽에 표시할 네트워크·동기화 상태.
///
/// 기존 홈(WalletHomeViewModel)의 연결 상태 판정과 같은 규칙을 쓴다. 구 홈을 지우는 0.12 이후에는 이 클래스만 남는다.
class HomeConnectionStatusViewModel extends ChangeNotifier {
  final ConnectivityProvider _connectivityProvider;
  final NodeProvider _nodeProvider;
  StreamSubscription<NodeSyncState>? _syncNodeStateSubscription;

  NodeSyncState _nodeSyncState = NodeSyncState.syncing;
  bool _isFirstLoaded = false;
  DateTime? _failedFromSyncingOrInitAt;
  Timer? _errorDisplayDelayTimer;
  final DateTime _createdAt = DateTime.now();
  bool _sawDisconnect = false;
  bool _showReconnected = false;
  bool _recoveryInterrupted = false;
  Timer? _reconnectedTimer;

  HomeConnectionStatusViewModel(this._connectivityProvider, this._nodeProvider) {
    _syncNodeStateSubscription = _nodeProvider.syncStateStream.listen(_handleNodeSyncState);
    _nodeProvider.addListener(_onNodeProviderChanged);
    _connectivityProvider.addListener(_onConnectivityChanged);
  }

  bool get showElectrumReconnected => _showReconnected;

  bool get isSyncing => (!_isFirstLoaded && _nodeSyncState == NodeSyncState.syncing) || _isInErrorDisplayDelay;

  NetworkStatus get networkStatus {
    if (_connectivityProvider.isInternetOff && _connectivityProvider.isVpnInactive) {
      return NetworkStatus.offline;
    }

    if (!_recoveryInterrupted &&
        (_nodeSyncState == NodeSyncState.completed ||
            _nodeSyncState == NodeSyncState.init ||
            _nodeSyncState == NodeSyncState.syncing ||
            _nodeProvider.isInitializing)) {
      return NetworkStatus.online;
    }

    if (_nodeSyncState == NodeSyncState.failed || _nodeProvider.hasConnectionError) {
      if (!_recoveryInterrupted && _isInErrorDisplayDelay) {
        return NetworkStatus.online;
      }
      if (_connectivityProvider.isVpnActive) {
        if (_connectivityProvider.isInternetOff) {
          return NetworkStatus.offline;
        }
        return NetworkStatus.vpnBlocked;
      }
      return NetworkStatus.connectionFailed;
    }

    return NetworkStatus.online;
  }

  bool get _isInErrorDisplayDelay {
    if (!_isFirstLoaded && (_nodeSyncState == NodeSyncState.failed || _nodeProvider.hasConnectionError)) {
      final now = DateTime.now();
      if (_failedFromSyncingOrInitAt != null &&
          now.difference(_failedFromSyncingOrInitAt!) < kHomeErrorDisplayDelayDuration) {
        return true;
      }
      if (now.difference(_createdAt) < kHomeErrorDisplayDelayDuration) {
        return true;
      }
    }
    return false;
  }

  void _onNodeProviderChanged() {
    if (_nodeProvider.hasConnectionError &&
        (_nodeSyncState == NodeSyncState.syncing || _nodeSyncState == NodeSyncState.init) &&
        !_isFirstLoaded &&
        _failedFromSyncingOrInitAt == null) {
      _startErrorDisplayDelay();
    }
    _refreshElectrumRecoveryNotice();
    notifyListeners();
  }

  void _onConnectivityChanged() {
    _refreshElectrumRecoveryNotice();
    notifyListeners();
  }

  void _startErrorDisplayDelay() {
    _failedFromSyncingOrInitAt = DateTime.now();
    _errorDisplayDelayTimer?.cancel();
    _errorDisplayDelayTimer = Timer(kHomeErrorDisplayDelayDuration, () {
      _clearErrorDisplayDelay();
      _refreshElectrumRecoveryNotice();
      notifyListeners();
    });
  }

  void _clearErrorDisplayDelay() {
    _errorDisplayDelayTimer?.cancel();
    _errorDisplayDelayTimer = null;
    _failedFromSyncingOrInitAt = null;
  }

  void _handleNodeSyncState(NodeSyncState syncState) {
    if (_nodeSyncState == syncState) {
      if (syncState == NodeSyncState.completed) _isFirstLoaded = true;
      return;
    }
    if (syncState == NodeSyncState.completed) {
      _isFirstLoaded = true;
      _clearErrorDisplayDelay();
    } else if (syncState == NodeSyncState.failed) {
      final wasSyncingOrInit = _nodeSyncState == NodeSyncState.syncing || _nodeSyncState == NodeSyncState.init;
      if (wasSyncingOrInit) {
        _startErrorDisplayDelay();
      } else {
        _clearErrorDisplayDelay();
      }
    } else if (syncState == NodeSyncState.syncing || syncState == NodeSyncState.init) {
      _clearErrorDisplayDelay();
    }
    _nodeSyncState = syncState;
    _refreshElectrumRecoveryNotice();
    notifyListeners();
  }

  void _refreshElectrumRecoveryNotice() {
    if (_showReconnected &&
        (_nodeSyncState == NodeSyncState.failed ||
            _nodeProvider.state.nodeSyncState == NodeSyncState.failed ||
            _nodeProvider.hasConnectionError)) {
      _recoveryInterrupted = true;
    }
    final disconnected = networkStatus != NetworkStatus.online;
    final connected =
        _nodeProvider.isConnected &&
        (_nodeSyncState == NodeSyncState.syncing || _nodeSyncState == NodeSyncState.completed);

    if (disconnected || (_showReconnected && !connected)) {
      _sawDisconnect = true;
      if (_showReconnected) {
        _showReconnected = false;
        _reconnectedTimer?.cancel();
        _reconnectedTimer = null;
      }
      return;
    }
    if (!_sawDisconnect || !connected || _showReconnected) return;

    _sawDisconnect = false;
    _recoveryInterrupted = false;
    _showReconnected = true;
    _reconnectedTimer?.cancel();
    _reconnectedTimer = Timer(kHomeReconnectedNoticeDuration, () {
      _reconnectedTimer = null;
      _showReconnected = false;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _errorDisplayDelayTimer?.cancel();
    _reconnectedTimer?.cancel();
    _syncNodeStateSubscription?.cancel();
    _connectivityProvider.removeListener(_onConnectivityChanged);
    _nodeProvider.removeListener(_onNodeProviderChanged);
    super.dispose();
  }
}
