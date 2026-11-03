import 'package:coconut_design_system/coconut_design_system.dart' show CoconutTypography;
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/view_model/wallet_detail/wallet_detail_view_model.dart';
import 'package:coconut_wallet/widgets/common/buttons/coconut_icon_button.dart';
import 'package:flutter/material.dart';
import 'package:coconut_wallet/widgets/size_reporting_widget.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// 지갑 카드 아래에서 펼쳐지는 보안 알림. 접는 동안에는 이전 내용을 유지한다.
class WalletSecurityBanner extends StatefulWidget {
  final WalletDetailSecurityWarningType? warning;
  final int walletId;
  final bool moving;
  final VoidCallback onTap;
  final VoidCallback onClosed;
  final ValueChanged<double>? onHeightChanged;

  const WalletSecurityBanner({
    super.key,
    required this.warning,
    required this.walletId,
    this.moving = false,
    required this.onTap,
    required this.onClosed,
    this.onHeightChanged,
  });

  @override
  State<WalletSecurityBanner> createState() => _WalletSecurityBannerState();
}

class _WalletSecurityBannerState extends State<WalletSecurityBanner> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  WalletDetailSecurityWarningType? _content;
  int? _walletId;
  double _contentHeight = 40;

  void _reportHeight() =>
      widget.onHeightChanged?.call(_contentHeight * Curves.easeInOutCubic.transform(_controller.value));

  bool get _shouldShow => !widget.moving && widget.warning != null;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 250));
    _controller.addListener(_reportHeight);
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.dismissed && _shouldShow) _show();
    });
    if (_shouldShow) _show();
  }

  void _show() {
    _content = widget.warning;
    _walletId = widget.walletId;
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant WalletSecurityBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_shouldShow || _walletId != widget.walletId || _content != widget.warning) {
      if (_controller.isDismissed) {
        if (_shouldShow) _show();
      } else {
        _controller.reverse();
      }
    } else if (_controller.isDismissed) {
      _show();
    } else if (_controller.status != AnimationStatus.reverse) {
      _controller.forward();
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
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final mnemonic = _content == WalletDetailSecurityWarningType.unbackedHotWallet;
        return ClipRect(
          child: SizeTransition(
            sizeFactor: _controller.drive(CurveTween(curve: Curves.easeInOutCubic)),
            axisAlignment: -1,
            child: ColoredBox(
              color: colors.appLockWarningBackground,
              child: IgnorePointer(
                ignoring: !_shouldShow || _controller.status == AnimationStatus.reverse,
                child: SizeReportingWidget(
                  onSizeChanged: (size) {
                    _contentHeight = size.height;
                    if (mounted) _reportHeight();
                  },
                  child: Material(
                    key: const Key('wallet-security-banner'),
                    color: colors.appLockWarningBackground,
                    child: InkWell(
                      onTap: widget.onTap,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 16, right: 4),
                        child: Row(
                          children: [
                            SvgPicture.asset(
                              CommonStateIconPath.triangleWarning,
                              width: 20,
                              height: 20,
                              colorFilter: ColorFilter.mode(colors.appLockWarningForeground, BlendMode.srcIn),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Text(
                                  mnemonic
                                      ? t.wallet_home_screen.unbacked_hot_wallet_warning.title
                                      : t.wallet_home_screen.app_lock_warning.title,
                                  style: CoconutTypography.body2_14.copyWith(color: colors.appLockWarningForeground),
                                ),
                              ),
                            ),
                            Theme(
                              data: Theme.of(context).copyWith(materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
                              child: CoconutIconButton(
                                key: const Key('wallet-security-banner-close'),
                                onPressed: widget.onClosed,
                                constraints: const BoxConstraints.tightFor(width: 40, height: 40),
                                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                                icon: SvgPicture.asset(
                                  CommonActionIconPath.close,
                                  width: 18,
                                  height: 18,
                                  colorFilter: ColorFilter.mode(colors.appLockWarningForeground, BlendMode.srcIn),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class WalletSettingsBackupBadge extends StatelessWidget {
  final bool visible;
  final Widget child;
  const WalletSettingsBackupBadge({super.key, required this.visible, required this.child});

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      child,
      if (visible)
        Positioned(
          top: -2,
          right: -2,
          child: Container(
            key: const Key('wallet-settings-backup-dot'),
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: context.coconutColors.danger, shape: BoxShape.circle),
          ),
        ),
    ],
  );
}
