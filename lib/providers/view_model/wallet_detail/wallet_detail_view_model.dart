import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/api/error/default_error_response.dart';
import 'package:coconut_wallet/model/api/request/faucet_request.dart';
import 'package:coconut_wallet/model/api/response/faucet_response.dart';
import 'package:coconut_wallet/model/api/response/faucet_status_response.dart';
import 'package:coconut_wallet/model/app/faucet/faucet_history.dart';
import 'package:coconut_wallet/model/app/utxo/utxo.dart' as model;
import 'package:coconut_wallet/model/app/utxo/utxo_tag.dart';
import 'package:coconut_wallet/model/app/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/providers/transaction_provider.dart';
import 'package:coconut_wallet/providers/utxo_tag_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/repository/converter/transaction.dart';
import 'package:coconut_wallet/services/faucet_service.dart';
import 'package:coconut_wallet/services/shared_prefs_service.dart';
import 'package:coconut_wallet/utils/derivation_path_util.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/utils/utxo_util.dart';
import 'package:flutter/cupertino.dart';

class WalletDetailViewModel extends ChangeNotifier {
  static const int kMaxFaucetRequestCount = 3;
  final int _walletId;
  final WalletProvider _walletProvider;
  final TransactionProvider _txProvider;
  final UtxoTagProvider _tagProvider;

  final SharedPrefs _sharedPrefs = SharedPrefs();

  List<model.UTXO> _utxoList = [];

  WalletListItemBase? _walletListBaseItem;
  late WalletFeature _walletFeature;
  WalletType _walletType = WalletType.singleSignature;

  WalletInitState _prevWalletInitState = WalletInitState.never;
  bool _prevIsLatestTxBlockHeightZero = false;

  WalletInitState? _walletInitState;

  bool _isUtxoListLoadComplete = false;
  int? _prevTxCount;

  UtxoOrderEnum _selectedUtxoOrder = UtxoOrderEnum.byTimestampDesc;
  bool _faucetTooltipVisible = false;

  /// Faucet
  final Faucet _faucetService = Faucet();
  late AddressBook _walletAddressBook;
  late FaucetRecord _faucetRecord;

  String _walletAddress = '';
  String _derivationPath = '';

  String _walletName = '';
  String _receiveAddressIndex = '';

  double _requestAmount = 0.0;
  int _requestCount = 0;

  /// faucet 상태 조회 후 수령할 수 있는 최댓값과 최솟값
  double _faucetMaxAmount = 0;
  double _faucetMinAmount = 0;

  bool _isFaucetRequestLimitExceeded = false; // Faucet 요청가능 횟수 초과 여부
  bool _isRequesting = false;

  WalletDetailViewModel(this._walletId, this._walletProvider, this._txProvider,
      this._tagProvider) {
    // 지갑 상세 초기화
    _prevWalletInitState = _walletProvider.walletInitState;
    _walletInitState = _walletProvider.walletInitState;
    final walletBaseItem = _walletProvider.getWalletById(_walletId);
    _walletListBaseItem = walletBaseItem;
    _walletFeature = walletBaseItem.walletFeature;

    _prevTxCount = walletBaseItem.txCount;
    _prevIsLatestTxBlockHeightZero = walletBaseItem.isLatestTxBlockHeightZero;
    _walletType = walletBaseItem.walletType;

    if (_walletProvider.walletInitState == WalletInitState.finished) {
      getUtxoListWithHoldingAddress();
    }

    _txProvider.initTxList(_walletId);
    _tagProvider.initTagList(_walletId);

    // Faucet
    Address receiveAddress = walletBaseItem.walletBase.getReceiveAddress();
    _walletAddress = receiveAddress.address;
    _derivationPath = receiveAddress.derivationPath;
    _walletName = walletBaseItem.name.length > 20
        ? '${walletBaseItem.name.substring(0, 17)}...'
        : walletBaseItem.name; // FIXME 지갑 이름 최대 20자로 제한, 이 코드 필요 없음
    _receiveAddressIndex = receiveAddress.derivationPath.split('/').last;
    _walletAddressBook = walletBaseItem.walletBase.addressBook;
    _faucetRecord = _sharedPrefs.getFaucetHistoryWithId(_walletId);
    _checkFaucetRecord();
    _getFaucetStatus();

    showFaucetTooltip();
  }

