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
  static const String nextIdField = 'nextId';

  final SharedPrefsRepository _sharedPrefs;

  WalletRepository(super._realmManager)
      : _sharedPrefs = SharedPrefsRepository();

  /// 지갑 목록을 DB에서 로드
  Future<List<WalletListItemBase>> getWalletItemList() async {
    int multisigWalletIndex = 0;
    List<WalletListItemBase> walletList = [];

    var walletBases =
        realm.all<RealmWalletBase>().query('TRUEPREDICATE SORT(id DESC)');
    var multisigWallets =
        realm.all<RealmMultisigWallet>().query('TRUEPREDICATE SORT(id DESC)');

    for (var i = 0; i < walletBases.length; i++) {
      String? decryptedDescriptor;
      if (cryptography != null) {
        decryptedDescriptor =
            await cryptography!.decrypt(walletBases[i].descriptor);
      }

      if (walletBases[i].walletType == WalletType.singleSignature.name) {
        walletList.add(
            mapRealmToSingleSigWalletItem(walletBases[i], decryptedDescriptor));
      } else {
        assert(walletBases[i].id == multisigWallets[multisigWalletIndex].id);
        walletList.add(mapRealmToMultisigWalletItem(
            multisigWallets[multisigWalletIndex++], decryptedDescriptor));
      }
    }

    return walletList;
  }

  /// 싱글시그 지갑 추가
  Future<SinglesigWalletListItem> addSinglesigWallet(
      WatchOnlyWallet watchOnlyWallet) async {
    var id = _getNextWalletId();
    String descriptor = cryptography != null
        ? await cryptography!.encrypt(watchOnlyWallet.descriptor)
        : watchOnlyWallet.descriptor;

    var wallet = RealmWalletBase(
        id,
        watchOnlyWallet.colorIndex,
        watchOnlyWallet.iconIndex,
        descriptor,
        watchOnlyWallet.name,
        WalletType.singleSignature.name);

    realm.write(() {
      realm.add(wallet);
    });

    _recordNextWalletId(id + 1);

    return mapRealmToSingleSigWalletItem(wallet, descriptor);
  }

  /// 멀티시그 지갑 추가
  Future<MultisigWalletListItem> addMultisigWallet(
      WatchOnlyWallet walletSync) async {
    var id = _getNextWalletId();
    String descriptor = cryptography != null
        ? await cryptography!.encrypt(walletSync.descriptor)
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

    realm.write(() {
      realm.add(realmWalletBase);
      realm.add(realmMultisigWallet);
    });

    _recordNextWalletId(id + 1);

    return mapRealmToMultisigWalletItem(realmMultisigWallet, descriptor);
  }

  /// 지갑 UI 정보 업데이트
  void updateWalletUI(int id, WatchOnlyWallet watchOnlyWallet) {
    final RealmWalletBase wallet =
        realm.all<RealmWalletBase>().query('id = $id').first;
    final RealmMultisigWallet? multisigWallet =
        realm.all<RealmMultisigWallet>().query('id = $id').firstOrNull;
    if (wallet.walletType == WalletType.multiSignature.name) {
      assert(multisigWallet != null);
    }

    // ui 정보 변경하기
    realm.write(() {
      wallet.name = watchOnlyWallet.name;
      wallet.colorIndex = watchOnlyWallet.colorIndex;
      wallet.iconIndex = watchOnlyWallet.iconIndex;

      if (multisigWallet != null) {
        multisigWallet.signersInJsonSerialization =
            MultisigSigner.toJsonList(watchOnlyWallet.signers!);
      }
    });
  }

  /// 지갑 삭제
  Future<void> deleteWallet(int walletId) async {
    final walletBaseResults = realm.query<RealmWalletBase>('id == $walletId');
    final walletBase = walletBaseResults.first;
    final transactions = realm.query<RealmTransaction>('walletId == $walletId');
    final walletBalance =
        realm.query<RealmWalletBalance>('walletId == $walletId');
    final walletAddress =
        realm.query<RealmWalletAddress>('walletId == $walletId');
    final utxos = realm.query<RealmUtxo>('walletId == $walletId');
    final scriptStatuses =
        realm.query<RealmScriptStatus>('walletId == $walletId');

    final realmMultisigWalletResults =
        walletBase.walletType == WalletType.multiSignature.name
            ? realm.query<RealmMultisigWallet>('id == $walletId')
            : null;
    final realmMultisigWallet = realmMultisigWalletResults?.first;

    await realm.writeAsync(() {
      realm.delete(walletBase);
      realm.deleteMany(transactions);
      if (realmMultisigWallet != null) {
        realm.delete(realmMultisigWallet);
      }
      realm.deleteMany(walletBalance);
      realm.deleteMany(walletAddress);
      realm.deleteMany(utxos);
      realm.deleteMany(scriptStatuses);
    });
  }

  /// 다음 지갑 ID 가져오기
  int _getNextWalletId() {
    var id = _sharedPrefs.getInt(nextIdField);
    if (id == 0) {
      return 1;
    }
    return id;
  }

  /// 다음 지갑 ID 기록
  void _recordNextWalletId(int value) {
    _sharedPrefs.setInt(nextIdField, value);
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
    final balanceResults =
        realm.query<RealmWalletBalance>('walletId == $walletId');

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

  Future<RealmWalletBalance> accumulateWalletBalance(
      int walletId, Balance balanceDiff) async {
    final realmWalletBalance = getWalletBalance(walletId);

    await realm.writeAsync(() {
      realmWalletBalance.total += balanceDiff.total;
      realmWalletBalance.confirmed += balanceDiff.confirmed;
      realmWalletBalance.unconfirmed += balanceDiff.unconfirmed;
    });
    return realmWalletBalance;
  }

  RealmWalletBalance _createNewWalletBalance(
      RealmWalletBase realmWalletBase, Balance walletBalance) {
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
    final realmWalletBalance =
        realm.query<RealmWalletBalance>('walletId == $walletId').firstOrNull;

    if (realmWalletBalance == null) {
      return _createNewWalletBalance(
        realm.find<RealmWalletBase>(walletId)!,
        Balance(0, 0),
      );
    }

    return realmWalletBalance;
  }
}
