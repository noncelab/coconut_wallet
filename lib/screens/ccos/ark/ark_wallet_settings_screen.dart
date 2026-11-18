import 'package:coconut_design_system/coconut_design_system.dart' hide CoconutAppBar, CoconutPopup;
import 'package:coconut_wallet/ccos/features/ark/ark_wallet_provider.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/screens/ccos/ark/ark_backup_flow.dart';
import 'package:coconut_wallet/ui/coconut/coconut_app_bar.dart';
import 'package:coconut_wallet/widgets/common/buttons/button_group.dart';
import 'package:coconut_wallet/widgets/common/buttons/single_button.dart';
import 'package:coconut_wallet/app_guard.dart';
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/screens/common/flutter_hot_wallet_authenticator.dart';
import 'package:coconut_wallet/ui/coconut/coconut_overlays.dart';
import 'package:coconut_wallet/widgets/common/dialogs/dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

/// 아크 지갑 설정
class ArkWalletSettingsScreen extends StatelessWidget {
  const ArkWalletSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final wallet = context.watch<ArkWalletProvider>();
    return Scaffold(
      backgroundColor: colors.background,
      appBar: CoconutAppBar.build(context: context, title: t.ark_wallet.settings_title),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: CoconutLayout.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 20, 0, 12),
              child: Text(t.security, style: CoconutTypography.body1_16_Bold.setColor(colors.primaryText)),
            ),
            ButtonGroup(
              buttons: [
                SingleButton(
                  title: t.wallet_info_screen.mnemonic_backup,
                  onPressed: () => startArkWalletBackup(context, wallet),
                  rightElement:
                      wallet.needsBackup
                          ? Text(
                            t.wallet_info_screen.backup_required,
                            style: CoconutTypography.body2_14_Bold.setColor(colors.appLockWarningBackground),
                          )
                          : null,
                  showRightArrowWithRightElement: true,
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 20, 0, 12),
              child: Text(
                t.wallet_info_screen.section_danger,
                style: CoconutTypography.body1_16_Bold.setColor(colors.primaryText),
              ),
            ),
            ButtonGroup(
              buttons: [
                SingleButton(
                  title: t.wallet_info_screen.delete_wallet,
                  onPressed: () => _delete(context, wallet),
                  rightElement: SvgPicture.asset(
                    CommonActionIconPath.trash,
                    width: 20,
                    height: 20,
                    colorFilter: ColorFilter.mode(colors.danger, BlendMode.srcIn),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _delete(BuildContext context, ArkWalletProvider wallet) async {
    final language = context.read<PreferenceProvider>().language;
    if (!wallet.isBalanceKnown) {
      await showInfoDialog(context, language, t.ark_wallet.delete_not_ready, t.ark_wallet.delete_not_ready_body);
      return;
    }
    if (wallet.balance.total > 0) {
      await showInfoDialog(context, language, t.ark_wallet.delete_blocked_title, t.ark_wallet.delete_blocked_body);
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => CoconutPopup(
            languageCode: language,
            title: t.alert.wallet_delete.confirm_delete,
            description: t.alert.wallet_delete.confirm_delete_description,
            onTapRight: () => Navigator.of(dialogContext).pop(true),
            onTapLeft: () => Navigator.of(dialogContext).pop(false),
            rightButtonText: t.delete,
            rightButtonColor: context.coconutColors.dangerText,
            leftButtonText: t.cancel,
          ),
    );
    if (confirmed != true || !context.mounted) return;
    if (!await AppGuard.runWithoutPrivacyScreen(() => FlutterHotWalletAuthenticator(context).authenticate())) return;
    await wallet.wipe();
    if (context.mounted) Navigator.of(context).pop();
  }
}
