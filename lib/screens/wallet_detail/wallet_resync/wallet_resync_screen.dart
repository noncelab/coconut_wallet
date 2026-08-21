import 'dart:async';

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/enums/node_connection_status.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/error/app_error.dart';
import 'package:coconut_wallet/model/node/resync_progress.dart';
import 'package:coconut_wallet/providers/auth_provider.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/screens/common/pin_check_screen.dart';
import 'package:coconut_wallet/screens/wallet_detail/wallet_info/wallet_info_screen.dart';
import 'package:coconut_wallet/utils/icons_util.dart';
import 'package:coconut_wallet/widgets/button/fixed_bottom_button.dart';
import 'package:coconut_wallet/widgets/custom_loading_overlay.dart';
import 'package:coconut_wallet/widgets/overlays/common_bottom_sheets.dart';
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
  bool _isRunning = false;

  final List<ResyncProgress> _phaseQueue = [];
  bool _isDrainingPhaseQueue = false;

  bool get _isInProgress =>
      _progress != null &&
      (_progress!.phase == ResyncPhase.wiping ||
          _progress!.phase == ResyncPhase.scanning ||
          _progress!.phase == ResyncPhase.restoringMetadata);

  @override
  void initState() {
    super.initState();
    _checkConnection();
    // NodeProvider.getResyncProgressStream은 구독 시점에 그 지갑의 "마지막" 재동기화 상태를
    // 그대로 리플레이한다(이 화면을 벗어나도 NodeStateManager 쪽 캐시는 안 지워짐). initState에서
    // 바로 구독하면 예전에 재동기화했던 적이 있는 지갑은 그 마지막 상태(예: completed)를 즉시
    // 받아버려서 확인 화면을 건너뛰고 바로 결과 화면으로 가버린다 — 그래서 사용자가 실제로
    // "시작" 버튼을 눌러 이번 재동기화를 시작한 뒤에만 구독을 시작한다(_beginResyncFlow).
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
    _progressSubscription?.cancel();
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
    if (_connectionStatus != NodeConnectionStatus.connected) return;
    await _handleAuthFlow(onComplete: _beginResyncFlow);
  }

  /// 사용자가 실제로 재동기화를 시작(또는 재시도)한 뒤에만 진행률 스트림을 구독한다.
  void _beginResyncFlow() {
    _progressSubscription ??= context.read<NodeProvider>().getResyncProgressStream(widget.id).listen((progress) {
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
    if (!mounted) return;

    if (result.isSuccess) {
      await walletProvider.refreshWalletAfterResync(widget.id);
      if (!mounted) return;
      _enqueuePhase(const ResyncProgress(phase: ResyncPhase.completed));
    } else {
      _enqueuePhase(ResyncProgress(phase: ResyncPhase.failed, errorMessage: result.error.message));
    }
  }

  void _onRetryPressed() {
    _beginResyncFlow();
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
      canPop: !_isInProgress,
      onPopInvokedWithResult: (didPop, _) {},
      child: Scaffold(
        backgroundColor: context.coconutColors.background,
        appBar: CoconutAppBar.build(
          title: t.wallet_resync_screen.title,
          context: context,
          onBackPressed: _isInProgress ? () {} : () => Navigator.of(context).pop(),
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
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  ({String text, VoidCallback onPressed, bool isActive})? get _bottomButtonConfig {
    if (_progress == null) {
      return (
        text: t.wallet_resync_screen.confirm.cta,
        onPressed: _onStartPressed,
        isActive: _connectionStatus == NodeConnectionStatus.connected,
      );
    }
    switch (_progress!.phase) {
      case ResyncPhase.completed:
        return (text: t.wallet_resync_screen.progress.success_cta, onPressed: _onDonePressed, isActive: true);
      case ResyncPhase.failed:
        return (text: t.wallet_resync_screen.progress.error_cta, onPressed: _onRetryPressed, isActive: true);
      case ResyncPhase.wiping:
      case ResyncPhase.scanning:
      case ResyncPhase.restoringMetadata:
        return null;
    }
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
            'assets/svg/broom.svg',
            width: 48,
            height: 48,
            colorFilter: ColorFilter.mode(context.coconutColors.primaryText, BlendMode.srcIn),
          ),
          title: t.wallet_resync_screen.progress.phase_wiping,
        );
      case ResyncPhase.scanning:
        return _buildStatusColumn(
          key: const ValueKey('scanning'),
          icon: SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(color: context.coconutColors.primary, strokeWidth: 4),
          ),
          title: t.wallet_resync_screen.progress.phase_scanning,
          extra: _buildFetchProgress(),
        );
      case ResyncPhase.restoringMetadata:
        return _buildStatusColumn(
          key: const ValueKey('restoringMetadata'),
          icon: SvgPicture.asset(
            'assets/svg/arrow-reload.svg',
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
            'assets/svg/circle-check.svg',
            width: 48,
            height: 48,
            colorFilter: ColorFilter.mode(context.coconutColors.textHighlight, BlendMode.srcIn),
          ),
          title: t.wallet_resync_screen.progress.success_title,
        );
      case ResyncPhase.failed:
        return _buildStatusColumn(
          key: const ValueKey('failed'),
          icon: SvgPicture.asset(
            'assets/svg/circle-warning.svg',
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t.wallet_resync_screen.confirm.description,
          style: CoconutTypography.body1_16.setColor(context.coconutColors.primaryText),
        ),
        CoconutLayout.spacing_600h,
        _buildConnectionAlertBox(),
      ],
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
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: context.coconutColors.surfaceCard),
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
          CustomIcons.triangleWarning,
          height: 20,
          colorFilter: ColorFilter.mode(context.coconutColors.danger, BlendMode.srcIn),
        );
      case NodeConnectionStatus.connecting:
        return const CupertinoActivityIndicator(radius: 10);
      case NodeConnectionStatus.connected:
        return SvgPicture.asset(
          'assets/svg/circle-check.svg',
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

  Widget? _buildFetchProgress() {
    final completed = _progress?.fetchCompleted;
    final total = _progress?.fetchTotal;
    if (completed == null || total == null || total <= 0) return null;

    final ratio = (completed / total).clamp(0.0, 1.0);
    final percentText = '${(ratio * 100).round()}%';

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 6,
              backgroundColor: context.coconutColors.surfaceCard,
              color: context.coconutColors.primary,
            ),
          ),
          CoconutLayout.spacing_200h,
          Text(percentText, style: CoconutTypography.body3_12.setColor(context.coconutColors.secondaryText)),
        ],
      ),
    );
  }

  Widget? _buildErrorDetail() {
    final errorMessage = _progress?.errorMessage;
    if (errorMessage == null || errorMessage.isEmpty) return null;

    return Container(
      margin: const EdgeInsets.only(top: 16),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: context.coconutColors.surfaceCard,
        borderRadius: BorderRadius.circular(CoconutStyles.radius_200),
      ),
      child: Text(
        errorMessage,
        style: CoconutTypography.body2_14.setColor(context.coconutColors.secondaryText),
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
