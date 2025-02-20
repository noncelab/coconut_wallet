import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/error/app_error.dart';
import 'package:coconut_wallet/model/wallet/balance.dart';
import 'package:coconut_wallet/model/wallet/multisig_wallet_list_item.dart';
import 'package:coconut_wallet/model/wallet/singlesig_wallet_list_item.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/model/wallet/wallet_address.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/model/wallet/watch_only_wallet.dart';
import 'package:coconut_wallet/repository/realm/wallet_data_manager.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:coconut_wallet/services/model/response/fetch_transaction_response.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:flutter/material.dart';

/// Represents the initialization state of a wallet. 처음 초기화 때만 사용하지 않고 refresh 할 때도 사용합니다.
enum WalletInitState {
  /// The wallet has never been initialized.
  never,

  /// The wallet is currently being processed.
  processing,

  /// The wallet has finished successfully.
  finished,

  /// An error occurred during wallet initialization.
  error,

  /// waiting for device's network state value.
  networkWaiting,

  /// Update impossible (node connection finally failed)
  impossible,
}

class WalletProvider extends ChangeNotifier {
  final SharedPrefsRepository _sharedPrefs = SharedPrefsRepository();

  // 잔액 갱신 전 local db에서 지갑 목록 조회를 끝냈는지 여부
  bool _isWalletsLoadedFromDb = false;
  bool get isWalletsLoadedFromDb => _isWalletsLoadedFromDb;

  // init 결과를 알리는 Toast는 "wallet_list_screen"에서 호출합니다.
  WalletInitState _walletInitState = WalletInitState.never;
  WalletInitState get walletInitState => _walletInitState;

  AppError? _walletInitError;
  AppError? get walletInitError => _walletInitError;

  bool? _isNetworkOn;

  List<WalletListItemBase> _walletItemList = [];
  List<WalletListItemBase> get walletItemList => _walletItemList;

  /// 마지막 업데이트 시간
  int _lastUpdateTime = 0;
  int get lastUpdateTime => _lastUpdateTime;

  int gapLimit = 20;

  late final WalletDataManager _walletDataManager;

  late final Future<void> Function(int) _setWalletCount;
  late final bool _isSetPin;

  WalletProvider(this._walletDataManager, this._isNetworkOn,
      this._setWalletCount, this._isSetPin) {
    initWallet().catchError((_) {
      Logger.error(_);
    });
    _lastUpdateTime =
        _sharedPrefs.getInt(SharedPrefsRepository.kLastUpdateTime);
  }

  Future<void> _setLastUpdateTime() async {
    _lastUpdateTime = DateTime.now().millisecondsSinceEpoch;
    await _sharedPrefs.setInt(
        SharedPrefsRepository.kLastUpdateTime, _lastUpdateTime);
    notifyListeners();
  }

  /// 네트워크가 끊겼을 때 처리할 로직
  void handleNetworkDisconnected() {
    if (_walletInitState == WalletInitState.finished) return;
    setWalletInitState(WalletInitState.error, error: ErrorCodes.networkError);
  }

  /// 지갑 목록 화면에서 '마지막 업데이트' 일시를 보여주기 위해,
  /// id 매개변수를 받더라도, 해당 지갑만 업데이트 하지 않고 다른 지갑이 있는 경우 업데이트 해준다.
  Future<void> initWallet(
      {int? targetId, int? exceptionalId, bool syncOthers = true}) async {
    assert(targetId == null || exceptionalId == null,
        'targetId and exceptionalId cannot be used at the same time');

    if (_walletInitState == WalletInitState.processing &&
        exceptionalId == null) {
      Logger.log(">>>>> !!!!!!!!!!!!!!!!!!! initWallet 중복 실행 방지");
      return;
    }
    bool isFirstInit = _walletInitState == WalletInitState.never;
    setWalletInitState(WalletInitState.processing);

    try {
      Logger.log(">>>>> ===================== initWallet 시작 $_walletInitError");
      // 처음 앱을 실행했거나, storageReadError가 발생한 경우 재시도
      if (isFirstInit ||
          (_walletInitError != null &&
              _walletInitError!.code == ErrorCodes.storageReadError.code)) {
        Logger.log(">>>>> 1. _loadWalletFromLocal");
        await _loadWalletFromLocal();
      }

      // 네트워크 확인이 완료된 후 다음 과정 진행
      if (_isNetworkOn == null) {
        Logger.log(">>>>> ===================== initWallet 끝 (네트워크 확인 전)");
        setWalletInitState(WalletInitState.networkWaiting);
        return;
      }

      if (_isNetworkOn == false) {
        setWalletInitState(WalletInitState.error,
            error: ErrorCodes.networkError);
        return;
      }

      if (_isNetworkOn == true) {
        // 1개만 업데이트 (하지만 나머지 지갑들도 업데이트 함)
        if (targetId != null) {
          Logger.log(">>>>> 3. _fetchWalletLatestInfo id: $targetId");
          // 나머지 지갑들도 업데이트
          if (syncOthers) {
            initWallet(exceptionalId: targetId);
          } else {
            setWalletInitState(WalletInitState.finished);
          }
          return;
        }

        Logger.log(
            ">>>>> 3. _fetchWalletLatestInfo (exceptionalId: $exceptionalId)");
      }

      setWalletInitState(WalletInitState.finished);
      // notifyListeners(); ^ setWalletInitState 안에서 실행되어서 주석처리 했습니다.
      _setLastUpdateTime();

      Logger.log(">>>>> ===================== initWallet 정상 끝");
    } catch (e) {
      Logger.log(
          ">>>>> ===================== initWallet catch!! notifyListeners() ${e.toString()}");
      notifyListeners();
      rethrow; // TODO: check
    }
  }

