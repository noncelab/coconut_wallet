import 'dart:async';
import 'dart:convert';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/constants/dotenv_keys.dart';
import 'package:coconut_wallet/constants/secure_keys.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/error/app_error.dart';
import 'package:coconut_wallet/model/utxo/utxo_tag.dart';
import 'package:coconut_wallet/model/wallet/balance.dart';
import 'package:coconut_wallet/model/wallet/multisig_signer.dart';
import 'package:coconut_wallet/model/wallet/multisig_wallet_list_item.dart';
import 'package:coconut_wallet/model/wallet/singlesig_wallet_list_item.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/model/wallet/wallet_address.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/model/wallet/watch_only_wallet.dart';
import 'package:coconut_wallet/repository/realm/converter/address.dart';
import 'package:coconut_wallet/repository/realm/converter/multisig_wallet.dart';
import 'package:coconut_wallet/repository/realm/converter/singlesig_wallet.dart';
import 'package:coconut_wallet/repository/realm/converter/transaction.dart';
import 'package:coconut_wallet/repository/realm/converter/utxo_tag.dart';
import 'package:coconut_wallet/repository/realm/migration/migrator_ver2_1_0.dart';
import 'package:coconut_wallet/repository/realm/model/coconut_wallet_model.dart';
import 'package:coconut_wallet/repository/realm/service/realm_id_service.dart';
import 'package:coconut_wallet/repository/realm/wallet_data_manager_cryptography.dart';
import 'package:coconut_wallet/repository/secure_storage/secure_storage_repository.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:coconut_wallet/services/model/response/block_timestamp.dart';
import 'package:coconut_wallet/services/model/response/fetch_transaction_response.dart';
import 'package:coconut_wallet/utils/result.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:realm/realm.dart';

class WalletDataManager {
  static const String nextIdField = 'nextId';
  static const String nonceField = 'nonce';
  static const String pinField = kSecureStoragePinKey;

  final SecureStorageRepository _storageService = SecureStorageRepository();
  final SharedPrefsRepository _sharedPrefs = SharedPrefsRepository();

  static final WalletDataManager _instance = WalletDataManager._internal();
  factory WalletDataManager() => _instance;

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  WalletDataManagerCryptography? _cryptography;

  late Realm _realm;

  List<WalletListItemBase>? _walletList;
  get walletList => _walletList;

  List<UtxoTag> _utxoTagList = [];
  final MigratorVer2_1_0 _migratorVer2_1_0 = MigratorVer2_1_0();

  WalletDataManager._internal();

  void _initRealm() {
    var config = Configuration.local(
      [
        RealmWalletBase.schema,
        RealmMultisigWallet.schema,
        RealmTransaction.schema,
        RealmIntegerId.schema,
        TempBroadcastTimeRecord.schema,
        RealmUtxoTag.schema,
        RealmWalletAddress.schema,
        RealmWalletBalance.schema,
      ],
      schemaVersion: 1,
      migrationCallback: (migration, oldVersion) {},
    );
    _realm = Realm(config);
  }

