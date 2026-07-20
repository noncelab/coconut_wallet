import 'package:coconut_wallet/model/wallet/multisig_signer.dart';
import 'package:coconut_wallet/model/wallet/multisig_wallet_item.dart';
import 'package:coconut_wallet/repository/realm/model/coconut_wallet_model.dart';

MultisigWalletItem mapRealmToMultisigWalletItem(RealmMultisigWallet realmMultisigWallet, String? decryptedDescriptor) {
  return MultisigWalletItem(
    id: realmMultisigWallet.id,
    name: realmMultisigWallet.walletBase!.name,
    colorIndex: realmMultisigWallet.walletBase!.colorIndex,
    iconIndex: realmMultisigWallet.walletBase!.iconIndex,
    descriptor: decryptedDescriptor ?? realmMultisigWallet.walletBase!.descriptor,
    signers: MultisigSigner.fromJsonList(realmMultisigWallet.signersInJsonSerialization),
    requiredSignatureCount: realmMultisigWallet.requiredSignatureCount,
    receiveUsedIndex: realmMultisigWallet.walletBase!.usedReceiveIndex,
    changeUsedIndex: realmMultisigWallet.walletBase!.usedChangeIndex,
  );
}
