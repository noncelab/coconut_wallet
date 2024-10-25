import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:ui';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:flutter/foundation.dart';
import 'package:coconut_wallet/app.dart';
import 'package:coconut_wallet/main.dart';
import 'package:coconut_wallet/model/app_error.dart';
import 'package:coconut_wallet/providers/app_sub_state_model.dart';
import 'package:coconut_wallet/model/enums.dart';
import 'package:coconut_wallet/model/request/faucet_request.dart';
import 'package:coconut_wallet/model/wallet_list_item.dart';
import 'package:coconut_wallet/model/wallet_sync.dart';
import 'package:coconut_wallet/repositories/faucet_repository.dart';
import 'package:coconut_wallet/services/isolate_entry_point.dart';
import 'package:coconut_wallet/services/secure_storage_service.dart';
import 'package:coconut_wallet/services/shared_prefs_service.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/utils/serialization_extensions.dart';
import 'package:coconut_wallet/utils/vibration_util.dart';

// ignore: constant_identifier_names
const String WALLET_LIST = "WALLET_LIST";

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

class AppStateModel extends ChangeNotifier {
  final SecureStorageService _storageService = SecureStorageService();
  AppSubStateModel _subStateModel;

  // 잔액 갱신 전 local db에서 지갑 목록 조회를 끝냈는지 여부
  bool _fastLoadDone = false;
  bool get fastLoadDone => _fastLoadDone;

  // init 결과를 알리는 Toast는 "wallet_list_screen"에서 호출합니다.
  WalletInitState _walletInitState = WalletInitState.never;
  WalletInitState get walletInitState => _walletInitState;

  AppError? _walletInitError;
  AppError? get walletInitError => _walletInitError;

  bool? _isNetworkOn;
  bool? get isNetworkOn => _isNetworkOn;

  NodeConnector? _nodeConnector;

  List<WalletListItem> _walletList = [];
  List<WalletListItem> get walletList => _walletList;

  String? txWaitingForSign;
  String? signedTransaction; // hex decode result

  bool _isFaucetRequesting = false;
  bool get isFaucetRequesting => _isFaucetRequesting;

  final String _dbDiretoryPath = dbDirectoryPath;
  String get dbDiretoryPath => _dbDiretoryPath;

  final FaucetRepository _faucetRepository = FaucetRepository();

  AppStateModel(this._subStateModel) {
    initWallet();
  }

  /// [_subStateModel]의 변동사항 업데이트
  void updateWithSubState(AppSubStateModel subStateModel) {
    _subStateModel = subStateModel;
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
      if (isNetworkOn == null) {
        Logger.log(">>>>> ===================== initWallet 끝 (네트워크 확인 전)");
        setWalletInitState(WalletInitState.networkWaiting);
        return;
      }

      if (isNetworkOn == false) {
        setWalletInitState(WalletInitState.error,
            error: ErrorCodes.networkError);
        throw "Network is off";
      }

      if (isNetworkOn == true) {
        await _initNodeConnectionWhenIsNull();

        // 1개만 업데이트 (하지만 나머지 지갑들도 업데이트 함)
        if (targetId != null) {
          Logger.log(">>>>> 3. _fetchWalletLatestInfo id: $targetId");
          await _fetchWalletLatestInfo(targetId);
          notifyListeners();
          // 나머지 지갑들도 업데이트
          if (syncOthers) {
            initWallet(exceptionalId: targetId);
          } else {
            setWalletInitState(WalletInitState.finished);
          }
          return;
        }

        if (exceptionalId != null) {
          Logger.log(
              ">>>>> 3. _fetchWalletLatestInfo exceptionalId: $exceptionalId");
          await _fetchAllWalletLatestInfo(exceptionalId: exceptionalId);
        } else {
          Logger.log(">>>>> 3. _fetchAllWalletLatestInfo");
          await _fetchAllWalletLatestInfo();
        }
      }

      setWalletInitState(WalletInitState.finished);
      // notifyListeners(); ^ setWalletInitState 안에서 실행되어서 주석처리 했습니다.
      _subStateModel.setLastUpdateTime();

      vibrateLight();
      Logger.log(">>>>> ===================== initWallet 정상 끝");
    } catch (e) {
      vibrateLightDouble();
      Logger.log(
          ">>>>> ===================== initWallet catch!! notifyListeners() ${e.toString()}");
      notifyListeners();
      await _updateWalletInStorage();
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
          PowWalletApp.kElectrumHost, PowWalletApp.kElectrumPort,
          ssl: PowWalletApp.kElectrumIsSSL);

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

