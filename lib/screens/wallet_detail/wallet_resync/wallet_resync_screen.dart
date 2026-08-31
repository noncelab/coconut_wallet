import 'dart:async';
import 'dart:math' as math;

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/enums/node_connection_status.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/error/app_error.dart';
import 'package:coconut_wallet/model/node/resync_progress.dart';
import 'package:coconut_wallet/model/node/wallet_fetch_progress.dart';
import 'package:coconut_wallet/providers/auth_provider.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/screens/common/pin_check_screen.dart';
import 'package:coconut_wallet/screens/wallet_detail/wallet_info/wallet_info_screen.dart';
import 'package:coconut_wallet/widgets/common/buttons/fixed_bottom_button.dart';
import 'package:coconut_wallet/widgets/common/overlays/custom_loading_overlay.dart';
import 'package:coconut_wallet/widgets/common/overlays/common_bottom_sheets.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

const double _kStatusIconSlotHeight = 64;

/// 실제 작업은 순식간에 끝날 수 있어(특히 빈 지갑) 단계가 눈에 보이지도 않고 지나가는 걸 막기 위해,
/// 단계가 바뀔 때마다 최소 이만큼은 화면에 머무르도록 큐에 쌓아서 순서대로 보여준다.
/// 같은 단계 안에서의 fetch 진행률(N/M) 갱신은 이 지연 없이 바로 반영된다.
const Duration _kMinPhaseDisplayDuration = Duration(milliseconds: 700);

/// 지갑 재동기화 확인 + 진행/결과를 한 화면에서 처리한다(bitbox02 연결 화면과 동일한 단일 상태머신 구조).
/// _progress == null: 확인 단계(연결 상태 확인 + 시작 버튼). 그 외에는 ResyncPhase에 따라 본문/하단 버튼 전환.
class WalletResyncScreen extends StatefulWidget {
  final int id;

  const WalletResyncScreen({super.key, required this.id});

  @override
  State<WalletResyncScreen> createState() => _WalletResyncScreenState();
}

class _WalletResyncScreenState extends State<WalletResyncScreen> {
  NodeConnectionStatus _connectionStatus = NodeConnectionStatus.connecting;
  ResyncProgress? _progress;
  StreamSubscription<ResyncProgress>? _progressSubscription;
  StreamSubscription<WalletFetchProgress>? _fetchProgressSubscription;
  bool _isRunning = false;
  bool _isWalletSyncing = false;
  ConnectivityProvider? _connectivityProvider;

  final List<ResyncProgress> _phaseQueue = [];
  bool _isDrainingPhaseQueue = false;

  /// 재동기화 시작 버튼을 누른 시점부터 화면 이탈을 막아야 함
  bool _isStarting = false;

  bool get _isInProgress =>
      _progress != null &&
      (_progress!.phase == ResyncPhase.wiping ||
          _progress!.phase == ResyncPhase.scanning ||
          _progress!.phase == ResyncPhase.restoringMetadata);

  bool get _blocksExit => _isStarting || _isInProgress;

  @override
  void initState() {
    super.initState();
    _checkConnection();
    // NodeProvider.getResyncProgressStream은 구독 시점에 그 지갑의 "마지막" 재동기화 상태를
    // 그대로 리플레이한다(이 화면을 벗어나도 NodeStateManager 쪽 캐시는 안 지워짐). initState에서
    // 바로 구독하면 예전에 재동기화했던 적이 있는 지갑은 그 마지막 상태(예: completed)를 즉시
    // 받아버려서 확인 화면을 건너뛰고 바로 결과 화면으로 가버린다 — 그래서 사용자가 실제로
    // "시작" 버튼을 눌러 이번 재동기화를 시작한 뒤에만 구독을 시작한다(_beginResyncFlow).
    _connectivityProvider = context.read<ConnectivityProvider>()..addListener(_onConnectivityChanged);
    _fetchProgressSubscription = context.read<NodeProvider>().getWalletFetchProgressStream(widget.id).listen((
      progress,
    ) {
      if (!mounted) return;
      setState(() => _isWalletSyncing = progress.isFetching);
    });
  }

