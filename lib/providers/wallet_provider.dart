import 'dart:async';
import 'dart:collection';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/node/node_provider_state.dart';
import 'package:coconut_wallet/model/node/wallet_update_info.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/wallet/balance.dart';
import 'package:coconut_wallet/model/wallet/multisig_wallet_list_item.dart';
import 'package:coconut_wallet/model/wallet/singlesig_wallet_list_item.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/model/wallet/wallet_address.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/model/wallet/watch_only_wallet.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/repository/realm/address_repository.dart';
import 'package:coconut_wallet/repository/realm/realm_manager.dart';
import 'package:coconut_wallet/repository/realm/transaction_repository.dart';
import 'package:coconut_wallet/repository/realm/utxo_repository.dart';
import 'package:coconut_wallet/repository/realm/wallet_repository.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/utils/result.dart';
import 'package:flutter/material.dart';

enum WalletLoadState {
  never,
  loadingFromDB,
  loadCompleted,
}

/// failed: 네트워크가 꺼져있을 때
enum WalletSubscriptionState { never, syncing, completed, failed }

typedef WalletUpdateListener = void Function(WalletUpdateInfo walletUpdateInfo);

class WalletProvider extends ChangeNotifier {
  WalletLoadState _walletLoadState = WalletLoadState.never;
  WalletLoadState get walletLoadState => _walletLoadState;

  WalletSubscriptionState _walletSubscriptionState = WalletSubscriptionState.never;
  WalletSubscriptionState get walletSubscriptionState => _walletSubscriptionState;

  bool? _isNetworkOn;

  List<WalletListItemBase> _walletItemList = [];
  List<WalletListItemBase> get walletItemList => _walletItemList;

  Map<int, Balance> _walletBalance = {};
  Map<int, Balance> get walletBalance => UnmodifiableMapView(_walletBalance);

  int gapLimit = 20;

  bool _isSyncing = true;
  bool _isAnyBalanceUpdating = true;

  final RealmManager _realmManager;
  final AddressRepository _addressRepository;
  final TransactionRepository _transactionRepository;
  final UtxoRepository _utxoRepository;
  final WalletRepository _walletRepository;

  late final Future<void> Function(int) _saveWalletCount;
  late final bool _isSetPin;

  late final NodeProvider _nodeProvider;
  late bool _isNodeProviderInitialized;

  // db 업데이트 중인가
  bool get isSyncing => _isSyncing;
  bool get isAnyBalanceUpdating => _isAnyBalanceUpdating;
  final Map<int, List<WalletUpdateListener>> _walletUpdateListeners = {};

  void addWalletUpdateListener(int walletId, WalletUpdateListener listener) {
    if (!_walletUpdateListeners.containsKey(walletId)) {
      _walletUpdateListeners[walletId] = [];
    }
    _walletUpdateListeners[walletId]!.add(listener);
  }

  void removeWalletUpdateListener(int walletId, WalletUpdateListener listener) {
    _walletUpdateListeners[walletId]?.remove(listener);
    if (_walletUpdateListeners[walletId]?.isEmpty ?? false) {
      _walletUpdateListeners.remove(walletId);
    }
  }

  void _notifyWalletUpdateListeners(WalletUpdateInfo walletUpdateInfo) {
    if (_walletUpdateListeners.containsKey(walletUpdateInfo.walletId)) {
      for (var listener in _walletUpdateListeners[walletUpdateInfo.walletId]!) {
        listener(walletUpdateInfo);
      }
    }
  }

  WalletProvider(
    this._realmManager,
    this._addressRepository,
    this._transactionRepository,
    this._utxoRepository,
    this._walletRepository,
    bool? isNetworkOn,
    Future<void> Function(int) saveWalletCount,
    bool isSetPin,
    this._nodeProvider,
  )   : _isNetworkOn = isNetworkOn,
        _saveWalletCount = saveWalletCount,
        _isSetPin = isSetPin {
    _nodeProvider.addListener(_onNodeProviderStateUpdated);
    _isNodeProviderInitialized = _nodeProvider.isInitialized;
    _loadWalletListFromDB().then((_) {
      if (_walletItemList.isEmpty) {
        _isSyncing = false;
        _isAnyBalanceUpdating = false;
        notifyListeners();
      } else {
        _subscribeNodeProvider();
      }
    });
  }

