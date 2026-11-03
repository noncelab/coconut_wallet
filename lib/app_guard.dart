import 'dart:async';
import 'dart:io';
import 'package:coconut_wallet/constants/icon_path.dart';

import 'package:coconut_design_system/coconut_design_system.dart'
    hide CoconutToolTip, CoconutTooltipType, CoconutTooltipState, CoconutToast, CoconutToastLevel, CoconutPopup;
import 'package:coconut_wallet/ui/coconut/coconut_overlays.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/auth_provider.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/price_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/widgets/common/icon/coconut_logo_icon.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:screen_capture_event/screen_capture_event.dart';

/// 백그라운드 체류가 이보다 길었을 때만 resume 시 소켓 생존 여부 확인
const Duration _kBackgroundSocketHealthCheckThreshold = Duration(seconds: 30);

/// 백그라운드 체류가 이보다 길었으면 resume 시 모든 지갑을 다시 동기화
const Duration _kBackgroundResyncThreshold = Duration(minutes: 5);

enum ResumeConnectionCheck { none, probeSocket, resyncWallets }

/// 백그라운드 체류 시간에 따른 resume 시 연결 확인 방법
/// paused 시각은 resume 때 한 번만 쓰고 지움 (제어 센터 등 inactive → resumed에서 재사용 방지)
class BackgroundResumePolicy {
  final DateTime Function() _now;
  DateTime? _pausedAt;

  BackgroundResumePolicy({DateTime Function()? now}) : _now = now ?? DateTime.now;

  void onPaused() => _pausedAt = _now();

  ResumeConnectionCheck onResumed() {
    final pausedAt = _pausedAt;
    _pausedAt = null;
    if (pausedAt == null) return ResumeConnectionCheck.none;
    final backgroundDuration = _now().difference(pausedAt);
    if (backgroundDuration >= _kBackgroundResyncThreshold) return ResumeConnectionCheck.resyncWallets;
    if (backgroundDuration >= _kBackgroundSocketHealthCheckThreshold) return ResumeConnectionCheck.probeSocket;
    return ResumeConnectionCheck.none;
  }
}

// 앱 root 화면(HomeScreen)의 부모 위젯으로 설정하여 항상 활성화 된 위젯으로 유지
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

  /// 생체인증처럼 앱이 일시적으로 inactive 상태가 되는 작업 동안 화면보호기를
  /// 비활성화하고, 성공·취소·예외 여부와 관계없이 이전 상태로 복원합니다.
  static Future<T> runWithoutPrivacyScreen<T>(Future<T> Function() action) async {
    final wasPrivacyEnabled = _isPrivacyEnabled;
    disablePrivacyScreen();
    try {
      return await action();
    } finally {
      if (wasPrivacyEnabled) {
        enablePrivacyScreen();
      }
    }
  }

  /// 앱 복귀 때 NodeProvider 연결을 확인하고 필요하면 재연결한다.
  @visibleForTesting
  static Future<void> reconnectNodeOnResume(NodeProvider nodeProvider, ResumeConnectionCheck resumeCheck) async {
    // 0. 백그라운드에서 사라졌거나 걸지 못한 블록 확인을 되살리고 재연결 대기 간격을 처음으로 돌린다.
    // 아래에서 재연결하면 그 재연결이 타이머를 다시 정한다.
    nodeProvider.resumeBlockUpdates();

    // 1. 초기화가 진행 중이면 reconnect 무시
    if (nodeProvider.isInitializing) {
      Logger.log('AppGuard: NodeProvider is initializing, skipping reconnect');
      return;
    }

    // 2. 연결이 없으면(실패 상태로 백그라운드에 가며 연결을 닫은 경우 등) 다시 연결하고 지갑을 다시 구독한다.
    // initialize()만 하면 첫 초기화가 아닌 한 지갑을 구독하지 않아 동기화가 멈춘 채로 남는다.
    if (!nodeProvider.isInitialized) {
      Logger.log('AppGuard: NodeProvider is not initialized, reconnecting');
      nodeProvider.reconnectWhenIdle();
      return;
    }

    // 3. 초기 동기화(init/syncing) 중 reconnect 보류
    final nodeSyncState = nodeProvider.state.nodeSyncState;
    if (nodeSyncState == NodeSyncState.init || nodeSyncState == NodeSyncState.syncing) {
      Logger.log('AppGuard: NodeProvider is syncing, skipping reconnect');
      return;
    }

    // 4. 연결 에러가 있거나 ping이 실패한 경우 재연결
    if (nodeProvider.hasConnectionError || nodeSyncState == NodeSyncState.failed) {
      Logger.log('AppGuard: Connection issues detected, attempting reconnect');
      nodeProvider.reconnectWhenIdle();
      return;
    }

    // 5. 플래그가 정상이어도 백그라운드 체류가 길면 소켓이 끊겼거나 알림을 놓쳤을 수 있음
    // 5분 이상이면 전체 재동기화, 30초 이상이면 소켓 확인
    if (resumeCheck == ResumeConnectionCheck.resyncWallets) {
      Logger.log('AppGuard: Long background, resyncing all wallets');
      unawaited(nodeProvider.refreshWallets());
      return;
    }
    if (resumeCheck == ResumeConnectionCheck.none) {
      Logger.log('AppGuard: Connection is healthy, skipping reconnect');
      return;
    }

    final probe = await nodeProvider.getLatestBlock();
    if (probe.isFailure) {
      Logger.log('AppGuard: Long background + held socket probe failed, forcing reconnect');
      nodeProvider.reconnectWhenIdle();
    } else {
      Logger.log('AppGuard: Long background but held socket still alive, skipping reconnect');
    }
  }

  final Widget child;
  const AppGuard({super.key, required this.child});

  @override
  State<AppGuard> createState() => _AppGuardState();
}

