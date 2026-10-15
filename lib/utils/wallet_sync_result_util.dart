import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/ui/coconut/coconut_overlays.dart' as wallet_ui;
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/screens/common/flutter_hot_wallet_authenticator.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/utils/text_utils.dart';
import 'package:coconut_wallet/utils/vibration_util.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

TextSpan buildDuplicateWalletDescriptionSpan({required String name, required String type}) {
  final strings = t.wallet_home_screen.hot_wallet_restore;
  return TextSpan(
    children: [
      TextSpan(text: strings.duplicate_wallet_description_prefix),
      TextSpan(text: '$name($type)', style: CoconutTypography.body1_16_Bold),
      TextSpan(text: strings.duplicate_wallet_description_suffix),
    ],
  );
}

/// Resolves a localized (title, description) pair for a [ResultOfSyncFromVault]
/// that is not [WalletSyncResult.newWalletAdded] or [WalletSyncResult.existingWalletUpdated].
///
/// Shared by wallet-add flows (air-gapped scanner, Trezor/BitBox02 connect screens)
/// so error dialogs stay consistent and localized instead of hardcoded English text.
(String title, String description) resolveWalletSyncResultDialog(
  ResultOfSyncFromVault result,
  WalletProvider walletProvider,
) {
  switch (result.result) {
    case WalletSyncResult.existingWalletNoUpdate:
      return (
        t.alert.wallet_add.update_failed,
        t.alert.wallet_add.update_failed_description(
          name: TextUtils.ellipsisIfLonger(walletProvider.getWalletById(result.walletId!).name, maxLength: 15),
        ),
      );
    case WalletSyncResult.existingName:
      return (t.alert.wallet_add.duplicate_name, t.alert.wallet_add.duplicate_name_description);
    case WalletSyncResult.existingWalletUpdateImpossible:
      return (
        t.alert.wallet_add.already_exist,
        t.alert.wallet_add.already_exist_description(
          name: TextUtils.ellipsisIfLonger(walletProvider.getWalletById(result.walletId!).name, maxLength: 15),
        ),
      );
    case WalletSyncResult.existingWalletDifferentType:
      final existingWallet = walletProvider.getWalletById(result.walletId!);
      return (
        t.wallet_home_screen.hot_wallet_restore.duplicate_wallet_title,
        '${t.wallet_home_screen.hot_wallet_restore.duplicate_wallet_description_prefix}'
            '${TextUtils.ellipsisIfLonger(existingWallet.name, maxLength: 15)}'
            '(${t.wallet_home_screen.hot_wallet_restore.hot_wallet_type})'
            '${t.wallet_home_screen.hot_wallet_restore.duplicate_wallet_description_suffix}',
      );
    case WalletSyncResult.newWalletAdded:
    case WalletSyncResult.existingWalletUpdated: // only CoconutVault update
      throw StateError(
        'resolveWalletSyncResultDialog should not be called for ${result.result.name}; '
        'handle it as a success case (e.g. navigation) instead of showing an error dialog.',
      );
  }
}

/// Vibrates and shows a localized error [CoconutPopup] for a [ResultOfSyncFromVault]
/// that is not [WalletSyncResult.newWalletAdded] or [WalletSyncResult.existingWalletUpdated].
///
/// Shared by the Trezor/BitBox02 connect screens to avoid duplicating the
/// vibrate + resolve + showDialog boilerplate.
void showWalletSyncResultErrorDialog(
  BuildContext context,
  ResultOfSyncFromVault result,
  WalletProvider walletProvider,
) {
  vibrateLightDouble();
  final (title, description) = resolveWalletSyncResultDialog(result, walletProvider);

  if (!context.mounted) return;
  showDialog(
    context: context,
    builder:
        (context) => CoconutPopup(
          languageCode: context.read<PreferenceProvider>().language,
          title: title,
          description: description,
          onTapRight: () => Navigator.pop(context),
          rightButtonText: t.confirm,
        ),
  );
}

/// Returns null when the user cancels or authentication fails.
Future<ResultOfSyncFromVault?> confirmConnectedWatchOnlyWalletAddition(
  BuildContext context,
  ResultOfSyncFromVault result,
) async {
  if (result.result != WalletSyncResult.existingWalletDifferentType) return result;
  final provider = context.read<WalletProvider>();
  final existingWallet = provider.getWalletById(result.walletId!);
  var removeHotWallet = false;
  final shouldAdd = await showDialog<bool>(
    context: context,
    builder:
        (dialogContext) => StatefulBuilder(
          builder:
              (context, setDialogState) => wallet_ui.CoconutPopup(
                languageCode: context.read<PreferenceProvider>().language,
                title: t.wallet_home_screen.hot_wallet_restore.duplicate_wallet_title,
                description: '',
                descriptionSpan: buildDuplicateWalletDescriptionSpan(
                  name: existingWallet.name,
                  type: t.wallet_home_screen.hot_wallet_restore.hot_wallet_type,
                ),
                backgroundColor: context.coconutColors.popupBackground.withValues(alpha: 0.7),
                checkboxText: t.wallet_home_screen.hot_wallet_restore.remove_hot_wallet,
                isCheckboxSelected: removeHotWallet,
                onCheckboxChanged: (value) => setDialogState(() => removeHotWallet = value),
                rightButtonText: t.wallet_home_screen.add_wallet_action,
                rightButtonColor: context.coconutColors.primaryText,
                onTapRight: () => Navigator.of(dialogContext).pop(true),
              ),
        ),
  );
  if (!context.mounted || shouldAdd != true) return null;
  if (removeHotWallet) {
    final authenticated = await FlutterHotWalletAuthenticator(context).authenticate();
    if (!context.mounted || !authenticated) return null;
  }
  try {
    return await provider.confirmWatchOnlyWalletAddition(result, removeExistingHotWallet: removeHotWallet);
  } catch (error) {
    if (!context.mounted) return null;
    await showDialog<void>(
      context: context,
      builder:
          (dialogContext) => wallet_ui.CoconutPopup(
            languageCode: context.read<PreferenceProvider>().language,
            title: t.alert.wallet_add.add_failed,
            description: error.toString(),
            rightButtonText: t.OK,
            onTapRight: () => Navigator.of(dialogContext).pop(),
          ),
    );
    return null;
  }
}
