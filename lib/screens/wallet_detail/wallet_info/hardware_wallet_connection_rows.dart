import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:coconut_design_system/coconut_design_system.dart' show CoconutTypography;
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/widgets/common/buttons/shrink_animation_button.dart';
import 'package:flutter/material.dart';

class HardwareWalletConnectionRows extends StatelessWidget {
  final bool isConnected;
  final bool isBusy;
  final VoidCallback onDisconnect;
  final VoidCallback onReconnect;

  const HardwareWalletConnectionRows({
    super.key,
    required this.isConnected,
    this.isBusy = false,
    required this.onDisconnect,
    required this.onReconnect,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final labels = t.wallet_info_screen.connected_hardware_wallet;
    return ShrinkAnimationButton(
      onPressed: isConnected ? onDisconnect : onReconnect,
      isActive: !isBusy,
      defaultColor: Colors.transparent,
      disabledColor: Colors.transparent,
      pressedOverlayColor: colors.primaryText,
      pressedOverlayOpacity: 0.08,
      borderRadius: 12,
      child: SizedBox(
        height: 52,
        child: Padding(
          padding: const EdgeInsets.only(left: 12, right: 8),
          child: Row(
            children: [
              Text(labels.connection_status, style: CoconutTypography.body2_14.copyWith(color: colors.primaryText)),
              const SizedBox(width: 8),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      isConnected ? labels.connected : labels.disconnected,
                      style: CoconutTypography.body2_14.copyWith(color: colors.tertiaryText),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SvgPicture.asset(
                CommonNavigationIconPath.arrowRight,
                width: 7,
                height: 12,
                colorFilter: ColorFilter.mode(colors.iconSecondary, BlendMode.srcIn),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