  WalletListItemBase getWalletById(int id) {
    if (_walletItemList.isEmpty) {
      throw Exception('WalletItem is Empty');
    }
    return _walletItemList.firstWhere((element) => element.id == id);
  }

  // syncFromVault start
  /// case1. 새로운 fingerprint인지 확인 후 지갑으로 추가하기 ("지갑을 추가했습니다.")
  /// case2. 이미 존재하는 fingerprint이지만 이름/계정/칼라 중 하나라도 변경되었을 경우 ("동기화를 완료했습니다.")
  /// case3. 이미 존재하고 변화가 없는 경우 ("이미 추가된 지갑입니다.")
  /// case4. 같은 이름을 가진 다른 지갑이 있는 경우 ("같은 이름을 가진 지갑이 있습니다. 이름을 변경한 후 동기화 해주세요.")
  Future<ResultOfSyncFromVault> syncFromVault(
      WatchOnlyWallet watchOnlyWallet) async {
    // _walletList 동시 변경 방지를 위해 상태 확인 후 sync 진행하기
    while (_walletInitState == WalletInitState.never ||
        _walletInitState == WalletInitState.processing) {
      await Future.delayed(const Duration(seconds: 2));
    }

    WalletSyncResult result = WalletSyncResult.newWalletAdded;
    final index = _walletItemList.indexWhere(
        (element) => element.descriptor == watchOnlyWallet.descriptor);

    bool isMultisig = watchOnlyWallet.signers != null;

    if (index != -1) {
      // case 3: 변경사항 없음
      result = WalletSyncResult.existingWalletNoUpdate;

      // case 2: 변경 사항 체크하며 업데이트
      if (_hasChanged(_walletItemList[index], watchOnlyWallet)) {
        try {
          _walletDataManager.updateWalletUI(
              _walletItemList[index].id, watchOnlyWallet);
        } catch (e) {
          setWalletInitState(WalletInitState.error,
              error: ErrorCodes.withMessage(
                  ErrorCodes.storageWriteError, e.toString()));
          rethrow;
        }

        _walletItemList[index] = _walletDataManager.walletList[index];
        List<WalletListItemBase> updatedList = List.from(_walletItemList);
        _walletItemList = updatedList;
        result = WalletSyncResult.existingWalletUpdated;
        notifyListeners();
      }
      return ResultOfSyncFromVault(
          result: result, walletId: _walletItemList[index].id);
    }

    // 새 지갑 추가
    final sameNameIndex = _walletItemList
        .indexWhere((element) => element.name == watchOnlyWallet.name);
    if (sameNameIndex != -1) {
      // case 4: 동일 이름 존재
      return ResultOfSyncFromVault(result: WalletSyncResult.existingName);
    }

    // case 1: 새 지갑 생성
    WalletListItemBase newItem;
    if (isMultisig) {
      newItem = await _walletDataManager.addMultisigWallet(watchOnlyWallet);
    } else {
      newItem = await _walletDataManager.addSinglesigWallet(watchOnlyWallet);
    }
    //final newItem = await _createNewWallet(walletSync, isMultisig);
    List<WalletListItemBase> updatedList = List.from(_walletItemList);
    updatedList.add(newItem);
    _walletItemList = updatedList;

    if (result == WalletSyncResult.newWalletAdded) {
      // TODO: 화면에서
      // setAnimatedWalletFlags(
      //     index: _walletItemList.length - 1,
      //     type: WalletSyncResult.newWalletAdded);
      //if (!_subStateModel.isNotEmptyWalletList) {
      _setWalletCount(updatedList.length);
      //_subStateModel.saveNotEmptyWalletList(true);
      //}
    }

    await initWallet(targetId: newItem.id, syncOthers: false);

    notifyListeners();
    return ResultOfSyncFromVault(result: result, walletId: newItem.id);
  }

