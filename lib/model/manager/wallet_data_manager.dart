import 'dart:isolate';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/model/data/multisig_signer.dart';
import 'package:coconut_wallet/model/data/multisig_wallet_list_item.dart';
import 'package:coconut_wallet/model/data/singlesig_wallet_list_item.dart';
import 'package:coconut_wallet/model/data/wallet_list_item_base.dart';
import 'package:coconut_wallet/model/data/wallet_type.dart';
import 'package:coconut_wallet/model/manager/converter/multisig_wallet.dart';
import 'package:coconut_wallet/model/manager/converter/singlesig_wallet.dart';
import 'package:coconut_wallet/model/manager/converter/transaction.dart';
import 'package:coconut_wallet/model/manager/realm/model/coconut_wallet_data.dart';
import 'package:coconut_wallet/model/manager/realm/realm_id_service.dart';
import 'package:coconut_wallet/model/wallet_sync.dart';
import 'package:coconut_wallet/services/secure_storage_service.dart';
import 'package:coconut_wallet/services/shared_prefs_service.dart';
import 'package:realm/realm.dart';

class WalletDataManager {
  static String vaultListField = 'VAULT_LIST';
  static String nextIdField = 'nextId';
  static String vaultTypeField = WalletListItemBase.walletTypeField;

  final SecureStorageService _storageService = SecureStorageService();
  final SharedPrefs _sharedPrefs = SharedPrefs();

  static final WalletDataManager _instance = WalletDataManager._internal();
  factory WalletDataManager() => _instance;

  late Realm realm;

  List<WalletListItemBase>? _walletList;
  get walletList => _walletList;

  WalletDataManager._internal();

  void init() {
    var config = Configuration.local([
      RealmWalletBase.schema,
      RealmMultisigWallet.schema,
      RealmTransaction.schema,
      RealmIntegerId.schema
    ]);
    realm = Realm(config);
  }

  Future<List<WalletListItemBase>> loadFromDB() async {
    // RealmWalletBase를 모두 조회
    // RealmMultisigWallet을 모두 조회
    // RealmWalletBase의 타입이 싱글이면 SinglesigWalletListItem 생성
    // 타입이 멀티면 MultisigWalletListItem을 생성.
    // 멀티 지갑 생성 시 RealmMultisigWallet에서 id가 같은 것을 찾아서 필요한 정보를 써서 만들면 됨
    // TODO: 임시 초기화!!!!
    _walletList = [];
    int multisigWalletIndex = 0;
    var walletBases =
        realm.all<RealmWalletBase>().query('TRUEPREDICATE SORT(id ASC)');
    var multisigWallets =
        realm.all<RealmMultisigWallet>().query('TRUEPREDICATE SORT(id ASC)');
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
    realm.write(() {
      realm.add(wallet);
    });
    _recordNextWalletId();

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
    realm.write(() {
      realm.add(realmWalletBase);
      realm.add(realmMultisigWallet);
    });
    _recordNextWalletId();

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

  // RealmResults<RealmWalletBase> getAll() {
  //   var list = realm.all<RealmWalletBase>();

  // }
  void getAll() {
    // TODO: 임시 초기화!!!!
    _walletList = [];
    var list = realm.all<RealmWalletBase>();
    for (var i = 0; i < list.length; i++) {
      print('--> ${list[i].name}');
    }
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
      WalletFeature coconutWallet = _getWalletFeatureByWalletType(targets[i]);
      await coconutWallet.fetchOnChainData(nodeConnector);
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
    final realmWallets = realm
        .all<RealmWalletBase>()
        .query(r'id IN $0 SORT(id ASC)', [needToUpdateIds]);

    for (int i = 0; i < realmWallets.length; i++) {
      _updateWalletBaseDBAndWalletList(
          needToUpdateList[i], realmWallets[i], syncResults[i]);
    }

    //realm.writeAsync(writeCallback) // TODO: 언제 쓰는건지 테스트 필요..
    return true;
  }

  void _updateWalletBaseDBAndWalletList(WalletListItemBase walletItem,
      RealmWalletBase realmWallet, WalletStatus syncResult) {
    // 갱신해야 하는 txList 개수 구하기
    int newTxCount = 0;
    if (realmWallet.txCount == null ||
        realmWallet.txCount != syncResult.transactionList.length) {
      newTxCount =
          syncResult.transactionList.length - (realmWallet.txCount ?? 0);
    }
    RealmResults<RealmTransaction>? updateTargets;
    // 전송 중, 받는 중인 트랜잭션이 있는 경우
    if (walletItem.isLatestTxBlockHeightZero) {
      updateTargets = realm
          .all<RealmTransaction>()
          .query(r'walletBase.id = $0', [realmWallet.id]);
      // db에서 blockHeight가 0인 tx 중 가장 작은 id
      final firstProcessingTx =
          updateTargets.query('blockHeight == 0 SORT(id ASC)').first;

      updateTargets = updateTargets.query(r'id >= $0', [firstProcessingTx.id]);
      print('--> updateTargets: ${updateTargets.length}');
      newTxCount = newTxCount + updateTargets.length;
    }
    print(
        '--> nexTxCount 계산: ${syncResult.transactionList.length} ${realmWallet.txCount}');
    print('--> newTxCount: $newTxCount');
    if (newTxCount == 0) return;

    var walletFeature = _getWalletFeatureByWalletType(walletItem);
    // TODO: 라이브러리 수정 필요
    List<Transfer> newTxList =
        walletFeature.getTransferList(cursor: 0, count: newTxCount);
    print('--> newTxList length: ${newTxList.length}');
    int nextId = generateNextId(realm, (RealmTransaction).toString());
    realm.write(() {
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
        if (existingTx != null) {
          // TODO: 업데이트 해야하는 정보가 blockHeight 뿐인지 확실하지 않음
          // TODO: 업데이트 해야 하는 정보만 확실하면 그것만 업데이트할것.
          saveTarget = mapTransferToRealmTransaction(
              newTxList[i], realmWallet, existingTx.id);
        } else {
          saveTarget =
              mapTransferToRealmTransaction(newTxList[i], realmWallet, nextId);
          nextId++;
        }

        realm.add<RealmTransaction>(saveTarget, update: existingTx != null);
      }

      realmWallet.txCount = syncResult.transactionList.length;
      realmWallet.isLatestTxBlockHeightZero =
          newTxList.isNotEmpty && newTxList[0].blockHeight == 0;
      realmWallet.balance =
          walletFeature.getBalance() + walletFeature.getUnconfirmedBalance();
    });
    saveNextId(realm, (RealmTransaction).toString(), nextId);

    _walletList!.firstWhere((w) => w.id == realmWallet.id)
      ..txCount = realmWallet.txCount
      ..isLatestTxBlockHeightZero = realmWallet.isLatestTxBlockHeightZero
      ..balance = realmWallet.balance;
  }