  void _onNodeProviderStateUpdated() {
    if (!_isNodeProviderInitialized && _nodeProvider.isInitialized) {
      Logger.log('--> _nodeProvider.isInitialized: ${_nodeProvider.isInitialized}');
      _isNodeProviderInitialized = true;
      _subscribeNodeProvider();
    }

    // 화면 이탈 후 재연결 시 재구독이 필요한 상황
    if (_nodeProvider.needSubscribeWallets) {
      _subscribeNodeProvider();
    }

    // NodeProvider 상태 출력
    _printWalletStatus();

    // TODO: notifyListeners()가 빈번 -> 개선 필요
    _updateIsSyncingIfNeeded(_nodeProvider.state);
    if (_isAnyBalanceUpdating) {
      _walletBalance = fetchWalletBalanceMap();
      notifyListeners();
    }
    _updateIsAnyBalanceUpdatingIfNeeded(_nodeProvider.state);
    for (var key in _nodeProvider.state.registeredWallets.keys) {
      if (_nodeProvider.state.registeredWallets[key] != null) {
        _notifyWalletUpdateListeners(_nodeProvider.state.registeredWallets[key]!);
      }
    }
  }

  void _updateIsSyncingIfNeeded(NodeProviderState nodeProviderState) {
    final newSyncingState = nodeProviderState.connectionState == MainClientState.syncing;
    if (_isSyncing != newSyncingState) {
      _isSyncing = newSyncingState;
      notifyListeners();
    }
  }

  void _updateIsAnyBalanceUpdatingIfNeeded(NodeProviderState nodeProviderState) {
    if (nodeProviderState.connectionState != MainClientState.syncing) return;

    bool anyBalanceSyncing = false;

    for (var walletId in nodeProviderState.registeredWallets.keys) {
      var wallet = nodeProviderState.registeredWallets[walletId];
      if (wallet == null) continue;

      // 업데이트 예정 중이거나 업데이트 중
      if (wallet.balance == UpdateStatus.waiting || wallet.balance == UpdateStatus.syncing) {
        anyBalanceSyncing = true;
        break;
      }
    }

    if (_isAnyBalanceUpdating != anyBalanceSyncing) {
      _isAnyBalanceUpdating = anyBalanceSyncing;
      Logger.log('--> _isAnyBalanceUpdating 업데이트 / $_isAnyBalanceUpdating');
      notifyListeners();
    }
  }