  /// 변동 사항이 있었으면 true, 없었으면 false를 반환합니다.
  bool _hasChanged(
      WalletListItemBase existingWallet, WatchOnlyWallet watchOnlyWallet) {
    bool hasChanged = false;

    if (existingWallet.name != watchOnlyWallet.name ||
        existingWallet.colorIndex != watchOnlyWallet.colorIndex ||
        existingWallet.iconIndex != watchOnlyWallet.iconIndex) {
      hasChanged = true;
    }

    if (existingWallet is SinglesigWalletListItem) {
      return hasChanged;
    }

    var multisigWallet = existingWallet as MultisigWalletListItem;
    for (int i = 0; i < multisigWallet.signers.length; i++) {
      if (multisigWallet.signers[i].name != watchOnlyWallet.signers![i].name ||
          multisigWallet.signers[i].colorIndex !=
              watchOnlyWallet.signers![i].colorIndex ||
          multisigWallet.signers[i].iconIndex !=
              watchOnlyWallet.signers![i].iconIndex ||
          multisigWallet.signers[i].memo != watchOnlyWallet.signers![i].memo) {
        hasChanged = true;
        break;
      }
    }

    return hasChanged;
  }

  Future<void> deleteWallet(int walletId) async {
    _walletDataManager.deleteWallet(walletId);
    _walletItemList = List.from(_walletDataManager.walletList);
    //_walletItemList = _walletDataManager.walletList;
    _walletDataManager.deleteAllUtxoTag(walletId);
    _setWalletCount(_walletItemList.length);
    //if (_walletItemList.isEmpty) {
    //_subStateModel.saveNotEmptyWalletList(false);
    //}
    // await _subStateModel.removeFaucetHistory(id);
    notifyListeners();
  }

  void setWalletInitState(WalletInitState state, {AppError? error}) {
    assert(state != WalletInitState.never);
    if (state == WalletInitState.error) {
      assert(error != null,
          'error must not be null when walletInitState is error');
      _walletInitError = error;
    }

    if (_walletInitState == state) {
      return;
    }

    if (state == WalletInitState.finished) {
      assert(
          error == null, 'error must be null when walletInitState is finished');
      _walletInitError = null;
    }
    _walletInitState = state;

    // 상태 변화에 따른 UI 변경 때문에 호출하게 됨.
    notifyListeners();
  }

  // secure storage에 저장된 지갑 목록을 불러옵니다.
  Future<void> _loadWalletFromLocal() async {
    List<WalletListItemBase> wallets;
    try {
      Logger.log(
          '--> _walletDataManager.isInitialized: ${_walletDataManager.isInitialized}');
      if (!_walletDataManager.isInitialized) {
        await _walletDataManager.init(_isSetPin);
      }
      wallets = await _walletDataManager.loadWalletsFromDB();
    } catch (e) {
      // Unhandled Exception: PlatformException(Exception encountered, read, javax.crypto.BadPaddingException: error:1e000065:Cipher functions:OPENSSL_internal:BAD_DECRYPT
      // 앱 삭제 후 재설치 했는데 위 에러가 발생하는 경우가 있습니다.
      setWalletInitState(WalletInitState.error,
          error: ErrorCodes.withMessage(
              ErrorCodes.storageReadError, e.toString()));
      _onFinallyLoadingWalletsFromDb();
      return;
    }

    if (wallets.isEmpty) {
      _onFinallyLoadingWalletsFromDb();
      return;
    }

    _walletItemList = wallets;
    //_animatedWalletFlags = List.filled(_walletItemList.length, null);
    //_subStateModel.saveNotEmptyWalletList(_walletItemList.isNotEmpty);
    // for wallet_list_screen
    _onFinallyLoadingWalletsFromDb();
  }

