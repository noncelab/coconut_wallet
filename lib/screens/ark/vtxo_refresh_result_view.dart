import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/constants/lottie_path.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/widgets/common/buttons/fixed_bottom_button.dart';
import 'package:coconut_wallet/widgets/common/buttons/fixed_bottom_tween_button.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

enum VtxoRefreshPhase { requesting, requested, failed }

/// VTXO 갱신 요청 진행과 결과. 브로드캐스팅 화면과 같은 체크 로티
class VtxoRefreshResultView extends StatefulWidget {
  const VtxoRefreshResultView({
    super.key,
    required this.phase,
    required this.count,
    required this.feeText,
    required this.onDone,
    required this.onRetry,
  });

  final VtxoRefreshPhase phase;
  final int count;
  final String? feeText;
  final VoidCallback onDone;
  final VoidCallback onRetry;

  @override
  State<VtxoRefreshResultView> createState() => _VtxoRefreshResultViewState();
}

class _VtxoRefreshResultViewState extends State<VtxoRefreshResultView> with SingleTickerProviderStateMixin {
  static const _pivot = 22 / 60;
  static const _pivotDuration = Duration(milliseconds: 733);

  late final AnimationController _controller = AnimationController(vsync: this);
  bool _loaded = false;

  @override
  void didUpdateWidget(covariant VtxoRefreshResultView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.phase != widget.phase) _animate();
  }

  Future<void> _animate() async {
    if (!_loaded) return;
    switch (widget.phase) {
      case VtxoRefreshPhase.requesting:
        _controller.value = 0;
        while (mounted && widget.phase == VtxoRefreshPhase.requesting) {
          await _controller.animateTo(_pivot, duration: _pivotDuration, curve: Curves.easeInOut);
          if (!mounted || widget.phase != VtxoRefreshPhase.requesting) break;
          await _controller.animateBack(0, duration: _pivotDuration, curve: Curves.easeInOut);
        }
        if (mounted) _animate();
      case VtxoRefreshPhase.requested:
        await _controller.animateTo(
          1,
          duration: Duration(milliseconds: ((1 - _controller.value) * 2000).round()),
          curve: Curves.linear,
        );
      case VtxoRefreshPhase.failed:
        _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final (title, description) = switch (widget.phase) {
      VtxoRefreshPhase.requesting => (t.ark.vtxo.refresh_requesting, null),
      VtxoRefreshPhase.requested => (t.ark.vtxo.refresh_requested_title, t.ark.vtxo.refresh_requested_description),
      VtxoRefreshPhase.failed => (
        t.ark.vtxo.refresh_request_failed_title,
        t.ark.vtxo.refresh_request_failed_description,
      ),
    };
    return Stack(
      children: [
        Positioned.fill(
          child: Column(
            children: [
              SizedBox(height: MediaQuery.sizeOf(context).height * 0.25),
              Opacity(
                opacity: widget.phase == VtxoRefreshPhase.failed ? 0 : 1,
                child: Lottie.asset(
                  TransactionLottiePath.checkSpinning,
                  controller: _controller,
                  width: 70,
                  height: 70,
                  repeat: false,
                  onLoaded: (composition) {
                    _controller.duration = composition.duration;
                    _loaded = true;
                    _animate();
                  },
                ),
              ),
              CoconutLayout.spacing_400h,
              Text(title, style: CoconutTypography.heading4_18_Bold.setColor(colors.primaryText)),
              if (description != null) ...[
                CoconutLayout.spacing_200h,
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    description,
                    textAlign: TextAlign.center,
                    style: CoconutTypography.body2_14.setColor(colors.secondaryText),
                  ),
                ),
              ],
              if (widget.phase == VtxoRefreshPhase.requested && widget.feeText != null) ...[
                CoconutLayout.spacing_400h,
                Text(
                  t.ark.vtxo.refresh_requested_summary(count: widget.count, fee: widget.feeText!),
                  style: CoconutTypography.body3_12_Number.setColor(colors.tertiaryText),
                ),
              ],
            ],
          ),
        ),
        if (widget.phase == VtxoRefreshPhase.requested)
          FixedBottomButton(
            key: const Key('vtxo-refresh-result-done'),
            showSurroundings: false,
            isVisibleAboveKeyboard: false,
            onButtonClicked: widget.onDone,
            text: t.confirm,
          ),
        if (widget.phase == VtxoRefreshPhase.failed)
          FixedBottomTweenButton(
            leftButtonRatio: 0.35,
            leftText: t.close,
            rightText: t.ark.vtxo.refresh_retry,
            leftButtonClicked: widget.onDone,
            rightButtonClicked: widget.onRetry,
          ),
      ],
    );
  }
}
