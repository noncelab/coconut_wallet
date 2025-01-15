import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/api/error/default_error_response.dart';
import 'package:coconut_wallet/model/api/request/faucet_request.dart';
import 'package:coconut_wallet/model/api/response/faucet_response.dart';
import 'package:coconut_wallet/model/api/response/faucet_status_response.dart';
import 'package:coconut_wallet/model/app/faucet/faucet_history.dart';
import 'package:coconut_wallet/model/app/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/providers/app_state_model.dart';
import 'package:coconut_wallet/repository/converter/transaction.dart';
import 'package:coconut_wallet/services/faucet_service.dart';
import 'package:coconut_wallet/services/shared_prefs_service.dart';
import 'package:coconut_wallet/utils/cconut_wallet_util.dart';
import 'package:coconut_wallet/utils/derivation_path_util.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/utils/utxo_util.dart';
import 'package:flutter/cupertino.dart';
import 'package:coconut_wallet/model/app/utxo/utxo.dart' as model;

class WalletDetailViewModel extends ChangeNotifier {
  static const int kMaxRequestCount = 3;
  final int _walletId;
  WalletDetailViewModel(this._walletId);

  /// Common variables ---------------------------------------------------------
  final SharedPrefs _sharedPrefs = SharedPrefs();

  /// Wallet detail variables --------------------------------------------------
  late WalletListItemBase _walletListBaseItem;
  WalletListItemBase get walletListBaseItem => _walletListBaseItem;

  late WalletFeature _walletFeature;

  WalletType _walletType = WalletType.singleSignature;
  WalletType get walletType => _walletType;

  WalletInitState _prevWalletInitState = WalletInitState.never;
  bool _prevIsLatestTxBlockHeightZero = false;

  bool _isUtxoListLoadComplete = false;
  bool get isUtxoListLoadComplete => _isUtxoListLoadComplete;

  int? _prevTxCount;

  List<TransferDTO> _txList = [];
  List<TransferDTO> get txList => _txList;

  List<model.UTXO> _utxoList = [];
  List<model.UTXO> get utxoList => _utxoList;

  UtxoOrderEnum _selectedFilter = UtxoOrderEnum.byTimestampDesc; // 초기 정렬 방식
  UtxoOrderEnum get selectedFilter => _selectedFilter;

  bool _faucetTipVisible = false;
  bool get faucetTipVisible => _faucetTipVisible;

  bool _faucetTooltipVisible = false;
  bool get faucetTooltipVisible => _faucetTooltipVisible;

  /// Faucet variables ---------------------------------------------------------
  final Faucet _faucetService = Faucet();
  late AddressBook _walletAddressBook;
  AddressBook get walletAddressBook => _walletAddressBook;
  late FaucetRecord _faucetRecord;

  String _walletAddress = '';
  String get walletAddress => _walletAddress;

  String _walletName = '';
  String get walletName => _walletName;

  String _walletIndex = '';
  String get walletIndex => _walletIndex;

  double _requestAmount = 0.0;
  double get requestAmount => _requestAmount;

  int _requestCount = 0;

  // TODO: 검증 필요
  // bool _isErrorInServerStatus = false;
  // bool get isErrorInServerStatus => _isErrorInServerStatus;

  bool _isErrorInRemainingTime = false;
  bool get isErrorInRemainingTime => _isErrorInRemainingTime;

  bool _isRequesting = false;
  bool get isRequesting => _isRequesting;

  /// Common Methods -----------------------------------------------------------
  AppStateModel? _appStateModel;
  void appStateModelListener(AppStateModel appStateModel) async {
    // initialize
    if (_appStateModel == null) {
      _appStateModel = appStateModel;
      _prevWalletInitState = appStateModel.walletInitState;
      final walletBaseItem = appStateModel.getWalletById(_walletId);
      _walletListBaseItem = walletBaseItem;
      _walletFeature = getWalletFeatureByWalletType(walletBaseItem);
      _prevTxCount = walletBaseItem.txCount;
      _prevIsLatestTxBlockHeightZero = walletBaseItem.isLatestTxBlockHeightZero;
      _walletType = walletBaseItem.walletType;

      if (appStateModel.walletInitState == WalletInitState.finished) {
        getUtxoListWithHoldingAddress();
      }
      _txList = appStateModel.getTxList(_walletId) ?? [];

      /// Faucet
      Address receiveAddress = walletBaseItem.walletBase.getReceiveAddress();
      _walletAddress = receiveAddress.address;
      _walletName = walletBaseItem.name.length > 20
          ? '${walletBaseItem.name.substring(0, 17)}...'
          : walletBaseItem.name; // FIXME 지갑 이름 최대 20자로 제한, 이 코드 필요 없음
      _walletIndex = receiveAddress.derivationPath.split('/').last;
      _walletAddressBook = walletBaseItem.walletBase.addressBook;
      _faucetRecord = _sharedPrefs.getFaucetHistoryWithId(_walletId);
      _checkFaucetRecord();
      _getFaucetStatus();

      showFaucetTooltip();
    }
    // _stateListener
    else {
      if (_prevWalletInitState != WalletInitState.finished &&
          appStateModel.walletInitState == WalletInitState.finished) {
        _checkTxCount();
        getUtxoListWithHoldingAddress();
      }
      _prevWalletInitState = appStateModel.walletInitState;
      notifyListeners();
    }
  }

