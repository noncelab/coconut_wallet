import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/widgets/button/shrink_animation_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class WalletAddDialog extends StatelessWidget {
  final Animation<double> animation;
  final ValueChanged<WalletImportSource> onWalletSelected;

  const WalletAddDialog({super.key, required this.animation, required this.onWalletSelected});

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
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildWalletRow([
                      WalletImportSource.coconutVault,
                      WalletImportSource.keystone,
                      WalletImportSource.seedSigner,
                    ]),
                    _buildWalletRow([WalletImportSource.jade, WalletImportSource.coldCard, WalletImportSource.krux]),
                    _buildWalletRow([
                      WalletImportSource.passport,
                      WalletImportSource.trezor,
                      WalletImportSource.bitbox02,
                    ]),
                    CoconutLayout.spacing_400h,
                    _buildWalletRow([WalletImportSource.extendedPublicKey]),
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(top: 0, left: 0, right: 0, child: _buildHeader(context)),
      ],
    );
  }

  Widget _buildWalletRow(List<WalletImportSource> walletImportSources) {
    return Row(
      children:
          walletImportSources
              .map(
                (source) => Expanded(
                  child: _WalletImportSourceButton(
                    walletImportSource: source,
                    onPressed: () => onWalletSelected(source),
                  ),
                ),
              )
              .toList(),
    );
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
                  // TODO: light 모드에서 iconHighlight가 회색임....
                  highlightColor: context.coconutColors.iconHighlight,
                  splashRadius: 20,
                  padding: EdgeInsets.zero,
                  icon: SvgPicture.asset(
                    'assets/svg/close-bold.svg',
                    width: 14,
                    height: 14,
                    colorFilter: ColorFilter.mode(context.coconutColors.iconDefault, BlendMode.srcIn),
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

class _WalletImportSourceButton extends StatelessWidget {
  final WalletImportSource walletImportSource;
  final VoidCallback onPressed;

  const _WalletImportSourceButton({required this.walletImportSource, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return ShrinkAnimationButton(
      defaultColor: context.coconutColors.homeBackground,
      pressedColor: context.coconutColors.homeSurfaceCardPressed,
      onPressed: onPressed,
      child:
          walletImportSource == WalletImportSource.extendedPublicKey
              ? _buildExtendedPublicKeyButton(context)
              : _buildWalletTypeButton(context),
    );
  }

  Widget _buildWalletTypeButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      child: Column(
        children: [
          _buildIcon(context),
          CoconutLayout.spacing_100h,
          Text(
            walletImportSource.displayName,
            style: CoconutTypography.body2_14.setColor(context.coconutColors.primaryText),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildExtendedPublicKeyButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      child: Row(
        children: [
          _buildIcon(context),
          CoconutLayout.spacing_400w,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  walletImportSource.displayName,
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
    );
  }

  Widget _buildIcon(BuildContext context) {
    return SvgPicture.asset(
      walletImportSource.externalWalletIconPath,
      width: 24,
      height: 24,
      colorFilter: ColorFilter.mode(context.coconutColors.iconDefault, BlendMode.srcIn),
    );
  }
}
