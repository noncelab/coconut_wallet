import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/app.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/app/error/app_error.dart';
import 'package:coconut_wallet/model/app/wallet/multisig_wallet_list_item.dart';
import 'package:coconut_wallet/model/app/wallet/singlesig_wallet_list_item.dart';
import 'package:coconut_wallet/model/app/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/model/app/wallet/watch_only_wallet.dart';
import 'package:coconut_wallet/repository/converter/transaction.dart';
import 'package:coconut_wallet/repository/wallet_data_manager.dart';
import 'package:coconut_wallet/services/shared_prefs_service.dart';
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
  final SharedPrefs _sharedPrefs = SharedPrefs();

  // 잔액 갱신 전 local db에서 지갑 목록 조회를 끝냈는지 여부
  bool _isWalletsLoadedFromDb = false;
  bool get isWalletsLoadedFromDb => _isWalletsLoadedFromDb;

  // init 결과를 알리는 Toast는 "wallet_list_screen"에서 호출합니다.
  WalletInitState _walletInitState = WalletInitState.never;
  WalletInitState get walletInitState => _walletInitState;

  AppError? _walletInitError;
  AppError? get walletInitError => _walletInitError;

  bool? _isNetworkOn;

  NodeConnector? _nodeConnector;

  List<WalletListItemBase> _walletItemList = [];
  List<WalletListItemBase> get walletItemList => _walletItemList;

  /// 마지막 업데이트 시간
  int _lastUpdateTime = 0;
  int get lastUpdateTime => _lastUpdateTime;

  late final WalletDataManager _walletDataManager;

  late final Future<void> Function(int) _setWalletCount;
  late final bool _isSetPin;

  WalletProvider(this._walletDataManager, this._isNetworkOn,
      this._setWalletCount, this._isSetPin) {
    initWallet().catchError((_) {
      Logger.error(_);
    });
    _lastUpdateTime = _sharedPrefs.getInt(SharedPrefs.kLastUpdateTime);
  }

  Future<void> _setLastUpdateTime() async {
    _lastUpdateTime = DateTime.now().millisecondsSinceEpoch;
    await _sharedPrefs.setInt(SharedPrefs.kLastUpdateTime, _lastUpdateTime);
    notifyListeners();
  }

  /// 네트워크가 끊겼을 때 처리할 로직
  void handleNetworkDisconnected() {
    disposeNodeConnector();

    if (_walletInitState == WalletInitState.finished) return;
    setWalletInitState(WalletInitState.error, error: ErrorCodes.networkError);
  }

  // 앱 AppLifecycleState detached or paused일 때 nodeConnector 종료
  void disposeNodeConnector() {
    _nodeConnector?.stopFetching();
    _nodeConnector = null;
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
        await _initNodeConnectionWhenIsNull();

        // 1개만 업데이트 (하지만 나머지 지갑들도 업데이트 함)
        if (targetId != null) {
          Logger.log(">>>>> 3. _fetchWalletLatestInfo id: $targetId");
          int i =
              _walletItemList.indexWhere((element) => element.id == targetId);
          await _syncWalletsAsLatest([_walletItemList[i]]);
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

        var targets = exceptionalId == null
            ? _walletItemList
            : _walletItemList.where((e) => e.id != exceptionalId).toList();
        await _syncWalletsAsLatest(targets);
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

  Future _initNodeConnectionWhenIsNull() async {
    if (_nodeConnector != null) return;
    _nodeConnector = await _initNodeConnection();
  }

  Future<NodeConnector> _initNodeConnection() async {
    try {
      Logger.log(">>>>> 2. _initNodeConnection");
      NodeConnector nodeConnector = await NodeConnector.connectSync(
          CoconutWalletApp.kElectrumHost, CoconutWalletApp.kElectrumPort,
          ssl: CoconutWalletApp.kElectrumIsSSL);

      if (nodeConnector.connectionStatus == SocketConnectionStatus.connected) {
        return nodeConnector;
      }

      if (nodeConnector.connectionStatus == SocketConnectionStatus.terminated) {
        setWalletInitState(WalletInitState.impossible);
      }

      throw 'NodeConnector is not connected.';
    } catch (e) {
      setWalletInitState(WalletInitState.error,
          error: ErrorCodes.withMessage(
              ErrorCodes.nodeConnectionError, e.toString()));
      rethrow;
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

  Future<void> deleteWallet(int id) async {
    _walletDataManager.deleteWallet(id);
    _walletItemList = List.from(_walletDataManager.walletList);
    //_walletItemList = _walletDataManager.walletList;
    _walletDataManager.deleteAllUtxoTag(id);
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

    // isolate
    // final receivePort = ReceivePort();
    // await Isolate.spawn(
    //     isolateEntryDecodeWallets, [receivePort.sendPort, jsonArrayString]);
    // final result = await receivePort.first as List<WalletListItemBase>;

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

  Future<List<WalletListItemBase>> _filterWalletsToUpdate(
      List<WalletListItemBase> wallets) async {
    if (_nodeConnector == null) {
      throw StateError(
          '[filterWalletsToUpdate] _nodeConnector must not be null');
    }

    List<WalletListItemBase> result = [];
    for (var wallet in wallets) {
      var shouldUpdate =
          await wallet.checkIfWalletShouldUpdate(_nodeConnector!);
      if (shouldUpdate) {
        result.add(wallet);
      }
    }

    return result;
  }

  Future<void> _syncWalletsAsLatest(List<WalletListItemBase> targets) async {
    List<WalletListItemBase> needToUpdateTargets =
        await _filterWalletsToUpdate(targets);
    await _walletDataManager.syncWithLatest(needToUpdateTargets);
    _walletItemList = List.from(_walletDataManager.walletList);
  }

  List<TransferDTO>? getTxList(int walletId) {
    return _walletDataManager.getTxList(walletId);
  }

  /// 네트워크가 꺼지면 네트워크를 해제함.
  void setIsNetworkOn(bool isNetworkOn) {
    if (_isNetworkOn == isNetworkOn) return;

    if (_isNetworkOn == null && isNetworkOn) {
      _isNetworkOn = isNetworkOn;
      initWallet().catchError((_) {
        Logger.error(_);
      });
      return;
    }

    _isNetworkOn = isNetworkOn;

    if (!isNetworkOn) {
      handleNetworkDisconnected();
      notifyListeners();
    }
  }

  Future<int?> getCurrentBlockHeight() async {
    try {
      await _initNodeConnectionWhenIsNull();

      return _nodeConnector!.currentBlock.height;
    } catch (e) {
      Logger.log('[app_state_model] getCurrentBlockHeight error: $e');
      return null;
    }
  }

  Future<Result<int, CoconutError>?> getMinimumNetworkFeeRate() async {
    try {
      await _initNodeConnectionWhenIsNull();

      Result<int, CoconutError> result =
          await _nodeConnector!.getNetworkMinimumFeeRate();
      return result;
    } catch (e) {
      Logger.log('[app_state_model] getMinimumNetworkFeeRate error: $e');
      return null;
    }
  }

  Future<Result<String, CoconutError>> broadcast(Transaction signedTx) async {
    await _initNodeConnectionWhenIsNull();

    Result<String, CoconutError> result =
        await _nodeConnector!.broadcast(signedTx.serialize());

    if (result.isFailure) {
      return result;
    }

    _walletDataManager
        .recordTemporaryBroadcastTime(signedTx.transactionHash, DateTime.now())
        .catchError((_) {
      // ignore intentionally
      Logger.error(_);
    });
    return result;
  }

  Future encryptWalletSecureData(String hashedPin) async {
    await _walletDataManager.encrypt(hashedPin);
  }

  Future decryptWalletSecureData() async {
    await _walletDataManager.decrypt();
  }
}

class ResultOfSyncFromVault {
  ResultOfSyncFromVault({required this.result, this.walletId});

  final WalletSyncResult result;
  final int? walletId; // 관련있는 지갑 id
}
