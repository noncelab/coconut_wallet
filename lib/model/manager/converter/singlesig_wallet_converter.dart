import 'package:coconut_wallet/model/data/singlesig_wallet_list_item.dart';
import 'package:coconut_wallet/model/manager/realm/model/coconut_wallet_data.dart';

SinglesigWalletListItem mapRealmWalletBaseToSinglesigWalletListItem(
    RealmWalletBase realmWalletBase) {
  return SinglesigWalletListItem(
      id: realmWalletBase.id,
      name: realmWalletBase.name,
      colorIndex: realmWalletBase.colorIndex,
      iconIndex: realmWalletBase.iconIndex,
      descriptor: realmWalletBase.descriptor,
      balance: realmWalletBase.balance,
      txCount: realmWalletBase.txCount,
      isLatestTxBlockHeightZero: realmWalletBase.isLatestTxBlockHeightZero);
}