  // Returns a copy of the list of wallet list.
  List<WalletListItem> getWallets() {
    if (_walletList.isEmpty) {
      return [];
    }

    return List.from(_walletList);
  }

  WalletListItem getWalletById(int id) {
    return _walletList.firstWhere((element) => element.id == id);
  }

  /// case1. 새로운 fingerprint인지 확인 후 지갑으로 추가하기 ("지갑을 추가했습니다.")
  /// case2. 이미 존재하는 fingerprint이지만 이름/계정/칼라 중 하나라도 변경되었을 경우 ("동기화를 완료했습니다.")
  /// case3. 이미 존재하고 변화가 없는 경우 ("이미 추가된 지갑입니다.")
  /// case4. 같은 이름을 가진 다른 지갑이 있는 경우 ("같은 이름을 가진 지갑이 있습니다. 이름을 변경한 후 동기화 해주세요.")
  Future<ResultOfSyncFromVault> syncFromVault(WalletSync walletSync) async {
    // _walletList 동시 변경 방지를 위해 상태 확인 후 sync 진행하기
    while (_walletInitState == WalletInitState.never ||
        _walletInitState == WalletInitState.processing) {
      await Future.delayed(const Duration(seconds: 2));
    }

    int id;
    SyncResult result = SyncResult.newWalletAdded;
    final index = _walletList
        .indexWhere((element) => element.descriptor == walletSync.descriptor);

    if (index != -1) {
      WalletListItem existingWallet = _walletList[index];
      // 변동사항이 있는지 체크하기: 이름, pubkeys, colorIndex, iconIndex
      if (walletSync.name != existingWallet.name ||
          walletSync.colorIndex != existingWallet.colorIndex ||
          walletSync.iconIndex != existingWallet.iconIndex) {
        // case 2
        var updateItem = WalletListItem(
            id: existingWallet.id,
            name: walletSync.name,
            colorIndex: walletSync.colorIndex,
            iconIndex: walletSync.iconIndex,
            descriptor: walletSync.descriptor,
            balance: existingWallet.balance);

        List<WalletListItem> updatedList = List.from(_walletList);
        updatedList[index] = updateItem;

        // Assign the new list back to _walletList
        _walletList = updatedList;

        result = SyncResult.existingWalletUpdated;

        // 에러 발생 시 wallet_list_screen에서 toast로 알리게 하기 위해서 notifyListeners() 호출
        _updateWalletInStorage().catchError((e) => notifyListeners());
      } else {
        // case 3
        result = SyncResult.existingWalletNoUpdate;
        return ResultOfSyncFromVault(
            result: result, walletId: existingWallet.id);
      }
      id = existingWallet.id;
    } else {
      final sameNameIndex =
          _walletList.indexWhere((element) => element.name == walletSync.name);
      if (sameNameIndex != -1) {
        // case 4
        result = SyncResult.existingName;
        return ResultOfSyncFromVault(result: result);
      }

      // case1
      // Create a new list and add the new item
      List<WalletListItem> updatedList = List.from(_walletList);
      WalletListItem newItem =
          await WalletListItem.create(walletSyncObject: walletSync);
      updatedList.add(newItem);
      // Assign the new list back to _walletList
      _walletList = updatedList;

      id = newItem.id;
      await initWallet(targetId: id, syncOthers: false);
    }
    notifyListeners(); // 추가한 지갑이 목록에 바로 보이게 하기
    return ResultOfSyncFromVault(result: result, walletId: id);
  }