  Future<void> _loadWalletListFromDB() async {
    // 두 번 이상 호출 될 필요 없는 함수
    assert(_walletLoadState == WalletLoadState.never);

    _walletLoadState = WalletLoadState.loadingFromDB;

    try {
      Logger.log('--> RealmManager.isInitialized: ${_realmManager.isInitialized}');
      if (_realmManager.isInitialized) {
        await _realmManager.init(_isSetPin);
      }
      _walletItemList = await _fetchWalletListFromDB();
      _walletBalance = fetchWalletBalanceMap();
      _walletLoadState = WalletLoadState.loadCompleted;
      _walletItemList.map((e) => debugPrint(e.name));
    } catch (e) {
      // Unhandled Exception: PlatformException(Exception encountered, read, javax.crypto.BadPaddingException: error:1e000065:Cipher functions:OPENSSL_internal:BAD_DECRYPT
      // 앱 삭제 후 재설치 했는데 위 에러가 발생하는 경우가 있습니다.
      // unhandle
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  Map<int, Balance> fetchWalletBalanceMap() {
    return {for (var wallet in _walletItemList) wallet.id: getWalletBalance(wallet.id)};
  }

  bool _canSubscribeWallets() {
    if (_walletLoadState != WalletLoadState.loadCompleted ||
        !_isNodeProviderInitialized ||
        _isNetworkOn != true ||
        _walletSubscriptionState == WalletSubscriptionState.syncing) {
      Logger.log('--> subscribe wallet 준비 안됐거나 이미 진행 중');
      return false;
    }
    return true;
  }

  Future<WalletSubscriptionState?> _subscribeNodeProvider() async {
    _nodeProvider.needSubscribeWallets = false;

    if (!_canSubscribeWallets()) {
      return null;
    }

    await _unsubscribeWalletsIfNeeded();
    _walletSubscriptionState = WalletSubscriptionState.syncing;
    notifyListeners();

    Result<bool> result = await _nodeProvider.subscribeWallets(walletItems: _walletItemList);
    if (result.isSuccess) {
      _walletSubscriptionState = WalletSubscriptionState.completed;
    } else {
      _onFailedSubscription();
    }
    notifyListeners();

    return _walletSubscriptionState;
  }

  // TODO: 실패 했을 때 사용자에게 알리는 장치가 없음
  void _onFailedSubscription() {
    _walletSubscriptionState = WalletSubscriptionState.failed;
    _isSyncing = false;
    _isAnyBalanceUpdating = false;
  }

  Future<void> _unsubscribeWalletsIfNeeded() async {
    if (_walletSubscriptionState != WalletSubscriptionState.completed) {
      return;
    }

    for (var wallet in _walletItemList) {
      await _nodeProvider.unsubscribeWallet(wallet);
    }
  }

  WalletListItemBase getWalletById(int id) {
    if (_walletItemList.isEmpty) {
      throw Exception('WalletItem is Empty');
    }
    return _walletItemList.firstWhere((element) => element.id == id);
  }

  Future<List<WalletListItemBase>> _fetchWalletListFromDB() async {
    return await _walletRepository.getWalletItemList();
  }

  int _findSameWalletIndex(String descriptorString, {required bool isMultisig}) {
    WalletBase walletBase;
    if (isMultisig) {
      walletBase = MultisignatureWallet.fromDescriptor(descriptorString);
    } else {
      walletBase = SingleSignatureWallet.fromDescriptor(descriptorString);
    }
    var newWalletAddress = walletBase.getAddress(0);
    for (var index = 0; index < _walletItemList.length; index++) {
      if (isMultisig) {
        if (_walletItemList[index] is MultisigWalletListItem &&
            _walletItemList[index].walletBase.getAddress(0) == newWalletAddress) {
          return index;
        }
      } else {
        if (_walletItemList[index] is SinglesigWalletListItem &&
            _walletItemList[index].walletBase.getAddress(0) == newWalletAddress) {
          return index;
        }
      }
    }
    return -1;
  }

  /// case1. 새로운 pubkey인지 확인 후 지갑으로 추가하기 ("지갑을 추가했습니다.")
  /// case2. 이미 존재하는 fingerprint이지만 이름/계정/칼라 중 하나라도 변경되었을 경우 ("동기화를 완료했습니다.")
  /// case3. 이미 존재하고 변화가 없는 경우 ("이미 추가된 지갑입니다.")
  /// case4. 같은 이름을 가진 다른 지갑이 있는 경우 ("같은 이름을 가진 지갑이 있습니다. 이름을 변경한 후 동기화 해주세요.")
  /// case5. 외부 지갑 형태로 이미 추가된 지갑 ("이미 추가된 지갑입니다. ([지갑 이름])")
  Future<ResultOfSyncFromVault> syncFromCoconutVault(WatchOnlyWallet watchOnlyWallet) async {
    WalletSyncResult result = WalletSyncResult.newWalletAdded;
    bool isMultisig = watchOnlyWallet.signers != null;
    int index = _findSameWalletIndex(watchOnlyWallet.descriptor, isMultisig: isMultisig);

    if (index != -1) {
      if (_walletItemList[index].walletImportSource != WalletImportSource.coconutVault) {
        // case 5
        return ResultOfSyncFromVault(
            result: WalletSyncResult.existingWalletUpdateImpossible,
            walletId: _walletItemList[index].id);
      }
      // case 3
      result = WalletSyncResult.existingWalletNoUpdate;

      // case 2: 변경 사항 체크하며 업데이트
      if (_hasChangedOfUI(_walletItemList[index], watchOnlyWallet)) {
        _walletRepository.updateWalletUI(_walletItemList[index].id, watchOnlyWallet);

        // 업데이트된 지갑 목록 가져오기
        _walletItemList = await _fetchWalletListFromDB();
        result = WalletSyncResult.existingWalletUpdated;
        notifyListeners();
      }
      return ResultOfSyncFromVault(result: result, walletId: _walletItemList[index].id);
    }

    // 새 지갑 추가
    final sameNameIndex =
        _walletItemList.indexWhere((element) => element.name == watchOnlyWallet.name);
    if (sameNameIndex != -1) {
      // case 4: 동일 이름 존재
      return ResultOfSyncFromVault(result: WalletSyncResult.existingName);
    }

    // case 1: 새 지갑 생성
    var newWallet = await _addNewWallet(watchOnlyWallet, isMultisig);

    await _waitForSubscriptionDone();

    if (_walletSubscriptionState != WalletSubscriptionState.failed) {
      _nodeProvider.subscribeWallet(newWallet);
    }

    return ResultOfSyncFromVault(result: result, walletId: newWallet.id);
  }

  /// TODO: 추후 멀티시그지갑 descriptor 추가 가능해 진 후 함수 변경 필요
  Future<ResultOfSyncFromVault> syncFromThirdParty(WatchOnlyWallet watchOnlyWallet) async {
    final sameNameIndex =
        _walletItemList.indexWhere((element) => element.name == watchOnlyWallet.name);
    assert(sameNameIndex == -1);

    WalletSyncResult result = WalletSyncResult.newWalletAdded;

    final index = _findSameWalletIndex(watchOnlyWallet.descriptor, isMultisig: false);

    if (index != -1) {
      return ResultOfSyncFromVault(
          result: WalletSyncResult.existingWalletUpdateImpossible,
          walletId: _walletItemList[index].id);
    }
    // case 1: 새 지갑 생성
    bool isMultisig = watchOnlyWallet.signers != null;
    var newWallet = await _addNewWallet(watchOnlyWallet, isMultisig);

    await _waitForSubscriptionDone();

    if (_walletSubscriptionState != WalletSubscriptionState.failed) {
      _nodeProvider.subscribeWallet(newWallet);
    }

    return ResultOfSyncFromVault(result: result, walletId: newWallet.id);
  }

  // 기존 지갑들의 구독이 완료될 때까지 기다립니다.
  Future<void> _waitForSubscriptionDone() async {
    while (_walletSubscriptionState != WalletSubscriptionState.completed &&
        _walletSubscriptionState != WalletSubscriptionState.failed) {
      await Future.delayed(const Duration(seconds: 1));
    }
  }

  Future<WalletListItemBase> _addNewWallet(WatchOnlyWallet wallet, bool isMultisig) async {
    WalletListItemBase newItem;
    if (isMultisig) {
      newItem = await _walletRepository.addMultisigWallet(wallet);
    } else {
      newItem = await _walletRepository.addSinglesigWallet(wallet);
    }

    // 지갑 추가 후 receive, change 주소 각각 1개씩 생성
    await _addressRepository.ensureAddressesInit(walletItemBase: newItem);

    List<WalletListItemBase> updatedList = List.from(_walletItemList);
    updatedList.insert(0, newItem); // wallet-list의 지갑 정렬 방식을 최신순으로 하기 위함
    _walletItemList = updatedList;

    _saveWalletCount(updatedList.length);
    return newItem;
  }

  Future<void> fetchWalletBalance(int walletId) async {
    final Balance balance = getWalletBalance(walletId);
    _walletBalance[walletId] = balance;
    notifyListeners();
  }

  /// 변동 사항이 있었으면 true, 없었으면 false를 반환합니다.
  bool _hasChangedOfUI(WalletListItemBase existingWallet, WatchOnlyWallet watchOnlyWallet) {
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
          multisigWallet.signers[i].colorIndex != watchOnlyWallet.signers![i].colorIndex ||
          multisigWallet.signers[i].iconIndex != watchOnlyWallet.signers![i].iconIndex ||
          multisigWallet.signers[i].memo != watchOnlyWallet.signers![i].memo) {
        hasChanged = true;
        break;
      }
    }

    return hasChanged;
  }