  /// Wallet detail methods ----------------------------------------------------
  void getUtxoListWithHoldingAddress() {
    List<model.UTXO> utxos = [];

    if (_walletFeature.walletStatus?.utxoList.isNotEmpty == true) {
      for (var utxo in _walletFeature.walletStatus!.utxoList) {
        String ownedAddress = _walletListBaseItem.walletBase.getAddress(
            DerivationPathUtil.getAccountIndex(
                _walletType, utxo.derivationPath),
            isChange: DerivationPathUtil.getChangeElement(
                    _walletType, utxo.derivationPath) ==
                1);

        final tags = _appStateModel?.loadUtxoTagListByTxHashIndex(
            _walletId, utxo.utxoId);

        utxos.add(model.UTXO(
          utxo.timestamp.toString(),
          utxo.blockHeight.toString(),
          utxo.amount,
          ownedAddress,
          utxo.derivationPath,
          utxo.transactionHash,
          utxo.index,
          tags: tags,
        ));
      }
    }

    _isUtxoListLoadComplete = true;
    _utxoList = utxos;
    model.UTXO.sortUTXO(_utxoList, _selectedFilter);
  }

  void updateUtxoFilter(UtxoOrderEnum orderEnum) async {
    _selectedFilter = orderEnum;
    model.UTXO.sortUTXO(_utxoList, orderEnum);
    notifyListeners();
  }

  void _checkTxCount() {
    final txCount = _walletListBaseItem.txCount;
    final isLatestTxBlockHeightZero =
        _walletListBaseItem.isLatestTxBlockHeightZero;
    Logger.log('--> prevTxCount: $_prevTxCount, wallet.txCount: $txCount');
    Logger.log(
        '--> prevIsZero: $_prevIsLatestTxBlockHeightZero, wallet.isZero: $isLatestTxBlockHeightZero');

    /// _walletListItem의 txCount, isLatestTxBlockHeightZero가 변경되었을 때만 트랜잭션 목록 업데이트
    if (_prevTxCount != txCount ||
        _prevIsLatestTxBlockHeightZero != isLatestTxBlockHeightZero) {
      List<TransferDTO>? newTxList = _appStateModel?.getTxList(_walletId);
      if (newTxList != null) {
        _txList = newTxList;
      }
    }
    _prevTxCount = txCount;
    _prevIsLatestTxBlockHeightZero = isLatestTxBlockHeightZero;
  }

  /// Faucet methods -----------------------------------------------------------
  void showFaucetTooltip() async {
    final faucetHistory = _sharedPrefs.getFaucetHistoryWithId(_walletId);
    if (_walletListBaseItem.balance == 0 && faucetHistory.count < 3) {
      _faucetTooltipVisible = true;
      await Future.delayed(const Duration(milliseconds: 500));
      _faucetTipVisible = true;
    }
    notifyListeners();
  }

  void removeFaucetTooltip() {
    _faucetTipVisible = false;
    _faucetTooltipVisible = false;
    notifyListeners();
  }

  void _checkFaucetRecord() {
    if (!_faucetRecord.isToday) {
      // 오늘 처음 요청
      _initFaucetRecord();
      _saveFaucetRecordToSharedPrefs();
      return;
    }

    if (_faucetRecord.count == kMaxRequestCount) {
      _isErrorInRemainingTime = _faucetRecord.count == kMaxRequestCount;
      notifyListeners();
    }
  }

  Future<void> requestTestBitcoin(
      String address, Function(bool, String) onResult) async {
    _isRequesting = true;
    notifyListeners();

    try {
      final response = await _faucetService
          .getTestCoin(FaucetRequest(address: address, amount: _requestAmount));
      if (response is FaucetResponse) {
        _isErrorInRemainingTime = false;
        onResult(true, '테스트 비트코인을 요청했어요. 잠시만 기다려 주세요.');
        _updateFaucetRecord();
      } else if (response is DefaultErrorResponse &&
          response.error == 'TOO_MANY_REQUEST_FAUCET') {
        _isErrorInRemainingTime = true;
        onResult(false, '해당 주소로 이미 요청했습니다. 입금까지 최대 5분이 걸릴 수 있습니다.');
      } else {
        _isErrorInRemainingTime = true;
        onResult(false, '요청에 실패했습니다. 잠시 후 다시 시도해 주세요.');
      }
    } catch (e) {
      // Error handling
      _isErrorInRemainingTime = true;
      onResult(false, '요청에 실패했습니다. 잠시 후 다시 시도해 주세요.');
    } finally {
      _isRequesting = false;
      notifyListeners();
    }
  }

  void _updateFaucetRecord() {
    _checkFaucetRecord();

    int count = _faucetRecord.count;
    int dateTime = DateTime.now().millisecondsSinceEpoch;
    _faucetRecord =
        _faucetRecord.copyWith(dateTime: dateTime, count: count + 1);
    _saveFaucetRecordToSharedPrefs();
  }

  void _initFaucetRecord() {
    _faucetRecord = FaucetRecord(
        id: _walletId,
        dateTime: DateTime.now().millisecondsSinceEpoch,
        count: 0);
  }

  void _saveFaucetRecordToSharedPrefs() {
    Logger.log('_checkFaucetHistory(): $_faucetRecord');
    _sharedPrefs.saveFaucetHistory(_faucetRecord);
  }

  Future<void> _getFaucetStatus() async {
    try {
      final response = await _faucetService.getStatus();
      if (response is FaucetStatusResponse) {
        // _isLoading = false;
        _requestCount = _faucetRecord.count;
        if (_requestCount == 0) {
          _requestAmount = response.maxLimit;
        } else if (_requestCount <= 2) {
          _requestAmount = response.minLimit;
        }
      }
    } catch (_) {
      // setErrorInStatus(true);
    } finally {
      notifyListeners();
    }
  }

  // TODO: 검증 필요
  // void setErrorInStatus(bool statusValue) {
  //   _isErrorInServerStatus = statusValue;
  // }
}
