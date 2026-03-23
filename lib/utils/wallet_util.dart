import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/wallet/multisig_wallet_list_item.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/services/wallet_add_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

bool isWalletWithoutMfp(WalletListItemBase? wallet) {
  if (wallet != null &&
      wallet is! MultisigWalletListItem &&
      (wallet.walletBase as SingleSignatureWallet).keyStore.masterFingerprint ==
          WalletAddService.masterFingerprintPlaceholder) {
    return true;
  }
  return false;
}

// MFP가 있는 지갑이 하나라도 존재하는지 여부
bool hasMfpWallet(List<WalletListItemBase> walletItemList) {
  return walletItemList.any(
    (wallet) =>
        wallet is MultisigWalletListItem ||
        (wallet.walletBase as SingleSignatureWallet).keyStore.masterFingerprint !=
            WalletAddService.masterFingerprintPlaceholder,
  );
}

Future<bool?> showNoMfpDialog(BuildContext context, VoidCallback onTapConfirm) async {
  return await showDialog(
    context: context,
    builder: (BuildContext context) {
      return CoconutPopup(
        languageCode: context.read<PreferenceProvider>().language,
        title: t.alert.without_mfp.title,
        description: t.alert.without_mfp.description,
        leftButtonText: t.alert.without_mfp.skip_button,
        rightButtonText: t.alert.without_mfp.confirm_button,
        onTapLeft: () {
          Navigator.of(context).pop(false);
        },
        onTapRight: () {
          onTapConfirm();
        },
      );
    },
  );
}
