import 'package:coconut_wallet/constants/shared_pref_keys.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/wallet/balance.dart';
import 'package:coconut_wallet/model/wallet/multisig_wallet_list_item.dart';
import 'package:coconut_wallet/model/wallet/multisig_signer.dart';
import 'package:coconut_wallet/model/wallet/singlesig_wallet_list_item.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/model/wallet/watch_only_wallet.dart';
import 'package:coconut_wallet/repository/realm/base_repository.dart';
import 'package:coconut_wallet/repository/realm/converter/multisig_wallet.dart';
import 'package:coconut_wallet/repository/realm/converter/singlesig_wallet.dart';
import 'package:coconut_wallet/repository/realm/model/coconut_wallet_model.dart';
import 'package:coconut_wallet/repository/realm/service/realm_id_service.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:realm/realm.dart';

class WalletRepository extends BaseRepository {
  final SharedPrefsRepository _sharedPrefs;

  WalletRepository(super._realmManager) : _sharedPrefs = SharedPrefsRepository();

  /// 지갑 목록을 DB에서 로드
  Future<List<WalletListItemBase>> getWalletItemList() async {
    List<WalletListItemBase> walletList = [];
    int multisigWalletIndex = 0;
    int externalWalletIndex = 0;

    var walletBases = realm.all<RealmWalletBase>().query('TRUEPREDICATE SORT(id DESC)');
    var multisigWallets = realm.all<RealmMultisigWallet>().query('TRUEPREDICATE SORT(id DESC)');
    var externalWallets = realm.all<RealmExternalWallet>().query('TRUEPREDICATE SORT(id DESC)');

    for (var i = 0; i < walletBases.length; i++) {
      if (walletBases[i].walletType == WalletType.singleSignature.name) {
        // 외부 지갑인 경우 WalletImportSource 데이터 추가
        if (externalWalletIndex < externalWallets.length &&
            walletBases[i].id == externalWallets[externalWalletIndex].id) {
          walletList.add(
            mapRealmToSingleSigWalletItem(
              walletBases[i],
              walletBases[i].descriptor,
              WalletImportSourceExtension.fromStringDefaultCoconut(
                externalWallets[externalWalletIndex++].walletImportSource,
              ),
            ),
          );
        } else {
          walletList.add(mapRealmToSingleSigWalletItem(walletBases[i], walletBases[i].descriptor, null));
        }
      } else {
        assert(walletBases[i].id == multisigWallets[multisigWalletIndex].id);
        walletList.add(mapRealmToMultisigWalletItem(multisigWallets[multisigWalletIndex++], walletBases[i].descriptor));
      }
    }

    return walletList;
  }

  /// 싱글시그 지갑 추가
  Future<SinglesigWalletListItem> addSinglesigWallet(WatchOnlyWallet watchOnlyWallet) async {
    var id = _getNextWalletId();
    var realmWalletBase = RealmWalletBase(
      id,
      watchOnlyWallet.colorIndex,
      watchOnlyWallet.iconIndex,
      watchOnlyWallet.descriptor,
      watchOnlyWallet.name,
      WalletType.singleSignature.name,
    );

    realm.write(() {
      realm.add(realmWalletBase);

      // 외부 지갑인 경우 ExternalWallet 생성
      if (watchOnlyWallet.walletImportSource.name != WalletImportSource.coconutVault.name) {
        var realmExternalWallet = RealmExternalWallet(
          id,
          watchOnlyWallet.walletImportSource.name,
          walletBase: realmWalletBase,
        );
        realm.add(realmExternalWallet);
      }
    });

    _recordNextWalletId(id + 1);
    return mapRealmToSingleSigWalletItem(
      realmWalletBase,
      watchOnlyWallet.descriptor,
      watchOnlyWallet.walletImportSource,
    );
  }

  /// 멀티시그 지갑 추가
  Future<MultisigWalletListItem> addMultisigWallet(WatchOnlyWallet walletSync) async {
    var id = _getNextWalletId();
    var realmWalletBase = RealmWalletBase(
      id,
      walletSync.colorIndex,
      walletSync.iconIndex,
      walletSync.descriptor,
      walletSync.name,
      WalletType.multiSignature.name,
    );
    var realmMultisigWallet = RealmMultisigWallet(
      id,
      MultisigSigner.toJsonList(walletSync.signers!),
      walletSync.requiredSignatureCount!,
      walletBase: realmWalletBase,
    );

    realm.write(() {
      realm.add(realmWalletBase);
      realm.add(realmMultisigWallet);
    });

    _recordNextWalletId(id + 1);

    return mapRealmToMultisigWalletItem(realmMultisigWallet, walletSync.descriptor);
  }

  /// 지갑 UI 정보 업데이트
  void updateWalletUI(int id, WatchOnlyWallet watchOnlyWallet) {
    final RealmWalletBase wallet = realm.all<RealmWalletBase>().query('id = $id').first;
    final RealmMultisigWallet? multisigWallet = realm.all<RealmMultisigWallet>().query('id = $id').firstOrNull;
    if (wallet.walletType == WalletType.multiSignature.name) {
      assert(multisigWallet != null);
    }

    // ui 정보 변경하기
    realm.write(() {
      wallet.name = watchOnlyWallet.name;
      wallet.colorIndex = watchOnlyWallet.colorIndex;
      wallet.iconIndex = watchOnlyWallet.iconIndex;

      if (multisigWallet != null) {
        multisigWallet.signersInJsonSerialization = MultisigSigner.toJsonList(watchOnlyWallet.signers!);
      }
    });
  }