  Future<void> deleteWallet(int id) async {
    final index = _walletList.indexWhere((item) => item.id == id);
    if (index == -1) {
      throw Exception('deleteVault: no wallet id is "$id"');
    }

    _walletList = List.from(_walletList)..removeAt(index);

    if (_walletList.isEmpty) {
      _subStateModel.saveNotEmptyWalletList(false);
    }

    await _subStateModel.removeFaucetHistory(id);

    /// txList 삭제
    await SharedPrefs().removeTxList(id);
    await _updateWalletInStorage();
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
    String? jsonArrayString;

    try {
      jsonArrayString = await _storageService.read(key: WALLET_LIST);
      Logger.log('>>>>> [AppStateModel] jsonArrayStr: $jsonArrayString');
    } catch (e) {
      // Unhandled Exception: PlatformException(Exception encountered, read, javax.crypto.BadPaddingException: error:1e000065:Cipher functions:OPENSSL_internal:BAD_DECRYPT
      // 앱 삭제 후 재설치 했는데 위 에러가 발생하는 경우가 있습니다.

      setWalletInitState(WalletInitState.error,
          error: ErrorCodes.withMessage(
              ErrorCodes.storageReadError, e.toString()));

      if (!_fastLoadDone) {
        _fastLoadDone = true;
        notifyListeners();
      }

      rethrow;
    }

    if (jsonArrayString == null) {
      if (!_fastLoadDone) {
        _fastLoadDone = true;
        notifyListeners();
      }

      return;
    }

    final List<dynamic> itemList = jsonDecode(jsonArrayString) as List;
    for (final item in itemList) {
      var walletListItem = WalletListItem.fromJson(item);
      addOrUpdateWalletList(walletListItem);
    }

    _subStateModel.saveNotEmptyWalletList(_walletList.isNotEmpty);

    // for wallet_list_screen
    if (!_fastLoadDone) {
      _fastLoadDone = true;
      notifyListeners();
    }
  }

  // _walletList에 walletListItem을 추가하거나 있으면 대체합니다.
  void addOrUpdateWalletList(WalletListItem walletListItem) {
    int index = _walletList.indexWhere((element) =>
        element.coconutWallet.keyStore.fingerprint ==
            walletListItem.coconutWallet.keyStore.fingerprint &&
        element.id == walletListItem.id);

    List<WalletListItem> updatedList = List.from(_walletList);

    if (index != -1) {
      updatedList[index] = walletListItem;
    } else {
      updatedList.add(walletListItem);
    }

    _walletList = updatedList;

    _subStateModel.saveNotEmptyWalletList(_walletList.isNotEmpty);

    notifyListeners();
  }

  Future<void> _fetchAllWalletLatestInfo({int? exceptionalId}) async {
    //Logger.log(">>>>> [_fetchAllWalletLatestInfo] exceptionalId: $exceptionalId");
    List<WalletListItem> targetWalletList = _walletList;
    int? exceptionIndex;
    if (exceptionalId != null) {
      exceptionIndex =
          _walletList.indexWhere((element) => element.id == exceptionalId);
      targetWalletList = List<WalletListItem>.from(_walletList)
        ..removeAt(exceptionIndex);
    }

    List<WalletListItem> newWalletList =
        await _fetchWalletsData(targetWalletList);

    if (exceptionalId != null) {
      assert(exceptionIndex != -1);
      newWalletList.insert(exceptionIndex!, _walletList[exceptionIndex]);
    }
    // for update _walletList and UI both
    _walletList = newWalletList;

    await _updateWalletInStorage();
    //_walletList = List.from(_walletList);
  }

  Future<void> _fetchWalletLatestInfo(int walletId) async {
    try {
      int i = _walletList.indexWhere((element) => element.id == walletId);
      WalletListItem existingWallet = _walletList[i];
      List<WalletListItem> fetchResult =
          await _fetchWalletsData([existingWallet]);
      _walletList[i] = fetchResult[0];
    } finally {
      await _updateWalletInStorage();
      // UI 업데이트를 위해 _walletList reference를 변경해준다
      _walletList = List.from(_walletList);
    }
  }

