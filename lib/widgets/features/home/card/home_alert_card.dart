import 'dart:async';

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/ccos/open_store/coconut_open_store_content.dart';
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/widgets/features/ccos/card/coconut_open_store_intro_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

enum HomeAlertCardType { mnemonicBackup, appLock, openStore }

class HomeAlertCard extends StatefulWidget {
  const HomeAlertCard.security({
    super.key,
    required this.type,
    required this.showDelay,
    required this.title,
    required this.description,
    required this.icon,
    required this.onTap,
    required this.onClosed,
  }) : assert(type != HomeAlertCardType.openStore),
       intro = null;

  const HomeAlertCard.openStore({
    super.key,
    required this.showDelay,
    required CcosOpenStoreIntro this.intro,
    required this.onTap,
    required this.onClosed,
  }) : type = HomeAlertCardType.openStore,
       title = null,
       description = null,
       icon = null;

  final HomeAlertCardType type;
  final Duration showDelay;
  final String? title;
  final String? description;
  final Widget? icon;
  final CcosOpenStoreIntro? intro;
  final VoidCallback onTap;
  final VoidCallback onClosed;

  @override
  State<HomeAlertCard> createState() => _HomeAlertCardState();
}

class _HomeAlertCardState extends State<HomeAlertCard> with SingleTickerProviderStateMixin {
  static const _animationDuration = Duration(milliseconds: 240);

  late final AnimationController _controller;
  late final Animation<double> _animation;
  Timer? _showDelayTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _animationDuration);
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
    _showDelayTimer = Timer(widget.showDelay, () {
      if (mounted) _controller.forward(from: 0);
    });
  }

  @override
  void dispose() {
    _showDelayTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    _showDelayTimer?.cancel();
    await _controller.reverse();
    if (mounted) widget.onClosed();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final value = _animation.value;
        return ClipRect(
          child: Align(
            heightFactor: value,
            child: Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, 4 * (1 - value)),
                child: Transform.scale(scale: 0.96 + (0.04 * value), child: child),
              ),
            ),
          ),
        );
      },
      child: widget.type == HomeAlertCardType.openStore ? _buildOpenStoreCard() : _buildSecurityCard(context),
    );
  }

  Widget _buildOpenStoreCard() {
    return CoconutOpenStoreIntroCard(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      intro: widget.intro!,
      onTap: widget.onTap,
      onDismiss: _close,
    );
  }

  Widget _buildSecurityCard(BuildContext context) {
    final isMnemonicBackup = widget.type == HomeAlertCardType.mnemonicBackup;
    final textColor =
        isMnemonicBackup
            ? context.coconutColors.unbackedWarningForeground
            : context.coconutColors.appLockWarningForeground;
    final iconColor =
        isMnemonicBackup ? context.coconutColors.iconOnDanger : context.coconutColors.appLockWarningForeground;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
        decoration: BoxDecoration(
          color: isMnemonicBackup ? null : context.coconutColors.appLockWarningBackground,
          gradient:
              isMnemonicBackup
                  ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [context.coconutColors.danger, const Color(0xFFE18A99)],
                  )
                  : null,
          borderRadius: BorderRadius.circular(CoconutStyles.radius_200),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(padding: const EdgeInsets.only(top: 2), child: widget.icon!),
            CoconutLayout.spacing_200w,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.title!, style: CoconutTypography.body1_16_Bold.setColor(textColor)),
                  const SizedBox(height: 10),
                  Text(widget.description!, style: CoconutTypography.body3_12_Bold.setColor(textColor)),
                ],
              ),
            ),
            Semantics(
              button: true,
              label: t.close,
              child: InkWell(
                onTap: _close,
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: SvgPicture.asset(
                    CommonActionIconPath.closeBold,
                    width: 12,
                    height: 12,
                    colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
