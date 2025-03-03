import 'package:coconut_wallet/model/data/multisig_signer.dart';
import 'package:coconut_wallet/model/data/multisig_wallet_list_item.dart';
import 'package:coconut_wallet/model/manager/realm/model/coconut_wallet_data.dart';

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
      balance: realmMultisigWallet.walletBase!.balance,
      txCount: realmMultisigWallet.walletBase!.txCount,
      isLatestTxBlockHeightZero:
          realmMultisigWallet.walletBase!.isLatestTxBlockHeightZero);
}