  Future<void> runSaveRepositoryInIsolate(List<WalletListItem> walletListItems,
      List<WalletFetchResult> retchResults) async {
    assert(walletListItems.length == retchResults.length);
    final ReceivePort receivePort = ReceivePort();
    final RootIsolateToken rootIsolateToken = RootIsolateToken.instance!;
    final isolateData = <String, dynamic>{};
    isolateData['count'] = walletListItems.length;
    isolateData['dbDirectoryPath'] = _dbDiretoryPath;
    isolateData['bitcoinNetwork'] = BitcoinNetwork.regtest;
    for (int i = 0; i < walletListItems.length; i++) {
      isolateData['descriptor$i'] = walletListItems[i].descriptor;

      /// add isolate result data
      isolateData['txEntityList$i'] = retchResults[i]
          .txEntityList
          .map((entry) => jsonEncode(entry.toJson()))
          .toList();
      isolateData['utxoEntityList$i'] = retchResults[i]
          .utxoEntityList
          .map((entry) => jsonEncode(entry.toJson()))
          .toList();
      isolateData['blockEntityMap$i'] = retchResults[i]
          .blockEntityMap
          .map((key, value) => MapEntry(key, jsonEncode(value.toJson())));
      isolateData['balanceEntity$i'] =
          jsonEncode(retchResults[i].balanceEntity.toJson());
      isolateData['addressBalanceMap$i'] = retchResults[i].addressBalanceMap;
      isolateData['usedIndexList$i'] = retchResults[i].usedIndexList;
      isolateData['maxGapMap$i'] = retchResults[i].maxGapMap;
      isolateData['initialReceiveIndex$i'] =
          retchResults[i].initialReceiveIndex;
      isolateData['initialChangeIndex$i'] = retchResults[i].initialChangeIndex;
    }

    /// Isolate (2) - repository close / isolate spawn
    Repository().close();
    Isolate isolate = await Isolate.spawn(isolateEntryPoint,
        [receivePort.sendPort, isolateData, rootIsolateToken]);

    /// Isolate (6) - afterIsolate / get wallet / initialize repository
    final coconutWallets = await receivePort.first;
    Repository.initialize(_dbDiretoryPath);

    /// Isolate (7) - update wallet
    for (int i = 0; i < walletListItems.length; i++) {
      walletListItems[i].coconutWallet = coconutWallets[i];
    }
    // if (coconutWallet is SingleSignatureWallet) {
    //   int i =
    //       _walletList.indexWhere((element) => element.id == walletListItems.id);
    //   _walletList[i].coconutWallet = coconutWallet;
    // }

    // Isolate (8) - close isolate
    isolate.kill(priority: Isolate.immediate);
    receivePort.close();
  }

  // 지갑의 잔액, 트랜잭션 목록 최신 정보를 조회합니다.
  Future<List<WalletListItem>> _fetchWalletsData(
      List<WalletListItem> walletListItems) async {
    List<int> noNeedToUpdate = [];
    List<WalletListItem> needToUpdateList = [];
    List<WalletFetchResult> syncResults = []; // db update 성공 후 txCount 업데이트를 위해

    await _initNodeConnectionWhenIsNull();

    try {
      for (int i = 0; i < walletListItems.length; i++) {
        Result<WalletFetchResult, CoconutError> syncResult =
            await _nodeConnector!.fetch(walletListItems[i].coconutWallet);
        if (syncResult.isFailure) {
          throw syncResult.error?.message ??
              Exception('_nodeConnector.fetch() failed.');
        }
        if (syncResult.value == null) {
          throw Exception('_nodeConnector.fetch() returned null');
        }
        // regtest에서는 txEntityList.count가 변경되지 않았으면 db update를 하지 않습니다.
        // mainnet에서는 트랜잭션을 추가해서 기존 트잭을 무효화시키는 경우가 있어서 5% 미만의 확률로 아래 조건문이 유효하지 않을 수 있습니다.
        // 하지만 현재는 regtest용 앱만 있고 우리 지갑에서 rbf나 cpfp 등의 기능을 제공하지 않기 때문에 유효한 조건문입니다.
        // 진행중인 트랜잭션이 없거나 (isLatestTxBlockHeightZero == false) txEntityList.count가 변경되지 않았으면 db update를 하지 않습니다.
        if (!walletListItems[i].isLatestTxBlockHeightZero &&
            syncResult.value!.txEntityList.length ==
                walletListItems[i].txCount) {
          noNeedToUpdate.add(i);
          walletListItems[i].coconutWallet.updateAddressBook();
          Logger.log('>>>>> noNeedToUpdate: ${walletListItems[i].name}');
          continue;
        }

        needToUpdateList.add(walletListItems[i]);
        syncResults.add(syncResult.value!);
        // TODO: 현재 coconut_lib getAddressList 결과에 오류가 있어 대신 사용합니다. (라이브러리 버그 픽싱 후 삭제)
        walletListItems[i].addressBalanceMap =
            syncResult.value!.addressBalanceMap;
        // TODO: 현재 coconut_lib getAddressList 결과에 오류가 있어 대신 사용합니다. (라이브러리 버그 픽싱 후 삭제)
        walletListItems[i].usedIndexList = syncResult.value!.usedIndexList;
      }

      /// Isolate (1) - call runSaveRepositoryInIsolate
      if (needToUpdateList.isNotEmpty) {
        await runSaveRepositoryInIsolate(needToUpdateList, syncResults);
      }

      /// MainThread - repositorySync
      // await Repository().sync(wallet, syncResult.value!);
    } catch (e) {
      setWalletInitState(WalletInitState.error,
          error:
              ErrorCodes.withMessage(ErrorCodes.syncFailedError, e.toString()));
      rethrow;
    }

    // db sync 성공 후 txCount, isLatestTxBlockHeightZero 업데이트 / txCount와 isLatestTxBlockHeightZero 다음 sync 여부를 결정합니다
    for (int i = 0; i < needToUpdateList.length; i++) {
      needToUpdateList[i].txCount = syncResults[i].txEntityList.length;

      // 잔액 업데이트
      try {
        needToUpdateList[i].balance =
            needToUpdateList[i].coconutWallet.getBalance() +
                needToUpdateList[i].coconutWallet.getUnconfirmedBalance();
      } catch (e) {
        setWalletInitState(WalletInitState.error,
            error: ErrorCodes.withMessage(
                ErrorCodes.fetchBalanceError, e.toString()));
        rethrow;
      }

      // txlist 업데이트
      try {
        List<Transfer> txList = needToUpdateList[i]
            .coconutWallet
            .getTransferList(cursor: 0, count: needToUpdateList[i].txCount!);
        Logger.log(">>>>>> ${txList.toJsonList()}");
        await SharedPrefs()
            .setTxList(needToUpdateList[i].id, jsonEncode(txList.toJsonList()));
        // 최신 트랜잭션의 블록 높이가 0인지 확인: 아직 Confirm 안된 트랜잭션이 있다는 의미입니다.
        needToUpdateList[i].isLatestTxBlockHeightZero =
            txList.isNotEmpty && txList[0].blockHeight == 0;
      } catch (e) {
        setWalletInitState(WalletInitState.error,
            error: ErrorCodes.withMessage(
                ErrorCodes.fetchTransferListError, e.toString()));
        rethrow;
      }
    }

    // 받은 리스트 그대로 반환해야됨.
    for (int i = 0; i < noNeedToUpdate.length; i++) {
      needToUpdateList.insert(
          noNeedToUpdate[i], walletListItems[noNeedToUpdate[i]]);
    }
    return needToUpdateList;
  }