  Future<void> deleteWallet(int walletId) async {
    await _nodeProvider.closeConnection();
    _nodeProvider.deleteWallet(walletId);
    await _nodeProvider.initialize();
    await _walletRepository.deleteWallet(walletId);
    _walletItemList = await _fetchWalletListFromDB();
    _saveWalletCount(_walletItemList.length);
    _walletBalance.remove(walletId);
    notifyListeners();

    unawaited(_subscribeNodeProvider());
  }

  /// [싱글시그니처] 외부지갑 이름변경
  Future<void> updateWalletName(int id, String name) async {
    final index = _walletItemList.indexWhere((element) => element.id == id);
    if (walletItemList[index] is! SinglesigWalletListItem) {
      throw Exception('해당 지갑은 싱글시그가 아닙니다. 멀티시그의 이름은 변경할 수 없습니다.');
    }

    // 싱글시그니처 지갑만 허용하므로, _requiredSignatureCount과 _signers는 null로 할당
    WatchOnlyWallet watchOnlyWallet = WatchOnlyWallet(
        name,
        walletItemList[index].colorIndex,
        walletItemList[index].iconIndex,
        walletItemList[index].descriptor,
        null,
        null,
        walletItemList[index].walletImportSource.name);
    _walletRepository.updateWalletUI(id, watchOnlyWallet);
    _walletItemList = await _fetchWalletListFromDB();

    notifyListeners();
  }

