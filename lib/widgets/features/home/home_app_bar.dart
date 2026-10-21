import 'dart:math' as math;

import 'package:coconut_design_system/coconut_design_system.dart' show CoconutAppBar, CoconutTypography;
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/services/safety/home_safety_status_resolver.dart';
import 'package:coconut_wallet/widgets/common/buttons/coconut_icon_button.dart';
import 'package:coconut_wallet/widgets/features/home/home_connection_status_indicator.dart';
import 'package:coconut_wallet/widgets/features/safety/home_safety_status_chip.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Material, MaterialType;
import 'package:flutter/rendering.dart';
import 'package:flutter_svg/flutter_svg.dart';

class HomeAppBar extends StatelessWidget {
  static const addWalletButtonSize = CoconutAppBarActionButton.minimumSize;

  final NetworkStatus networkStatus;
  final bool showReconnected;
  final bool isSyncing;
  final bool isArranging;
  final HomeAddWalletOption homeAddWalletOption;
  final LayerLink addWalletButtonLink;
  final VoidCallback onArrangeDone;
  final VoidCallback? onUndoArrangement;
  final VoidCallback onEdit;
  final VoidCallback onAddWallet;
  final VoidCallback onSettings;

  /// 지갑 상태 칩. 없으면 기존 연결 상태 표시를 그린다.
  final HomeSafetyStatus? safetyStatus;
  final VoidCallback? onStatusTap;

  /// 첫 노출 말풍선이 칩 아래에 붙는 자리
  final LayerLink? statusChipLink;

  const HomeAppBar({
    super.key,
    required this.networkStatus,
    required this.showReconnected,
    required this.isSyncing,
    required this.isArranging,
    this.homeAddWalletOption = HomeAddWalletOption.all,
    required this.addWalletButtonLink,
    required this.onArrangeDone,
    this.onUndoArrangement,
    required this.onEdit,
    required this.onAddWallet,
    required this.onSettings,
    this.safetyStatus,
    this.onStatusTap,
    this.statusChipLink,
  });

  @override
  Widget build(BuildContext context) {
    final addWalletIcon = switch (homeAddWalletOption) {
      HomeAddWalletOption.all => FeatureWalletIconPath.walletAddDefault,
      HomeAddWalletOption.watchOnly => FeatureWalletIconPath.walletEyes,
      HomeAddWalletOption.hotWallet => FeatureWalletIconPath.walletAddHot,
      HomeAddWalletOption.hidden => null,
    };
    final iconColor = context.coconutColors.iconPrimary;
    final pressedIconBackground = Color.lerp(context.coconutColors.iconButtonHighlight, iconColor, 0.2)!;
    // CDS reserves 32px for outer padding, 16px around leading, and 4px after the empty title.
    // Keep the three 48px actions (edit, add wallet, settings) outside the status indicator's maximum width.
    final statusWidth = math.max(
      0.0,
      MediaQuery.sizeOf(context).width -
          MediaQuery.paddingOf(context).horizontal -
          32 -
          16 -
          4 -
          addWalletButtonSize * 3,
    );
    return CoconutAppBar.buildHomeAppbar(
      context: context,
      isLeadingSvgAssetVisible: !isArranging,
      leadingSvgAsset: Transform.translate(
        offset: const Offset(-8, 2),
        child: _VerticalHitSlop(
          child: ConstrainedBox(constraints: BoxConstraints(maxWidth: statusWidth), child: _buildStatus(statusWidth)),
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
          if (addWalletIcon != null)
            CompositedTransformTarget(
              link: addWalletButtonLink,
              child: Material(
                type: MaterialType.transparency,
                child: CoconutAppBarActionButton(
                  buttonKey: const Key('home-add-wallet-button'),
                  tooltip: t.home_widgets.add_wallet,
                  size: addWalletButtonSize,
                  icon: SvgPicture.asset(addWalletIcon, colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn)),
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
        ],
      ],
    );
  }

  Widget _buildStatus(double maxWidth) {
    final status = safetyStatus;
    if (status == null) {
      return HomeConnectionStatusIndicator(
        networkStatus: networkStatus,
        showReconnected: showReconnected,
        isSyncing: isSyncing,
      );
    }
    final chip = HomeSafetyStatusChip(status: status, maxWidth: maxWidth, onTap: onStatusTap);
    final link = statusChipLink;
    return link == null ? chip : CompositedTransformTarget(link: link, child: chip);
  }
}

/// 상태칩(40)의 누름 영역을 위아래 4씩 넓혀 오른쪽 버튼과 같은 48로. leading 여백(위아래 8) 안이라 배치·그림은 그대로다.
class _VerticalHitSlop extends SingleChildRenderObjectWidget {
  static const slop = 4.0;

  const _VerticalHitSlop({required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderVerticalHitSlop();
}

class _RenderVerticalHitSlop extends RenderProxyBox {
  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (position.dy < -_VerticalHitSlop.slop || position.dy > size.height + _VerticalHitSlop.slop) return false;
    // 넓힌 곳의 누름은 칩 가장자리로 옮겨 칩이 받게 한다
    return super.hitTest(result, position: Offset(position.dx, math.min(math.max(position.dy, 0), size.height - 1)));
  }
}
