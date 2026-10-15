import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/wallet/singlesig_wallet_item.dart';
import 'package:coconut_wallet/model/wallet/hot_wallet_metadata.dart';
import 'package:coconut_wallet/repository/realm/model/coconut_wallet_model.dart';

SinglesigWalletItem mapRealmToSingleSigWalletItem(
  RealmWalletBase realmWalletBase,
  String? decryptedDescriptor,
  WalletImportSource? walletImportSource, [
  HotWalletMetadata? hotWalletMetadata,
]) {
  return SinglesigWalletItem(
    id: realmWalletBase.id,
    name: realmWalletBase.name,
    colorIndex: realmWalletBase.colorIndex,
    iconIndex: realmWalletBase.iconIndex,
    descriptor: decryptedDescriptor ?? realmWalletBase.descriptor,
    receiveUsedIndex: realmWalletBase.usedReceiveIndex,
    changeUsedIndex: realmWalletBase.usedChangeIndex,
    walletImportSource: walletImportSource ?? WalletImportSource.coconutVault,
    hotWalletMetadata: hotWalletMetadata,
  );
}
