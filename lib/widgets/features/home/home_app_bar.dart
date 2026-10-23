import 'dart:math' as math;

import 'package:coconut_design_system/coconut_design_system.dart' show CoconutAppBar, CoconutTypography;
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/widgets/common/buttons/coconut_icon_button.dart';
import 'package:coconut_wallet/widgets/features/home/home_connection_status_indicator.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Material, MaterialType;
import 'package:flutter_svg/flutter_svg.dart';

class HomeAppBar extends StatelessWidget {
  static const actionButtonWidth = CoconutAppBarActionButton.actionWidth;

  final NetworkStatus networkStatus;
  final bool showReconnected;
  final bool isSyncing;
  final bool isArranging;
  final LayerLink addWalletButtonLink;
  final VoidCallback onArrangeDone;
  final VoidCallback? onUndoArrangement;
  final VoidCallback onEdit;
  final VoidCallback onAddWallet;
  final VoidCallback onSettings;

  const HomeAppBar({
    super.key,
    required this.networkStatus,
    required this.showReconnected,
    required this.isSyncing,
    required this.isArranging,
    required this.addWalletButtonLink,
    required this.onArrangeDone,
    this.onUndoArrangement,
    required this.onEdit,
    required this.onAddWallet,
    required this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = context.coconutColors.iconPrimary;
    final pressedIconBackground = Color.lerp(context.coconutColors.iconButtonHighlight, iconColor, 0.2)!;
    // CDS reserves 20px for outer padding, 16px around leading, and 4px after the empty title.
    // Keep the three actions and their trailing 4px outside the status indicator's maximum width.
    final statusWidth = math.max(
      0.0,
      MediaQuery.sizeOf(context).width -
          MediaQuery.paddingOf(context).horizontal -
          20 -
          16 -
          4 -
          actionButtonWidth * 3 -
          4,
    );
    return CoconutAppBar.buildHomeAppbar(
      context: context,
      isLeadingSvgAssetVisible: !isArranging,
      leadingSvgAsset: Transform.translate(
        offset: const Offset(-6, 2),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: statusWidth),
          child: HomeConnectionStatusIndicator(
            networkStatus: networkStatus,
            showReconnected: showReconnected,
            isSyncing: isSyncing,
          ),
        ),
      ),
      appTitle: '',
      actionButtonList: [
        if (isArranging && onUndoArrangement != null)
          CupertinoButton(
            key: const Key('home-arrange-undo'),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: const Size(40, 40),
            onPressed: onUndoArrangement,
            child: Text(t.home_presets.undo, style: CoconutTypography.body2_14_Bold.copyWith(color: iconColor)),
          ),
        if (isArranging)
          CupertinoButton(
            key: const Key('home-arrange-done'),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: const Size(40, 40),
            onPressed: onArrangeDone,
            child: Text(t.done, style: CoconutTypography.body2_14_Bold.copyWith(color: iconColor)),
          )
        else ...[
          Material(
            type: MaterialType.transparency,
            child: CoconutAppBarActionButton(
              buttonKey: const Key('home-edit-button'),
              width: actionButtonWidth,
              tooltip: t.home_menu.edit_home_screen,
              icon: SvgPicture.asset(
                CommonActionIconPath.editHome,
                colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
              ),
              onPressed: onEdit,
              color: iconColor,
              highlightColor: pressedIconBackground,
            ),
          ),
          CompositedTransformTarget(
            link: addWalletButtonLink,
            child: Material(
              type: MaterialType.transparency,
              child: CoconutAppBarActionButton(
                buttonKey: const Key('home-add-wallet-button'),
                width: actionButtonWidth,
                tooltip: t.home_widgets.add_wallet,
                icon: SvgPicture.asset(
                  FeatureWalletIconPath.walletAddDefault,
                  colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
                ),
                onPressed: onAddWallet,
                color: iconColor,
                highlightColor: pressedIconBackground,
              ),
            ),
          ),
          Material(
            type: MaterialType.transparency,
            child: CoconutAppBarActionButton(
              buttonKey: const Key('home-settings-button'),
              width: actionButtonWidth,
              tooltip: t.settings,
              icon: SvgPicture.asset(
                FeatureSettingsIconPath.settings,
                colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
              ),
              onPressed: onSettings,
              color: iconColor,
              highlightColor: pressedIconBackground,
            ),
          ),
          const SizedBox(width: 4),
        ],
      ],
    );
  }
}
