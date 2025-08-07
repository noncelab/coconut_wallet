import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/model/wallet/multisig_wallet_list_item.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/services/wallet_add_service.dart';

bool isWalletNonMfp(WalletListItemBase? wallet) {
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
  return walletItemList.any((wallet) =>
      wallet is MultisigWalletListItem ||
      (wallet.walletBase as SingleSignatureWallet).keyStore.masterFingerprint !=
          WalletAddService.masterFingerprintPlaceholder);
}
