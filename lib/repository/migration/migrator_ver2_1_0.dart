// ignore: camel_case_types
import 'dart:convert';

import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/repository/realm/model/coconut_wallet_data.dart';
import 'package:coconut_wallet/repository/wallet_data_manager.dart';
import 'package:coconut_wallet/repository/wallet_data_manager_cryptography.dart';
import 'package:coconut_wallet/services/secure_storage_service.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:realm/realm.dart';

// ignore: camel_case_types
class MigratorVer2_1_0 {
  final String walletListField = 'WALLET_LIST';
  final String migrationFailedField = 'migrationFailed2_1_0';
  final String idField = 'id';
  final String colorField = 'colorIndex';
  final String iconField = 'iconIndex';
  final String descriptorField = 'descriptor';
  final String nameField = 'name';
  final String typeField = 'walletType';
  final String signersField = 'signers';
  final String requiredSignatureCountField = 'requiredSignatureCount';
  final String balanceField = 'balance';

  bool? _isNeedToMigrate;

  List<Map<String, dynamic>>? existingWalletList;

  Future<bool> hasFailed() async {
    String? failedDateTime =
        await SecureStorageService().read(key: migrationFailedField);

    return failedDateTime != null;
  }

  Future recordFailedDateTime() async {
    await SecureStorageService().write(
        key: migrationFailedField, value: DateTime.now().toIso8601String());
  }

  Future<bool> needToMigrate() async {
    if (_isNeedToMigrate != null) {
      return _isNeedToMigrate!;
    }

    bool failed = await hasFailed();
    if (failed) {
      return false;
    }

    String? walletListJsonString =
        await SecureStorageService().read(key: walletListField);
    if (walletListJsonString == null) return false;

    try {
      List<Map<String, dynamic>> walletAsMap = [];
      final List<dynamic> walletList = jsonDecode(walletListJsonString) as List;
      for (final wallet in walletList) {
        final Map<String, dynamic> walletData = wallet as Map<String, dynamic>;
        walletAsMap.add(walletData);
      }
      existingWalletList = walletAsMap;
    } catch (e) {
      await recordFailedDateTime();
      Logger.error(e);
      _isNeedToMigrate = false;
      return false;
    }

    _isNeedToMigrate = true;
    return true;
  }

  Future migrateWallets(
      Realm realm, WalletDataManagerCryptography? cryptography) async {
    if (_isNeedToMigrate == null) {
      var need = await needToMigrate();
      if (!need) return;
    }

    List<RealmWalletBase> migratedWallets = [];
    List<RealmMultisigWallet> migratedMultisigWallets = [];
    try {
      for (final wallet in existingWalletList!) {
        var descriptor = cryptography == null
            ? wallet[descriptorField]
            : await cryptography.encrypt(wallet[descriptorField]);

        migratedWallets.add(RealmWalletBase(
            wallet[idField],
            wallet[colorField],
            wallet[iconField],
            descriptor,
            wallet[nameField],
            wallet[typeField] ?? WalletType.singleSignature.name,
            balance: wallet[balanceField],
            txCount: 0));

        if (wallet[typeField] == WalletType.multiSignature.name) {
          migratedMultisigWallets.add(RealmMultisigWallet(
              wallet[idField],
              jsonEncode(wallet[signersField]),
              wallet[requiredSignatureCountField],
              walletBase: migratedWallets.last));
        }
      }
    } catch (e) {
      await recordFailedDateTime();
      Logger.error(e);
      return;
    }

    try {
      await realm.writeAsync(() {
        int multisigWalletIndex = 0;
        for (int i = 0; i < migratedWallets.length; i++) {
          realm.add(migratedWallets[i]);
          if (migratedWallets[i].walletType == WalletType.multiSignature.name) {
            realm.add(migratedMultisigWallets[multisigWalletIndex++]);
          }
        }
      });
    } catch (e) {
      await recordFailedDateTime();
      Logger.error(e);
      return;
    }

    if (cryptography != null) {
      await SecureStorageService()
          .write(key: WalletDataManager.nonceField, value: cryptography.nonce);
    }
    await SecureStorageService().delete(key: walletListField);
    Logger.log('--> migration 성공');
  }
}
