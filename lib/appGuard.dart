import 'package:coconut_wallet/providers/upbit_connect_model.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:coconut_wallet/providers/app_state_model.dart';
import 'package:coconut_wallet/providers/app_sub_state_model.dart';
import 'package:coconut_wallet/widgets/custom_toast.dart';
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
  late AppStateModel _appStateModel;
  late AppSubStateModel _appSubModel;
  late UpbitConnectModel _upbitConnectModel;
  final ScreenCaptureEvent _screenListener = ScreenCaptureEvent();

  bool _isPause = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _appStateModel = Provider.of<AppStateModel>(context, listen: false);
    _appSubModel = Provider.of<AppSubStateModel>(context, listen: false);
    _upbitConnectModel = Provider.of<UpbitConnectModel>(context, listen: false);
    _connectivity.onConnectivityChanged.listen(_checkConnectivity);
    _screenListener.addScreenShotListener((_) {
      CustomToast.showToast(
          context: context, text: '스크린 캡처가 감지되었습니다.', seconds: 4);
    });
    _screenListener.watch();
  }

  void _checkConnectivity(List<ConnectivityResult> result) {
    bool isNetworkOn = !result.contains(ConnectivityResult.none);

    if (_isNetworkOn != isNetworkOn) {
      _appStateModel.setIsNetworkOn(isNetworkOn);
      _isNetworkOn = isNetworkOn;
      _showToastAboutNetwork(isNetworkOn);

      if (isNetworkOn) {
        /// 네트워크가 꺼졌다가 다시 켜지면 시세를 위한 소켓을 연결함.
        _upbitConnectModel.initUpbitWebSocketService();
      } else {
        /// 네트워크 켜져있는 상태에서 꺼질 때 upbit provider dispose
        _upbitConnectModel.disposeUpbitWebSocketService();
      }
    }
  }

  void _showToastAboutNetwork(bool isNetworkOn) {
    if (!isNetworkOn) {
      CustomToast.showToast(
          context: context, text: "네트워크 연결이 없습니다.", seconds: 7);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.resumed:
        if (_isPause) {
          _isPause = false;
          _appSubModel.checkDeviceBiometrics();
          // if (_appStateModel.nodeConnection == null) {
          //   _appStateModel.initWallet();
          // }
          if (_upbitConnectModel.upbitWebSocketService == null) {
            _upbitConnectModel.initUpbitWebSocketService();
          }
        }
        break;
      case AppLifecycleState.hidden:
      case AppLifecycleState.inactive:
        break;
      case AppLifecycleState.detached:
      case AppLifecycleState.paused:
        _isPause = true;
        _appStateModel.disposeNodeConnector();
        _upbitConnectModel.disposeUpbitWebSocketService();
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
    _screenListener.dispose();
    super.dispose();
  }
}
