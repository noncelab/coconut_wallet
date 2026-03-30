import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/widgets/button/shrink_animation_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

/// 스크롤 가능한 본문 위에 하단 액션 버튼을 오버레이로 띄워주는 위젯입니다.
///
/// 본문은 스크롤 뷰 안에 배치하고, 하단의 "금액 입력" / "공유" 버튼은
/// 화면 아래에 고정된 오버레이로 fade / slide 애니메이션과 함께 노출합니다.
/// 또한 오버레이가 본문을 가리지 않도록, 실제 오버레이 높이를 측정한 뒤
/// 스크롤 영역 하단에 같은 높이만큼 공간을 확보합니다.
class InputAndShareOverlay extends StatefulWidget {
  const InputAndShareOverlay({
    super.key,
    required this.child,
    required this.onEnterAmountTap,
    required this.onShareTap,
    this.shareButtonKey,
    this.scrollController,
    this.showBottomActions = true,
    this.bottomButtonPadding = const EdgeInsets.only(left: 16, right: 16, bottom: 120, top: 40),
  });

  final Widget child;
  final VoidCallback onEnterAmountTap;
  final VoidCallback onShareTap;
  final GlobalKey? shareButtonKey;
  final ScrollController? scrollController;
  final bool showBottomActions;
  final EdgeInsets bottomButtonPadding;

  @override
  State<InputAndShareOverlay> createState() => _InputAndShareOverlayState();
}

class _InputAndShareOverlayState extends State<InputAndShareOverlay> with WidgetsBindingObserver {
  final GlobalKey _bottomOverlayKey = GlobalKey();
  bool _showBottomOverlayGradient = false;
  bool _showEnterAmountButton = false;
  bool _showShareButton = false;
  double _bottomOverlayReservedHeight = 0;
  bool _isHeightMeasurementScheduled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.showBottomActions) {
      _startBottomOverlayAnimation();
      _scheduleBottomOverlayHeightMeasurement();
    }
  }

  @override
  void didUpdateWidget(covariant InputAndShareOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.showBottomActions && widget.showBottomActions) {
      _startBottomOverlayAnimation();
      _scheduleBottomOverlayHeightMeasurement();
    }
    if (oldWidget.showBottomActions && !widget.showBottomActions && _bottomOverlayReservedHeight != 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _bottomOverlayReservedHeight = 0;
          _showBottomOverlayGradient = false;
          _showEnterAmountButton = false;
          _showShareButton = false;
        });
      });
    }
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    _scheduleBottomOverlayHeightMeasurement();
  }

  void _scheduleBottomOverlayHeightMeasurement() {
    if (!widget.showBottomActions || _isHeightMeasurementScheduled) return;

    _isHeightMeasurementScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _isHeightMeasurementScheduled = false;
      if (!mounted) return;
      final context = _bottomOverlayKey.currentContext;
      if (context == null) return;
      final renderBox = context.findRenderObject() as RenderBox?;
      if (renderBox == null || !renderBox.hasSize) return;

      final nextHeight = renderBox.size.height;
      if ((_bottomOverlayReservedHeight - nextHeight).abs() < 1) return;

      setState(() {
        _bottomOverlayReservedHeight = nextHeight;
      });
    });
  }

  Future<void> _startBottomOverlayAnimation() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    if (!mounted || !widget.showBottomActions) return;
    setState(() {
      _showBottomOverlayGradient = true;
    });

    await Future<void>.delayed(const Duration(milliseconds: 200));
    if (!mounted || !widget.showBottomActions) return;
    setState(() {
      _showEnterAmountButton = true;
    });

    await Future<void>.delayed(const Duration(milliseconds: 100));
    if (!mounted || !widget.showBottomActions) return;
    setState(() {
      _showShareButton = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          fit: StackFit.expand,
          children: [
            SingleChildScrollView(
              controller: widget.scrollController,
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  children: [
                    widget.child,
                    if (widget.showBottomActions) SizedBox(height: _bottomOverlayReservedHeight),
                  ],
                ),
              ),
            ),
            if (widget.showBottomActions)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Stack(
                  key: _bottomOverlayKey,
                  children: [
                    AnimatedOpacity(
                      opacity: _showBottomOverlayGradient ? 1 : 0,
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOut,
                      child: IgnorePointer(
                        ignoring: true,
                        child: Container(
                          padding: widget.bottomButtonPadding,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                CoconutColors.black.withValues(alpha: 0.1),
                                CoconutColors.black.withValues(alpha: 0.4),
                                CoconutColors.black.withValues(alpha: 0.7),
                                CoconutColors.black.withValues(alpha: 0.9),
                              ],
                              stops: const [0.0, 0.1, 0.2, 0.5, 0.9],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: widget.bottomButtonPadding,
                        child: Column(
                          children: [
                            AnimatedOpacity(
                              opacity: _showEnterAmountButton ? 1 : 0,
                              duration: const Duration(milliseconds: 280),
                              curve: Curves.easeOutCubic,
                              child: AnimatedSlide(
                                offset: _showEnterAmountButton ? Offset.zero : const Offset(0, 0.35),
                                duration: const Duration(milliseconds: 280),
                                curve: Curves.easeOutCubic,
                                child: CoconutUnderlinedButton(
                                  text: t.address_list_screen.set_amount,
                                  textStyle: CoconutTypography.body3_12,
                                  onTap: widget.onEnterAmountTap,
                                ),
                              ),
                            ),
                            CoconutLayout.spacing_300h,
                            AnimatedOpacity(
                              opacity: _showShareButton ? 1 : 0,
                              duration: const Duration(milliseconds: 280),
                              curve: Curves.easeOutCubic,
                              child: AnimatedSlide(
                                offset: _showShareButton ? Offset.zero : const Offset(0, 0.35),
                                duration: const Duration(milliseconds: 280),
                                curve: Curves.easeOutCubic,
                                child: ShrinkAnimationButton(
                                  key: widget.shareButtonKey,
                                  onPressed: widget.onShareTap,
                                  borderRadius: 8,
                                  pressedColor: CoconutColors.gray850,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 40),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        SvgPicture.asset('assets/svg/export.svg'),
                                        CoconutLayout.spacing_100w,
                                        Text(
                                          t.address_list_screen.share,
                                          style: CoconutTypography.body3_12.copyWith(height: 1.0),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