  void _onConnectivityChanged() {
    if (!mounted) return;

    if (_progress?.phase == ResyncPhase.failed) {
      // 실패 화면에서 재시도 버튼의 활성/비활성 상태가 네트워크에 따라 바뀌므로 다시 그려준다.
      setState(() {});
      return;
    }

    if (_progress != null) return;

    if (_connectivityProvider!.isInternetOn) {
      if (_connectionStatus == NodeConnectionStatus.failed ||
          _connectionStatus == NodeConnectionStatus.networkMismatch) {
        _checkConnection();
      }
      return;
    }

    if (_connectionStatus == NodeConnectionStatus.connected) {
      setState(() => _connectionStatus = NodeConnectionStatus.failed);
    }
  }

  /// [progress]가 현재(또는 큐에서 대기 중인) 단계와 같은 phase면 fetch 진행률 갱신으로 보고
  /// 지연 없이 바로 반영하고, 다른 phase면 큐에 쌓아서 순서대로/최소 시간만큼 보여준다.
  void _enqueuePhase(ResyncProgress progress) {
    final currentPhase = _phaseQueue.isNotEmpty ? _phaseQueue.last.phase : _progress?.phase;
    if (currentPhase == progress.phase) {
      if (_phaseQueue.isNotEmpty) {
        _phaseQueue[_phaseQueue.length - 1] = progress;
      } else {
        setState(() => _progress = progress);
      }
      return;
    }

    _phaseQueue.add(progress);
    _drainPhaseQueue();
  }

  Future<void> _drainPhaseQueue() async {
    if (_isDrainingPhaseQueue) return;
    _isDrainingPhaseQueue = true;

    while (_phaseQueue.isNotEmpty) {
      final next = _phaseQueue.removeAt(0);
      if (!mounted) break;
      setState(() => _progress = next);
      await Future.delayed(_kMinPhaseDisplayDuration);
    }

    _isDrainingPhaseQueue = false;
  }

  @override
  void dispose() {
    _connectivityProvider?.removeListener(_onConnectivityChanged);
    _progressSubscription?.cancel();
    _fetchProgressSubscription?.cancel();
    super.dispose();
  }

  Future<void> _checkConnection() async {
    setState(() => _connectionStatus = NodeConnectionStatus.connecting);

    final nodeProvider = context.read<NodeProvider>();
    final result = await nodeProvider.verifyCurrentConnectionHealth();
    if (!mounted) return;

    if (result.isFailure) {
      setState(() {
        _connectionStatus =
            result.error.code == ErrorCodes.chainMismatchError.code
                ? NodeConnectionStatus.networkMismatch
                : NodeConnectionStatus.failed;
      });
      return;
    }

    setState(() => _connectionStatus = NodeConnectionStatus.connected);
  }

  Future<void> _onStartPressed() async {
    if (_isStarting || _isInProgress) return;
    if (_connectionStatus != NodeConnectionStatus.connected) return;

    setState(() => _isStarting = true);
    await _checkConnection();
    if (!mounted) return;
    if (_connectionStatus != NodeConnectionStatus.connected) {
      setState(() => _isStarting = false);
      return;
    }

    await _handleAuthFlow(onComplete: _beginResyncFlow);
    // 인증을 중간에 취소하는 등 _beginResyncFlow가 끝내 실행되지 않았다면 화면을 이탈할 수 있도록 함.
    if (mounted && _progress == null) {
      setState(() => _isStarting = false);
    }
  }

