import 'package:coconut_wallet/model/wallet/singlesig_wallet_list_item.dart';
import 'package:coconut_wallet/repository/realm/model/coconut_wallet_model.dart';

SinglesigWalletListItem mapRealmToSingleSigWalletItem(
    RealmWalletBase realmWalletBase, String? decryptedDescriptor) {
  return SinglesigWalletListItem(
      id: realmWalletBase.id,
      name: realmWalletBase.name,
      colorIndex: realmWalletBase.colorIndex,
      iconIndex: realmWalletBase.iconIndex,
      descriptor: decryptedDescriptor ?? realmWalletBase.descriptor,
      receiveUsedIndex: realmWalletBase.usedReceiveIndex,
      changeUsedIndex: realmWalletBase.usedChangeIndex);
}
