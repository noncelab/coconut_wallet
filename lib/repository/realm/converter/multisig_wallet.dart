import 'package:coconut_wallet/model/wallet/multisig_signer.dart';
import 'package:coconut_wallet/model/wallet/multisig_wallet_list_item.dart';
import 'package:coconut_wallet/repository/realm/model/coconut_wallet_model.dart';

MultisigWalletListItem mapRealmMultisigWalletToMultisigWalletListItem(
    RealmMultisigWallet realmMultisigWallet, String? decryptedDescriptor) {
  return MultisigWalletListItem(
      id: realmMultisigWallet.id,
      name: realmMultisigWallet.walletBase!.name,
      colorIndex: realmMultisigWallet.walletBase!.colorIndex,
      iconIndex: realmMultisigWallet.walletBase!.iconIndex,
      descriptor:
          decryptedDescriptor ?? realmMultisigWallet.walletBase!.descriptor,
      signers: MultisigSigner.fromJsonList(
          realmMultisigWallet.signersInJsonSerialization),
      requiredSignatureCount: realmMultisigWallet.requiredSignatureCount,
      txCount: realmMultisigWallet.walletBase!.txCount,
      isLatestTxBlockHeightZero:
          realmMultisigWallet.walletBase!.isLatestTxBlockHeightZero,
      receiveUsedIndex: realmMultisigWallet.walletBase!.usedReceiveIndex,
      changeUsedIndex: realmMultisigWallet.walletBase!.usedChangeIndex);
}
