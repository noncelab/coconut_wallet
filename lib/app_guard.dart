import 'dart:async';
import 'dart:io';

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/auth_provider.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/price_provider.dart';
import 'package:coconut_wallet/utils/file_logger.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:screen_capture_event/screen_capture_event.dart';

// 앱 root 화면(WalletListScreen)의 부모 위젯으로 설정하여 항상 활성화 된 위젯으로 유지
class AppGuard extends StatefulWidget {
  static bool _isPrivacyEnabled = true;

  /// 화면보호기 활성화 여부를 반환합니다.
  static bool get isPrivacyEnabled => _isPrivacyEnabled;

  /// 화면보호기를 활성화합니다.
  static void enablePrivacyScreen() {
    _isPrivacyEnabled = true;
  }

  /// 화면보호기를 비활성화합니다.
  static void disablePrivacyScreen() {
    _isPrivacyEnabled = false;
  }

  final Widget child;
  const AppGuard({super.key, required this.child});

  @override
  State<AppGuard> createState() => _AppGuardState();
}

class _AppGuardState extends State<AppGuard> {
  final Connectivity _connectivity = Connectivity();
  bool? _isNetworkOn;
  late PriceProvider _priceProvider;
  late AuthProvider _authProvider;
  late NodeProvider _nodeProvider;
  final ScreenCaptureEvent _screenListener = ScreenCaptureEvent();
  late ConnectivityProvider _connectivityProvider;
  bool _isPaused = false;
  late final AppLifecycleListener _lifecycleListener;

  /// 안드로이드에서 앱 실행 시 홈화면 시작 후, inactive -> resume이 항상 한번 실행되면서 PrivacyScreen이 보이는 문제
  bool _isFirstInactiveSkipped = false;

  @override
  void initState() {
    super.initState();

    _priceProvider = Provider.of<PriceProvider>(context, listen: false);
    _nodeProvider = Provider.of<NodeProvider>(context, listen: false);
    _authProvider = Provider.of<AuthProvider>(context, listen: false);
    _connectivityProvider = Provider.of<ConnectivityProvider>(context, listen: false);
    _connectivity.onConnectivityChanged.listen(_checkConnectivity);

    _lifecycleListener = AppLifecycleListener(onStateChange: _handleAppLifecycleState);

    _screenListener.addScreenShotListener((_) {
      CoconutToast.showToast(
        context: context,
        text: t.toast.screen_capture,
        seconds: 4,
        isVisibleIcon: true,
        iconPath: 'assets/svg/triangle-warning.svg',
        iconSize: Sizes.size16,
      );
    });
    _screenListener.watch();
  }

  void _checkConnectivity(List<ConnectivityResult> result) {
    bool isNetworkOn = !result.contains(ConnectivityResult.none);

    if (_isNetworkOn != isNetworkOn) {
      _connectivityProvider.setIsNetworkOn(isNetworkOn);
      _isNetworkOn = isNetworkOn;
    }
  }

  void _handleAppLifecycleState(AppLifecycleState state) {
    /// 안드로이드에서 앱 실행 시 홈화면 시작 후, inactive -> resume이 항상 한번 실행되면서 PrivacyScreen이 보이는 문제
    if (Platform.isAndroid && !_isFirstInactiveSkipped) {
      _isFirstInactiveSkipped = true;
      return;
    }
    Logger.log('AppGuard: AppLifecycleState: $state / AppGuard._isPrivacyEnabled: ${AppGuard._isPrivacyEnabled}');
    switch (state) {
      case AppLifecycleState.resumed:
        if (_isPaused) {
          setState(() {
            _isPaused = false;
          });
          _authProvider.checkDeviceBiometrics();
          _priceProvider.initWebSocketService();
          _handleReconnect();
        }
        break;
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        FileLogger.dispose();
      case AppLifecycleState.paused:
        if (_isPaused) break;
        setState(() {
          _isPaused = true;
        });
        _priceProvider.disposeWebSocketService();
        _handleDisconnect();
        break;
      case AppLifecycleState.inactive:
        setState(() {
          _isPaused = true;
        });
        break;
    }
  }

  void _handleReconnect() {
    // 1. 이미 초기화되어 있고 연결이 정상인 경우 재연결하지 않음
    if (_nodeProvider.isInitialized &&
        !_nodeProvider.hasConnectionError &&
        _nodeProvider.state.nodeSyncState != NodeSyncState.failed) {
      Logger.log('AppGuard: Connection is healthy, skipping reconnect');
      return;
    }

    // 2. 연결 에러가 있거나 ping이 실패한 경우 재연결
    if (_nodeProvider.hasConnectionError || _nodeProvider.state.nodeSyncState == NodeSyncState.failed) {
      Logger.log('AppGuard: Connection issues detected, attempting reconnect');
      _nodeProvider.reconnect();
    }
  }

  void _handleDisconnect() {
    // 1. 네트워크가 끊어진 경우 연결 해제
    if (!_connectivityProvider.isNetworkOn) {
      Logger.log('AppGuard: Network disconnected, closing connection');
      unawaited(_nodeProvider.closeConnection());
      return;
    }

    // 2. 연결 에러가 있거나 ping이 실패한 경우 연결 해제
    if (_nodeProvider.hasConnectionError || _nodeProvider.state.nodeSyncState == NodeSyncState.failed) {
      Logger.log('AppGuard: Connection issues detected, closing connection');
      unawaited(_nodeProvider.closeConnection());
      return;
    }

    // 3. 그 외 연결 유지 (ping이 정상적으로 작동 중)
    Logger.log('AppGuard: Connection is healthy, keeping connection alive');
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.topLeft,
      children: [
        widget.child,
        if (_isPaused && AppGuard._isPrivacyEnabled)
          Container(
            color: CoconutColors.black,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [Image.asset('assets/images/splash_logo_$appFlavor.png', width: 48, height: 48)],
              ),
            ),
          ),
      ],
    );
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    _screenListener.dispose();
    super.dispose();
  }
}
