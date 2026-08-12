import 'package:coconut_design_system/coconut_design_system.dart';
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
      TextSpan(text: '$name($type)', style: CoconutTypography.heading4_18_Bold),
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
