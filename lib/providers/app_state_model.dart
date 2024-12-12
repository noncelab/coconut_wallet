import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/model/data/multisig_signer.dart';
import 'package:coconut_wallet/model/data/multisig_wallet_list_item.dart';
import 'package:coconut_wallet/model/data/multisig_wallet_list_item_factory.dart';
import 'package:coconut_wallet/model/data/singlesig_wallet_list_item.dart';
import 'package:coconut_wallet/model/data/singlesig_wallet_list_item_factory.dart';
import 'package:coconut_wallet/model/data/wallet_list_item_base.dart';
import 'package:coconut_wallet/model/data/wallet_type.dart';
import 'package:coconut_wallet/utils/print_util.dart';
import 'package:coconut_wallet/screens/wallet_list_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:coconut_wallet/app.dart';
import 'package:coconut_wallet/model/app_error.dart';
import 'package:coconut_wallet/providers/app_sub_state_model.dart';
import 'package:coconut_wallet/model/enums.dart';
import 'package:coconut_wallet/model/request/faucet_request.dart';
import 'package:coconut_wallet/model/wallet_sync.dart';
import 'package:coconut_wallet/repositories/faucet_repository.dart';
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

  List<WalletListItemBase> _walletItemList = [];
  List<WalletListItemBase> get walletItemList => _walletItemList;

  // 애니메이션이 동작해야하면 해당하는 ReturnPageResult.<add/update>, 아니면 ReturnPageResult.none을 담습니다.
  List<ReturnPageResult> _animatedWalletFlags = [];
  List<ReturnPageResult> get animatedWalletFlags => _animatedWalletFlags;

  String? txWaitingForSign;
  String? signedTransaction; // hex decode result

  bool _isFaucetRequesting = false;
  bool get isFaucetRequesting => _isFaucetRequesting;

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

  void setAnimatedWalletFlags(
      {int? index, ReturnPageResult type = ReturnPageResult.none}) {
    _animatedWalletFlags =
        List.filled(_walletItemList.length, ReturnPageResult.none);
    if (index != null) {
      _animatedWalletFlags[index - 1] = type;
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
  List<SinglesigWalletListItem> getWallets() {
    if (_walletItemList.isEmpty) {
      return [];
    }

    return List.from(_walletItemList);
  }

  WalletListItemBase getWalletById(int id) {
    return _walletItemList.firstWhere((element) => element.id == id);
  }

  // syncFromVault start
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

    SyncResult result = SyncResult.newWalletAdded;
    final index = _walletItemList
        .indexWhere((element) => element.descriptor == walletSync.descriptor);

    bool isMultisig = walletSync.signers != null;

    // 기존 지갑이 있는 경우
    if (index != -1) {
      final existingWallet = _walletItemList[index];
      bool isMultisigUpdated = false;
      if (isMultisig) {
        final existingMultiWallet = existingWallet as MultisigWalletListItem;
        for (MultisigSigner signer in walletSync.signers!) {
          int index = walletSync.signers!.indexOf(signer);
          final existingSigner = existingMultiWallet.signers[index];
          if (signer.name != existingSigner.name ||
              signer.colorIndex != existingSigner.colorIndex ||
              signer.iconIndex != existingSigner.iconIndex ||
              signer.memo != existingSigner.memo) {
            isMultisigUpdated = true;
            break;
          }
        }
      }

      // 변동사항이 있는지 체크
      if (existingWallet.name != walletSync.name ||
          existingWallet.colorIndex != walletSync.colorIndex ||
          existingWallet.iconIndex != walletSync.iconIndex ||
          isMultisigUpdated) {
        // case 2: 업데이트
        final updateItem =
            await _createUpdatedWallet(existingWallet, walletSync, isMultisig);

        List<WalletListItemBase> updatedList = List.from(_walletItemList);
        updatedList[index] = updateItem;
        _walletItemList = updatedList;

        result = SyncResult.existingWalletUpdated;
        // 에러 발생 시 wallet_list_screen에서 toast로 알리게 하기 위해서 notifyListeners() 호출
        setAnimatedWalletFlags(index: index + 1, type: ReturnPageResult.update);

        _updateWalletInStorage().catchError((e) {
          notifyListeners();
        });
      } else {
        // case 3: 변경사항 없음
        return ResultOfSyncFromVault(
            result: SyncResult.existingWalletNoUpdate,
            walletId: existingWallet.id);
      }

      return ResultOfSyncFromVault(result: result, walletId: existingWallet.id);
    }

    // 새 지갑 추가
    final sameNameIndex = _walletItemList
        .indexWhere((element) => element.name == walletSync.name);
    if (sameNameIndex != -1) {
      // case 4: 동일 이름 존재
      return ResultOfSyncFromVault(result: SyncResult.existingName);
    }

    // case 1: 새 지갑 생성
    final newItem = await _createNewWallet(walletSync, isMultisig);
    List<WalletListItemBase> updatedList = List.from(_walletItemList);
    updatedList.add(newItem);
    _walletItemList = updatedList;

    if (result == SyncResult.newWalletAdded) {
      setAnimatedWalletFlags(
          index: _walletItemList.length, type: ReturnPageResult.add);
    }
    await initWallet(targetId: newItem.id, syncOthers: false);

    notifyListeners();
    return ResultOfSyncFromVault(result: result, walletId: newItem.id);
  }

  Future<WalletListItemBase> _createUpdatedWallet(
      WalletListItemBase existingWallet,
      WalletSync walletSync,
      bool isMultisig) async {
    if (isMultisig) {
      return MultisigWalletListItem(
        id: existingWallet.id,
        name: walletSync.name,
        colorIndex: walletSync.colorIndex,
        iconIndex: walletSync.iconIndex,
        descriptor: walletSync.descriptor,
        requiredSignatureCount: walletSync.requiredSignatureCount ?? 0,
        signers: walletSync.signers ?? [],
        balance: existingWallet.balance,
      );
    }

    return SinglesigWalletListItem(
        id: existingWallet.id,
        name: walletSync.name,
        colorIndex: walletSync.colorIndex,
        iconIndex: walletSync.iconIndex,
        descriptor: walletSync.descriptor,
        balance: (existingWallet as SinglesigWalletListItem).balance);
  }

  Future<WalletListItemBase> _createNewWallet(
      WalletSync walletSync, bool isMultiSig) async {
    if (isMultiSig) {
      final secrets = {
        MultisigWalletListItemFactory.signersField: walletSync.signers,
        MultisigWalletListItemFactory.requiredSignatureCountField:
            walletSync.requiredSignatureCount,
      };

      return MultisigWalletListItemFactory().create(
        name: walletSync.name,
        colorIndex: walletSync.colorIndex,
        iconIndex: walletSync.iconIndex,
        descriptor: walletSync.descriptor,
        secrets: secrets,
      );
    }

    return SinglesigWalletListItemFactory().create(
      name: walletSync.name,
      colorIndex: walletSync.colorIndex,
      iconIndex: walletSync.iconIndex,
      descriptor: walletSync.descriptor,
    );
  }
  // syncFromVault end

  Future<void> deleteWallet(int id) async {
    final index = _walletItemList.indexWhere((item) => item.id == id);
    if (index == -1) {
      throw Exception('deleteVault: no wallet id is "$id"');
    }

    _walletItemList = List.from(_walletItemList)..removeAt(index);

    if (_walletItemList.isEmpty) {
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
      printLongString('>>>>> [AppStateModel] jsonArrayStr: $jsonArrayString');
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

      return;
    }

    if (jsonArrayString == null) {
      if (!_fastLoadDone) {
        _fastLoadDone = true;
        notifyListeners();
      }

      return;
    }

    // isolate
    final receivePort = ReceivePort();
    await Isolate.spawn(
        isolateEntryDecodeWallets, [receivePort.sendPort, jsonArrayString]);
    final result = await receivePort.first as List<WalletListItemBase>;

    _walletItemList = result;
    _animatedWalletFlags =
        List.filled(_walletItemList.length, ReturnPageResult.none);
    _subStateModel.saveNotEmptyWalletList(_walletItemList.isNotEmpty);

    // for wallet_list_screen
    if (!_fastLoadDone) {
      _fastLoadDone = true;
      notifyListeners();
    }
  }

  static isolateEntryDecodeWallets(List<Object> args) async {
    BitcoinNetwork.setNetwork(BitcoinNetwork.regtest);

    final SendPort sendPort = args[0] as SendPort;
    final String jsonArrayString = args[1] as String;

    try {
      final List<dynamic> itemList = jsonDecode(jsonArrayString) as List;
      List<WalletListItemBase> loadWallets = [];
      for (final item in itemList) {
        final Map<String, dynamic> walletData = item as Map<String, dynamic>;
        WalletListItemBase loadWallet;
        if (walletData['walletType'] == null ||
            walletData['walletType'] == WalletType.singleSignature.name) {
          loadWallet = SinglesigWalletListItem.fromJson(walletData);
        } else if (walletData['walletType'] == WalletType.multiSignature.name) {
          loadWallet = MultisigWalletListItem.fromJson(walletData);
        } else {
          throw ArgumentError('wrong walletType: ${walletData['walletType']}');
        }
        loadWallets.add(loadWallet);
      }

      sendPort.send(loadWallets);
    } catch (e) {
      sendPort.send([]);
    }
  }

  // _walletList에 walletListItem을 추가하거나 있으면 대체합니다.
  void addOrUpdateWalletList(WalletListItemBase walletListItem) {
    int index;
    if (walletListItem.walletType == WalletType.multiSignature) {
      index = _walletItemList
          .indexWhere((element) => element.id == walletListItem.id);
    } else {
      index = _walletItemList.indexWhere((element) {
        if (element.walletType == WalletType.multiSignature) return false;
        final baseMFP = (element.walletBase as SingleSignatureWallet)
            .keyStore
            .masterFingerprint;
        final newMFP = (walletListItem.walletBase as SingleSignatureWallet)
            .keyStore
            .masterFingerprint;
        return baseMFP == newMFP && element.id == walletListItem.id;
      });
    }

    List<WalletListItemBase> updatedList = List.from(_walletItemList);

    if (index != -1) {
      updatedList[index] = walletListItem;
    } else {
      updatedList.add(walletListItem);
    }

    _walletItemList = updatedList;

    _subStateModel.saveNotEmptyWalletList(_walletItemList.isNotEmpty);
    _animatedWalletFlags =
        List.filled(_walletItemList.length, ReturnPageResult.none);
    notifyListeners();
  }

  Future<void> _fetchAllWalletLatestInfo({int? exceptionalId}) async {
    //Logger.log(">>>>> [_fetchAllWalletLatestInfo] exceptionalId: $exceptionalId");
    List<WalletListItemBase> targetWalletList = _walletItemList;
    int? exceptionIndex;
    if (exceptionalId != null) {
      exceptionIndex =
          _walletItemList.indexWhere((element) => element.id == exceptionalId);
      targetWalletList = List<WalletListItemBase>.from(_walletItemList)
        ..removeAt(exceptionIndex);
    }

    List<WalletListItemBase> newWalletList =
        await _fetchWalletsData(targetWalletList);

    if (exceptionalId != null) {
      assert(exceptionIndex != -1);
      newWalletList.insert(exceptionIndex!, _walletItemList[exceptionIndex]);
    }
    // for update _walletList and UI both
    _walletItemList = newWalletList;

    await _updateWalletInStorage();
    //_walletList = List.from(_walletList);
  }

  Future<void> _fetchWalletLatestInfo(int walletId) async {
    try {
      int i = _walletItemList.indexWhere((element) => element.id == walletId);

      final walletBaseItem = _walletItemList[i];
      WalletListItemBase existingWallet;

      if (walletBaseItem.walletType == WalletType.multiSignature) {
        existingWallet = walletBaseItem as MultisigWalletListItem;
      } else {
        existingWallet = walletBaseItem as SinglesigWalletListItem;
      }

      List<WalletListItemBase> fetchResult =
          await _fetchWalletsData([existingWallet]);
      _walletItemList[i] = fetchResult[0];
    } finally {
      await _updateWalletInStorage();
      // UI 업데이트를 위해 _walletList reference를 변경해준다
      _walletItemList = List.from(_walletItemList);
    }
  }

  // _fetchWalletsData start
  // 지갑의 잔액, 트랜잭션 목록 최신 정보를 조회합니다.
  Future<List<WalletListItemBase>> _fetchWalletsData(
      List<WalletListItemBase> walletListItems) async {
    List<int> noNeedToUpdate = [];
    List<WalletListItemBase> needToUpdateList = [];
    List<WalletStatus> syncResults = [];

    await _initNodeConnectionWhenIsNull();

    try {
      for (int i = 0; i < walletListItems.length; i++) {
        final walletBaseItem = walletListItems[i];

        if (walletBaseItem.walletType == WalletType.multiSignature) {
          final multisigWallet =
              walletBaseItem.walletBase as MultisignatureWallet;
          final multisigItem = walletBaseItem as MultisigWalletListItem;
          await multisigWallet.fetchOnChainData(_nodeConnector!);

          if (multisigWallet.walletStatus == null) {
            throw Exception(
                "${walletBaseItem.name} 지갑의 fetchOnChainData 결과가 null");
          }
          WalletStatus syncResult = multisigWallet.walletStatus!;

          if (!_needsUpdate(multisigItem, syncResult)) {
            noNeedToUpdate.add(i);
            Logger.log('>>>>> noNeedToUpdate: ${walletListItems[i].name}');
            continue;
          }

          needToUpdateList.add(walletListItems[i]);
          syncResults.add(syncResult);
          _updateLegacyMaps(multisigItem, syncResult);
        } else {
          final singlesigWallet =
              walletBaseItem.walletBase as SingleSignatureWallet;
          final singlesigItem = walletBaseItem as SinglesigWalletListItem;
          await singlesigWallet.fetchOnChainData(_nodeConnector!);

          if (singlesigWallet.walletStatus == null) {
            throw Exception(
                "${walletBaseItem.name} 지갑의 fetchOnChainData 결과가 null");
          }
          WalletStatus syncResult = singlesigWallet.walletStatus!;

          if (!_needsUpdate(singlesigItem, syncResult)) {
            noNeedToUpdate.add(i);
            Logger.log('>>>>> noNeedToUpdate: ${walletListItems[i].name}');
            continue;
          }

          needToUpdateList.add(walletListItems[i]);
          syncResults.add(syncResult);
          _updateLegacyMaps(singlesigItem, syncResult);
        }
      }
    } catch (e) {
      setWalletInitState(WalletInitState.error,
          error:
              ErrorCodes.withMessage(ErrorCodes.syncFailedError, e.toString()));
      rethrow;
    }

    // 상태 업데이트
    await _updateWalletStates(needToUpdateList, syncResults);

    // 원본 순서 복원
    for (int i = 0; i < noNeedToUpdate.length; i++) {
      needToUpdateList.insert(
          noNeedToUpdate[i], walletListItems[noNeedToUpdate[i]]);
    }
    return needToUpdateList;
  }

  bool _needsUpdate(dynamic walletItem, WalletStatus syncResult) {
    return walletItem.isLatestTxBlockHeightZero ||
        syncResult.transactionList.length != walletItem.txCount ||
        walletItem.balance == null;
  }

  void _updateLegacyMaps(dynamic walletItem, WalletStatus syncResult) {
    walletItem.addressBalanceMap = {
      0: syncResult.receiveAddressBalanceMap,
      1: syncResult.changeAddressBalanceMap
    };
    walletItem.usedIndexList = {
      0: syncResult.receiveUsedIndexList,
      1: syncResult.changeUsedIndexList
    };
  }

  Future<void> _updateWalletStates(
      List<WalletListItemBase> wallets, List<WalletStatus> syncResults) async {
    for (int i = 0; i < wallets.length; i++) {
      if (wallets[i].walletType == WalletType.multiSignature) {
        await _updateMultisigWallet(
            wallets[i] as MultisigWalletListItem, syncResults[i]);
      } else {
        await _updateSinglesigWallet(
            wallets[i] as SinglesigWalletListItem, syncResults[i]);
      }
    }
  }

  Future<void> _updateMultisigWallet(
      MultisigWalletListItem wallet, WalletStatus syncResult) async {
    final multisigWallet = wallet.walletBase as MultisignatureWallet;

    wallet.txCount = syncResult.transactionList.length;

    try {
      wallet.balance =
          multisigWallet.getBalance() + multisigWallet.getUnconfirmedBalance();
    } catch (e) {
      setWalletInitState(WalletInitState.error,
          error: ErrorCodes.withMessage(
              ErrorCodes.fetchBalanceError, e.toString()));
      rethrow;
    }

    try {
      List<Transfer> txList =
          multisigWallet.getTransferList(cursor: 0, count: wallet.txCount!);
      await SharedPrefs().setTxList(wallet.id, jsonEncode(txList.toJsonList()));
      wallet.isLatestTxBlockHeightZero =
          txList.isNotEmpty && txList[0].blockHeight == 0;
    } catch (e) {
      setWalletInitState(WalletInitState.error,
          error: ErrorCodes.withMessage(
              ErrorCodes.fetchTransferListError, e.toString()));
      rethrow;
    }
  }

  Future<void> _updateSinglesigWallet(
      SinglesigWalletListItem wallet, WalletStatus syncResult) async {
    final singlesigWallet = wallet.walletBase as SingleSignatureWallet;

    wallet.txCount = syncResult.transactionList.length;

    try {
      wallet.balance = singlesigWallet.getBalance() +
          singlesigWallet.getUnconfirmedBalance();
    } catch (e) {
      setWalletInitState(WalletInitState.error,
          error: ErrorCodes.withMessage(
              ErrorCodes.fetchBalanceError, e.toString()));
      rethrow;
    }

    try {
      List<Transfer> txList =
          singlesigWallet.getTransferList(cursor: 0, count: wallet.txCount!);
      await SharedPrefs().setTxList(wallet.id, jsonEncode(txList.toJsonList()));
      wallet.isLatestTxBlockHeightZero =
          txList.isNotEmpty && txList[0].blockHeight == 0;
    } catch (e) {
      setWalletInitState(WalletInitState.error,
          error: ErrorCodes.withMessage(
              ErrorCodes.fetchTransferListError, e.toString()));
      rethrow;
    }
  }
  // _fetchWalletsData end

  Future<void> _updateWalletInStorage() async {
    final jsonString = jsonEncode(_walletItemList
        .map((item) => item.walletType == WalletType.multiSignature
            ? (item as MultisigWalletListItem).toJson()
            : (item as SinglesigWalletListItem).toJson())
        .toList());

    _subStateModel.saveNotEmptyWalletList(_walletItemList.isNotEmpty);

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