  Future init(bool isSetPin) async {
    _initRealm();

    bool needToMigrate = await _migratorVer2_1_0.needToMigrate();
    String? hashedPin;
    if (isSetPin) {
      hashedPin = await _storageService.read(key: pinField);
      String? nonce = await _storageService.read(key: nonceField);
      await _initCryptography(nonce, hashedPin!);
    }

    if (needToMigrate) {
      await _migratorVer2_1_0.migrateWallets(_realm, _cryptography);
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

  void _checkInitialized() {
    if (!_isInitialized) {
      throw StateError(
          'WalletDataManager is not initialized. Call initialize first.');
    }
  }

  Future<List<WalletListItemBase>> loadWalletsFromDB() async {
    _checkInitialized();

    _walletList = [];
    int multisigWalletIndex = 0;
    var walletBases =
        _realm.all<RealmWalletBase>().query('TRUEPREDICATE SORT(id ASC)');
    var multisigWallets =
        _realm.all<RealmMultisigWallet>().query('TRUEPREDICATE SORT(id ASC)');
    for (var i = 0; i < walletBases.length; i++) {
      String? decryptedDescriptor;
      if (_cryptography != null) {
        decryptedDescriptor =
            await _cryptography!.decrypt(walletBases[i].descriptor);
      }

      var balance = getTotalBalanceFromDb(walletBases[i].id);
      if (walletBases[i].walletType == WalletType.singleSignature.name) {
        _walletList!.add(mapRealmWalletBaseToSinglesigWalletListItem(
            walletBases[i], decryptedDescriptor, balance));
      } else {
        assert(walletBases[i].id == multisigWallets[multisigWalletIndex].id);
        _walletList!.add(mapRealmMultisigWalletToMultisigWalletListItem(
            multisigWallets[multisigWalletIndex++],
            decryptedDescriptor,
            balance));
      }
    }

    return List.from(_walletList!);
  }

  int getTotalBalanceFromDb(int walletId) {
    var balance = _realm.query<RealmWalletBalance>('walletId == $walletId}');
    return balance.last.total;
  }

  Future<SinglesigWalletListItem> addSinglesigWallet(
      WatchOnlyWallet watchOnlyWallet) async {
    _checkInitialized();

    var id = _getNextWalletId();
    String descriptor = _cryptography != null
        ? await _cryptography!.encrypt(watchOnlyWallet.descriptor)
        : watchOnlyWallet.descriptor;

    var wallet = RealmWalletBase(
        id,
        watchOnlyWallet.colorIndex,
        watchOnlyWallet.iconIndex,
        descriptor,
        watchOnlyWallet.name,
        WalletType.singleSignature.name);
    _realm.write(() {
      _realm.add(wallet);
    });
    _recordNextWalletId(id + 1);

    var singlesigWallet = SinglesigWalletListItem(
        id: id,
        name: watchOnlyWallet.name,
        colorIndex: watchOnlyWallet.colorIndex,
        iconIndex: watchOnlyWallet.iconIndex,
        descriptor: watchOnlyWallet.descriptor);

    _walletList!.add(singlesigWallet);

    return singlesigWallet;
  }

  Future<MultisigWalletListItem> addMultisigWallet(
      WatchOnlyWallet walletSync) async {
    _checkInitialized();

    var id = _getNextWalletId();
    String descriptor = _cryptography != null
        ? await _cryptography!.encrypt(walletSync.descriptor)
        : walletSync.descriptor;

    var realmWalletBase = RealmWalletBase(
        id,
        walletSync.colorIndex,
        walletSync.iconIndex,
        descriptor,
        walletSync.name,
        WalletType.multiSignature.name);
    var realmMultisigWallet = RealmMultisigWallet(
        id,
        MultisigSigner.toJsonList(walletSync.signers!),
        walletSync.requiredSignatureCount!,
        walletBase: realmWalletBase);
    _realm.write(() {
      _realm.add(realmWalletBase);
      _realm.add(realmMultisigWallet);
    });
    _recordNextWalletId(id + 1);

    var multisigWallet = MultisigWalletListItem(
        id: id,
        name: walletSync.name,
        colorIndex: walletSync.colorIndex,
        iconIndex: walletSync.iconIndex,
        descriptor: walletSync.descriptor,
        signers: walletSync.signers!,
        requiredSignatureCount: walletSync.requiredSignatureCount!);

    _walletList!.add(multisigWallet);

    return multisigWallet;
  }

  RealmResults<RealmTransaction> getUnconfirmedTransactions(int walletId) {
    return _realm.query<RealmTransaction>(
        r'walletId = $0 AND blockHeight = 0', [walletId]);
  }

  void updateWalletUI(int id, WatchOnlyWallet watchOnlyWallet) {
    _checkInitialized();

    final RealmWalletBase wallet =
        _realm.all<RealmWalletBase>().query('id = $id').first;
    final RealmMultisigWallet? multisigWallet =
        _realm.all<RealmMultisigWallet>().query('id = $id').firstOrNull;
    if (wallet.walletType == WalletType.multiSignature.name) {
      assert(multisigWallet != null);
    }

    // ui 정보 변경하기
    _realm.write(() {
      wallet.name = watchOnlyWallet.name;
      wallet.colorIndex = watchOnlyWallet.colorIndex;
      wallet.iconIndex = watchOnlyWallet.iconIndex;

      if (multisigWallet != null) {
        multisigWallet.signersInJsonSerialization =
            MultisigSigner.toJsonList(watchOnlyWallet.signers!);
      }
    });

    WalletListItemBase walletListItemBase =
        _walletList!.firstWhere((wallet) => wallet.id == id);
    walletListItemBase
      ..name = watchOnlyWallet.name
      ..colorIndex = watchOnlyWallet.colorIndex
      ..iconIndex = watchOnlyWallet.iconIndex;

    if (wallet.walletType == WalletType.multiSignature.name) {
      (walletListItemBase as MultisigWalletListItem).signers =
          watchOnlyWallet.signers!;
    }
  }

  void deleteWallet(int walletId) {
    _checkInitialized();

    final walletBaseResults = _realm.query<RealmWalletBase>('id == $walletId');
    final walletBase = walletBaseResults.first;
    final transactions =
        _realm.query<RealmTransaction>('walletId == $walletId');
    final walletBalance =
        _realm.query<RealmWalletBalance>('walletId == $walletId');
    final walletAddress =
        _realm.query<RealmWalletAddress>('walletId == $walletId');
    // TODO: utxos

    final realmMultisigWalletResults =
        walletBase.walletType == WalletType.multiSignature.name
            ? _realm.query<RealmMultisigWallet>('id == $walletId')
            : null;
    final realmMultisigWallet = realmMultisigWalletResults?.first;

    _realm.write(() {
      _realm.delete(walletBase);
      _realm.deleteMany(transactions);
      if (realmMultisigWallet != null) {
        _realm.delete(realmMultisigWallet);
      }
      _realm.deleteMany(walletBalance);
      _realm.deleteMany(walletAddress);
    });

    final index = _walletList!.indexWhere((item) => item.id == walletId);
    _walletList!.removeAt(index);
  }

  /// walletId 로 태그 목록 조회
  Result<List<UtxoTag>> loadUtxoTagList(int walletId) {
    _utxoTagList = [];
    final tags = _realm
        .query<RealmUtxoTag>("walletId == '$walletId' SORT(createAt DESC)");

    var result = _handleRealm<List<UtxoTag>>(
      () {
        _utxoTagList.addAll(tags.map(mapRealmUtxoTagToUtxoTag));
        return _utxoTagList;
      },
    );
    return result;
  }

  Future<Result<void>> updateTagsOfSpentUtxos(
      int walletId, List<String> usedUtxoIds, List<String> newUtxoIds) async {
    final tags = _realm.query<RealmUtxoTag>("walletId == '$walletId'");

    return _handleAsyncRealm(
      () async {
        await _realm.writeAsync(() {
          for (int i = 0; i < tags.length; i++) {
            if (tags[i].utxoIdList.isEmpty) continue;

            int previousCount = tags[i].utxoIdList.length;

            tags[i].utxoIdList.removeWhere((utxoId) =>
                usedUtxoIds.any((targetUtxoId) => targetUtxoId == utxoId));

            if (newUtxoIds.isNotEmpty) {
              bool needToMove = previousCount > tags[i].utxoIdList.length;
              if (needToMove) {
                tags[i].utxoIdList.addAll(newUtxoIds);
              }
            }
          }
        });
      },
    );
  }

  /// walletId 로 조회된 태그 목록에서 txHashIndex 를 포함하고 있는 태그 목록 조회
  Result<List<UtxoTag>> loadUtxoTagListByUtxoId(int walletId, String utxoId) {
    return _handleRealm<List<UtxoTag>>(() {
      _utxoTagList = [];

      final tags = _realm
          .all<RealmUtxoTag>()
          .query("walletId == '$walletId' SORT(createAt DESC)");

      _utxoTagList.addAll(
        tags
            .where((tag) => tag.utxoIdList.contains(utxoId))
            .map(mapRealmUtxoTagToUtxoTag),
      );

      return _utxoTagList;
    });
  }

  /// 태그 추가
  Result<UtxoTag> addUtxoTag(
      String id, int walletId, String name, int colorIndex) {
    return _handleRealm<UtxoTag>(() {
      final tag = RealmUtxoTag(id, walletId, name, colorIndex, DateTime.now());
      _realm.write(() {
        _realm.add(tag);
      });
      return mapRealmUtxoTagToUtxoTag(tag);
    });
  }

  /// id 로 조회된 태그의 속성 업데이트
  Result<UtxoTag> updateUtxoTag(String id, String name, int colorIndex) {
    return _handleRealm<UtxoTag>(() {
      final tags = _realm.query<RealmUtxoTag>("id == '$id'");

      if (tags.isEmpty) {
        throw ErrorCodes.realmNotFound;
      }

      final tag = tags.first;

      _realm.write(() {
        tag.name = name;
        tag.colorIndex = colorIndex;
      });
      return mapRealmUtxoTagToUtxoTag(tag);
    });
  }

  /// id 로 조회된 태그 삭제
  Result<UtxoTag> deleteUtxoTag(String id) {
    return _handleRealm<UtxoTag>(() {
      final tag = _realm.find<RealmUtxoTag>(id);

      if (tag == null) {
        throw ErrorCodes.realmNotFound;
      }

      final removeTag = mapRealmUtxoTagToUtxoTag(tag);

      _realm.write(() {
        _realm.delete(tag);
      });

      return removeTag;
    });
  }

  /// walletId 로 조회된 태그 전체 삭제
  Result<bool> deleteAllUtxoTag(int walletId) {
    return _handleRealm<bool>(() {
      final tags = _realm.query<RealmUtxoTag>("walletId == '$walletId'");

      if (tags.isEmpty) {
        throw ErrorCodes.realmNotFound;
      }

      _realm.deleteMany(tags);

      return true;
    });
  }

  /// utxoIdList 변경
  /// - [walletId] 목록 검색
  /// - [utxoId] Utxo Id
  /// - [addTags] 추가할 UtxoTag 목록
  /// - [selectedNames] 선택된 태그명 목록
  Result<bool> updateUtxoTagList(int walletId, String utxoId,
      List<UtxoTag> addTags, List<String> selectedNames) {
    return _handleRealm<bool>(
      () {
        _realm.write(() {
          // 새로운 태그 추가
          final now = DateTime.now();
          for (var utxoTag in addTags) {
            final tag = RealmUtxoTag(
              utxoTag.id,
              walletId,
              utxoTag.name,
              utxoTag.colorIndex,
              now,
            );
            _realm.add(tag);
          }

          // 태그 적용
          final tags = _realm.query<RealmUtxoTag>("walletId == '$walletId'");
          for (var tag in tags) {
            if (selectedNames.contains(tag.name)) {
              if (!tag.utxoIdList.contains(utxoId)) {
                tag.utxoIdList.add(utxoId);
              }
            } else {
              tag.utxoIdList.remove(utxoId);
            }
          }
        });

        return true;
      },
    );
  }

  /// walletID, txHash 로 transaction 조회
  Result<TransactionRecord?> loadTransaction(int walletId, String txHash) {
    final transactions = _realm.query<RealmTransaction>(
        "walletId == '$walletId' And transactionHash == '$txHash'");

    return _handleRealm<TransactionRecord?>(
      () => transactions.isEmpty
          ? null
          : mapRealmTransactionToTransaction(transactions.first),
    );
  }

  /// walletId, transactionHash 로 조회된 transaction 의 메모 변경
  Result<TransactionRecord> updateTransactionMemo(
      int walletId, String txHash, String memo) {
    final transactions = _realm.query<RealmTransaction>(
        "walletId == '$walletId' And transactionHash == '$txHash'");

    return _handleRealm<TransactionRecord>(
      () {
        final transaction = transactions.first;
        _realm.write(() {
          transaction.memo = memo;
        });
        return mapRealmTransactionToTransaction(transaction);
      },
    );
  }

  int _getNextWalletId() {
    _checkInitialized();

    var id = _sharedPrefs.getInt(nextIdField);
    if (id == 0) {
      return 1;
    }
    return id;
  }

  void _recordNextWalletId(int value) {
    _checkInitialized();

    _sharedPrefs.setInt(nextIdField, value);
  }

  List<TransactionRecord>? getTxList(int id) {
    _checkInitialized();

    final transactions =
        _realm.query<RealmTransaction>('walletId == $id SORT(timestamp DESC)');

    if (transactions.isEmpty) return null;
    List<TransactionRecord> result = [];

    final unconfirmed =
        transactions.query('blockHeight = 0 SORT(createdAt DESC)');
    final confirmed = transactions
        .query('blockHeight != 0 SORT(timestamp DESC, createdAt DESC)');

    for (var t in unconfirmed) {
      result.add(mapRealmTransactionToTransaction(t));
    }
    for (var t in confirmed) {
      result.add(mapRealmTransactionToTransaction(t));
    }

    return result;
  }

  Future<void> recordTemporaryBroadcastTime(
      String txHash, DateTime createdAt) async {
    await _realm.writeAsync(() {
      _realm.add(TempBroadcastTimeRecord(txHash, createdAt));
    });
  }

  void reset() {
    _initRealm();
    _realm.write(() {
      _realm.deleteAll<RealmWalletBase>();
      _realm.deleteAll<RealmMultisigWallet>();
      _realm.deleteAll<RealmTransaction>();
      _realm.deleteAll<RealmUtxoTag>();
      _realm.deleteAll<RealmWalletBalance>();
    });

    _walletList = [];
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
    _checkInitialized();

    var walletBases =
        _realm.all<RealmWalletBase>().query('TRUEPREDICATE SORT(id ASC)');

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
    await _realm.writeAsync(() {
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
    _checkInitialized();

    var walletBases =
        _realm.all<RealmWalletBase>().query('TRUEPREDICATE SORT(id ASC)');
    List<String> decryptedDescriptions =
        await _createDecryptedDescriptionList(walletBases);

    await _realm.writeAsync(() {
      for (var i = 0; i < walletBases.length; i++) {
        walletBases[i].descriptor = decryptedDescriptions[i];
      }
    });

    await _storageService.delete(key: nonceField);
    _cryptography = null;
  }

  updateWalletBalance(int walletId, Balance balance) {
    _checkInitialized();

    RealmWalletBase? realmWalletBase = _realm.find<RealmWalletBase>(walletId);
    RealmWalletBalance? realmWalletBalance =
        _realm.find<RealmWalletBalance>(walletId);

    if (realmWalletBase == null) {
      throw StateError('[updateWalletBalance] Wallet not found');
    }

    if (realmWalletBalance == null) {
      _createNewWalletBalance(realmWalletBase, balance);
      return;
    }

    _realm.write(() {
      realmWalletBase.balance = balance.total;
      realmWalletBalance.total = balance.total;
      realmWalletBalance.confirmed = balance.confirmed;
      realmWalletBalance.unconfirmed = balance.unconfirmed;
    });
  }

  void _createNewWalletBalance(
      RealmWalletBase realmWalletBase, Balance walletBalance) {
    int walletBalanceLastId =
        getLastId(_realm, (RealmWalletBalance).toString());

    final realmWalletBalance = RealmWalletBalance(
      ++walletBalanceLastId,
      realmWalletBase.id,
      walletBalance.confirmed + walletBalance.unconfirmed,
      walletBalance.confirmed,
      walletBalance.unconfirmed,
    );

    _realm.write(() {
      realmWalletBase.balance = walletBalance.total;
      _realm.add(realmWalletBalance);
    });
    saveLastId(_realm, (RealmWalletBalance).toString(), walletBalanceLastId);
  }

  // not used
  void dispose() {
    _realm.close();
  }

  Balance getWalletBalance(int walletId) {
    final realmWalletBalance =
        _realm.query<RealmWalletBalance>('walletId == $walletId');

    if (realmWalletBalance.isEmpty) {
      _createNewWalletBalance(
        _realm.find<RealmWalletBase>(walletId)!,
        Balance(0, 0),
      );
      return Balance(0, 0);
    }

    return Balance(
      realmWalletBalance.last.confirmed,
      realmWalletBalance.last.unconfirmed,
    );
  }

  List<WalletAddress> getWalletAddressList(
    WalletListItemBase walletItemBase,
    int cursor,
    int count,
    bool isChange,
  ) {
    ensureAddressesExist(
      walletItemBase: walletItemBase,
      cursor: cursor,
      count: count,
      isChange: isChange,
    );

    return _getAddressesFromDB(
      walletId: walletItemBase.id,
      cursor: cursor,
      count: count,
      isChange: isChange,
    );
  }

  /// 필요한 경우 새로운 주소를 생성하고 저장
  void ensureAddressesExist({
    required WalletListItemBase walletItemBase,
    required int cursor,
    required int count,
    required bool isChange,
  }) {
    _checkInitialized();

    final realmWalletBase = _realm.find<RealmWalletBase>(walletItemBase.id);
    if (realmWalletBase == null) {
      throw StateError('[getWalletAddressList] Wallet not found');
    }

    final currentIndex = isChange
        ? realmWalletBase.generatedChangeIndex
        : realmWalletBase.generatedReceiveIndex;

    if (cursor + count > currentIndex) {
      final startIndex = currentIndex + 1;
      final endIndex = cursor + count;
      final addressCount = endIndex - startIndex;

      if (addressCount > 0) {
        final addresses = _generateAddresses(
          wallet: walletItemBase.walletBase,
          startIndex: startIndex,
          count: addressCount,
          isChange: isChange,
        );

        _saveAddressesToDB(realmWalletBase, addresses, isChange);
      }
    }
  }

  /// DB에서 주소 목록 조회
  List<WalletAddress> _getAddressesFromDB({
    required int walletId,
    required int cursor,
    required int count,
    required bool isChange,
  }) {
    final query = _realm.query<RealmWalletAddress>(
        'walletId == $walletId AND isChange == $isChange SORT(index ASC)');
    final paginatedResults = query.skip(cursor).take(count);

    return paginatedResults.map((e) => mapRealmToWalletAddress(e)).toList();
  }

  void _saveAddressesToDB(RealmWalletBase realmWalletBase,
      List<WalletAddress> addresses, bool isChange) {
    int lastId = getLastId(_realm, (RealmWalletAddress).toString());

    final realmAddresses = addresses
        .map(
          (address) => RealmWalletAddress(
            ++lastId,
            realmWalletBase.id,
            address.address,
            address.index,
            isChange,
            address.derivationPath,
            address.isUsed,
            address.confirmed,
            address.unconfirmed,
            address.total,
          ),
        )
        .toList();

    _realm.write(() {
      _realm.addAll(realmAddresses);

      // 생성된 주소 인덱스 업데이트
      if (isChange) {
        realmWalletBase.generatedChangeIndex = realmAddresses.last.index;
      } else {
        realmWalletBase.generatedReceiveIndex = realmAddresses.last.index;
      }
    });
    saveLastId(_realm, (RealmWalletAddress).toString(), lastId);
  }

  WalletAddress _generateAddress(WalletBase wallet, int index, bool isChange) {
    String address = wallet.getAddress(index, isChange: isChange);
    String derivationPath =
        '${wallet.derivationPath}${isChange ? '/1' : '/0'}/$index';

    return WalletAddress(
      address,
      derivationPath,
      index,
      false,
      0,
      0,
      0,
    );
  }

  List<WalletAddress> _generateAddresses(
      {required WalletBase wallet,
      required int startIndex,
      required int count,
      required bool isChange}) {
    return List.generate(count,
        (index) => _generateAddress(wallet, startIndex + index, isChange));
  }

  /// 공통 에러 핸들링
  Result<T> _handleRealm<T>(
    T Function() operation,
  ) {
    try {
      return Result.success(operation());
    } catch (e) {
      return _handleError<T>(e);
    }
  }

  /// 비동기 공통 에러 핸들링
  Future<Result<T>> _handleAsyncRealm<T>(
    Future<T> Function() operation,
  ) async {
    try {
      return Result.success(await operation());
    } catch (e) {
      return _handleError(e);
    }
  }

  Result<T> _handleError<T>(e) {
    if (e is AppError) {
      return Result<T>.failure(e);
    }

    if (e is RealmException) {
      return Result<T>.failure(
        ErrorCodes.withMessage(ErrorCodes.realmException, e.message),
      );
    }

    return Result<T>.failure(
      ErrorCodes.withMessage(ErrorCodes.realmUnknown, e.toString()),
    );
  }

  Future<void> updateTransactionStates(
    int walletId,
    List<String> txsToUpdate,
    List<String> txsToDelete,
    Map<String, FetchTransactionResponse> fetchedTxMap,
    Map<int, BlockTimestamp> blockTimestampMap,
  ) async {
    _checkInitialized();

    final realmWalletBase = _realm.find<RealmWalletBase>(walletId);
    if (realmWalletBase == null) {
      throw StateError('[updateTransactionStates] Wallet not found');
    }

    RealmResults<RealmTransaction>? txsToDeleteRealm;
    RealmResults<RealmTransaction>? txsToUpdateRealm;

    if (txsToDelete.isNotEmpty) {
      txsToDeleteRealm = _realm.query<RealmTransaction>(
          'walletId == $walletId AND transactionHash IN \$0', [txsToDelete]);
    }

    if (txsToUpdate.isNotEmpty) {
      txsToUpdateRealm = _realm.query<RealmTransaction>(
          'walletId == $walletId AND transactionHash IN \$0', [txsToUpdate]);
    }

    await _realm.writeAsync(() {
      // 1. 삭제할 트랜잭션 처리
      if (txsToDeleteRealm != null) {
        _realm.deleteMany(txsToDeleteRealm);
      }

      // 2. 업데이트할 트랜잭션 처리
      if (txsToUpdateRealm != null) {
        for (final tx in txsToUpdateRealm) {
          final fetchedTx = fetchedTxMap[tx.transactionHash]!;
          tx.blockHeight = fetchedTx.height;
          tx.timestamp = blockTimestampMap[fetchedTx.height]!.timestamp;
        }
      }

      // 3. 지갑의 최신 트랜잭션 상태 업데이트
      realmWalletBase.isLatestTxBlockHeightZero =
          fetchedTxMap.values.any((tx) => tx.height == 0);
    });
  }

  Set<String> getExistingConfirmedTxHashes(int walletId) {
    final realmTxs = _realm
        .query<RealmTransaction>('walletId == $walletId AND blockHeight > 0');
    return realmTxs.map((tx) => tx.transactionHash).toSet();
  }

  bool containsAddress(int walletId, String address) {
    final realmWalletAddress = _realm.query<RealmWalletAddress>(
      r'walletId == $0 AND address == $1',
      [walletId, address],
    );
    return realmWalletAddress.isNotEmpty;
  }

  List<WalletAddress> filterChangeAddressesFromList(
      int walletId, List<String> addresses) {
    final realmWalletAddresses = _realm.query<RealmWalletAddress>(
      r'walletId == $0 AND address IN $1 AND isChange == true',
      [walletId, addresses],
    );
    return realmWalletAddresses.map((e) => mapRealmToWalletAddress(e)).toList();
  }

  void addAllTransactions(int walletId, List<TransactionRecord> txList) {
    _checkInitialized();

    final realmWalletBase = _realm.find<RealmWalletBase>(walletId);
    if (realmWalletBase == null) {
      throw StateError('[addAllTransactions] Wallet not found');
    }

    final now = DateTime.now();
    int lastId = getLastId(_realm, (RealmTransaction).toString());

    final realmTxs = txList
        .map((tx) => mapTransactionToRealmTransaction(
              tx,
              walletId,
              ++lastId,
              now,
            ))
        .toList();
    _realm.write(() {
      _realm.addAll(realmTxs);
    });
    saveLastId(_realm, (RealmTransaction).toString(), lastId);
  }

  // 잔액과 사용여부만 갱신합니다.
  void updateWalletAddressList(WalletListItemBase walletItem,
      List<WalletAddress> walletAddressList, bool isChange) {
    _checkInitialized();

    final realmWalletAddresses = _realm.query<RealmWalletAddress>(
      r'walletId == $0 AND isChange == $1',
      [walletItem.id, isChange],
    );

    _realm.write(() {
      for (final walletAddress in walletAddressList) {
        final realmAddress = realmWalletAddresses.firstWhere(
          (a) => a.index == walletAddress.index,
        );

        realmAddress.confirmed = walletAddress.confirmed;
        realmAddress.unconfirmed = walletAddress.unconfirmed;
        realmAddress.total = walletAddress.total;
        realmAddress.isUsed = walletAddress.isUsed;
      }
    });
  }

  WalletAddress getChangeAddress(int walletId) {
    final realmWalletBase = getExistingWalletBase(walletId);
    final changeIndex = realmWalletBase.generatedChangeIndex + 1;
    final realmWalletAddress = _realm.query<RealmWalletAddress>(
      r'walletId == $0 AND isChange == true AND index == $1',
      [walletId, changeIndex],
    );

    return mapRealmToWalletAddress(realmWalletAddress.first);
  }

  WalletAddress getReceiveAddress(int walletId) {
    final realmWalletBase = getExistingWalletBase(walletId);
    final receiveIndex = realmWalletBase.generatedReceiveIndex + 1;
    final realmWalletAddress = _realm.query<RealmWalletAddress>(
      r'walletId == $0 AND isChange == false AND index == $1',
      [walletId, receiveIndex],
    );

    return mapRealmToWalletAddress(realmWalletAddress.first);
  }

  RealmWalletBase getExistingWalletBase(int walletId) {
    final realmWalletBase = _realm.find<RealmWalletBase>(walletId);
    if (realmWalletBase == null) {
      throw StateError('[getExistingWalletBase] Wallet not found');
    }
    return realmWalletBase;
  }
}
