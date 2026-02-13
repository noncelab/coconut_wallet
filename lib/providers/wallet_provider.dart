import 'dart:async';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/node/wallet_update_info.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/wallet/balance.dart';
import 'package:coconut_wallet/model/wallet/multisig_wallet_list_item.dart';
import 'package:coconut_wallet/model/wallet/singlesig_wallet_list_item.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/model/wallet/wallet_address.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/model/wallet/watch_only_wallet.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/view_model/home/wallet_add_scanner_view_model.dart';
import 'package:coconut_wallet/repository/realm/address_repository.dart';
import 'package:coconut_wallet/repository/realm/transaction_repository.dart';
import 'package:coconut_wallet/repository/realm/utxo_repository.dart';
import 'package:coconut_wallet/repository/realm/wallet_repository.dart';
import 'package:coconut_wallet/services/model/response/block_timestamp.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:flutter/material.dart';
import 'package:collection/collection.dart';
import 'package:tuple/tuple.dart';

typedef WalletUpdateListener = void Function(WalletUpdateInfo walletUpdateInfo);

class WalletProvider extends ChangeNotifier {
  WalletLoadState _walletLoadState = WalletLoadState.never;
  WalletLoadState get walletLoadState => _walletLoadState;

  List<WalletListItemBase> _walletItemList = [];
  List<WalletListItemBase> get walletItemList => walletItemListNotifier.value;

  int gapLimit = 20;

  final AddressRepository _addressRepository;
  final TransactionRepository _transactionRepository;
  final UtxoRepository _utxoRepository;
  final WalletRepository _walletRepository;

  late final PreferenceProvider _preferenceProvider;

  late final Future<void> Function(int) _saveWalletCount;

  late final ValueNotifier<WalletLoadState> walletLoadStateNotifier;
  late final ValueNotifier<List<WalletListItemBase>> walletItemListNotifier;
  late final ValueNotifier<BlockTimestamp?> currentBlockHeightNotifier;

  void _setWalletItemList(List<WalletListItemBase> value) {
    _walletItemList = value;
    walletItemListNotifier.value = value;
  }

  WalletProvider(
    this._addressRepository,
    this._transactionRepository,
    this._utxoRepository,
    this._walletRepository,
    Future<void> Function(int) saveWalletCount,
    this._preferenceProvider,
  ) : _saveWalletCount = saveWalletCount {
    // ValueNotifier들 초기화
    walletLoadStateNotifier = ValueNotifier(_walletLoadState);
    walletItemListNotifier = ValueNotifier(_walletItemList);
    currentBlockHeightNotifier = ValueNotifier(null);

    _loadWalletListFromDB().then((_) {
      _preferenceProvider.setWalletPreferences(walletItemList); // 이전 버전에서의 지갑목록과 충돌을 없애기 위한 초기화
      notifyListeners();
    });
  }

  Future<void> _loadWalletListFromDB() async {
    // 두 번 이상 호출 될 필요 없는 함수
    assert(_walletLoadState == WalletLoadState.never);

    _walletLoadState = WalletLoadState.loadingFromDB;
    walletLoadStateNotifier.value = _walletLoadState;

    try {
      _setWalletItemList(await _fetchWalletListFromDB());
      _walletLoadState = WalletLoadState.loadCompleted;

      walletLoadStateNotifier.value = _walletLoadState;
    } catch (e) {
      Logger.log('--> _loadWalletListFromDB error: $e');
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

  Future<void> addToWalletOrder(int walletId) async {
    final walletOrder = _preferenceProvider.walletOrder.toList();
    if (!walletOrder.contains(walletId)) {
      walletOrder.add(walletId);

      await _preferenceProvider.setWalletOrder(walletOrder);
    }
  }

  Future<void> addToFavoriteWalletsUntilFive(int walletId) async {
    final favoriteWallets = _preferenceProvider.favoriteWalletIds.toList();

    // 즐겨찾기된 지갑이 5개이상이면 등록안함
    if (favoriteWallets.length < kMaxStarLenght && !favoriteWallets.contains(walletId)) {
      favoriteWallets.add(walletId);
      await _preferenceProvider.setFavoriteWalletIds(favoriteWallets);
    }
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
          walletId: _walletItemList[index].id,
        );
      }
      // case 3
      result = WalletSyncResult.existingWalletNoUpdate;

      // case 2: 변경 사항 체크하며 업데이트
      if (_hasChangedOfUI(_walletItemList[index], watchOnlyWallet)) {
        _walletRepository.updateWalletUI(_walletItemList[index].id, watchOnlyWallet);

        // 업데이트된 지갑 목록 가져오기
        _setWalletItemList(await _fetchWalletListFromDB());
        result = WalletSyncResult.existingWalletUpdated;
        notifyListeners();
      }
      return ResultOfSyncFromVault(result: result, walletId: _walletItemList[index].id);
    }

