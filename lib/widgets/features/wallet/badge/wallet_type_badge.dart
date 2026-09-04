import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class WalletTypeBadge extends StatelessWidget {
  final bool isHotWallet;
  final EdgeInsetsGeometry padding;
  final double? iconSize;
  final TextStyle? textStyle;

  const WalletTypeBadge({
    super.key,
    required this.isHotWallet,
    this.padding = const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    this.iconSize,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedIconSize = iconSize ?? (isHotWallet ? 10.0 : 14.0);
    final iconBoxSize = iconSize ?? 14.0;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: context.coconutColors.chipUnselectedBackground,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: iconBoxSize,
            height: iconBoxSize,
            child: Center(
              child: SvgPicture.asset(
                isHotWallet ? FeatureWalletIconPath.hotWalletFire : FeatureWalletIconPath.watchOnlyEyes,
                width: resolvedIconSize,
                height: resolvedIconSize,
                colorFilter: isHotWallet ? null : ColorFilter.mode(context.coconutColors.primary, BlendMode.srcIn),
              ),
            ),
          ),
          CoconutLayout.spacing_100w,
          Text(
            isHotWallet ? t.wallet_home_screen.wallet_filter.hot : t.wallet_home_screen.wallet_filter.watch_only,
            style: textStyle ?? CoconutTypography.caption_10.setColor(context.coconutColors.primaryText),
          ),
        ],
      ),
    );
  }
}
