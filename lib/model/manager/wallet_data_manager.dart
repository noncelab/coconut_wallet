import 'dart:convert';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/constants/app_info.dart';
import 'package:coconut_wallet/constants/dotenv_keys.dart';
import 'package:coconut_wallet/model/app_error.dart';
import 'package:coconut_wallet/model/data/multisig_signer.dart';
import 'package:coconut_wallet/model/data/multisig_wallet_list_item.dart';
import 'package:coconut_wallet/model/data/singlesig_wallet_list_item.dart';
import 'package:coconut_wallet/model/data/wallet_list_item_base.dart';
import 'package:coconut_wallet/model/data/wallet_type.dart';
import 'package:coconut_wallet/model/manager/converter/multisig_wallet.dart';
import 'package:coconut_wallet/model/manager/converter/singlesig_wallet.dart';
import 'package:coconut_wallet/model/manager/converter/transaction.dart';
import 'package:coconut_wallet/model/manager/converter/utxo_tag.dart';
import 'package:coconut_wallet/model/manager/migration/migrator_ver2_1_0.dart';
import 'package:coconut_wallet/model/manager/realm/model/coconut_wallet_data.dart';
import 'package:coconut_wallet/model/manager/realm/realm_id_service.dart';
import 'package:coconut_wallet/model/manager/wallet_data_manager_cryptography.dart';
import 'package:coconut_wallet/model/utxo_tag.dart';
import 'package:coconut_wallet/model/wallet_sync.dart';
import 'package:coconut_wallet/services/secure_storage_service.dart';
import 'package:coconut_wallet/services/shared_prefs_service.dart';
import 'package:coconut_wallet/utils/cconut_wallet_util.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:realm/realm.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class WalletDataManager {
  static const String nextIdField = 'nextId';
  static const String nonceField = 'nonce';
  static const String pinField = kSecureStoragePinKey;

  final SecureStorageService _storageService = SecureStorageService();
  final SharedPrefs _sharedPrefs = SharedPrefs();

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

      if (walletBases[i].walletType == WalletType.singleSignature.name) {
        _walletList!.add(mapRealmWalletBaseToSinglesigWalletListItem(
            walletBases[i], decryptedDescriptor));
      } else {
        assert(walletBases[i].id == multisigWallets[multisigWalletIndex].id);
        _walletList!.add(mapRealmMultisigWalletToMultisigWalletListItem(
            multisigWallets[multisigWalletIndex++], decryptedDescriptor));
      }
    }

    return List.from(_walletList!);
  }

  Future<SinglesigWalletListItem> addSinglesigWallet(
      WalletSync walletSync) async {
    _checkInitialized();

    var id = _getNextWalletId();
    String descriptor = _cryptography != null
        ? await _cryptography!.encrypt(walletSync.descriptor)
        : walletSync.descriptor;

    var wallet = RealmWalletBase(
        id,
        walletSync.colorIndex,
        walletSync.iconIndex,
        descriptor,
        walletSync.name,
        WalletType.singleSignature.name);
    _realm.write(() {
      _realm.add(wallet);
    });
    _recordNextWalletId(id + 1);

    var singlesigWallet = SinglesigWalletListItem(
        id: id,
        name: walletSync.name,
        colorIndex: walletSync.colorIndex,
        iconIndex: walletSync.iconIndex,
        descriptor: walletSync.descriptor);

    _walletList!.add(singlesigWallet);

    return singlesigWallet;
  }

  Future<MultisigWalletListItem> addMultisigWallet(
      WalletSync walletSync) async {
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

  /// 업데이트 해야 되는 지갑과 업데이트 내용에 따라 db와 _walletList 업데이트 합니다.
  /// 만약 업데이트 과정에서 에러 발생시, 에러를 반환합니다.
  /// 변경이 있었으면 true, 없었으면 false를 반환
  Future<bool> syncWithLatest(
      List<WalletListItemBase> targets, NodeConnector nodeConnector) async {
    _checkInitialized();

    List<int> noNeedToUpdate = [];
    List<WalletListItemBase> needToUpdateList = [];
    List<WalletStatus> syncResults = [];
    List<int> needToUpdateIds = [];
    for (int i = 0; i < targets.length; i++) {
      WalletFeature coconutWallet = getWalletFeatureByWalletType(targets[i]);
      try {
        await coconutWallet.fetchOnChainData(nodeConnector);
      } catch (e) {
        throw ErrorCodes.syncFailedError;
      }
      // assert(coconutWallet.walletStatus != null);
      WalletStatus syncResult = coconutWallet.walletStatus!;
      // check need to update
      Logger.log(
          '--> targets[i].isLatestTxBlockHeightZero: ${targets[i].isLatestTxBlockHeightZero}');
      Logger.log(
          '--> syncResult.transactionList.length, targets[i].txCount: ${syncResult.transactionList.length} ${targets[i].txCount}');
      Logger.log('--> targets[i].balance: ${targets[i].balance}');
      if (!targets[i].isLatestTxBlockHeightZero &&
          syncResult.transactionList.length == targets[i].txCount &&
          targets[i].balance != null) {
        noNeedToUpdate.add(i);
        continue;
      }

      needToUpdateIds.add(targets[i].id);
      needToUpdateList.add(targets[i]);
      syncResults.add(syncResult);
    }
    Logger.log('--> noNeedToUpdate: ${noNeedToUpdate.length}');
    Logger.log('--> needToUpdateIds: ${needToUpdateIds.length}');
    if (noNeedToUpdate.length == targets.length) return false;

    // TODO: 정렬 되는지 확인하기.
    final realmWallets = _realm
        .all<RealmWalletBase>()
        .query(r'id IN $0 SORT(id ASC)', [needToUpdateIds]);

    for (int i = 0; i < realmWallets.length; i++) {
      _updateDBAndWalletListAsLatest(
          needToUpdateList[i], realmWallets[i], syncResults[i]);
    }

    return true;
  }

  // TODO: 함수명, 리팩토링
  void _updateDBAndWalletListAsLatest(WalletListItemBase walletItem,
      RealmWalletBase realmWallet, WalletStatus syncResult) {
    _checkInitialized();

    // 갱신해야 하는 txList 개수 구하기
    int getTxCount = 0;
    // 지갑에서 보내기 한 내역 조회, createdAt값 저장을 위해
    RealmResults<TempBroadcastTimeRecord>? tempBroadcastTimeRecord =
        _realm.all<TempBroadcastTimeRecord>();
    if (realmWallet.txCount == null ||
        realmWallet.txCount != syncResult.transactionList.length) {
      getTxCount =
          syncResult.transactionList.length - (realmWallet.txCount ?? 0);
    }
    RealmResults<RealmTransaction>? updateTargets;
    List<RealmTransaction>?
        finalUpdateTargets; // 새로운 row 추가 시 updateTargets 결과가 변경되기 때문에 처음 결과를 이 변수에 저장
    // 전송 중, 받는 중인 트랜잭션이 있는 경우
    if (walletItem.isLatestTxBlockHeightZero) {
      updateTargets = _realm
          .all<RealmTransaction>()
          .query(r'walletBase.id = $0', [realmWallet.id]);
      // db에서 blockHeight가 0인 tx 중 가장 작은 id
      final firstProcessingTx =
          updateTargets.query('blockHeight == 0 SORT(id ASC)').first;

      updateTargets = updateTargets.query('id >= ${firstProcessingTx.id}');
      Logger.log('--> updateTargets: ${updateTargets.length}');
      getTxCount = getTxCount + updateTargets.length;
      finalUpdateTargets = updateTargets.toList();
    }
    Logger.log(
        '--> getTxCount 계산: ${syncResult.transactionList.length} - ${realmWallet.txCount} + ${finalUpdateTargets?.length} = $getTxCount');

    var walletFeature = getWalletFeatureByWalletType(walletItem);
    // 항상 최신순으로 반환
    List<Transfer> newTxList =
        walletFeature.getTransferList(cursor: 0, count: getTxCount);
    Logger.log('--> newTxList length: ${newTxList.length}');
    int nextId = generateNextId(_realm, (RealmTransaction).toString());
    List<int> matchedUpdateTargetIds = [];
    _realm.write(() {
      for (int i = newTxList.length - 1; i >= 0; i--) {
        RealmTransaction? existingTx;
        if (walletItem.isLatestTxBlockHeightZero &&
            updateTargets != null &&
            updateTargets.isNotEmpty) {
          existingTx = updateTargets.query(r'transactionHash = $0',
              [newTxList[i].transactionHash]).firstOrNull;
        }

        RealmTransaction saveTarget;
        TempBroadcastTimeRecord? record = tempBroadcastTimeRecord
            .query('transactionHash = \'${newTxList[i].transactionHash}\'')
            .firstOrNull;
        if (existingTx != null) {
          existingTx
            ..timestamp = newTxList[i].timestamp
            ..blockHeight = newTxList[i].blockHeight;
          matchedUpdateTargetIds.add(existingTx.id);
        } else {
          saveTarget = mapTransferToRealmTransaction(
              newTxList[i], realmWallet, nextId, record?.createdAt);
          nextId++;

          _realm.add<RealmTransaction>(saveTarget);
        }

        // 코코넛 월렛 안의 지갑끼리 주고받은 경우를 위해 삭제 시점을 아래로 변경
        // 컨펌된 트랜잭션의 TempBroadcastTimeRecord 삭제
        if (record != null && newTxList[i].blockHeight != 0) {
          _realm.delete<TempBroadcastTimeRecord>(record);
        }
      }

      // INFO: RBF(Replace-By-Fee)에 의해서 처리되지 않은 트랜잭션이 삭제된 경우를 대비
      // INFO: 추후에는 삭제가 아니라 '무효화됨'으로 표기될 수 있음
      if (finalUpdateTargets != null && finalUpdateTargets.isNotEmpty) {
        for (var ut in finalUpdateTargets) {
          var index = matchedUpdateTargetIds.indexWhere((x) => x == ut.id);
          if (index == -1) {
            _realm.delete(ut);
          }
        }
      }

      realmWallet.txCount = syncResult.transactionList.length;
      realmWallet.isLatestTxBlockHeightZero =
          newTxList.isNotEmpty && newTxList[0].blockHeight == 0;
      realmWallet.balance =
          walletFeature.getBalance() + walletFeature.getUnconfirmedBalance();
    });
    saveNextId(_realm, (RealmTransaction).toString(), nextId);

    _walletList!.firstWhere((w) => w.id == realmWallet.id)
      ..txCount = realmWallet.txCount
      ..isLatestTxBlockHeightZero = realmWallet.isLatestTxBlockHeightZero
      ..balance = realmWallet.balance;
  }

  void updateWalletUI(int id, WalletSync walletSync) {
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
      wallet.name = walletSync.name;
      wallet.colorIndex = walletSync.colorIndex;
      wallet.iconIndex = walletSync.iconIndex;

      if (multisigWallet != null) {
        multisigWallet.signersInJsonSerialization =
            MultisigSigner.toJsonList(walletSync.signers!);
      }
    });

    WalletListItemBase walletListItemBase =
        _walletList!.firstWhere((wallet) => wallet.id == id);
    walletListItemBase
      ..name = walletSync.name
      ..colorIndex = walletSync.colorIndex
      ..iconIndex = walletSync.iconIndex;

    if (wallet.walletType == WalletType.multiSignature.name) {
      (walletListItemBase as MultisigWalletListItem).signers =
          walletSync.signers!;
    }
  }

  void deleteWallet(int id) {
    _checkInitialized();

    final RealmWalletBase walletBase =
        _realm.all<RealmWalletBase>().query('id == $id').first;
    final transactions =
        _realm.all<RealmTransaction>().query('walletBase.id == $id');
    // TODO: utxos

    final realmMultisigWallet =
        walletBase.walletType == WalletType.multiSignature.name
            ? _realm.all<RealmMultisigWallet>().query('id == $id').first
            : null;

    _realm.write(() {
      _realm.delete(walletBase);
      _realm.deleteMany(transactions);
      if (realmMultisigWallet != null) {
        _realm.delete(realmMultisigWallet);
      }
    });

    final index = _walletList!.indexWhere((item) => item.id == id);
    _walletList!.removeAt(index);
  }

  /// walletId 로 태그 목록 조회
  RealmResult<List<UtxoTag>> loadUtxoTagList(int walletId) {
    _utxoTagList = [];

    try {
      final tags = _realm
          .all<RealmUtxoTag>()
          .query("walletId == '$walletId' SORT(createAt DESC)");

      _utxoTagList.addAll(tags.map(mapRealmUtxoTagToUtxoTag));

      return RealmResult(data: _utxoTagList);
    } catch (e) {
      return RealmResult(
        error: e is RealmException
            ? ErrorCodes.withMessage(ErrorCodes.realmException, e.message)
            : ErrorCodes.withMessage(ErrorCodes.realmUnknown, e.toString()),
      );
    }
  }

  // TODO: 주석 확인 후 제거
  // deleteTags 동일한 기능이 필요하여 합쳐짐
  Future<RealmResult<void>> updateTagsOfUsedUtxos(
      int walletId, List<String> usedUtxoIds, List<String> newUtxoIds) async {
    try {
      final tags = _realm.query<RealmUtxoTag>("walletId == '$walletId'");

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
      return RealmResult();
    } catch (e) {
      return RealmResult(
        error: e is RealmException
            ? ErrorCodes.withMessage(ErrorCodes.realmException, e.message)
            : ErrorCodes.withMessage(ErrorCodes.realmUnknown, e.toString()),
      );
    }
  }
  // Future<RealmResult<int>> deleteTags(int walletId, List<String> utxoIds) async {
  //   try {
  //     final tags = _realm.query<RealmUtxoTag>("walletId == '$walletId'");
  //
  //     if (tags.isEmpty) {
  //       return RealmResult(data: 0);
  //     }
  //
  //     int deleteCount = 0;
  //
  //     await _realm.writeAsync(() {
  //       for (int i = 0; i < tags.length; i++) {
  //         if (tags[i].utxoIdList.isEmpty) continue;
  //
  //         int previousCount = tags[i].utxoIdList.length;
  //
  //         tags[i].utxoIdList.removeWhere((utxoId) =>
  //             utxoIds.any((targetUtxoId) => targetUtxoId == utxoId));
  //         deleteCount += previousCount - tags[i].utxoIdList.length;
  //       }
  //     });
  //
  //     return RealmResult(data: deleteCount);
  //   } catch (e) {
  //     return RealmResult(
  //       error: e is RealmException
  //           ? ErrorCodes.withMessage(ErrorCodes.realmException, e.message)
  //           : ErrorCodes.withMessage(ErrorCodes.realmUnknown, e.toString()),
  //     );
  //   }
  // }

  /// walletId 로 조회된 태그 목록에서 txHashIndex 를 포함하고 있는 태그 목록 조회
  RealmResult<List<UtxoTag>> loadUtxoTagListByUtxoId(
      int walletId, String utxoId) {
    _utxoTagList = [];

    try {
      final tags = _realm
          .all<RealmUtxoTag>()
          .query("walletId == '$walletId' SORT(createAt DESC)");

      _utxoTagList.addAll(
        tags
            .where((tag) => tag.utxoIdList.contains(utxoId))
            .map(mapRealmUtxoTagToUtxoTag),
      );

      return RealmResult(data: _utxoTagList);
    } catch (e) {
      return RealmResult(
        error: e is RealmException
            ? ErrorCodes.withMessage(ErrorCodes.realmException, e.message)
            : ErrorCodes.withMessage(ErrorCodes.realmUnknown, e.toString()),
      );
    }
  }

  /// 태그 추가
  RealmResult<UtxoTag> addUtxoTag(
      String id, int walletId, String name, int colorIndex) {
    try {
      final tag = RealmUtxoTag(id, walletId, name, colorIndex, DateTime.now());
      _realm.write(() {
        _realm.add(tag);
      });
      return RealmResult(data: mapRealmUtxoTagToUtxoTag(tag));
    } catch (e) {
      return RealmResult(
        error: e is RealmException
            ? ErrorCodes.withMessage(ErrorCodes.realmException, e.message)
            : ErrorCodes.withMessage(ErrorCodes.realmUnknown, e.toString()),
      );
    }
  }

  /// id 로 조회된 태그의 속성 업데이트
  RealmResult<UtxoTag> updateUtxoTag(String id, String name, int colorIndex) {
    try {
      final tags = _realm.query<RealmUtxoTag>("id == '$id'");

      if (tags.isEmpty) {
        return RealmResult(
            error: ErrorCodes.withMessage(ErrorCodes.realmNotFound, ''));
      }

      final tag = tags.first;

      _realm.write(() {
        tag.name = name;
        tag.colorIndex = colorIndex;
      });
      return RealmResult(data: mapRealmUtxoTagToUtxoTag(tag));
    } catch (e) {
      return RealmResult(
        error: e is RealmException
            ? ErrorCodes.withMessage(ErrorCodes.realmException, e.message)
            : ErrorCodes.withMessage(ErrorCodes.realmUnknown, e.toString()),
      );
    }
  }

  /// id 로 조회된 태그 삭제
  RealmResult<UtxoTag> deleteUtxoTag(String id) {
    try {
      final tag = _realm.find<RealmUtxoTag>(id);

      if (tag == null) {
        return RealmResult(
            error: ErrorCodes.withMessage(ErrorCodes.realmNotFound, ''));
      }

      final removeTag = mapRealmUtxoTagToUtxoTag(tag);

      _realm.write(() {
        _realm.delete(tag);
      });

      return RealmResult(data: removeTag);
    } catch (e) {
      return RealmResult(
        error: e is RealmException
            ? ErrorCodes.withMessage(ErrorCodes.realmException, e.message)
            : ErrorCodes.withMessage(ErrorCodes.realmUnknown, e.toString()),
      );
    }
  }

  /// walletId 로 조회된 태그 전체 삭제
  RealmResult<bool> deleteAllUtxoTag(int walletId) {
    try {
      final tags = _realm.query<RealmUtxoTag>("walletId == '$walletId'");

      if (tags.isEmpty) {
        return RealmResult(
            error: ErrorCodes.withMessage(ErrorCodes.realmNotFound, ''));
      }

      _realm.write(() {
        for (var tag in tags) {
          _realm.delete(tag);
        }
      });

      return RealmResult(data: true);
    } catch (e) {
      return RealmResult(
        error: e is RealmException
            ? ErrorCodes.withMessage(ErrorCodes.realmException, e.message)
            : ErrorCodes.withMessage(ErrorCodes.realmUnknown, e.toString()),
      );
    }
  }

  /// utxoIdList 변경
  /// - [walletId] 목록 검색
  /// - [txHashIndex] UTXO Id
  /// - [txHashIndex] 추가할 UtxoTag 목록
  /// - [selectedNames] 선택된 태그명 목록
  RealmResult<bool> updateUtxoTagList(int walletId, String txHashIndex,
      List<UtxoTag> addTags, List<String> selectedNames) {
    try {
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
            if (!tag.utxoIdList.contains(txHashIndex)) {
              tag.utxoIdList.add(txHashIndex);
            }
          } else {
            tag.utxoIdList.remove(txHashIndex);
          }
        }
      });

      return RealmResult(data: true);
    } catch (e) {
      return RealmResult(
        error: e is RealmException
            ? ErrorCodes.withMessage(ErrorCodes.realmException, e.message)
            : ErrorCodes.withMessage(ErrorCodes.realmUnknown, e.toString()),
      );
    }
  }

  /// walletID, txHash 로 transaction 조회
  RealmResult<TransferDTO?> loadTransaction(int walletId, String txHash) {
    try {
      final transactions = _realm.query<RealmTransaction>(
          "walletBase.id == '$walletId' And transactionHash == '$txHash'");

      if (transactions.isEmpty) {
        return RealmResult(
            error: ErrorCodes.withMessage(ErrorCodes.realmNotFound, ''));
      }

      return RealmResult(
          data: mapRealmTransactionToTransfer(transactions.first));
    } catch (e) {
      return RealmResult(
        error: e is RealmException
            ? ErrorCodes.withMessage(ErrorCodes.realmException, e.message)
            : ErrorCodes.withMessage(ErrorCodes.realmUnknown, e.toString()),
      );
    }
  }

  /// walletId, transactionHash 로 조회된 transaction 의 메모 변경
  RealmResult<TransferDTO> updateTransactionMemo(
      int walletId, String txHash, String memo) {
    try {
      final transactions = _realm.query<RealmTransaction>(
          "walletBase.id == '$walletId' And transactionHash == '$txHash'");

      if (transactions.isEmpty) {
        return RealmResult(
            error: ErrorCodes.withMessage(ErrorCodes.realmNotFound, ''));
      }

      final transaction = transactions.first;

      _realm.write(() {
        transaction.memo = memo;
      });

      return RealmResult(data: mapRealmTransactionToTransfer(transaction));
    } catch (e) {
      return RealmResult(
        error: e is RealmException
            ? ErrorCodes.withMessage(ErrorCodes.realmException, e.message)
            : ErrorCodes.withMessage(ErrorCodes.realmUnknown, e.toString()),
      );
    }
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

  List<TransferDTO>? getTxList(int id) {
    _checkInitialized();

    final transactions = _realm
        .all<RealmTransaction>()
        .query('walletBase.id == $id SORT(timestamp DESC)');

    if (transactions.isEmpty) return null;
    List<TransferDTO> result = [];

    final unconfirmed =
        transactions.query('blockHeight = 0 SORT(createdAt DESC)');
    final confirmed =
        transactions.query('blockHeight != 0 SORT(timestamp DESC)');

    for (var t in unconfirmed) {
      result.add(mapRealmTransactionToTransfer(t));
    }
    for (var t in confirmed) {
      result.add(mapRealmTransactionToTransfer(t));
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

  // not used
  void dispose() {
    _realm.close();
  }
}

/// TODO: 임시
class RealmResult<T> {
  final T? data;
  final AppError? error;

  RealmResult({this.data, this.error});

  bool get isSuccess => error == null;
  bool get isError => error != null;

  @override
  String toString() =>
      isSuccess ? 'RealmResult(data: $data)' : 'RealmResult(error: $error)';
}