  WalletFeature _getWalletFeatureByWalletType(WalletListItemBase walletItem) {
    if (walletItem.walletType == WalletType.singleSignature) {
      return walletItem.walletBase as SingleSignatureWallet;
    } else {
      return walletItem.walletBase as MultisignatureWallet;
    }
  }

  void deleteWallet(int id) {
    final RealmWalletBase walletBase =
        realm.all<RealmWalletBase>().query('id == $id').first;
    final transactions =
        realm.all<RealmTransaction>().query('walletBase.id == $id');
    // TODO: utxos

    final realmMultisigWallet =
        walletBase.walletType == WalletType.multiSignature.name
            ? realm.all<RealmMultisigWallet>().query('id == $id').first
            : null;

    realm.write(() {
      realm.delete(walletBase);
      realm.deleteMany(transactions);
      if (realmMultisigWallet != null) {
        realm.delete(realmMultisigWallet);
      }
    });

    final RealmWalletBase? walletBase2 =
        realm.all<RealmWalletBase>().query('id == $id').firstOrNull;
    print('--> 삭제 후 조회: $walletBase2');
    // TODO: 삭제 후 조회 시 안찾아지는지 확인하기

    final index = _walletList!.indexWhere((item) => item.id == id);
    _walletList!.removeAt(index);
  }

  void dispose() {
    realm.close();
  }

  int _getNextWalletId() {
    return _sharedPrefs.getInt(nextIdField);
  }

  void _recordNextWalletId() {
    final int nextId = _getNextWalletId();
    print('--> nextId: $nextId');
    _sharedPrefs.setInt(nextIdField, nextId + 1);
  }

  List<Transfer>? getTxList(int id) {
    final transactions = realm
        .all<RealmTransaction>()
        .query('walletBase.id == $id SORT(timestamp DESC)');

    if (transactions.isEmpty) return null;
    List<Transfer> result = [];
    for (var t in transactions) {
      result.add(mapRealmTransactionToTransfer(t));
    }
    return result;
  }
}
