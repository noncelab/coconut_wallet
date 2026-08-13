import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/auth_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/screens/wallet_detail/wallet_info/wallet_info_screen.dart';
import 'package:coconut_wallet/widgets/button/fixed_bottom_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

class MnemonicBackupCompleteScreen extends StatelessWidget {
  const MnemonicBackupCompleteScreen({super.key, this.walletId, this.continueToAppLockGuide = false});

  final int? walletId;
  final bool continueToAppLockGuide;

  @override
  Widget build(BuildContext context) {
    final strings = t.wallet_home_screen.hot_wallet_setup;
    final isAppLockSet = context.watch<AuthProvider>().isAuthEnabled;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: context.coconutColors.background,
        appBar: CoconutAppBar.build(
          title: strings.backup_confirm_title,
          context: context,
          isLeadingVisible: false,
          backgroundColor: context.coconutColors.background,
        ),
        body: SafeArea(
          top: false,
          child: Stack(
            children: [
              Center(
                child: Transform.translate(
                  offset: const Offset(0, -28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SvgPicture.asset(
                        'assets/svg/circle-check.svg',
                        width: 72,
                        height: 72,
                        colorFilter: ColorFilter.mode(context.coconutColors.iconDefault, BlendMode.srcIn),
                      ),
                      CoconutLayout.spacing_600h,
                      Text(
                        strings.backup_complete_title,
                        style: CoconutTypography.heading3_21_Bold.setColor(context.coconutColors.primaryText),
                        textAlign: TextAlign.center,
                      ),
                      CoconutLayout.spacing_400h,
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          strings.backup_complete_description,
                          style: CoconutTypography.body2_14.setColor(context.coconutColors.secondaryText),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              FixedBottomButton(
                text: continueToAppLockGuide && !isAppLockSet ? t.next : t.complete,
                surroundingsColor: context.coconutColors.background,
                onButtonClicked: () => _complete(context, isAppLockSet),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _complete(BuildContext context, bool isAppLockSet) async {
    if (walletId != null) {
      await context.read<WalletProvider>().updateHotWalletBackupVerified(walletId!, backupVerified: true);
      if (!context.mounted) return;
    }

    if (!continueToAppLockGuide) {
      Navigator.pop(context, true);
      return;
    }

    if (isAppLockSet) {
      _openWalletDetail(context);
      return;
    }

    await Navigator.pushNamedAndRemoveUntil(
      context,
      '/hot-wallet-app-lock-guide-screen',
      (route) => route.isFirst,
      arguments: {'walletId': walletId},
    );
  }

  void _openWalletDetail(BuildContext context) {
    if (walletId == null) {
      Navigator.of(context).popUntil((route) => route.isFirst);
      return;
    }
    Navigator.of(context).pushNamedAndRemoveUntil(
      '/wallet-detail',
      (route) => route.isFirst,
      arguments: {'id': walletId, 'entryPoint': kEntryPointWalletHome},
    );
  }
}
