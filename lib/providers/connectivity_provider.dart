import 'dart:async';

import 'package:coconut_wallet/utils/logger.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:vpn_detector/vpn_detector.dart';

/// 디바이스 네트워크 연결 상태를 관리하는 Provider
/// - 인터넷 연결 상태
/// - VPN 연결 상태
class ConnectivityProvider extends ChangeNotifier {
  final Connectivity _connectivity;
  final VpnDetector _vpnDetector;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  StreamSubscription<VpnStatus>? _vpnSubscription;

  bool _isInternetOn = true;
  bool _isVpnActive = false;

  bool get isInternetOff => !_isInternetOn;
  bool get isInternetOn => _isInternetOn;
  bool get isVpnActive => _isVpnActive;
  bool get isVpnInactive => !_isVpnActive;

  ConnectivityProvider({Connectivity? connectivity, VpnDetector? vpnDetector})
    : _connectivity = connectivity ?? Connectivity(),
      _vpnDetector = vpnDetector ?? VpnDetector() {
    _initialize();
  }

  void _initialize() {
    // 초기 상태 확인
    _checkInitialConnectivity();
    _checkInitialVpnStatus();

    // 네트워크 변경 감지
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      _handleConnectivityChanged,
      onError: (error) {
        Logger.error('ConnectivityProvider: Connectivity stream error: $error');
      },
    );

    // VPN 변경 감지
    _vpnSubscription = _vpnDetector.onVpnStatusChanged.listen(
      _handleVpnStatusChanged,
      onError: (error) {
        Logger.error('ConnectivityProvider: VPN stream error: $error');
      },
    );
  }

  Future<void> _checkInitialConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity();
      _handleConnectivityChanged(result);
    } catch (e) {
      Logger.error('ConnectivityProvider: Failed to check initial connectivity: $e');
    }
  }

  Future<void> _checkInitialVpnStatus() async {
    try {
      final status = await _vpnDetector.isVpnActive();
      _handleVpnStatusChanged(status);
    } catch (e) {
      Logger.error('ConnectivityProvider: Failed to check initial VPN status: $e');
    }
  }

  /// 네트워크 변경 처리
  void _handleConnectivityChanged(List<ConnectivityResult> result) {
    Logger.log('ConnectivityProvider: Connectivity changed: $result');

    // 실제 인터넷 연결만 체크 (WiFi, Ethernet, Mobile)
    final isNetworkOn = result.any(
      (r) => r == ConnectivityResult.wifi || r == ConnectivityResult.ethernet || r == ConnectivityResult.mobile,
    );

    // VPN도 ConnectivityResult로 감지될 수 있음
    final vpnDetected = result.contains(ConnectivityResult.vpn);

    _updateInternetState(isNetworkOn);

    if (vpnDetected) {
      _updateVpnState(true);
    }
  }

  void _handleVpnStatusChanged(VpnStatus status) {
    Logger.log('ConnectivityProvider: VPN status changed: ${status.name}');
    _updateVpnState(status == VpnStatus.active);
  }

  void _updateInternetState(bool isOn) {
    if (_isInternetOn != isOn) {
      _isInternetOn = isOn;
      Logger.log('ConnectivityProvider: Internet ${isOn ? "ON" : "OFF"}');
      notifyListeners();
    }
  }

  void _updateVpnState(bool isActive) {
    if (_isVpnActive != isActive) {
      _isVpnActive = isActive;
      Logger.log('ConnectivityProvider: VPN ${isActive ? "ACTIVE" : "INACTIVE"}');
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _vpnSubscription?.cancel();
    super.dispose();
  }
}
