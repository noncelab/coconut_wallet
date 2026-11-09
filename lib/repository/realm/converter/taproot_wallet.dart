import 'dart:convert';

import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/wallet/taproot_script_path_seed_info.dart';
import 'package:coconut_wallet/model/wallet/taproot_wallet_item.dart';
import 'package:coconut_wallet/repository/realm/model/coconut_wallet_model.dart';
import 'package:coconut_wallet/utils/migration/taproot_legacy_inheritance_migration.dart';

TaprootWalletItem mapRealmToTaprootWalletItem(RealmTaprootWallet realmTaprootWallet, String? decryptedDescriptor) {
  final keyPathSeedInfos =
      (jsonDecode(realmTaprootWallet.keyPathSeedInfosInJsonSerialization) as List).map((e) => e as String).toList();
  final storedScriptPathSeedInfos =
      (jsonDecode(realmTaprootWallet.scriptPathSeedInfosInJsonSerialization) as List)
          .map((e) => TaprootScriptPathSeedInfo.fromJson(e as Map<String, dynamic>))
          .toList();
  final legacyInheritance = TaprootLegacyInheritanceMigration.migrate(
    descriptor: decryptedDescriptor ?? realmTaprootWallet.walletBase!.descriptor,
    scriptPathSeedInfos: storedScriptPathSeedInfos,
  );
  final userSelectedSpendType = _parseTaprootSpendType(realmTaprootWallet.defaultSpendTypeName);

  return TaprootWalletItem(
    id: realmTaprootWallet.id,
    name: realmTaprootWallet.walletBase!.name,
    colorIndex: realmTaprootWallet.walletBase!.colorIndex,
    iconIndex: realmTaprootWallet.walletBase!.iconIndex,
    descriptor: legacyInheritance.descriptor,
    keyPathSeedInfos: keyPathSeedInfos,
    scriptPathSeedInfos: legacyInheritance.scriptPathSeedInfos,
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
