import 'dart:async';
import 'dart:io';
import 'package:coconut_wallet/services/notification/local_notification_service.dart';
import 'package:coconut_wallet/app/router/route_args.dart';
import 'package:coconut_wallet/app/router/app_route_names.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/services/wallet/incoming_payment_watcher.dart';
import 'package:coconut_wallet/model/wallet/wallet_activity.dart';
import 'package:coconut_wallet/providers/ark_provider.dart';
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

  final Widget child;
  const AppGuard({super.key, required this.child, this.navigatorKey});

  /// 입금 토스트를 띄울 화면 층(Overlay)을 찾는 데 씀
  final GlobalKey<NavigatorState>? navigatorKey;

  @override
  State<AppGuard> createState() => _AppGuardState();
}

class _AppGuardState extends State<AppGuard> {
  StreamSubscription<String>? _notificationTaps;
  late final IncomingPaymentWatcher _incomingPaymentWatcher;
  late PriceProvider _priceProvider;
  late AuthProvider _authProvider;
  late NodeProvider _nodeProvider;
  late WalletProvider _walletProvider;
  late ArkProvider _arkProvider;
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
    _arkProvider = Provider.of<ArkProvider>(context, listen: false);
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

    _arkProvider.refreshIncomplete.addListener(_showRefreshIncomplete);
    _notificationTaps = LocalNotificationService.instance.taps.listen(_onNotificationTap);
    unawaited(
      LocalNotificationService.instance.consumeLaunchPayload().then((payload) {
        if (payload != null) _onNotificationTap(payload);
      }),
    );

    _incomingPaymentWatcher = IncomingPaymentWatcher(
      walletProvider: _walletProvider,
      arkProvider: _arkProvider,
      onReceived: _showIncomingPayment,
    )..start();
  }

  void _onNotificationTap(String payload) {
    if (!payload.startsWith(ArkProvider.arkExpiryPayloadPrefix)) return;
    final walletId = int.tryParse(payload.substring(ArkProvider.arkExpiryPayloadPrefix.length));
    if (walletId == null) return;
    widget.navigatorKey?.currentState?.pushNamed(
      AppRouteNames.vtxoList,
      arguments: VtxoListRouteArgs(id: walletId, startRefresh: true),
    );
  }

  void _showRefreshIncomplete() {
    final event = _arkProvider.refreshIncomplete.value;
    final overlay = widget.navigatorKey?.currentState?.overlay;
    final overlayContext = widget.navigatorKey?.currentContext;
    if (event == null || !mounted || overlay == null || overlayContext == null) return;
    CoconutToast.showToast(
      context: overlayContext,
      overlay: overlay,
      level: CoconutToastLevel.warning,
      text: t.ark.vtxo.refresh_incomplete(wallet: _walletProvider.getWalletById(event.walletId).name),
      seconds: 5,
      actionText: t.confirm,
      onAction:
          () => widget.navigatorKey?.currentState?.pushNamed(
            AppRouteNames.vtxoList,
            arguments: VtxoListRouteArgs(id: event.walletId, startRefresh: true),
          ),
    );
  }

  void _showIncomingPayment(IncomingPayment payment) {
    final overlay = widget.navigatorKey?.currentState?.overlay;
    final overlayContext = widget.navigatorKey?.currentContext;
    if (!mounted || overlay == null || overlayContext == null) return;
    final wallet = _walletProvider.getWalletById(payment.walletId).name;
    final amount = context.read<PreferenceProvider>().currentUnit.displayBitcoinAmount(payment.amount, withUnit: true);
    CoconutToast.showToast(
      context: overlayContext,
      overlay: overlay,
      isVisibleIcon: true,
      iconPath: FeatureTransactionIconPath.txReceived,
      iconSize: 16,
      text: switch (payment.rail) {
        ArkRail.onchain when payment.isPending => t.ark.toast.receiving_onchain(wallet: wallet, amount: amount),
        ArkRail.onchain => t.ark.toast.received_onchain(wallet: wallet, amount: amount),
        ArkRail.ark => t.ark.toast.received_ark(wallet: wallet, amount: amount),
        ArkRail.lightning => t.ark.toast.received_lightning(wallet: wallet, amount: amount),
      },
      seconds: 4,
    );
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
        _arkProvider.onResume();
        for (final wallet in _walletProvider.walletItemList) {
          unawaited(_nodeProvider.syncDormantAddresses(wallet));
        }
        break;
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        break;
      case AppLifecycleState.paused:
        _resumePolicy.onPaused();
        _arkProvider.onPause();
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
  Future<void> _handleNodeProviderReconnect(ResumeConnectionCheck resumeCheck) async {
    // 1. 초기화가 진행 중이면 reconnect 무시
    if (_nodeProvider.isInitializing) {
      Logger.log('AppGuard: NodeProvider is initializing, skipping reconnect');
      return;
    }

    // 2. 초기화 미완료 시 initialize 호출
    if (!_nodeProvider.isInitialized) {
      Logger.log('AppGuard: NodeProvider is not initialized yet, initializing instead of reconnect');
      try {
        await _nodeProvider.initialize();
      } catch (e) {
        // initialize() already exposes the connection failure through NodeProvider's state.
        Logger.log('AppGuard: NodeProvider initialization failed: $e');
      }
      return;
    }

    // 3. 초기 동기화(init/syncing) 중 reconnect 보류
    final nodeSyncState = _nodeProvider.state.nodeSyncState;
    if (nodeSyncState == NodeSyncState.init || nodeSyncState == NodeSyncState.syncing) {
      Logger.log('AppGuard: NodeProvider is syncing, skipping reconnect');
      return;
    }

    // 4. 연결 에러가 있거나 ping이 실패한 경우 재연결
    if (_nodeProvider.hasConnectionError || nodeSyncState == NodeSyncState.failed) {
      Logger.log('AppGuard: Connection issues detected, attempting reconnect');
      _nodeProvider.reconnect();
      return;
    }

    // 5. 플래그가 정상이어도 백그라운드 체류가 길면 소켓이 끊겼거나 알림을 놓쳤을 수 있음
    // 5분 이상이면 전체 재동기화, 30초 이상이면 소켓 확인
    if (resumeCheck == ResumeConnectionCheck.resyncWallets) {
      Logger.log('AppGuard: Long background, resyncing all wallets');
      unawaited(_nodeProvider.refreshWallets());
      return;
    }
    if (resumeCheck == ResumeConnectionCheck.none) {
      Logger.log('AppGuard: Connection is healthy, skipping reconnect');
      return;
    }

    final probe = await _nodeProvider.getLatestBlock();
    if (probe.isFailure) {
      Logger.log('AppGuard: Long background + held socket probe failed, forcing reconnect');
      _nodeProvider.reconnect();
    } else {
      Logger.log('AppGuard: Long background but held socket still alive, skipping reconnect');
    }
  }

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
    _incomingPaymentWatcher.stop();
    _arkProvider.refreshIncomplete.removeListener(_showRefreshIncomplete);
    _notificationTaps?.cancel();
    _lifecycleListener.dispose();
    _screenListener.dispose();
    super.dispose();
  }
}
