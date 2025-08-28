import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/auth_provider.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/price_provider.dart';
import 'package:coconut_wallet/utils/file_logger.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:screen_capture_event/screen_capture_event.dart';

// 앱 root 화면(WalletListScreen)의 부모 위젯으로 설정하여 항상 활성화 된 위젯으로 유지
class AppGuard extends StatefulWidget {
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
    switch (state) {
      case AppLifecycleState.resumed:
        if (_isPaused) {
          setState(() {
            _isPaused = false;
          });
          _authProvider.checkDeviceBiometrics();
          _priceProvider.initWebSocketService();
          // 노드 연결이 필요하지 않다면 연결하지 않음
          // TODO _nodeProvider.hasConnectionError 이 값으로 보장 가능?
          if (_nodeProvider.hasConnectionError) {
            _nodeProvider.reconnect();
          }
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
        // 무조건 연결 끊던 것을 주석처리 해놓음
        // unawaited(_nodeProvider.closeConnection());
        break;
      case AppLifecycleState.inactive:
        setState(() {
          _isPaused = true;
        });
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      widget.child,
      if (_isPaused)
        Container(
          color: CoconutColors.black,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/images/splash_logo_$appFlavor.png',
                  width: 48,
                  height: 48,
                ),
              ],
            ),
          ),
        ),
    ]);
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    _screenListener.dispose();
    super.dispose();
  }
}
