import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/widgets/common/buttons/shrink_animation_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class NoticeCard extends StatefulWidget {
  final String title;
  final String description;
  final String actionLabel;
  final VoidCallback onDismiss;
  final VoidCallback onDetails;

  const NoticeCard({
    super.key,
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.onDismiss,
    required this.onDetails,
  });

  @override
  State<NoticeCard> createState() => _NoticeCardState();
}

class _NoticeCardState extends State<NoticeCard> with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  bool _isDismissing = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
      reverseDuration: const Duration(milliseconds: 500),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _animationController.forward();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    if (_isDismissing || _animationController.status == AnimationStatus.dismissed) return;
    _isDismissing = true;
    await _animationController.reverse();
    if (mounted) widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    const backgroundColor = CoconutColors.gray800;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Container(
        padding: const EdgeInsets.fromLTRB(21, 0, 21, 0),
        decoration: BoxDecoration(color: backgroundColor, borderRadius: BorderRadius.circular(20)),
        child: SizeTransition(
          sizeFactor: CurvedAnimation(parent: _animationController, curve: Curves.linear),
          axisAlignment: -1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CoconutLayout.spacing_400h,
              Row(
                children: [
                  SvgPicture.asset(
                    'assets/svg/bold-bell.svg',
                    width: 16,
                    height: 16,
                    colorFilter: const ColorFilter.mode(CoconutColors.gray400, BlendMode.srcIn),
                  ),
                  const SizedBox(width: 5),
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Text(widget.title, style: CoconutTypography.body3_12_Bold.setColor(CoconutColors.gray400)),
                      Positioned(
                        top: -1,
                        right: -8,
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(color: CoconutColors.hotPink, shape: BoxShape.circle),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _dismiss,
                    child: const Icon(Icons.close, size: 18, color: CoconutColors.white),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(widget.description, style: CoconutTypography.body2_14_Bold.setColor(CoconutColors.white)),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: ShrinkAnimationButton(
                  onPressed: widget.onDetails,
                  defaultColor: backgroundColor,
                  borderRadius: 0,
                  borderWidth: 0,
                  animationEndValue: 0.85,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(widget.actionLabel, style: CoconutTypography.body3_12_Bold.setColor(CoconutColors.white)),
                        const SizedBox(width: 8),
                        SvgPicture.asset(
                          CommonNavigationIconPath.arrowRight,
                          width: 6,
                          height: 10,
                          colorFilter: const ColorFilter.mode(CoconutColors.white, BlendMode.srcIn),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              CoconutLayout.spacing_400h,
            ],
          ),
        ),
      ),
    );
  }
}
