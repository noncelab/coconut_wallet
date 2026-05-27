import 'dart:convert';

import 'package:coconut_wallet/enums/wallet_enums.dart';
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
  final userSelectedSpendType = _parseTaprootSpendType(realmTaprootWallet.defaultSpendTypeName);

  return TaprootWalletListItem(
    id: realmTaprootWallet.id,
    name: realmTaprootWallet.walletBase!.name,
    colorIndex: realmTaprootWallet.walletBase!.colorIndex,
    iconIndex: realmTaprootWallet.walletBase!.iconIndex,
    descriptor: decryptedDescriptor ?? realmTaprootWallet.walletBase!.descriptor,
    keyPathSeedInfos: keyPathSeedInfos,
    scriptPathSeedInfos: scriptPathSeedInfos,
    createdAtInVault: realmTaprootWallet.createdAtInVault,
    userSelectedSpendType: userSelectedSpendType,
    receiveUsedIndex: realmTaprootWallet.walletBase!.usedReceiveIndex,
    changeUsedIndex: realmTaprootWallet.walletBase!.usedChangeIndex,
  );
}

TaprootSpendType? _parseTaprootSpendType(String? name) {
  if (name == null) return null;
  for (final type in TaprootSpendType.values) {
    if (type.name == name) return type;
  }
  return null; // 알 수 없는 값은 미선택으로 처리
}
