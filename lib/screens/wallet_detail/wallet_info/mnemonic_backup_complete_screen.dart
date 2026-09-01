import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/auth_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/screens/home/wallet_add/hot_wallet/hot_wallet_app_lock_guide_screen.dart';
import 'package:coconut_wallet/screens/wallet_detail/wallet_info/wallet_info_screen.dart';
import 'package:coconut_wallet/widgets/common/buttons/fixed_bottom_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

class MnemonicBackupCompleteScreen extends StatefulWidget {
  const MnemonicBackupCompleteScreen({super.key, this.walletId, this.continueToAppLockGuide = false});

  final int? walletId;
  final bool continueToAppLockGuide;

  @override
  State<MnemonicBackupCompleteScreen> createState() => _MnemonicBackupCompleteScreenState();
}

class _MnemonicBackupCompleteScreenState extends State<MnemonicBackupCompleteScreen> {
  bool _isCompleting = false;

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
                        CommonFormIconPath.circleCheck,
                        width: 72,
                        height: 72,
                        colorFilter: ColorFilter.mode(context.coconutColors.iconPrimary, BlendMode.srcIn),
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
                text: widget.continueToAppLockGuide && !isAppLockSet ? t.next : t.complete,
                isActive: !_isCompleting,
                surroundingsColor: context.coconutColors.background,
                onButtonClicked: () => _handleComplete(isAppLockSet),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleComplete(bool isAppLockSet) async {
    if (_isCompleting) return;
    setState(() => _isCompleting = true);

    try {
      await _complete(isAppLockSet);
    } catch (_) {
      if (mounted) setState(() => _isCompleting = false);
      rethrow;
    }
  }

  Future<void> _complete(bool isAppLockSet) async {
    if (widget.walletId != null) {
      await context.read<WalletProvider>().updateHotWalletBackupVerified(widget.walletId!, backupVerified: true);
      if (!mounted) return;
    }

    if (!widget.continueToAppLockGuide) {
      Navigator.pop(context, true);
      return;
    }

    if (isAppLockSet) {
      _openWalletDetail();
      return;
    }

    await showHotWalletAppLockGuideBottomSheet(context);
    if (!mounted) return;
    _openWalletDetail();
  }

  void _openWalletDetail() {
    if (widget.walletId == null) {
      Navigator.of(context).popUntil((route) => route.isFirst);
      return;
    }
    Navigator.of(context).pushNamedAndRemoveUntil(
      '/renewal-wallet-detail',
      (route) => route.isFirst,
      arguments: {'id': widget.walletId, 'entryPoint': kEntryPointWalletHome},
    );
  }
}