class _AppGuardState extends State<AppGuard> {
  late PriceProvider _priceProvider;
  late AuthProvider _authProvider;
  late NodeProvider _nodeProvider;
  late WalletProvider _walletProvider;
  late ConnectivityProvider _connectivityProvider;
  final ScreenCaptureEvent _screenListener = ScreenCaptureEvent();
  bool _isPaused = false;
  final BackgroundResumePolicy _resumePolicy = BackgroundResumePolicy();
  late final AppLifecycleListener _lifecycleListener;

  /// 안드로이드에서 앱 실행 시 홈화면 시작 후, inactive -> resume이 항상 한번 실행되면서 PrivacyScreen이 보이는 문제
  bool _isFirstInactiveSkipped = false;

  @override
  void initState() {
    super.initState();

    _priceProvider = Provider.of<PriceProvider>(context, listen: false);
    _nodeProvider = Provider.of<NodeProvider>(context, listen: false);
    _walletProvider = Provider.of<WalletProvider>(context, listen: false);
    _authProvider = Provider.of<AuthProvider>(context, listen: false);
    _connectivityProvider = Provider.of<ConnectivityProvider>(context, listen: false);

    _lifecycleListener = AppLifecycleListener(onStateChange: _handleAppLifecycleState);

    _screenListener.addScreenShotListener((_) {
      CoconutToast.showToast(
        context: context,
        text: t.toast.screen_capture,
        seconds: 4,
        isVisibleIcon: true,
        iconPath: CommonStateIconPath.triangleWarning,
        iconSize: Sizes.size16,
      );
    });
    _screenListener.watch();
  }

  Future<void> _handleAppLifecycleState(AppLifecycleState state) async {
    /// 안드로이드에서 앱 실행 시 홈화면 시작 후, inactive -> resume이 항상 한번 실행되면서 PrivacyScreen이 보이는 문제
    if (Platform.isAndroid && !_isFirstInactiveSkipped) {
      _isFirstInactiveSkipped = true;
      return;
    }
    Logger.log('AppGuard: AppLifecycleState: $state / AppGuard._isPrivacyEnabled: ${AppGuard._isPrivacyEnabled}');
    switch (state) {
      case AppLifecycleState.resumed:
        final resumeCheck = _resumePolicy.onResumed();
        await _connectivityProvider.refreshConnectivity();
        if (_isPaused) {
          setState(() {
            _isPaused = false;
          });
          _authProvider.checkDeviceBiometrics();
          _priceProvider.initWebSocketService(force: true);
        } else {
          _authProvider.checkDeviceBiometrics();
          _priceProvider.initWebSocketService();
        }
        _handleNodeProviderReconnect(resumeCheck);
        for (final wallet in _walletProvider.walletItemList) {
          unawaited(_nodeProvider.syncDormantAddresses(wallet));
        }
        break;
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        break;
      case AppLifecycleState.paused:
        _resumePolicy.onPaused();
        if (_isPaused) break;
        setState(() {
          _isPaused = true;
        });
        _priceProvider.disposeWebSocketService();
        _handleNodeProviderDisconnect();
        break;
      case AppLifecycleState.inactive:
        setState(() {
          _isPaused = true;
        });
        break;
    }
  }

  /// NodeProvider 재연결
  Future<void> _handleNodeProviderReconnect(ResumeConnectionCheck resumeCheck) =>
      AppGuard.reconnectNodeOnResume(_nodeProvider, resumeCheck);

  /// NodeProvider 연결 해제
  void _handleNodeProviderDisconnect() {
    // 초기화 중/미초기화 상태에서 연결 해제 시도 시 연결 해제 무시
    if (_nodeProvider.isInitializing || !_nodeProvider.isInitialized) {
      Logger.log('AppGuard: NodeProvider is not ready for disconnect, skipping closeConnection');
      return;
    }

    // 1. 네트워크가 끊어진 경우 연결 해제
    if (!_connectivityProvider.isInternetOn) {
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
          ColoredBox(color: context.coconutColors.background, child: const Center(child: CoconutLogoIcon())),
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
