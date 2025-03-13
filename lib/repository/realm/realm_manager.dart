import 'dart:async';
import 'dart:convert';

import 'package:coconut_wallet/constants/dotenv_keys.dart';
import 'package:coconut_wallet/constants/secure_keys.dart';
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

  RealmManager()
      : _realm = Realm(
          Configuration.local(
            [
              RealmWalletBase.schema,
              RealmMultisigWallet.schema,
              RealmTransaction.schema,
              RealmIntegerId.schema,
              TempBroadcastTimeRecord.schema,
              RealmUtxoTag.schema,
              RealmWalletAddress.schema,
              RealmWalletBalance.schema,
              RealmScriptStatus.schema,
              RealmBlockTimestamp.schema,
              RealmUtxo.schema,
              RealmRbfHistory.schema,
              RealmCpfpHistory.schema,
            ],
            schemaVersion: 1,
            migrationCallback: (migration, oldVersion) {},
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
    _cryptography = WalletDataManagerCryptography(
        nonce: nonce == null ? null : base64Decode(nonce));
    await _cryptography!.initialize(
        iterations: int.parse(dotenv.env[DotenvKeys.pbkdf2Iteration]!),
        hashedPin: hashedPin);
  }

  void checkInitialized() {
    if (!_isInitialized) {
      throw StateError(
          'RealmManager is not initialized. Call initialize first.');
    }
  }

  void reset() {
    realm.write(() {
      realm.deleteAll<RealmWalletBase>();
      realm.deleteAll<RealmMultisigWallet>();
      realm.deleteAll<RealmTransaction>();
      realm.deleteAll<RealmUtxoTag>();
      realm.deleteAll<RealmWalletBalance>();
      realm.deleteAll<RealmWalletAddress>();
      realm.deleteAll<RealmUtxo>();
      realm.deleteAll<RealmScriptStatus>();
      realm.deleteAll<RealmBlockTimestamp>();
      realm.deleteAll<RealmIntegerId>();
      realm.deleteAll<TempBroadcastTimeRecord>();
    });

    _isInitialized = false;
    _cryptography = null;
  }

  Future<List<String>> _createEncryptedDescriptionList(
      List<String> plainTexts) async {
    List<String> encryptedDescriptions = [];
    for (var i = 0; i < plainTexts.length; i++) {
      var encrypted = await _cryptography!.encrypt(plainTexts[i]);
      encryptedDescriptions.add(encrypted);
    }

    return encryptedDescriptions;
  }

  Future<List<String>> _createDecryptedDescriptionList(
      RealmResults<RealmWalletBase> walletBases) async {
    List<String> decryptedDescriptions = [];
    for (var i = 0; i < walletBases.length; i++) {
      var encrypted = await _cryptography!.decrypt(walletBases[i].descriptor);
      decryptedDescriptions.add(encrypted);
    }

    return decryptedDescriptions;
  }

  Future encrypt(String hashedPin) async {
    checkInitialized();

    var walletBases =
        realm.all<RealmWalletBase>().query('TRUEPREDICATE SORT(id ASC)');

    // 비밀번호 변경 시
    List<String>? decryptedDescriptions;
    if (_cryptography != null) {
      decryptedDescriptions =
          await _createDecryptedDescriptionList(walletBases);
    }

    await _initCryptography(null, hashedPin);
    List<String> encryptedDescriptions = await _createEncryptedDescriptionList(
        decryptedDescriptions ??
            walletBases.map((walletBase) => walletBase.descriptor).toList());
    await realm.writeAsync(() {
      for (var i = 0; i < walletBases.length; i++) {
        walletBases[i].descriptor = encryptedDescriptions[i];
      }
    });

    await _saveNonceForEncryption(_cryptography!.nonce);
  }

  Future _saveNonceForEncryption(String nonce) async {
    await _storageService.write(key: nonceField, value: _cryptography!.nonce);
  }

  /// 기존 암호화 정보 복호화해서 저장
  Future decrypt() async {
    checkInitialized();

    var walletBases =
        realm.all<RealmWalletBase>().query('TRUEPREDICATE SORT(id ASC)');
    List<String> decryptedDescriptions =
        await _createDecryptedDescriptionList(walletBases);

    await realm.writeAsync(() {
      for (var i = 0; i < walletBases.length; i++) {
        walletBases[i].descriptor = decryptedDescriptions[i];
      }
    });

    await _storageService.delete(key: nonceField);
    _cryptography = null;
  }

  // not used
  void dispose() {
    realm.close();
  }
}
