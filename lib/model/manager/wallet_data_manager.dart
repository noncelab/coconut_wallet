import 'package:coconut_lib/coconut_lib.dart';
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
import 'package:coconut_wallet/model/manager/realm/model/coconut_wallet_data.dart';
import 'package:coconut_wallet/model/manager/realm/realm_id_service.dart';
import 'package:coconut_wallet/model/utxo_tag.dart';
import 'package:coconut_wallet/model/wallet_sync.dart';
import 'package:coconut_wallet/services/secure_storage_service.dart';
import 'package:coconut_wallet/services/shared_prefs_service.dart';
import 'package:coconut_wallet/utils/cconut_wallet_util.dart';
import 'package:realm/realm.dart';

class WalletDataManager {
  static String vaultListField = 'VAULT_LIST';
  static String nextIdField = 'nextId';
  static String vaultTypeField = WalletListItemBase.walletTypeField;

  final SecureStorageService _storageService = SecureStorageService();
  final SharedPrefs _sharedPrefs = SharedPrefs();

  static final WalletDataManager _instance = WalletDataManager._internal();
  factory WalletDataManager() => _instance;

  late Realm _realm;

  List<WalletListItemBase>? _walletList;
  get walletList => _walletList;

  List<UtxoTag> _utxoTagList = [];

  WalletDataManager._internal();

  void init() {
    var config = Configuration.local(
      [
        RealmWalletBase.schema,
        RealmMultisigWallet.schema,
        RealmTransaction.schema,
        RealmIntegerId.schema,
        TempBroadcastTimeRecord.schema,
        RealmUtxoTag.schema,
        RealmUtxoId.schema,
      ],
      schemaVersion: 1,
      migrationCallback: (migration, oldVersion) {},
    );
    _realm = Realm(config);
  }

  Future<List<WalletListItemBase>> loadFromDB() async {
    _walletList = [];
    int multisigWalletIndex = 0;
    var walletBases =
        _realm.all<RealmWalletBase>().query('TRUEPREDICATE SORT(id ASC)');
    var multisigWallets =
        _realm.all<RealmMultisigWallet>().query('TRUEPREDICATE SORT(id ASC)');
    for (var i = 0; i < walletBases.length; i++) {
      if (walletBases[i].walletType == WalletType.singleSignature.name) {
        _walletList!
            .add(mapRealmWalletBaseToSinglesigWalletListItem(walletBases[i]));
      } else {
        assert(walletBases[i].id == multisigWallets[multisigWalletIndex].id);
        _walletList!.add(mapRealmMultisigWalletToMultisigWalletListItem(
            multisigWallets[multisigWalletIndex]));
      }
    }

    return _walletList!;
  }