  /// 지갑 삭제
  Future<void> deleteWallet(int walletId) async {
    final walletBaseResults = realm.query<RealmWalletBase>('id == $walletId');
    final walletBase = walletBaseResults.firstOrNull;

    if (walletBase == null) {
      return;
    }

    final transactions = realm.query<RealmTransaction>('walletId == $walletId');
    final walletBalance = realm.query<RealmWalletBalance>('walletId == $walletId');
    final walletAddress = realm.query<RealmWalletAddress>('walletId == $walletId');
    final utxos = realm.query<RealmUtxo>('walletId == $walletId');
    final utxoTags = realm.query<RealmUtxoTag>('walletId == $walletId');
    final scriptStatuses = realm.query<RealmScriptStatus>('walletId == $walletId');

    final realmMultisigWalletResults =
        walletBase.walletType == WalletType.multiSignature.name
            ? realm.query<RealmMultisigWallet>('id == $walletId')
            : null;
    final realmMultisigWallet = realmMultisigWalletResults?.first;

    final realmExternalWalletResults =
        walletBase.walletType == WalletType.singleSignature.name
            ? realm.query<RealmExternalWallet>('id == $walletId')
            : null;
    final realmExternalWallet = realmExternalWalletResults?.firstOrNull;

    await realm.writeAsync(() {
      realm.delete(walletBase);
      if (transactions.isNotEmpty) {
        realm.deleteMany(transactions);
      }
      if (realmMultisigWallet != null) {
        realm.delete(realmMultisigWallet);
      }
      if (realmExternalWallet != null) {
        realm.delete(realmExternalWallet);
      }
      if (walletBalance.isNotEmpty) {
        realm.deleteMany(walletBalance);
      }
      if (walletAddress.isNotEmpty) {
        realm.deleteMany(walletAddress);
      }
      if (utxos.isNotEmpty) {
        realm.deleteMany(utxos);
      }
      if (utxoTags.isNotEmpty) {
        realm.deleteMany(utxoTags);
      }
      if (scriptStatuses.isNotEmpty) {
        realm.deleteMany(scriptStatuses);
      }
    });
  }

  /// 다음 지갑 ID 가져오기
  int _getNextWalletId() {
    var id = _sharedPrefs.getInt(SharedPrefKeys.kNextIdField);
    if (id == 0) {
      return 1;
    }
    return id;
  }

  /// 다음 지갑 ID 기록
  void _recordNextWalletId(int value) {
    _sharedPrefs.setInt(SharedPrefKeys.kNextIdField, value);
  }

  /// 지갑 베이스 조회
  RealmWalletBase getWalletBase(int walletId) {
    final realmWalletBase = realm.find<RealmWalletBase>(walletId);
    if (realmWalletBase == null) {
      throw StateError('[getWalletBase] Wallet not found');
    }
    return realmWalletBase;
  }

  RealmWalletBalance updateWalletBalance(int walletId, Balance balance) {
    final realmWalletBase = realm.find<RealmWalletBase>(walletId);
    final balanceResults = realm.query<RealmWalletBalance>('walletId == $walletId');

    if (realmWalletBase == null) {
      throw StateError('[updateWalletBalance] Wallet not found');
    }

    if (balanceResults.isEmpty) {
      return _createNewWalletBalance(realmWalletBase, balance);
    }

    final realmWalletBalance = balanceResults.first;

    realm.write(() {
      realmWalletBalance.total = balance.total;
      realmWalletBalance.confirmed = balance.confirmed;
      realmWalletBalance.unconfirmed = balance.unconfirmed;
    });

    return realmWalletBalance;
  }

  Future<RealmWalletBalance> accumulateWalletBalance(int walletId, Balance balanceDiff) async {
    final realmWalletBalance = getWalletBalance(walletId);

    await realm.writeAsync(() {
      realmWalletBalance.total += balanceDiff.total;
      realmWalletBalance.confirmed += balanceDiff.confirmed;
      realmWalletBalance.unconfirmed += balanceDiff.unconfirmed;
    });
    return realmWalletBalance;
  }

  RealmWalletBalance _createNewWalletBalance(RealmWalletBase realmWalletBase, Balance walletBalance) {
    int walletBalanceLastId = getLastId(realm, (RealmWalletBalance).toString());

    final realmWalletBalance = RealmWalletBalance(
      ++walletBalanceLastId,
      realmWalletBase.id,
      walletBalance.confirmed + walletBalance.unconfirmed,
      walletBalance.confirmed,
      walletBalance.unconfirmed,
    );

    realm.write(() {
      realm.add(realmWalletBalance);
    });
    saveLastId(realm, (RealmWalletBalance).toString(), walletBalanceLastId);

    return realmWalletBalance;
  }

  RealmWalletBalance getWalletBalance(int walletId) {
    final realmWalletBalance = realm.query<RealmWalletBalance>('walletId == $walletId').firstOrNull;

    if (realmWalletBalance == null) {
      return _createNewWalletBalance(realm.find<RealmWalletBase>(walletId)!, Balance(0, 0));
    }

    return realmWalletBalance;
  }
}