  /// WalletProvider 생성자에서 isNetworkOn은 null로 초기화 됩니다.
  /// 아직 앱 내에서 네트워크 상태가 확인이 안된 채로 지갑 동기화 함수가 호출됩니다.
  /// 따라서 네트워크 상태가 null -> true로 변경 되었을 때 지갑 동기화를 해줍니다.
  void setIsNetworkOn(bool? isNetworkOn) {
    if (_isNetworkOn == isNetworkOn) return;

    bool wasNull = _isNetworkOn == null;
    bool wasOff = _isNetworkOn == false;
    _isNetworkOn = isNetworkOn;

    if (wasNull) {
      _onNetworkInitialized();
    } else if (wasOff && _isNetworkOn == true) {
      _handleNetworkReconnected();
    }
  }

  void _onNetworkInitialized() {
    assert(_isNetworkOn != null);
    if (_isNetworkOn!) {
      _subscribeNodeProvider();
    } else {
      _isSyncing = false;
      _isAnyBalanceUpdating = false;
      _walletSubscriptionState = WalletSubscriptionState.failed;
      notifyListeners();
    }
  }

  void _handleNetworkReconnected() {
    if (_walletSubscriptionState == WalletSubscriptionState.never ||
        _walletSubscriptionState == WalletSubscriptionState.failed) {
      _nodeProvider.initialize().then((_) {
        _subscribeNodeProvider();
      });
    }
  }

  Balance getWalletBalance(int walletId) {
    final realmBalance = _walletRepository.getWalletBalance(walletId);
    return Balance(
      realmBalance.confirmed,
      realmBalance.unconfirmed,
    );
  }

  Future<List<WalletAddress>> getWalletAddressList(
    WalletListItemBase wallet,
    int cursor,
    int count,
    bool isChange,
    bool showOnlyUnusedAddresses,
  ) async {
    return _addressRepository.getWalletAddressList(
        wallet, cursor, count, isChange, showOnlyUnusedAddresses);
  }

  List<WalletAddress> searchWalletAddressList(WalletListItemBase wallet, String keyword) {
    return _addressRepository.searchWalletAddressList(wallet, keyword);
  }

  (int, int) getGeneratedIndexes(WalletListItemBase wallet) {
    return _addressRepository.getGeneratedAddressIndexes(wallet);
  }

  Future encryptWalletSecureData(String hashedPin) async {
    await _realmManager.encrypt(hashedPin);
  }

  Future decryptWalletSecureData() async {
    await _realmManager.decrypt();
  }

  bool containsAddress(int walletId, String address, {bool isChange = false}) {
    return _addressRepository.containsAddress(
      walletId,
      address,
      isChange: isChange,
    );
  }

  List<WalletAddress> filterChangeAddressesFromList(int walletId, List<String> addresses) {
    return _addressRepository.filterChangeAddressesFromList(walletId, addresses);
  }

  WalletAddress getChangeAddress(int walletId) {
    return _addressRepository.getChangeAddress(walletId);
  }

  WalletAddress getReceiveAddress(int walletId) {
    return _addressRepository.getReceiveAddress(walletId);
  }

  List<UtxoState> getUtxoList(int walletId) {
    return _utxoRepository.getUtxoStateList(walletId);
  }

  List<UtxoState> getUtxoListByStatus(int walletId, UtxoStatus utxoStatus) {
    return _utxoRepository.getUtxosByStatus(walletId, utxoStatus);
  }

  List<TransactionRecord> getTransactionRecordList(int walletId) {
    return _transactionRepository.getTransactionRecordList(walletId);
  }

