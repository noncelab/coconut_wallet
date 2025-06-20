import 'dart:async';
import 'dart:convert';

import 'package:coconut_wallet/constants/dotenv_keys.dart';
import 'package:coconut_wallet/constants/realm_constants.dart';
import 'package:coconut_wallet/constants/secure_keys.dart';
import 'package:coconut_wallet/repository/realm/migration/migration.dart';
import 'package:coconut_wallet/repository/realm/model/coconut_wallet_model.dart';
import 'package:coconut_wallet/repository/realm/wallet_data_manager_cryptography.dart';
import 'package:coconut_wallet/repository/secure_storage/secure_storage_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:realm/realm.dart';

class RealmManager {
  static const String nextIdField = 'nextId';
  static const String nonceField = 'nonce';
  static const String pinField = kSecureStoragePinKey;

  final SecureStorageRepository _storageService = SecureStorageRepository();

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  WalletDataManagerCryptography? _cryptography;
  WalletDataManagerCryptography? get cryptography => _cryptography;

  final Realm _realm;
  Realm get realm => _realm;

  RealmManager({Realm? realm})
      : _realm = realm ??
            Realm(
              Configuration.local(
                realmAllSchemas,
                schemaVersion: kRealmVersion,
                migrationCallback: defaultMigration,
              ),
            );

  @visibleForTesting
  RealmManager.withRealm(this._realm);

  Future init(bool isSetPin) async {
    String? hashedPin;
    if (isSetPin) {
      hashedPin = await _storageService.read(key: pinField);
      String? nonce = await _storageService.read(key: nonceField);
      await _initCryptography(nonce, hashedPin!);
    }

    _isInitialized = true;
  }

  Future _initCryptography(String? nonce, String hashedPin) async {
    _cryptography =
        WalletDataManagerCryptography(nonce: nonce == null ? null : base64Decode(nonce));
    await _cryptography!.initialize(
        iterations: int.parse(dotenv.env[DotenvKeys.pbkdf2Iteration]!), hashedPin: hashedPin);
  }

  void checkInitialized() {
    if (!_isInitialized) {
      throw StateError('RealmManager is not initialized. Call initialize first.');
    }
  }

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
      realm.deleteAll<TempBroadcastTimeRecord>();
      realm.deleteAll<RealmRbfHistory>();
      realm.deleteAll<RealmCpfpHistory>();
    });

    _isInitialized = false;
    _cryptography = null;
  }

  // not used
  void dispose() {
    realm.close();
  }
}