  /// 사용자가 실제로 재동기화를 시작(또는 재시도)한 뒤에만 진행률 스트림을 구독한다.
  void _beginResyncFlow() {
    final nodeProvider = context.read<NodeProvider>();
    // 이전 실행의 마지막 상태를 구독 직전 지워둔다
    nodeProvider.clearResyncProgress(widget.id);
    _progressSubscription ??= nodeProvider.getResyncProgressStream(widget.id).listen((progress) {
      if (!mounted) return;
      _enqueuePhase(progress);
    });
    _enqueuePhase(const ResyncProgress(phase: ResyncPhase.wiping));
    _startResync();
  }

  Future<void> _handleAuthFlow({required VoidCallback onComplete}) async {
    final authProvider = context.read<AuthProvider>();
    if (!authProvider.isAuthEnabled) {
      onComplete();
      return;
    }

    if (await authProvider.isBiometricsAuthValid()) {
      onComplete();
      return;
    }

    if (!mounted) return;
    await CommonBottomSheets.showCustomHeightBottomSheet(
      context: context,
      heightRatio: 0.9,
      child: CustomLoadingOverlay(child: PinCheckScreen(onComplete: onComplete)),
    );
  }

  Future<void> _startResync() async {
    if (_isRunning) return;
    _isRunning = true;

    final nodeProvider = context.read<NodeProvider>();
    final walletProvider = context.read<WalletProvider>();
    final walletItem = walletProvider.getWalletById(widget.id);

    final result = await nodeProvider.resyncWallet(walletItem);
    _isRunning = false;

    _isStarting = false;
    if (!mounted) return;

    if (result.isSuccess) {
      await walletProvider.refreshWalletAfterResync(widget.id);
      if (!mounted) return;
      _enqueuePhase(const ResyncProgress(phase: ResyncPhase.completed));
    } else {
      _enqueuePhase(ResyncProgress(phase: ResyncPhase.failed, errorMessage: result.error.message));
    }
  }

  bool get _isOffline => !(_connectivityProvider?.isInternetOn ?? true);

  void _onRetryPressed() {
    if (_isOffline) return;
    _beginResyncFlow();
  }

  void _showExitBlockedToast() {
    CoconutToast.showToast(context: context, isVisibleIcon: true, text: t.wallet_resync_screen.exit_blocked_toast);
  }