  void _onFinallyLoadingWalletsFromDb() {
    if (!_isWalletsLoadedFromDb) {
      _isWalletsLoadedFromDb = true;
      notifyListeners();
    }
  }

  List<TransactionRecord>? getTxList(int walletId) {
    return _walletDataManager.getTxList(walletId);
  }

  /// 네트워크가 꺼지면 네트워크를 해제함.
  void setIsNetworkOn(bool? isNetworkOn) {
    if (_isNetworkOn == isNetworkOn) return;

    if (_isNetworkOn == null && isNetworkOn == true) {
      _isNetworkOn = isNetworkOn;
      initWallet().catchError((_) {
        Logger.error(_);
      });
      return;
    }

    _isNetworkOn = isNetworkOn;

    if (isNetworkOn == false) {
      handleNetworkDisconnected();
      notifyListeners();
    }
  }

  Balance getWalletBalance(int walletId) {
    return _walletDataManager.getWalletBalance(walletId);
  }

  void generateWalletAddress(
      WalletListItemBase walletItem, int usedIndex, bool isChange) {
    _walletDataManager.ensureAddressesExist(
        walletItemBase: walletItem,
        cursor: usedIndex,
        count: gapLimit,
        isChange: isChange);
  }

  List<WalletAddress> getWalletAddressList(
      WalletListItemBase wallet, int cursor, int count, bool isChange) {
    return _walletDataManager.getWalletAddressList(
        wallet, cursor, count, isChange);
  }

  Future encryptWalletSecureData(String hashedPin) async {
    await _walletDataManager.encrypt(hashedPin);
  }

  Future decryptWalletSecureData() async {
    await _walletDataManager.decrypt();
  }

  bool containsAddress(int walletId, String address) {
    return _walletDataManager.containsAddress(walletId, address);
  }

  List<WalletAddress> filterChangeAddressesFromList(
      int walletId, List<String> addresses) {
    return _walletDataManager.filterChangeAddressesFromList(
        walletId, addresses);
  }

  /// 지갑 주소의 사용여부와 잔액을 업데이트 합니다.
  /// 새로운 트랜잭션 이력이 있는 주소를 기준으로 업데이트 합니다.
  void updateWalletAddressList(
      WalletListItemBase walletItem,
      List<AddressBalance> receiveBalanceList,
      List<AddressBalance> changeBalanceList,
      List<FetchTransactionResponse> newTxResList) {
    final receiveBalanceMap = <int, AddressBalance>{};
    final changeBalanceMap = <int, AddressBalance>{};

    for (var addressBalance in receiveBalanceList) {
      receiveBalanceMap[addressBalance.index] = addressBalance;
    }

    for (var addressBalance in changeBalanceList) {
      changeBalanceMap[addressBalance.index] = addressBalance;
    }

    final newReceiveBalanceList = <WalletAddress>[];
    final newChangeBalanceList = <WalletAddress>[];

    for (var fetchTxRes in newTxResList) {
      if (fetchTxRes.isChange) {
        newChangeBalanceList.add(WalletAddress(
            '',
            '',
            fetchTxRes.addressIndex,
            true,
            changeBalanceMap[fetchTxRes.addressIndex]!.confirmed,
            changeBalanceMap[fetchTxRes.addressIndex]!.unconfirmed,
            changeBalanceMap[fetchTxRes.addressIndex]!.total));
      } else {
        newReceiveBalanceList.add(WalletAddress(
            '',
            '',
            fetchTxRes.addressIndex,
            true,
            receiveBalanceMap[fetchTxRes.addressIndex]!.confirmed,
            receiveBalanceMap[fetchTxRes.addressIndex]!.unconfirmed,
            receiveBalanceMap[fetchTxRes.addressIndex]!.total));
      }
    }

    _walletDataManager.updateWalletAddressList(
        walletItem, newReceiveBalanceList, false);
    _walletDataManager.updateWalletAddressList(
        walletItem, newChangeBalanceList, true);
    notifyListeners();
  }

  String getChangeAddress(int walletId) {
    return _walletDataManager.getChangeAddress(walletId);
  }
}

class ResultOfSyncFromVault {
  ResultOfSyncFromVault({required this.result, this.walletId});

  final WalletSyncResult result;
  final int? walletId; // 관련있는 지갑 id
}
