import 'dart:io';

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/auth_provider.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/widgets/common/buttons/shrink_animation_button.dart';
import 'package:coconut_wallet/widgets/common/dialogs/dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

enum WalletAddDialogMode { walletType, watchOnlySource, hotWalletAction }

final topSheetWalletOptions = [
  WalletImportSource.coconutVault,
  WalletImportSource.keystone,
  WalletImportSource.seedSigner,
  WalletImportSource.jade,
  WalletImportSource.coldCard,
  WalletImportSource.krux,
  WalletImportSource.passport,
  WalletImportSource.trezor,
  WalletImportSource.bitbox02,
];

class WalletAddDialog extends StatelessWidget {
  final Animation<double> animation;
  final WalletAddDialogMode mode;

  const WalletAddDialog({super.key, required this.animation, required this.mode});

  static Future<void> show(BuildContext context, WalletAddDialogMode mode) async {
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: context.coconutColors.surface.withValues(alpha: 0.5),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, animation, secondaryAnimation) => WalletAddDialog(animation: animation, mode: mode),
      transitionBuilder: (_, animation, secondaryAnimation, child) => child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final slideDownAnimation = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);

    return Stack(
      children: [
        Positioned(
          top: kToolbarHeight + MediaQuery.paddingOf(context).top,
          left: 0,
          right: 0,
          child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero).animate(slideDownAnimation),
            child: Material(
              elevation: 4,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
              color: context.coconutColors.homeBackground,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
                child: _buildContent(context),
              ),
            ),
          ),
        ),
        Positioned(top: 0, left: 0, right: 0, child: _buildHeader(context)),
      ],
    );
  }

  Widget _buildContent(BuildContext context) {
    Widget buildWalletIconShrinkButton(VoidCallback onPressed, WalletImportSource scanType, {bool isWide = false}) {
      return ShrinkAnimationButton(
        // top sheet의 background 색상과 동일하게 homeBackground로 지정
        defaultColor: context.coconutColors.homeBackground,
        pressedOverlayColor: context.coconutColors.homeSurfacePressOverlay,
        pressedOverlayOpacity: context.coconutColors.homeSurfacePressOverlayOpacity,
        onPressed: () => onPressed(),
        borderRadius: isWide ? 12 : 24,
        child:
            isWide
                ? Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: context.coconutColors.border.withAlpha(60)),
                          borderRadius: const BorderRadius.all(Radius.circular(6.0)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: SvgPicture.asset(
                            scanType.externalWalletIconPath,
                            width: 20,
                            height: 20,
                            colorFilter: ColorFilter.mode(context.coconutColors.iconPrimary, BlendMode.srcIn),
                          ),
                        ),
                      ),
                      CoconutLayout.spacing_400w,
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              scanType.displayName,
                              style: CoconutTypography.body2_14.setColor(context.coconutColors.primaryText),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                            CoconutLayout.spacing_50h,
                            Text(
                              t.wallet_add_scanner_screen.self_description,
                              style: CoconutTypography.body3_12.setColor(context.coconutColors.primaryText),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
                : Padding(
                  padding: const EdgeInsets.all(8),
                  child: SizedBox.expand(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SvgPicture.asset(
                          scanType.externalWalletIconPath,
                          colorFilter: ColorFilter.mode(context.coconutColors.iconPrimary, BlendMode.srcIn),
                        ),
                        CoconutLayout.spacing_100h,
                        Text(
                          scanType.displayName,
                          style: CoconutTypography.body2_14.setColor(context.coconutColors.primaryText),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: switch (mode) {
        WalletAddDialogMode.walletType => [
          _WalletActionButton(
            iconPath: FeatureWalletIconPath.walletEyes,
            title: t.wallet_home_screen.wallet_type_selection.watch_only.title,
            description: t.wallet_home_screen.wallet_type_selection.watch_only.description,
            onPressed: () => _showMode(context, WalletAddDialogMode.watchOnlySource),
          ),
          _WalletActionButton(
            iconPath: FeatureWalletIconPath.walletAddHot,
            title: t.wallet_home_screen.wallet_type_selection.hot_wallet.title,
            description: t.wallet_home_screen.wallet_type_selection.hot_wallet.description,
            onPressed: () => _showMode(context, WalletAddDialogMode.hotWalletAction),
          ),
        ],
        WalletAddDialogMode.watchOnlySource => [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                itemCount: topSheetWalletOptions.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 0,
                  crossAxisSpacing: 0,
                  childAspectRatio: 1.2,
                ),
                itemBuilder: (context, index) {
                  if (index >= topSheetWalletOptions.length) {
                    return const SizedBox.expand();
                  }

                  final scanType = topSheetWalletOptions[index];
                  return buildWalletIconShrinkButton(() => _onWalletSelected(context, scanType), scanType);
                },
              ),
              CoconutLayout.spacing_200h,
              Row(
                children: [
                  Expanded(
                    child: buildWalletIconShrinkButton(
                      () => _onWalletSelected(context, WalletImportSource.extendedPublicKey),
                      WalletImportSource.extendedPublicKey,
                      isWide: true,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
        WalletAddDialogMode.hotWalletAction => [
          _WalletActionButton(
            iconPath: FeatureWalletIconPath.walletAddHot,
            title: t.wallet_home_screen.hot_wallet_add.create.title,
            description: t.wallet_home_screen.hot_wallet_add.create.description,
            onPressed: () => _openHotWalletScreen(context, '/hot-wallet-create'),
          ),
          _WalletActionButton(
            iconPath: FeatureWalletIconPath.walletImportHot,
            title: t.wallet_home_screen.hot_wallet_add.restore.title,
            description: t.wallet_home_screen.hot_wallet_add.restore.description,
            onPressed: () => _openHotWalletScreen(context, '/hot-wallet-restore'),
          ),
        ],
      },
    );
  }

  void _showMode(BuildContext context, WalletAddDialogMode nextMode) {
    final navigator = Navigator.of(context);
    navigator.pop();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (navigator.mounted) {
        WalletAddDialog.show(navigator.context, nextMode);
      }
    });
  }

  Future<void> _openHotWalletScreen(BuildContext context, String routeName) async {
    if (!await _ensureDevicePasscodeIsSet(context) || !context.mounted) return;

    final navigator = Navigator.of(context);
    navigator.pop();
    navigator.pushNamed(routeName);
  }

  Future<bool> _ensureDevicePasscodeIsSet(BuildContext context) async {
    final authProvider = context.read<AuthProvider>();
    final isDevicePasscodeSet = await authProvider.isDevicePasscodeSet();
    if (!context.mounted) return false;
    if (isDevicePasscodeSet) return true;

    await showConfirmDialog(
      context,
      context.read<PreferenceProvider>().language,
      t.wallet_home_screen.hot_wallet_add.device_passcode_required.title,
      t.wallet_home_screen.hot_wallet_add.device_passcode_required.description,
      leftButtonText: t.close,
      rightButtonText: t.go_to_settings,
      onTapLeft: () => Navigator.pop(context),
      onTapRight: () async {
        Navigator.pop(context);
        await authProvider.openDeviceSecuritySettings();
      },
    );
    return false;
  }

  void _onWalletSelected(BuildContext context, WalletImportSource walletImportSource) {
    final navigator = Navigator.of(context);
    navigator.pop();

    switch (walletImportSource) {
      case WalletImportSource.bitbox02:
        navigator.pushNamed('/bitbox02-connect', arguments: {'walletImportSource': WalletImportSource.bitbox02});
        return;
      case WalletImportSource.trezor:
        navigator.pushNamed(
          Platform.isAndroid ? '/trezor-transport-select' : '/trezor-ble-connect',
          arguments: const <String, dynamic>{},
        );
        return;
      default:
        navigator.pushNamed('/wallet-add-scanner', arguments: {'walletImportSource': walletImportSource});
        return;
    }
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      children: [
        Container(height: MediaQuery.paddingOf(context).top, color: context.coconutColors.homeBackground),
        Container(
          width: MediaQuery.sizeOf(context).width,
          height: kToolbarHeight,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          color: context.coconutColors.homeBackground,
          child: Row(
            children: [
              SizedBox(
                width: 40,
                height: 40,
                child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  highlightColor: context.coconutColors.iconPrimary,
                  splashRadius: 20,
                  padding: EdgeInsets.zero,
                  icon: SvgPicture.asset(
                    CommonActionIconPath.closeBold,
                    width: 14,
                    height: 14,
                    colorFilter: ColorFilter.mode(context.coconutColors.iconPrimary, BlendMode.srcIn),
                  ),
                ),
              ),
              const Spacer(),
              Text(
                t.wallet_add_scanner_screen.add_wallet,
                style: CoconutTypography.body1_16_Bold.setColor(context.coconutColors.primaryText),
              ),
              const Spacer(),
              const SizedBox(width: 40),
            ],
          ),
        ),
      ],
    );
  }
}

class _WalletActionButton extends StatelessWidget {
  const _WalletActionButton({
    required this.iconPath,
    required this.title,
    required this.description,
    required this.onPressed,
  });

  final String iconPath;
  final String title;
  final String description;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ShrinkAnimationButton(
      defaultColor: context.coconutColors.homeBackground,
      pressedOverlayColor: context.coconutColors.homeSurfacePressOverlay,
      pressedOverlayOpacity: context.coconutColors.homeSurfacePressOverlayOpacity,
      onPressed: onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        child: Row(
          children: [
            SvgPicture.asset(
              iconPath,
              width: 24,
              colorFilter: ColorFilter.mode(context.coconutColors.iconPrimary, BlendMode.srcIn),
            ),
            CoconutLayout.spacing_400w,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    description,
                    style: CoconutTypography.body3_12.setColor(context.coconutColors.primaryText),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  CoconutLayout.spacing_50h,
                  Text(
                    title,
                    style: CoconutTypography.body2_14_Bold.setColor(context.coconutColors.primaryText),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
