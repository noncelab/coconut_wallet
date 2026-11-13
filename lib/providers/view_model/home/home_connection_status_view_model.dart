import 'dart:async';

import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/providers/ark_provider.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:flutter/foundation.dart';

const kHomeErrorDisplayDelayDuration = Duration(seconds: 5);
const kHomeConnectedNoticeDuration = Duration(seconds: 1);
const kHomeUpdateCompletedNoticeDuration = Duration(seconds: 2);

enum _StatusPhase { none, waitingForConnection, connected, updating, completed }

/// 새 홈 App Bar 왼쪽에 표시할 네트워크·동기화 상태.
/// 첫 진입·당겨서 새로고침·연결 복구 때 연결됨 → 업데이트 중 → 업데이트 완료 순서로 표시
class HomeConnectionStatusViewModel extends ChangeNotifier {
  final ConnectivityProvider _connectivityProvider;
  final NodeProvider _nodeProvider;
  final ArkProvider? _arkProvider;
  final ValueListenable<List<WalletItemBase>> _walletItemListNotifier;
  StreamSubscription<NodeSyncState>? _syncNodeStateSubscription;

  NodeSyncState _nodeSyncState = NodeSyncState.syncing;
  bool _isFirstLoaded = false;
  Timer? _errorDisplayDelayTimer;
  Timer? _initialErrorDisplayDelayTimer;
  bool _sawDisconnect = false;
  bool _recoveryInterrupted = false;
  _StatusPhase _phase = _StatusPhase.none;
  Timer? _phaseTimer;
  bool _waitForDisconnect = false;
  Future<void>? _refreshing;
  bool _startingRefresh = false;
  bool _isRefreshing = false;
  bool _isDisposed = false;

  HomeConnectionStatusViewModel(
    this._connectivityProvider,
    this._nodeProvider,
    this._walletItemListNotifier, {
    ArkProvider? arkProvider,
    bool showsInitialStatus = true,
  }) : _arkProvider = arkProvider {
    _initialErrorDisplayDelayTimer = Timer(kHomeErrorDisplayDelayDuration, () {
      _initialErrorDisplayDelayTimer = null;
      _refreshElectrumRecoveryNotice();
      notifyListeners();
    });
    _syncNodeStateSubscription = _nodeProvider.syncStateStream.listen(_handleNodeSyncState);
    _nodeProvider.addListener(_onNodeProviderChanged);
    _connectivityProvider.addListener(_onConnectivityChanged);
    _walletItemListNotifier.addListener(_onWalletsChanged);
    if (showsInitialStatus) _phase = _StatusPhase.waitingForConnection;
  }

  bool get showElectrumReconnected => _phase == _StatusPhase.connected;
  bool get showUpdateCompleted => _phase == _StatusPhase.completed;

  bool get isSyncing => _hasWallets && (_phase == _StatusPhase.updating || _isInErrorDisplayDelay);

  Future<void> refresh() {
    final refreshing = _refreshing;
    if (refreshing != null) return refreshing;
    _startingRefresh = true;
    try {
      final walletsRefresh = _nodeProvider.refreshWallets();
      final arkRefresh = Future.wait([
        for (final wallet in _walletItemListNotifier.value)
          if (_arkProvider?.isOpen(wallet.id) ?? false) _arkProvider!.syncNow(wallet.id),
      ]);
      return _refreshing ??= _followRefresh(walletsRefresh, arkRefresh);
    } finally {
      _startingRefresh = false;
    }
  }

  Future<void> _followRefresh(Future<bool> walletsRefresh, [Future<List<void>>? arkRefresh]) async {
    _isRefreshing = true;
    if (_phase == _StatusPhase.none || _phase == _StatusPhase.completed) {
      if (_hasWallets && _nodeSyncState == NodeSyncState.syncing && _nodeProvider.isConnected) {
        _setPhase(_StatusPhase.updating);
      } else {
        _setPhase(_StatusPhase.waitingForConnection);
        _waitForDisconnect = true;
      }
    }
    notifyListeners();
    var refreshed = false;
    try {
      await Future.wait<void>([
        () async {
          refreshed = await walletsRefresh;
        }(),
        if (arkRefresh != null)
          () async {
            await arkRefresh;
          }(),
      ]);
    } finally {
      _isRefreshing = false;
      _refreshing = null;
      if (!_isDisposed) {
        if (_waitForDisconnect) {
          _waitForDisconnect = false;
          final online = networkStatus == NetworkStatus.online;
          if (online && refreshed && _nodeSyncState == NodeSyncState.completed) {
            _enterCompleted();
          } else if (online && _hasWallets && _nodeSyncState == NodeSyncState.syncing) {
            _setPhase(_StatusPhase.updating);
          } else {
            _setPhase(_StatusPhase.none);
          }
        } else if (!refreshed &&
            _nodeSyncState == NodeSyncState.completed &&
            (_phase == _StatusPhase.connected || _phase == _StatusPhase.updating)) {
          _setPhase(_StatusPhase.none);
        }
        _sawDisconnect = false;
        _refreshElectrumRecoveryNotice();
        notifyListeners();
      }
    }
  }

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