  Future<SinglesigWalletListItem> addSinglesigWallet(
      WalletSync walletSync) async {
    var id = _getNextWalletId();
    var wallet = RealmWalletBase(
        id,
        walletSync.colorIndex,
        walletSync.iconIndex,
        walletSync.descriptor,
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
    var id = _getNextWalletId();
    var realmWalletBase = RealmWalletBase(
        id,
        walletSync.colorIndex,
        walletSync.iconIndex,
        walletSync.descriptor,
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
    // TODO: same with _fetchWalletsData
    List<int> noNeedToUpdate = [];
    List<WalletListItemBase> needToUpdateList = [];
    List<WalletStatus> syncResults = [];
    List<int> needToUpdateIds = [];
    for (int i = 0; i < targets.length; i++) {
      WalletFeature coconutWallet = getWalletFeatureByWalletType(targets[i]);
      try {
        await coconutWallet.fetchOnChainData(nodeConnector);
      } catch (e) {
        // TODO:
        throw ErrorCodes.syncFailedError;
      }
      // assert(coconutWallet.walletStatus != null);
      WalletStatus syncResult = coconutWallet.walletStatus!;
      // check need to update
      print(
          '--> targets[i].isLatestTxBlockHeightZero: ${targets[i].isLatestTxBlockHeightZero}');
      print(
          '--> syncResult.transactionList.length, targets[i].txCount: ${syncResult.transactionList.length} ${targets[i].txCount}');
      print('--> targets[i].balance: ${targets[i].balance}');
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
    print('--> noNeedToUpdate: ${noNeedToUpdate.length}');
    print('--> needToUpdateIds: ${needToUpdateIds.length}');
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
      print('--> updateTargets: ${updateTargets.length}');
      getTxCount = getTxCount + updateTargets.length;
      finalUpdateTargets = updateTargets.toList();
    }
    print(
        '--> newTxCount 계산: ${syncResult.transactionList.length} - ${realmWallet.txCount} + ${finalUpdateTargets?.length} = $getTxCount');

    var walletFeature = getWalletFeatureByWalletType(walletItem);
    // 항상 최신순으로 반환
    List<Transfer> newTxList =
        walletFeature.getTransferList(cursor: 0, count: getTxCount);
    print('--> newTxList length: ${newTxList.length}');
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
        print(
            '--> existingTx: $existingTx, nextId: $nextId, timestamp: ${newTxList[i].timestamp}');

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
        print(
            '--> record: $record, newTxList[i].blockHeight: ${newTxList[i].blockHeight}');
        if (record != null && newTxList[i].blockHeight != 0) {
          print('--> delete record!!!!');
          _realm.delete<TempBroadcastTimeRecord>(record);
        }
      }

      // INFO: RBF(Replace-By-Fee)에 의해서 처리되지 않은 트랜잭션이 삭제된 경우를 대비
      // INFO: 추후에는 삭제가 아니라 '무효화됨'으로 표기될 수 있음
      // TODO: TEST
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

    final RealmWalletBase? walletBase2 =
        _realm.all<RealmWalletBase>().query('id == $id').firstOrNull;
    print('--> 삭제 후 조회: $walletBase2');
    // TODO: 삭제 후 조회 시 안찾아지는지 확인하기

    final index = _walletList!.indexWhere((item) => item.id == id);
    _walletList!.removeAt(index);
  }

  Future<List<UtxoTag>> loadUtxoTagList(int walletId) async {
    _utxoTagList = [];
    final utxoList = _realm
        .all<RealmUtxoTag>()
        .query("walletId == '$walletId' SORT(createAt DESC)");
    for (var i = 0; i < utxoList.length; i++) {
      _utxoTagList.add(mapRealmUtxoTagToUtxoTag(utxoList[i]));
    }

    return _utxoTagList;
  }

  void deleteAllUtxoTagWithWalletId(int walletId) {
    final tags = _realm.query<RealmUtxoTag>("walletId == '$walletId'");

    if (tags.isEmpty) return;

    _realm.write(() {
      for (var tag in tags) {
        _realm.delete(tag);
      }
    });
  }

  void addUtxoTagWithWalletId(
      String id, int walletId, String name, int colorIndex) {
    final utxoTag =
        RealmUtxoTag(id, walletId, name, colorIndex, DateTime.now());
    _realm.write(() {
      _realm.add(utxoTag);
    });
  }

  void deleteUtxoTagWithId(String id) {
    final tags = _realm.query<RealmUtxoTag>("id == '$id'");

    if (tags.isEmpty) return;

    _realm.write(() {
      _realm.delete(tags.first);
    });
  }

  void updateUtxoTagWithId(
      String id, String name, int colorIndex, List<String> utxoIdList) {
    final tags = _realm.query<RealmUtxoTag>("id == '$id'");

    if (tags.isEmpty) {
      return;
    }

    final utxoTag = tags.first;

    _realm.write(() {
      utxoTag.name = name;
      utxoTag.colorIndex = colorIndex;
      utxoTag.utxoIdList.clear();
      utxoTag.utxoIdList
          .addAll(utxoIdList.map((id) => mapStringToRealmUtxoId(id)));
    });
  }

  int _getNextWalletId() {
    var id = _sharedPrefs.getInt(nextIdField);
    if (id == 0) {
      return 1;
    }
    return id;
  }

  void _recordNextWalletId(int value) {
    _sharedPrefs.setInt(nextIdField, value);
  }

  /// 최신순으로 반환하지만, unconfirmed가 createdAt 순으로 가장 상위에 위치
  /// confirmed는 timestamp 순
  List<TransferDTO>? getTxList(int id) {
    final transactions =
        _realm.all<RealmTransaction>().query('walletBase.id == $id');

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
    _realm.write(() {
      _realm.deleteAll<RealmWalletBase>();
      _realm.deleteAll<RealmMultisigWallet>();
      _realm.deleteAll<RealmTransaction>();
      _realm.deleteAll<RealmUtxoTag>();
      _realm.deleteAll<RealmUtxoId>();
    });

    _walletList = [];
  }

  void dispose() {
    _realm.close();
  }
}