  UtxoState? getUtxoState(int walletId, String utxoId) {
    return _utxoRepository.getUtxoState(walletId, utxoId);
  }

  TransactionRecord? getTransactionRecord(int walletId, String transactionHash) {
    return _transactionRepository.getTransactionRecord(walletId, transactionHash);
  }

  WalletUpdateInfo getWalletUpdateInfo(int walletId) {
    var result = _nodeProvider.state.registeredWallets[walletId];
    if (result == null) {
      return WalletUpdateInfo(walletId);
    }

    return result;
  }

  Future<void> toggleUtxoLockStatus(int walletId, String utxoId) async {
    final result = await _utxoRepository.toggleUtxoLockStatus(walletId, utxoId);
    if (result.isFailure) {
      throw result.error;
    }
  }

  /// 백그라운드에서 미리 주소를 저장합니다.
  Future<void> addAddressesWithGapLimit({
    required WalletListItemBase walletItemBase,
    required List<WalletAddress> newAddresses,
    required bool isChange,
  }) async {
    return _addressRepository.addAddressesWithGapLimit(
      walletItemBase: walletItemBase,
      newAddresses: newAddresses,
      isChange: isChange,
    );
  }

  @override
  void dispose() {
    _nodeProvider.removeListener(_onNodeProviderStateUpdated);
    super.dispose();
  }

  void _printWalletStatus() {
    // UpdateStatus를 심볼로 변환하는 함수
    String statusToSymbol(UpdateStatus status) {
      switch (status) {
        case UpdateStatus.waiting:
          return '⏳'; // 대기 중
        case UpdateStatus.syncing:
          return '🔄'; // 동기화 중
        case UpdateStatus.completed:
          return '✅'; // 완료됨
      }
    }

    // ConnectionState를 심볼로 변환하는 함수
    String connectionStateToSymbol(MainClientState state) {
      switch (state) {
        case MainClientState.syncing:
          return '🔄 동기화 중';
        case MainClientState.waiting:
          return '🟢 대기 중ㅤ';
        case MainClientState.disconnected:
          return '🔴 연결 끊김';
      }
    }

    final connectionState = _nodeProvider.state.connectionState;
    final connectionStateSymbol = connectionStateToSymbol(connectionState);
    final buffer = StringBuffer();

    if (_nodeProvider.state.registeredWallets.isEmpty) {
      buffer.writeln('--> 등록된 지갑이 없습니다.');
      buffer.writeln('--> connectionState: $connectionState');
      Logger.log(buffer.toString());
      return;
    }

    // 등록된 지갑의 키 목록 얻기
    final walletKeys = _nodeProvider.state.registeredWallets.keys.toList();

    // 테이블 헤더 출력 (connectionState 포함)
    buffer.writeln('\n');
    buffer.writeln('┌───────────────────────────────────────┐');
    buffer.writeln('│ 연결 상태: $connectionStateSymbol${' ' * (23 - connectionStateSymbol.length)}│');
    buffer.writeln('├─────────┬─────────┬─────────┬─────────┤');
    buffer.writeln('│ 지갑 ID │  잔액   │  거래   │  UTXO   │');
    buffer.writeln('├─────────┼─────────┼─────────┼─────────┤');

    // 각 지갑 상태 출력
    for (int i = 0; i < walletKeys.length; i++) {
      final key = walletKeys[i];
      final value = _nodeProvider.state.registeredWallets[key]!;

      final balanceSymbol = statusToSymbol(value.balance);
      final transactionSymbol = statusToSymbol(value.transaction);
      final utxoSymbol = statusToSymbol(value.utxo);

      buffer.writeln(
          '│ ${key.toString().padRight(7)} │   $balanceSymbol    │   $transactionSymbol    │   $utxoSymbol    │');

      // 마지막 행이 아니면 행 구분선 추가
      if (i < walletKeys.length - 1) {
        buffer.writeln('├─────────┼─────────┼─────────┼─────────┤');
      }
    }

    buffer.writeln('└─────────┴─────────┴─────────┴─────────┘');
    Logger.log(buffer.toString());
  }
}

class ResultOfSyncFromVault {
  ResultOfSyncFromVault({required this.result, this.walletId});

  final WalletSyncResult result;
  final int? walletId; // 관련있는 지갑 id
}