  void _onDonePressed() {
    Navigator.of(context).pushNamedAndRemoveUntil(
      '/wallet-detail',
      (route) => route.isFirst,
      arguments: {'id': widget.id, 'entryPoint': kEntryPointWalletHome},
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_blocksExit,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _showExitBlockedToast();
      },
      child: Scaffold(
        backgroundColor: context.coconutColors.background,
        appBar: CoconutAppBar.build(
          title: t.wallet_resync_screen.title,
          context: context,
          onBackPressed: _blocksExit ? _showExitBlockedToast : () => Navigator.of(context).pop(),
        ),
        body: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
                    child: _buildContent(),
                  ),
                ),
              ),
              if (_bottomButtonConfig != null)
                Align(
                  alignment: Alignment.bottomCenter,
                  child: FixedBottomButton(
                    key: ValueKey(_bottomButtonConfig!.text),
                    onButtonClicked: _bottomButtonConfig!.onPressed,
                    text: _bottomButtonConfig!.text,
                    isActive: _bottomButtonConfig!.isActive,
                    subWidget: _bottomButtonConfig!.subWidget,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  ({String text, VoidCallback onPressed, bool isActive, Widget? subWidget})? get _bottomButtonConfig {
    if (_progress == null) {
      return (
        text: t.wallet_resync_screen.confirm.cta,
        onPressed: _onStartPressed,
        isActive: !_isStarting && _connectionStatus == NodeConnectionStatus.connected,
        subWidget: _buildLastResyncHint(),
      );
    }
    switch (_progress!.phase) {
      case ResyncPhase.completed:
        return (
          text: t.wallet_resync_screen.progress.success_cta,
          onPressed: _onDonePressed,
          isActive: true,
          subWidget: null,
        );
      case ResyncPhase.failed:
        return (
          text: t.wallet_resync_screen.progress.error_cta,
          onPressed: _onRetryPressed,
          isActive: !_isOffline,
          subWidget: null,
        );
      case ResyncPhase.wiping:
      case ResyncPhase.scanning:
      case ResyncPhase.restoringMetadata:
        return null;
    }
  }

  Widget? _buildLastResyncHint() {
    final lastResync = context.read<NodeProvider>().getLastResyncTimestamp(widget.id);
    if (lastResync == null) return null;

    return Text(
      t.wallet_resync_screen.confirm.last_resync_hint(time: _formatRelativeTime(lastResync)),
      style: CoconutTypography.body3_12.setColor(context.coconutColors.secondaryText),
      textAlign: TextAlign.center,
    );
  }

  String _formatRelativeTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return t.relative_time.just_now;
    if (diff.inHours < 1) return t.relative_time.minutes_ago(n: diff.inMinutes);
    if (diff.inDays < 1) return t.relative_time.hours_ago(n: diff.inHours);
    return t.relative_time.days_ago(n: diff.inDays);
  }

  Widget _buildContent() {
    if (_progress == null) {
      return _buildConfirmContent();
    }
    switch (_progress!.phase) {
      case ResyncPhase.wiping:
        return _buildStatusColumn(
          key: const ValueKey('wiping'),
          icon: SvgPicture.asset(
            FeatureSettingsIconPath.broom,
            width: 48,
            height: 48,
            colorFilter: ColorFilter.mode(context.coconutColors.primaryText, BlendMode.srcIn),
          ),
          title: t.wallet_resync_screen.progress.phase_wiping,
        );
      case ResyncPhase.scanning:
        final hasFetchProgress =
            _progress?.fetchCompleted != null && _progress?.fetchTotal != null && (_progress?.fetchTotal ?? 0) > 0;
        return _buildStatusColumn(
          key: const ValueKey('scanning'),
          icon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
            child: hasFetchProgress ? _buildFetchProgress(key: const ValueKey('progress')) : _buildScanningSpinner(),
          ),
          title: t.wallet_resync_screen.progress.phase_scanning,
          extra: hasFetchProgress ? _buildScanningHint() : null,
        );
      case ResyncPhase.restoringMetadata:
        return _buildStatusColumn(
          key: const ValueKey('restoringMetadata'),
          icon: SvgPicture.asset(
            CommonActionIconPath.arrowReload,
            width: 40,
            height: 40,
            colorFilter: ColorFilter.mode(context.coconutColors.primaryText, BlendMode.srcIn),
          ),
          title: t.wallet_resync_screen.progress.phase_restoring_metadata,
        );
      case ResyncPhase.completed:
        return _buildStatusColumn(
          key: const ValueKey('completed'),
          icon: SvgPicture.asset(
            CommonFormIconPath.circleCheck,
            width: 48,
            height: 48,
            colorFilter: ColorFilter.mode(context.coconutColors.accentForeground, BlendMode.srcIn),
          ),
          title: t.wallet_resync_screen.progress.success_title,
        );
      case ResyncPhase.failed:
        return _buildStatusColumn(
          key: const ValueKey('failed'),
          icon: SvgPicture.asset(
            CommonStateIconPath.circleWarning,
            width: 48,
            height: 48,
            colorFilter: ColorFilter.mode(context.coconutColors.danger, BlendMode.srcIn),
          ),
          title: t.wallet_resync_screen.progress.error_title,
          titleColor: context.coconutColors.danger,
          extra: _buildErrorDetail(),
        );
    }
  }

  Widget _buildConfirmContent() {
    return Column(
      key: const ValueKey('confirm'),
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          t.wallet_resync_screen.confirm.title,
          style: CoconutTypography.body1_16.setColor(context.coconutColors.primaryText),
          textAlign: TextAlign.center,
        ),
        CoconutLayout.spacing_100h,
        Text(
          t.wallet_resync_screen.confirm.description,
          style: CoconutTypography.body3_12.setColor(context.coconutColors.secondaryText),
          textAlign: TextAlign.center,
        ),
        CoconutLayout.spacing_600h,
        _buildConnectionAlertBox(),
        _buildAnimatedWarningSection(),
      ],
    );
  }

  /// connected일 때만 사용자 남용 경고 문구를 보여준다
  Widget _buildAnimatedWarningSection() {
    final isConnected = _connectionStatus == NodeConnectionStatus.connected;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder:
          (child, animation) =>
              FadeTransition(opacity: animation, child: SizeTransition(sizeFactor: animation, child: child)),
      child:
          isConnected
              ? Column(
                key: const ValueKey('warning-visible'),
                children: [
                  CoconutLayout.spacing_300h,
                  if (_isWalletSyncing) ...[
                    _buildInfoBox(
                      title: t.wallet_resync_screen.confirm.syncing_notice.title,
                      description: t.wallet_resync_screen.confirm.syncing_notice.description,
                      color: context.coconutColors.warning,
                    ),
                    CoconutLayout.spacing_300h,
                  ],
                  _buildInfoBox(
                    title: t.wallet_resync_screen.confirm.warning.title,
                    description: t.wallet_resync_screen.confirm.warning.description,
                    color: context.coconutColors.warning,
                  ),
                ],
              )
              : const SizedBox.shrink(key: ValueKey('warning-hidden')),
    );
  }

  Widget _buildInfoBox({required String title, required String description, required Color color}) {
    // connection_alert 아이콘과 같은 20px 슬롯 폭 + spacing_300w(12px) 만큼,
    // description을 들여써서 title과 텍스트 시작 x를 맞추기 위함
    const iconSlotWidth = 20.0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: context.coconutColors.surface),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: iconSlotWidth,
                child: Center(
                  child: SvgPicture.asset(
                    CommonStateIconPath.circleInfo,
                    // circle-check.svg(24x24, 링이 83% 채움)와 실제 렌더링 링 지름을 맞춘 값(circle-info.svg는 16x16, 94% 채움)
                    height: 17.78,
                    colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
                  ),
                ),
              ),
              CoconutLayout.spacing_300w,
              Expanded(child: Text(title, style: CoconutTypography.body2_14_Bold.setColor(color))),
            ],
          ),
          CoconutLayout.spacing_100h,
          Padding(
            padding: const EdgeInsets.only(left: iconSlotWidth + 12),
            child: Text(description, style: CoconutTypography.body3_12.setColor(context.coconutColors.secondaryText)),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionAlertBox() {
    return GestureDetector(
      onTap:
          (_connectionStatus == NodeConnectionStatus.failed ||
                  _connectionStatus == NodeConnectionStatus.networkMismatch)
              ? _checkConnection
              : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: context.coconutColors.surface),
        child: Row(
          children: [
            _buildConnectionAlertIcon(),
            CoconutLayout.spacing_300w,
            Expanded(
              child: Text(
                _connectionAlertText(),
                style: CoconutTypography.body2_14_Bold.setColor(context.coconutColors.primaryText),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionAlertIcon() {
    switch (_connectionStatus) {
      case NodeConnectionStatus.failed:
      case NodeConnectionStatus.networkMismatch:
        return SvgPicture.asset(
          CommonStateIconPath.triangleWarning,
          height: 20,
          colorFilter: ColorFilter.mode(context.coconutColors.danger, BlendMode.srcIn),
        );
      case NodeConnectionStatus.connecting:
        return const CupertinoActivityIndicator(radius: 10);
      case NodeConnectionStatus.connected:
        return SvgPicture.asset(
          CommonFormIconPath.circleCheck,
          height: 20,
          colorFilter: ColorFilter.mode(CoconutColors.colorPalette[3], BlendMode.srcIn),
        );
      case NodeConnectionStatus.waiting:
        return const SizedBox.shrink();
    }
  }

  String _connectionAlertText() {
    switch (_connectionStatus) {
      case NodeConnectionStatus.failed:
        return t.wallet_resync_screen.confirm.connection_alert.failed;
      case NodeConnectionStatus.networkMismatch:
        return t.wallet_resync_screen.confirm.connection_alert.network_mismatch;
      case NodeConnectionStatus.connecting:
        return t.wallet_resync_screen.confirm.connection_alert.connecting;
      case NodeConnectionStatus.connected:
        return t.wallet_resync_screen.confirm.connection_alert.connected;
      case NodeConnectionStatus.waiting:
        return '';
    }
  }

  Widget _buildScanningSpinner() {
    return SizedBox(
      key: const ValueKey('spinner'),
      width: 36,
      height: 36,
      child: CircularProgressIndicator(
        color: context.coconutColors.primary,
        strokeWidth: 5,
        strokeCap: StrokeCap.round,
      ),
    );
  }

  Widget _buildScanningHint() {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Text(
        t.wallet_resync_screen.progress.scanning_hint,
        style: CoconutTypography.body3_12.setColor(context.coconutColors.secondaryText),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildFetchProgress({required Key key}) {
    final ratio = (_progress!.fetchCompleted! / _progress!.fetchTotal!).clamp(0.0, 1.0);

    return TweenAnimationBuilder<double>(
      key: key,
      tween: Tween<double>(end: ratio),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      builder: (context, animatedRatio, _) => _buildProgressSlider(animatedRatio),
    );
  }

  Widget _buildProgressSlider(double ratio) {
    const double trackHeight = 8;
    const double thumbSize = 16;
    const double sliderAreaTop = 32;
    final percentText = '${(ratio * 100).round()}%';

    return SizedBox(
      height: sliderAreaTop + thumbSize,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final thumbCenterX = (width * ratio).clamp(thumbSize / 2, width - thumbSize / 2);

          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                top: sliderAreaTop + (thumbSize - trackHeight) / 2,
                left: 0,
                right: 0,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(trackHeight / 2),
                  child: Stack(
                    children: [
                      Container(height: trackHeight, color: context.coconutColors.surface),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: ratio,
                          child: Container(height: trackHeight, color: context.coconutColors.primary),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: sliderAreaTop,
                left: thumbCenterX - thumbSize / 2,
                child: Container(
                  width: thumbSize,
                  height: thumbSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: context.coconutColors.primary,
                    border: Border.all(color: context.coconutColors.background, width: 2),
                  ),
                ),
              ),
              Positioned(
                top: 0,
                left: thumbCenterX,
                child: FractionalTranslation(
                  translation: const Offset(-0.5, 0),
                  child: _buildPercentBubble(percentText),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPercentBubble(String text) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: context.coconutColors.tooltipBackground,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(text, style: CoconutTypography.body3_12_Bold.setColor(context.coconutColors.primaryText)),
        ),
        Transform.translate(
          offset: const Offset(0, -3),
          child: Transform.rotate(
            angle: math.pi / 4,
            child: Container(width: 6, height: 6, color: context.coconutColors.tooltipBackground),
          ),
        ),
      ],
    );
  }

  Widget? _buildErrorDetail() {
    final errorMessage = _progress?.errorMessage;
    if (errorMessage == null || errorMessage.isEmpty) return null;

    final trimmedMessage = errorMessage.replaceAll(RegExp(r'[.。]+$'), '');

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Text(
        trimmedMessage,
        style: CoconutTypography.body3_12.setColor(context.coconutColors.secondaryText),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildStatusColumn({
    required Key key,
    required Widget icon,
    required String title,
    Color? titleColor,
    Widget? extra,
  }) {
    return Column(
      key: key,
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(height: _kStatusIconSlotHeight, child: Center(child: icon)),
        CoconutLayout.spacing_400h,
        Text(
          title,
          style: CoconutTypography.body1_16_Bold.setColor(titleColor ?? context.coconutColors.primaryText),
          textAlign: TextAlign.center,
        ),
        if (extra != null) extra,
      ],
    );
  }
}
