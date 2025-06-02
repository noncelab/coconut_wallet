import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/auth_provider.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/upbit_connect_model.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:screen_capture_event/screen_capture_event.dart';

// 앱 root 화면(WalletListScreen)의 부모 위젯으로 설정하여 항상 활성화 된 위젯으로 유지
class AppGuard extends StatefulWidget {
  final Widget child;
  const AppGuard({super.key, required this.child});

  @override
  State<AppGuard> createState() => _AppGuardState();
}

class _AppGuardState extends State<AppGuard> with WidgetsBindingObserver {
  final Connectivity _connectivity = Connectivity();
  bool? _isNetworkOn;
  late UpbitConnectModel _upbitConnectModel;
  late AuthProvider _authProvider;
  late NodeProvider _nodeProvider;
  final ScreenCaptureEvent _screenListener = ScreenCaptureEvent();
  late ConnectivityProvider _connectivityProvider;
  bool _isPause = false;
  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _upbitConnectModel = Provider.of<UpbitConnectModel>(context, listen: false);
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
      // _showToastAboutNetwork(isNetworkOn);

      if (isNetworkOn) {
        _nodeProvider.reconnect();

        /// 네트워크가 꺼졌다가 다시 켜지면 시세를 위한 소켓을 연결함.
        _upbitConnectModel.initUpbitWebSocketService();
      } else {
        /// 네트워크 켜져있는 상태에서 꺼질 때 upbit provider dispose
        _upbitConnectModel.disposeUpbitWebSocketService();
      }
    }
  }

  // TODO: 아래를 주석처리 했기 때문에 네트워크 연결이 필요한 화면에서 별도 처리가 필요합니다.
  // void _showToastAboutNetwork(bool isNetworkOn) {
  //   if (!isNetworkOn) {
  //     CustomToast.showToast(
  //         context: context, text: "네트워크 연결이 없습니다.", seconds: 7);
  //   }
  // }

  // TODO: AppLifecycleListener로 교체시 didChangeAppLifecycleState는 삭제
  // @override
  // void didChangeAppLifecycleState(AppLifecycleState state) {
  //   super.didChangeAppLifecycleState(state);
  //   switch (state) {
  //     case AppLifecycleState.resumed:
  //       if (_isPause) {
  //         _isPause = false;
  //         _authProvider.checkDeviceBiometrics();
  //         if (_upbitConnectModel.upbitWebSocketService == null) {
  //           _upbitConnectModel.initUpbitWebSocketService();
  //         }
  //         _nodeProvider.initialize().then((_) => _nodeProvider.subscribeWallets(null));
  //       }
  //       break;
  //     case AppLifecycleState.hidden:
  //     case AppLifecycleState.detached:
  //     case AppLifecycleState.paused:
  //       if (_isPause) break;
  //       _isPause = true;
  //       _upbitConnectModel.disposeUpbitWebSocketService();
  //       _nodeProvider.closeConnection();
  //       break;
  //     case AppLifecycleState.inactive:
  //       break;
  //   }
  // }

  void _handleAppLifecycleState(AppLifecycleState state) {
    print('🔁 $state isPaused $_isPause');
    switch (state) {
      case AppLifecycleState.resumed:
        if (_isPause) {
          _isPause = false;
          _authProvider.checkDeviceBiometrics();
          if (_upbitConnectModel.upbitWebSocketService == null) {
            _upbitConnectModel.initUpbitWebSocketService();
          }
          _nodeProvider.initialize().then((_) => _nodeProvider.subscribeWallets(null));
        }
        break;
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
      case AppLifecycleState.paused:
        if (_isPause) break;
        _isPause = true;
        _upbitConnectModel.disposeUpbitWebSocketService();
        _nodeProvider.closeConnection();
        break;
      case AppLifecycleState.inactive:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _lifecycleListener.dispose();
    _screenListener.dispose();
    super.dispose();
  }
}