  List<TransferDTO> get txList => _txProvider.txList;
  bool get isUpdatedTagList => _tagProvider.isUpdatedTagList;
  List<UtxoTag> get selectedTagList => _tagProvider.selectedTagList;

  List<model.UTXO> get utxoList => _utxoList;

  String get derivationPath => _derivationPath;
  bool get faucetTooltipVisible => _faucetTooltipVisible;

  bool get isFaucetRequestLimitExceeded => _isFaucetRequestLimitExceeded;
  bool get isRequesting => _isRequesting;

  bool get isUtxoListLoadComplete => _isUtxoListLoadComplete;
  String get receiveAddressIndex => _receiveAddressIndex;

  double get requestAmount => _requestAmount;
  UtxoOrderEnum get selectedUtxoOrder => _selectedUtxoOrder;

  String get walletAddress => _walletAddress;

  AddressBook get walletAddressBook => _walletAddressBook;
  WalletInitState? get walletInitState => _walletInitState;

  WalletListItemBase? get walletListBaseItem => _walletListBaseItem;
  String get walletName => _walletName;

  WalletProvider? get walletProvider => _walletProvider;
  WalletType get walletType => _walletType;

  void updateProvider() async {
    if (_prevWalletInitState != WalletInitState.finished &&
        _walletProvider.walletInitState == WalletInitState.finished) {
      _checkTxCount();
      getUtxoListWithHoldingAddress();
    }
    _prevWalletInitState = _walletProvider.walletInitState;

    if (_faucetRecord.count >= kMaxFaucetRequestCount) {
      _isFaucetRequestLimitExceeded =
          _faucetRecord.count >= kMaxFaucetRequestCount;
    }

    try {
      final WalletListItemBase walletListItemBase =
          _walletProvider.getWalletById(_walletId);
      _walletAddress =
          walletListItemBase.walletBase.getReceiveAddress().address;

      /// 다음 Faucet 요청 수량 계산 1 -> 0.00021 -> 0.00021
      _requestCount = _faucetRecord.count;
      if (_requestCount == 0) {
        _requestAmount = _faucetMaxAmount;
      } else if (_requestCount <= 2) {
        _requestAmount = _faucetMinAmount;
      }
    } catch (e) {}

    notifyListeners();
  }

