import 'package:coconut_design_system/coconut_design_system.dart' hide CoconutAppBar, CoconutPopup;
import 'package:coconut_wallet/ccos/features/ark/ark_wallet_provider.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/screens/ccos/ark/ark_backup_flow.dart';
import 'package:coconut_wallet/screens/ccos/ark/ark_exit_screen.dart';
import 'package:coconut_wallet/screens/ccos/ark/ark_vtxo_list_screen.dart';
import 'package:coconut_wallet/ui/coconut/coconut_app_bar.dart';
import 'package:coconut_wallet/widgets/common/info/info_section.dart';
import 'package:coconut_wallet/app_guard.dart';
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/screens/common/flutter_hot_wallet_authenticator.dart';
import 'package:coconut_wallet/ui/coconut/coconut_overlays.dart';
import 'package:coconut_wallet/widgets/common/dialogs/dialog.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_server_config.dart';
import 'package:coconut_wallet/utils/clipboard_copy_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_feature.dart';
import 'package:coconut_wallet/screens/ccos/ark/ark_creator_screen.dart';
import 'package:coconut_wallet/screens/ccos/ark/ark_about_screen.dart';

/// 아크 지갑 설정
class ArkWalletSettingsScreen extends StatelessWidget {
  const ArkWalletSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final wallet = context.watch<ArkWalletProvider>();
    return Scaffold(
      backgroundColor: colors.background,
      appBar: CoconutAppBar.build(
        context: context,
        backgroundColor: colors.background,
        title: t.ark_wallet.settings_title,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InfoSection(
              title: t.security,
              dividerHeight: 0,
              children: [
                InfoMenuRow(
                  title: t.wallet_info_screen.mnemonic_backup,
                  onPressed: () => startArkWalletBackup(context, wallet),
                  subWidget:
                      wallet.needsBackup
                          ? Text(
                            t.wallet_info_screen.backup_required,
                            style: CoconutTypography.body2_14_Bold.setColor(colors.appLockWarningBackground),
                          )
                          : null,
                ),
              ],
            ),
            InfoSection(
              title: t.ark_wallet.section_funds,
              dividerHeight: _dividerHeight,
              children: [
                InfoMenuRow(
                  key: const Key('ark-settings-vtxos'),
                  title: t.ark_wallet.vtxos,
                  onPressed: () => ArkVtxoListScreen.open(context),
                  subWidget: Text(
                    wallet.vtxosToRenew.isNotEmpty ? t.ark_wallet.renew_needed : '${wallet.vtxos.length}',
                    style:
                        wallet.vtxosToRenew.isNotEmpty
                            ? CoconutTypography.body2_14_Bold.setColor(colors.appLockWarningBackground)
                            : CoconutTypography.body2_14_Number.setColor(colors.tertiaryText),
                  ),
                ),
                InfoMenuRow(
                  key: const Key('ark-settings-exit'),
                  title: t.ark_wallet.exit_title,
                  onPressed: () => ArkExitScreen.open(context),
                  subWidget:
                      wallet.hasActiveExit
                          ? Text(
                            t.ark_wallet.exit_running,
                            style: CoconutTypography.body2_14_Bold.setColor(colors.appLockWarningBackground),
                          )
                          : null,
                ),
              ],
            ),
            InfoSection(
              title: t.ark_wallet.wallet_name,
              dividerHeight: _dividerHeight,
              children: [
                if (wallet.remindersOn || wallet.remindersOff)
                  InfoMenuRow(
                    key: const Key('ark-settings-reminder'),
                    title: t.ark_wallet.reminder_row,
                    showArrowRight: wallet.remindersOff,
                    onPressed: wallet.remindersOff ? wallet.allowReminders : null,
                    subWidget: Text(
                      wallet.remindersOff ? t.ark_wallet.reminder_off : t.ark_wallet.reminder_on,
                      style:
                          wallet.remindersOff
                              ? CoconutTypography.body2_14_Bold.setColor(colors.appLockWarningBackground)
                              : CoconutTypography.body2_14.setColor(colors.tertiaryText),
                    ),
                  ),
                _serverRow(
                  context,
                  const Key('ark-settings-server'),
                  t.ark_wallet.ark_server,
                  ArkServerConfig.serverUrl,
                ),
              ],
            ),
            InfoSection(
              title: t.ark_wallet.section_about,
              dividerHeight: _dividerHeight,
              children: [
                InfoMenuRow(
                  key: const Key('ark-settings-about'),
                  title: t.ark_wallet.about_row,
                  onPressed: () => ArkAboutScreen.open(context),
                ),
                InfoMenuRow(
                  key: const Key('ark-settings-creator'),
                  title: t.ark_wallet.creator_row,
                  onPressed: () => ArkCreatorScreen.open(context),
                  subWidget: Text(
                    ArkFeature.listing.author,
                    style: CoconutTypography.body2_14.setColor(colors.tertiaryText),
                  ),
                ),
                InfoMenuRow(
                  key: const Key('ark-settings-bark-version'),
                  title: t.ark_wallet.bark_version,
                  showArrowRight: false,
                  subWidget: Text(
                    arkBarkVersion,
                    style: CoconutTypography.body2_14_Number.setColor(colors.tertiaryText),
                  ),
                ),
              ],
            ),
            InfoSection(
              title: t.wallet_info_screen.section_danger,
              dividerHeight: _dividerHeight,
              children: [
                InfoMenuRow(
                  title: t.wallet_info_screen.delete_wallet,
                  onPressed: () => _delete(context, wallet),
                  trailing: SvgPicture.asset(
                    CommonActionIconPath.trash,
                    width: 20,
                    height: 20,
                    colorFilter: ColorFilter.mode(colors.danger, BlendMode.srcIn),
                  ),
                ),
              ],
            ),
            CoconutLayout.spacing_2500h,
          ],
        ),
      ),
    );
  }

  /// 코코넛 지갑 정보 화면과 같은 묶음, 구분선만 얇게
  static const _dividerHeight = 1.0;

  /// 빌드할 때 정한 서버. 호스트(포트가 있으면 포트까지)만 보여 주고 누르면 전체 주소를 복사
  Widget _serverRow(BuildContext context, Key key, String title, String url) {
    final uri = Uri.tryParse(url);
    final host = uri == null || uri.host.isEmpty ? null : (uri.hasPort ? '${uri.host}:${uri.port}' : uri.host);
    return InfoMenuRow(
      key: key,
      title: title,
      showArrowRight: false,
      onPressed: url.isEmpty ? null : () => ClipboardCopyUtil.copyWithToast(context, text: url),
      subWidget: Text(
        host ?? (url.isEmpty ? '-' : url),
        style: CoconutTypography.body2_14_Number.setColor(context.coconutColors.tertiaryText),
      ),
    );
  }

  Future<void> _delete(BuildContext context, ArkWalletProvider wallet) async {
    final language = context.read<PreferenceProvider>().language;
    if (!wallet.isBalanceKnown) {
      await showInfoDialog(context, language, t.ark_wallet.delete_not_ready, t.ark_wallet.delete_not_ready_body);
      return;
    }
    if (wallet.hasActiveExit) {
      await showInfoDialog(context, language, t.ark_wallet.delete_blocked_title, t.ark_wallet.delete_exit_running);
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
            description: t.ark_wallet.delete_description,
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
