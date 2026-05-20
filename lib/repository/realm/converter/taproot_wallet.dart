import 'dart:convert';

import 'package:coconut_wallet/model/wallet/taproot_script_path_seed_info.dart';
import 'package:coconut_wallet/model/wallet/taproot_wallet_list_item.dart';
import 'package:coconut_wallet/repository/realm/model/coconut_wallet_model.dart';

TaprootWalletListItem mapRealmToTaprootWalletItem(RealmTaprootWallet realmTaprootWallet, String? decryptedDescriptor) {
  final keyPathSeedInfos =
      (jsonDecode(realmTaprootWallet.keyPathSeedInfosInJsonSerialization) as List).map((e) => e as String).toList();
  final scriptPathSeedInfos =
      (jsonDecode(realmTaprootWallet.scriptPathSeedInfosInJsonSerialization) as List)
          .map((e) => TaprootScriptPathSeedInfo.fromJson(e as Map<String, dynamic>))
          .toList();

  return TaprootWalletListItem(
    id: realmTaprootWallet.id,
    name: realmTaprootWallet.walletBase!.name,
    colorIndex: realmTaprootWallet.walletBase!.colorIndex,
    iconIndex: realmTaprootWallet.walletBase!.iconIndex,
    descriptor: decryptedDescriptor ?? realmTaprootWallet.walletBase!.descriptor,
    keyPathSeedInfos: keyPathSeedInfos,
    scriptPathSeedInfos: scriptPathSeedInfos,
    createdAtInVault: realmTaprootWallet.createdAtInVault,
    receiveUsedIndex: realmTaprootWallet.walletBase!.usedReceiveIndex,
    changeUsedIndex: realmTaprootWallet.walletBase!.usedChangeIndex,
  );
}