  void getUtxoListWithHoldingAddress() {
    List<model.UTXO> utxos = [];

    if (_walletFeature.walletStatus?.utxoList.isNotEmpty == true) {
      for (var utxo in _walletFeature.walletStatus!.utxoList) {
        String ownedAddress = _walletListBaseItem!.walletBase.getAddress(
            DerivationPathUtil.getAccountIndex(
                _walletType, utxo.derivationPath),
            isChange: DerivationPathUtil.getChangeElement(
                    _walletType, utxo.derivationPath) ==
                1);

        final tags =
            _tagProvider.loadSelectedUtxoTagList(_walletId, utxo.utxoId);

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
    model.UTXO.sortUTXO(_utxoList, _selectedUtxoOrder);
  }

  void updateUtxoTagList(String utxoId, List<UtxoTag> utxoTagList) {
    final findUtxo = utxoList.firstWhere((item) => item.utxoId == utxoId);
    findUtxo.tags?.clear();
    findUtxo.tags?.addAll(utxoTagList);
    notifyListeners();
  }

  WalletStatus? getInitializedWalletStatus() {
    try {
      return _walletFeature.walletStatus;
    } catch (e) {
      return null;
    }
  }

  void removeFaucetTooltip() {
    _faucetTooltipVisible = false;
    notifyListeners();
  }

  Future<void> requestTestBitcoin(
      String address, Function(bool, String) onResult) async {
    _isRequesting = true;
    notifyListeners();

    try {
      final response = await _faucetService
          .getTestCoin(FaucetRequest(address: address, amount: _requestAmount));
      if (response is FaucetResponse) {
        onResult(true, '테스트 비트코인을 요청했어요. 잠시만 기다려 주세요.');
        _updateFaucetRecord();
      } else if (response is DefaultErrorResponse &&
          response.error == 'TOO_MANY_REQUEST_FAUCET') {
        onResult(false, '해당 주소로 이미 요청했습니다. 입금까지 최대 5분이 걸릴 수 있습니다.');
      } else {
        onResult(false, '요청에 실패했습니다. 잠시 후 다시 시도해 주세요.');
      }
    } catch (e) {
      // Error handling
      onResult(false, '요청에 실패했습니다. 잠시 후 다시 시도해 주세요.');
    } finally {
      _isRequesting = false;
      notifyListeners();
    }
  }

  /// Faucet methods
  void showFaucetTooltip() async {
    final faucetHistory = _sharedPrefs.getFaucetHistoryWithId(_walletId);
    if (_walletListBaseItem!.balance == 0 && faucetHistory.count < 3) {
      _faucetTooltipVisible = true;
    }
    notifyListeners();
  }

  void updateUtxoFilter(UtxoOrderEnum selectedUtxoFilter) async {
    _selectedUtxoOrder = selectedUtxoFilter;
    model.UTXO.sortUTXO(_utxoList, selectedUtxoFilter);
    notifyListeners();
  }

  void _checkFaucetRecord() {
    if (!_faucetRecord.isToday) {
      // 오늘 처음 요청
      _initFaucetRecord();
      _saveFaucetRecordToSharedPrefs();
      return;
    }

    if (_faucetRecord.count >= kMaxFaucetRequestCount) {
      _isFaucetRequestLimitExceeded =
          _faucetRecord.count >= kMaxFaucetRequestCount;
      notifyListeners();
    }
  }

  void _checkTxCount() {
    final txCount = _walletListBaseItem!.txCount;
    final isLatestTxBlockHeightZero =
        _walletListBaseItem!.isLatestTxBlockHeightZero;
    Logger.log('--> prevTxCount: $_prevTxCount, wallet.txCount: $txCount');
    Logger.log(
        '--> prevIsZero: $_prevIsLatestTxBlockHeightZero, wallet.isZero: $isLatestTxBlockHeightZero');

    /// _walletListItem의 txCount, isLatestTxBlockHeightZero가 변경되었을 때만 트랜잭션 목록 업데이트
    if (_prevTxCount != txCount ||
        _prevIsLatestTxBlockHeightZero != isLatestTxBlockHeightZero) {
      _txProvider.initTxList(_walletId);
    }
    _prevTxCount = txCount;
    _prevIsLatestTxBlockHeightZero = isLatestTxBlockHeightZero;
  }

  Future<void> _getFaucetStatus() async {
    try {
      final response = await _faucetService.getStatus();
      if (response is FaucetStatusResponse) {
        // _isLoading = false;
        _faucetMaxAmount = response.maxLimit;
        _faucetMinAmount = response.minLimit;
        _requestCount = _faucetRecord.count;
        if (_requestCount == 0) {
          _requestAmount = _faucetMaxAmount;
        } else if (_requestCount <= 2) {
          _requestAmount = _faucetMinAmount;
        }
      }
    } finally {
      notifyListeners();
    }
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

  void _updateFaucetRecord() {
    _checkFaucetRecord();

    int count = _faucetRecord.count;
    int dateTime = DateTime.now().millisecondsSinceEpoch;
    _faucetRecord =
        _faucetRecord.copyWith(dateTime: dateTime, count: count + 1);
    _requestCount++;
    _saveFaucetRecordToSharedPrefs();
  }
}