  Future<void> _updateWalletInStorage() async {
    final jsonString =
        jsonEncode(_walletList.map((item) => item.toJson()).toList());

    _subStateModel.saveNotEmptyWalletList(_walletList.isNotEmpty);

    try {
      await _storageService.write(key: WALLET_LIST, value: jsonString);
    } catch (e) {
      setWalletInitState(WalletInitState.error,
          error: ErrorCodes.withMessage(
              ErrorCodes.storageWriteError, e.toString()));
      rethrow;
    }
  }

  void clearAllRelatedSending() {
    txWaitingForSign = null;
    signedTransaction = null;
  }

  /// 네트워크가 꺼지면 네트워크를 해제함.
  void setIsNetworkOn(bool isNetworkOn) {
    if (_isNetworkOn == null && isNetworkOn) {
      _isNetworkOn = isNetworkOn;
      initWallet();
      return;
    }

    _isNetworkOn = isNetworkOn;

    if (!isNetworkOn) {
      handleNetworkDisconnected();
      notifyListeners();
    }
  }

  Future<dynamic> startFaucetRequest(String address, double amount) async {
    _isFaucetRequesting = true;
    notifyListeners();

    try {
      final response = await _faucetRepository
          .getTestCoin(FaucetRequest(address: address, amount: amount));
      _isFaucetRequesting = false;
      notifyListeners();
      return response;
    } catch (e) {
      _isFaucetRequesting = false;
      notifyListeners();
      throw Exception('Failed to send request: $e');
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

  Future<Result<String, CoconutError>> broadcast(String signedTx) async {
    await _initNodeConnectionWhenIsNull();

    Result<String, CoconutError> result =
        await _nodeConnector!.broadcast(signedTx);
    return result;
  }
}

class ResultOfSyncFromVault {
  ResultOfSyncFromVault({required this.result, this.walletId});

  final SyncResult result;
  final int? walletId; // 관련있는 지갑 id
}