    // 새 지갑 추가
    final sameNameIndex = _walletItemList.indexWhere((element) => element.name == watchOnlyWallet.name);
    if (sameNameIndex != -1) {
      // case 4: 동일 이름 존재
      return ResultOfSyncFromVault(result: WalletSyncResult.existingName);
    }

    // case 1: 새 지갑 생성
    var newWallet = await _addNewWallet(watchOnlyWallet, isMultisig);

    Logger.log('--> syncFromCoconutVault:::::: ${_walletItemList.map((e) => e.id).toList()}');

    if (result == WalletSyncResult.newWalletAdded) {
      _handleNewWalletAdded(newWallet.id);
    }

    return ResultOfSyncFromVault(result: result, walletId: newWallet.id);
  }

  /// TODO: 추후 멀티시그지갑 descriptor 추가 가능해 진 후 함수 변경 필요
  Future<ResultOfSyncFromVault> syncFromThirdParty(WatchOnlyWallet watchOnlyWallet) async {
    final sameNameIndex = _walletItemList.indexWhere((element) => element.name == watchOnlyWallet.name);
    assert(sameNameIndex == -1);

    WalletSyncResult result = WalletSyncResult.newWalletAdded;

    final index = _findSameWalletIndex(watchOnlyWallet.descriptor, isMultisig: false);

    if (index != -1) {
      return ResultOfSyncFromVault(
        result: WalletSyncResult.existingWalletUpdateImpossible,
        walletId: _walletItemList[index].id,
      );
    }
    // case 1: 새 지갑 생성
    bool isMultisig = watchOnlyWallet.signers != null;
    var newWallet = await _addNewWallet(watchOnlyWallet, isMultisig);

    if (result == WalletSyncResult.newWalletAdded) {
      _handleNewWalletAdded(newWallet.id);
    }

    return ResultOfSyncFromVault(result: result, walletId: newWallet.id);
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
    updatedList.add(newItem); // 새로 추가된 지갑을 후순으로 변경 -> 대표 지갑 변경되는걸 막기 위함
    _setWalletItemList(updatedList);

    _saveWalletCount(updatedList.length);
    return newItem;
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
    await _walletRepository.deleteWallet(walletId);
    _setWalletItemList(await _fetchWalletListFromDB());
    _saveWalletCount(_walletItemList.length);
    await _preferenceProvider.removeWalletOrder(walletId);
    await _preferenceProvider.removeFavoriteWalletId(walletId);
    await _preferenceProvider.removeExcludedFromTotalBalanceWalletId(walletId);
    await _preferenceProvider.removeManualUtxoSelectionWalletId(walletId);
    if (_walletItemList.isEmpty) {
      await _preferenceProvider.changeIsBalanceHidden(false); // 잔액 숨기기 비활성화, fakeBalance 초기화
      await _preferenceProvider.clearFakeBalanceTotalAmount();
      await _preferenceProvider.toggleFakeBalanceActivation(false);
    } else if (_preferenceProvider.isFakeBalanceActive) {
      final fakeBalanceTotalSats = _preferenceProvider.fakeBalanceTotalAmount;
      await _preferenceProvider.distributeFakeBalance(
        _walletItemList,
        isFakeBalanceActive: true,
        fakeBalanceTotalSats: fakeBalanceTotalSats?.toDouble(),
      );
    }

    notifyListeners();
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
      walletItemList[index].walletImportSource.name,
    );
    _walletRepository.updateWalletUI(id, watchOnlyWallet);
    _setWalletItemList(await _fetchWalletListFromDB());

    notifyListeners();
  }

  Balance getWalletBalance(int walletId) {
    // 간헐적으로 이미 삭제된 지갑의 balance를 불러오려고 하는 경우가 있음(성능 차이)
    if (walletItemList.firstWhereOrNull((w) => w.id == walletId) == null) {
      return Balance(0, 0);
    }

    final realmBalance = _walletRepository.getWalletBalance(walletId);
    return Balance(realmBalance.confirmed, realmBalance.unconfirmed);
  }

  Future<List<WalletAddress>> getWalletAddressList(
    WalletListItemBase wallet,
    int cursor,
    int count,
    bool isChange,
    bool showOnlyUnusedAddresses,
  ) async {
    return _addressRepository.getWalletAddressList(wallet, cursor, count, isChange, showOnlyUnusedAddresses);
  }

  List<WalletAddress> searchWalletAddressList(WalletListItemBase wallet, String keyword) {
    return _addressRepository.searchWalletAddressList(wallet, keyword);
  }

  (int, int) getGeneratedIndexes(WalletListItemBase wallet) {
    return _addressRepository.getGeneratedAddressIndexes(wallet);
  }

  WalletAddress generateAddress(WalletBase wallet, int index, bool isChange) {
    return _addressRepository.generateAddress(wallet, index, isChange);
  }

  bool containsAddress(int walletId, String address, {bool? isChange}) {
    return _addressRepository.containsAddress(walletId, address, isChange: isChange);
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

  Map<int, WalletAddress> getReceiveAddressMap() {
    return _addressRepository.getReceiveAddressMap();
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

  Map<int, List<TransactionRecord>> getPendingAndDaysAgoTransactions(List<int> walletIds, int days) {
    Map<int, List<TransactionRecord>> result = {};

    // end = 지금, start = N일 전 (로컬 시간 기준)
    final DateTime end = DateTime.now();
    final DateTime start = end.subtract(Duration(days: days));
    final dateRange = Tuple2<DateTime, DateTime>(start, end);

    for (int walletId in walletIds) {
      final pendingTxs = _transactionRepository.getUnconfirmedTransactionRecordList(walletId);
      final confirmedTxs = getConfirmedTransactionRecordListWithinDateRange([walletId], dateRange);

      if (pendingTxs.isNotEmpty || confirmedTxs.isNotEmpty) {
        result.addAll({
          walletId: [...pendingTxs, ...confirmedTxs],
        });
      }
    }

    return result;
  }

  List<TransactionRecord> getConfirmedTransactionRecordListWithinDateRange(
    List<int> walletIds,
    Tuple2<DateTime, DateTime> dateRange,
  ) {
    List<TransactionRecord> result = [];
    for (int walletId in walletIds) {
      final transactions = _transactionRepository.getTransactionRecordListWithDateRange(walletId, dateRange);
      // confirmed 트랜잭션만 필터링 (blockHeight > 0)
      final confirmedTransactions = transactions.where((tx) => tx.blockHeight > 0).toList();
      result.addAll(confirmedTransactions);
    }

    return result;
  }

  UtxoState? getUtxoState(int walletId, String utxoId) {
    return _utxoRepository.getUtxoState(walletId, utxoId);
  }

  TransactionRecord? getTransactionRecord(int walletId, String transactionHash) {
    return _transactionRepository.getTransactionRecord(walletId, transactionHash);
  }

  Future<void> toggleUtxoLockStatus(int walletId, String utxoId) async {
    final result = await _utxoRepository.toggleUtxoLockStatus(walletId, utxoId);
    if (result.isFailure) {
      throw result.error;
    }
  }

  Future<void> updateUtxoStatus(int walletId, List<String> utxoList, UtxoStatus status) async {
    return _utxoRepository.updateUtxoStatus(walletId, utxoList, status);
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

  void setCurrentBlockHeight(BlockTimestamp? blockHeight) {
    currentBlockHeightNotifier.value = blockHeight;
  }

  /// 새 지갑이 추가되었을 때 처리하는 함수(가짜 잔액 재분배, 즐겨찾기, 지갑 순서 추가)
  Future<void> _handleNewWalletAdded(int walletId) async {
    // 가짜 잔액 활성화 상태라면 재분배 작업 수행
    if (_preferenceProvider.isFakeBalanceActive) {
      final fakeBalanceTotalAmount = _preferenceProvider.fakeBalanceTotalAmount;
      await _preferenceProvider.distributeFakeBalance(
        _walletItemList,
        isFakeBalanceActive: true,
        fakeBalanceTotalSats: fakeBalanceTotalAmount?.toDouble(),
      );
    }

    // 지갑 순서 목록에 추가
    addToWalletOrder(walletId);

    // 5개 이하라면 즐겨찾기 목록에 추가
    addToFavoriteWalletsUntilFive(walletId);
  }

  @override
  void dispose() {
    // ValueNotifier들 해제
    walletLoadStateNotifier.dispose();
    walletItemListNotifier.dispose();
    currentBlockHeightNotifier.dispose();
    super.dispose();
  }
}

class ResultOfSyncFromVault {
  ResultOfSyncFromVault({required this.result, this.walletId});

  final WalletSyncResult result;
  final int? walletId; // 관련있는 지갑 id
}
