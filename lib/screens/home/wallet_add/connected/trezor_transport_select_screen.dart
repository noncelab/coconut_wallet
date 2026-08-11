import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/widgets/button/shrink_animation_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class TrezorTransportSelectScreen extends StatelessWidget {
  final String? psbtBase64;
  final String? walletName;
  final String? walletFingerprint;

  const TrezorTransportSelectScreen({super.key, this.psbtBase64, this.walletName, this.walletFingerprint});

  @override
  Widget build(BuildContext context) {
    final strings = t.wallet_connect_screen.guide_trezor.transport_select;

    return Scaffold(
      backgroundColor: context.coconutColors.background,
      appBar: CoconutAppBar.build(title: strings.title, context: context, isBottom: true),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _TransportOptionCard(
                        iconPath: 'assets/svg/wallet-type/trezor.svg',
                        title: strings.btn.ble,
                        subtitle: strings.notice_ble,
                        onTap: () => _selectBle(context),
                      ),
                      CoconutLayout.spacing_300h,
                      _TransportOptionCard(
                        iconPath: 'assets/svg/wallet-type/trezor.svg',
                        title: strings.btn.usb,
                        subtitle: strings.notice_usb,
                        onTap: () => _selectUsb(context),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _selectBle(BuildContext context) {
    Navigator.pop(context);
    Navigator.pushNamed(
      context,
      '/trezor-ble-connect',
      arguments: {'psbtBase64': psbtBase64, 'walletName': walletName, 'walletFingerprint': walletFingerprint},
    );
  }

  void _selectUsb(BuildContext context) {
    Navigator.pop(context);
    Navigator.pushNamed(
      context,
      '/trezor-usb-connect',
      arguments: {'psbtBase64': psbtBase64, 'walletName': walletName, 'walletFingerprint': walletFingerprint},
    );
  }
}

class _TransportOptionCard extends StatelessWidget {
  final String iconPath;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _TransportOptionCard({
    required this.iconPath,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ShrinkAnimationButton(
      defaultColor: context.coconutColors.surface,
      pressedColor: context.coconutColors.surfacePressed,
      borderRadius: CoconutStyles.radius_200,
      onPressed: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Row(
          children: [
            SvgPicture.asset(
              iconPath,
              width: 40,
              height: 40,
              colorFilter: ColorFilter.mode(context.coconutColors.primaryText, BlendMode.srcIn),
            ),
            CoconutLayout.spacing_400w,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: CoconutTypography.body1_16_Bold.setColor(context.coconutColors.primaryText)),
                  CoconutLayout.spacing_50h,
                  Text(subtitle, style: CoconutTypography.body3_12.setColor(context.coconutColors.secondaryText)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: context.coconutColors.secondaryText, size: 20),
          ],
        ),
      ),
    );
  }
}
