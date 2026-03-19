import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/widgets/button/shrink_animation_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class EnterInputAndShareBottomActionOverlay extends StatefulWidget {
  const EnterInputAndShareBottomActionOverlay({
    super.key,
    required this.child,
    this.scrollController,
    this.showBottomActions = true,
    this.onEnterAmountTap,
    this.onShareTap,
    this.bottomButtonPadding = const EdgeInsets.only(left: 16, right: 16, bottom: 120, top: 40),
  });

  final Widget child;
  final ScrollController? scrollController;
  final bool showBottomActions;
  final VoidCallback? onEnterAmountTap;
  final VoidCallback? onShareTap;
  final EdgeInsets bottomButtonPadding;

  @override
  State<EnterInputAndShareBottomActionOverlay> createState() => _EnterInputAndShareBottomActionOverlayState();
}

class _EnterInputAndShareBottomActionOverlayState extends State<EnterInputAndShareBottomActionOverlay> {
  final GlobalKey _bottomOverlayKey = GlobalKey();
  bool _showBottomOverlayGradient = false;
  bool _showEnterAmountButton = false;
  bool _showShareButton = false;
  double _bottomOverlayReservedHeight = 0;

  @override
  void initState() {
    super.initState();
    if (widget.showBottomActions) {
      _startBottomOverlayAnimation();
    }
  }

  @override
  void didUpdateWidget(covariant EnterInputAndShareBottomActionOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.showBottomActions && widget.showBottomActions) {
      _startBottomOverlayAnimation();
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

  void _updateBottomOverlayHeight() {
    if (!widget.showBottomActions) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
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
    _updateBottomOverlayHeight();

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
                                CoconutColors.black,
                              ],
                              stops: const [0.0, 0.03, 0.07, 0.15, 0.23],
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
                                  onTap: widget.onEnterAmountTap ?? () {},
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
                                  onPressed: widget.onShareTap ?? () {},
                                  borderRadius: 8,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 40),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        SvgPicture.asset('assets/svg/export.svg'),
                                        CoconutLayout.spacing_100w,
                                        Text(t.address_list_screen.share, style: CoconutTypography.body3_12),
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
}