  bool get _isInErrorDisplayDelay =>
      !_isFirstLoaded &&
      (_nodeSyncState == NodeSyncState.failed || _nodeProvider.hasConnectionError) &&
      (_errorDisplayDelayTimer != null || _initialErrorDisplayDelayTimer != null);

  void _onNodeProviderChanged() {
    final walletsRefresh = _nodeProvider.walletsRefresh;
    if (walletsRefresh != null && _refreshing == null && !_startingRefresh) {
      _refreshing = _followRefresh(walletsRefresh);
    }
    if (_nodeProvider.hasConnectionError &&
        (_nodeSyncState == NodeSyncState.syncing || _nodeSyncState == NodeSyncState.init) &&
        !_isFirstLoaded &&
        _errorDisplayDelayTimer == null) {
      _startErrorDisplayDelay();
    }
    _refreshElectrumRecoveryNotice();
    notifyListeners();
  }

  void _onWalletsChanged() {
    _refreshElectrumRecoveryNotice();
    notifyListeners();
  }

  void _onConnectivityChanged() {
    _refreshElectrumRecoveryNotice();
    notifyListeners();
  }

  void _startErrorDisplayDelay() {
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
  }

  void _handleNodeSyncState(NodeSyncState syncState) {
    if (_nodeSyncState == syncState) {
      if (syncState == NodeSyncState.completed) _isFirstLoaded = true;
      _refreshElectrumRecoveryNotice();
      notifyListeners();
      return;
    }
    if (syncState == NodeSyncState.completed) {
      _isFirstLoaded = true;
      _clearErrorDisplayDelay();
      _initialErrorDisplayDelayTimer?.cancel();
      _initialErrorDisplayDelayTimer = null;
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
    final connected =
        _nodeProvider.isConnected &&
        (_nodeSyncState == NodeSyncState.syncing || _nodeSyncState == NodeSyncState.completed);
    if (_isRefreshing) {
      if (_waitForDisconnect) {
        if (!connected) _waitForDisconnect = false;
        return;
      }
      if (_phase == _StatusPhase.waitingForConnection && connected && _hasWallets) {
        _enterConnected();
      }
      return;
    }
    if (_phase == _StatusPhase.connected &&
        (_nodeSyncState == NodeSyncState.failed ||
            _nodeProvider.state.nodeSyncState == NodeSyncState.failed ||
            _nodeProvider.hasConnectionError)) {
      _recoveryInterrupted = true;
    }
    final disconnected = networkStatus != NetworkStatus.online;
    if (disconnected || (_phase == _StatusPhase.connected && !connected)) {
      _sawDisconnect = true;
      _setPhase(_StatusPhase.none);
      return;
    }
    if (!connected) return;
    if ((_phase == _StatusPhase.waitingForConnection && _hasWallets) ||
        (_sawDisconnect && _phase == _StatusPhase.none)) {
      _sawDisconnect = false;
      _recoveryInterrupted = false;
      _enterConnected();
    } else if (_phase == _StatusPhase.updating && _nodeSyncState == NodeSyncState.completed) {
      _enterCompleted();
    }
  }

  bool get _hasWallets => _walletItemListNotifier.value.isNotEmpty;

  void _setPhase(_StatusPhase phase, [Duration? duration, void Function()? onEnd]) {
    _phaseTimer?.cancel();
    _phaseTimer = null;
    _phase = phase;
    if (duration != null && onEnd != null) {
      _phaseTimer = Timer(duration, () {
        _phaseTimer = null;
        onEnd();
        notifyListeners();
      });
    }
  }

  void _enterConnected() {
    _setPhase(_StatusPhase.connected, kHomeConnectedNoticeDuration, () {
      if (!_isRefreshing && _nodeSyncState == NodeSyncState.completed) {
        _enterCompleted();
      } else {
        _setPhase(_StatusPhase.updating);
      }
    });
  }

  void _enterCompleted() {
    _setPhase(_StatusPhase.completed, kHomeUpdateCompletedNoticeDuration, () => _setPhase(_StatusPhase.none));
  }

  @override
  void dispose() {
    _isDisposed = true;
    _phaseTimer?.cancel();
    _errorDisplayDelayTimer?.cancel();
    _initialErrorDisplayDelayTimer?.cancel();
    _syncNodeStateSubscription?.cancel();
    _walletItemListNotifier.removeListener(_onWalletsChanged);
    _connectivityProvider.removeListener(_onConnectivityChanged);
    _nodeProvider.removeListener(_onNodeProviderChanged);
    super.dispose();
  }
}
