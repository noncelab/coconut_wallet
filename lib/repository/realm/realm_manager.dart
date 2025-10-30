import 'package:coconut_wallet/constants/realm_constants.dart';
import 'package:coconut_wallet/constants/secure_keys.dart';
import 'package:coconut_wallet/repository/realm/migration/migration.dart';
import 'package:coconut_wallet/repository/realm/model/coconut_wallet_model.dart';
import 'package:flutter/foundation.dart';
import 'package:realm/realm.dart';

class RealmManager {
  static const String nextIdField = 'nextId';
  static const String nonceField = 'nonce';
  static const String pinField = kSecureStoragePinKey;

  final Realm _realm;
  Realm get realm => _realm;

  RealmManager({Realm? realm})
    : _realm =
          realm ??
          Realm(
            Configuration.local(realmAllSchemas, schemaVersion: kRealmVersion, migrationCallback: defaultMigration),
          );

  @visibleForTesting
  RealmManager.withRealm(this._realm);

  void reset() {
    realm.write(() {
      realm.deleteAll<RealmWalletBase>();
      realm.deleteAll<RealmMultisigWallet>();
      realm.deleteAll<RealmExternalWallet>();
      realm.deleteAll<RealmTransaction>();
      realm.deleteAll<RealmUtxoTag>();
      realm.deleteAll<RealmWalletBalance>();
      realm.deleteAll<RealmWalletAddress>();
      realm.deleteAll<RealmUtxo>();
      realm.deleteAll<RealmScriptStatus>();
      realm.deleteAll<RealmBlockTimestamp>();
      realm.deleteAll<RealmIntegerId>();
      realm.deleteAll<RealmRbfHistory>();
      realm.deleteAll<RealmCpfpHistory>();
      realm.deleteAll<RealmTransactionMemo>();
      realm.deleteAll<RealmWalletPreferences>();
    });
  }

  // not used
  void dispose() {
    realm.close();
  }
}
