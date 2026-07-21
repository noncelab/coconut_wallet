import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:flutter/material.dart';

class TrezorUsbConnectScreen extends StatefulWidget {
  final String? psbtBase64;
  final String? walletName;
  final String? walletFingerprint;

  const TrezorUsbConnectScreen({super.key, this.psbtBase64, this.walletName, this.walletFingerprint});

  @override
  State<TrezorUsbConnectScreen> createState() => _TrezorUsbConnectScreenState();
}

class _TrezorUsbConnectScreenState extends State<TrezorUsbConnectScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.coconutColors.background,
      appBar: CoconutAppBar.build(title: WalletImportSource.trezor.displayName, context: context, isBottom: true),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('USB Connect', style: CoconutTypography.body1_16_Bold.setColor(context.coconutColors.primaryText)),
              CoconutLayout.spacing_200h,
              Text(
                'Trezor USB 연결 기능은 준비 중입니다.',
                style: CoconutTypography.body2_14.setColor(context.coconutColors.secondaryText),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
