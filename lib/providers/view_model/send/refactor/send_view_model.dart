import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/constants/bitcoin_network_rules.dart';
import 'package:coconut_wallet/core/transaction/transaction_builder.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/enums/transaction_enums.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/extensions/double_extensions.dart';
import 'package:coconut_wallet/extensions/int_extensions.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/send/fee_info.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/wallet/transaction_draft.dart';
import 'package:coconut_wallet/model/wallet/wallet_address.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/repository/realm/transaction_draft_repository.dart';
import 'package:coconut_wallet/repository/realm/utxo_repository.dart';
import 'package:coconut_wallet/repository/realm/wallet_preferences_repository.dart';
import 'package:coconut_wallet/screens/send/refactor/send_screen.dart';
import 'package:coconut_wallet/services/fee_service.dart';
import 'package:coconut_wallet/utils/address_util.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/utils/vibration_util.dart';
import 'package:coconut_wallet/utils/wallet_util.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

typedef WalletInfoUpdateCallback =
    void Function(WalletListItemBase walletItem, List<UtxoState> selectedUtxoList, bool isUtxoSelectionAuto);

enum AddressError {
  none,
  invalid,
  invalidNetworkAddress,
  duplicated;

  bool get isError => this != AddressError.none;
  bool get isNotError => this == AddressError.none;

  String getMessage() {
    switch (this) {
      case AddressError.invalid:
        return t.errors.address_error.invalid;
      case AddressError.duplicated:
        return t.errors.address_error.duplicated;
      case AddressError.invalidNetworkAddress:
        {
          if (NetworkType.currentNetworkType == NetworkType.testnet) {
            return t.errors.address_error.not_for_testnet;
          } else if (NetworkType.currentNetworkType == NetworkType.mainnet) {
            return t.errors.address_error.not_for_mainnet;
          } else if (NetworkType.currentNetworkType == NetworkType.regtest) {
            return t.errors.address_error.not_for_regtest;
          } else {
            throw "Unknown network type";
          }
        }
      case AddressError.none:
        return "";
    }
  }
}

enum AmountError {
  none,
  insufficientBalance,
  minimumAmount;

  bool get isError => this != AmountError.none;
  bool get isNotError => this == AmountError.none;

  String getMessage(BitcoinUnit currentUnit) {
    switch (this) {
      case AmountError.insufficientBalance:
        return t.errors.insufficient_balance;
      case AmountError.minimumAmount:
        return t.alert.error_send.minimum_amount(
          bitcoin:
              currentUnit == BitcoinUnit.btc
                  ? UnitUtil.convertSatoshiToBitcoin(dustLimit + 1)
                  : (dustLimit + 1).toThousandsSeparatedString(),
          unit: currentUnit.symbol,
        );
      case AmountError.none:
        return "";
    }
  }
}

class SendViewModel extends ChangeNotifier {
  final WalletProvider _walletProvider;
  final SendInfoProvider _sendInfoProvider;
  final PreferenceProvider _preferenceProvider;
  final TransactionDraftRepository _transactionDraftRepository;
  final WalletPreferencesRepository _walletPreferencesRepository;
  final UtxoRepository _utxoRepository;

  // send_screen: _amountController, _feeRateController, _recipientPageController
  final Function(String) _onAmountTextUpdate;
  final Function(String) _onFeeRateTextUpdate;
  final Function(int) _onRecipientPageDeleted;

  bool _isMaxMode = false;
  bool get isMaxMode => _isMaxMode;
  bool get isBatchMode => recipientList.length >= 2;

  // 수신자 정보
  List<RecipientInfo> _recipientList = [];
  List<RecipientInfo> get recipientList => _recipientList;

  int _currentIndex = 0;
  int get currentIndex => _currentIndex;
  int get lastIndex => _recipientList.length - 1;
  int get addRecipientCardIndex => _recipientList.length;

  bool _showAddressBoard = false;
  bool get showAddressBoard => _showAddressBoard;

  int _amountSum = 0;
  String get amountSumText => _currentUnit.displayBitcoinAmount(_amountSum, withUnit: true);

  WalletListItemBase? _selectedWalletItem;
  bool _isUtxoSelectionAuto = true;

  bool _isFeeSubtractedFromSendAmount = false;
  bool _previousIsFeeSubtractedFromSendAmount = false;
  bool get isFeeSubtractedFromSendAmount => _isFeeSubtractedFromSendAmount;

  List<UtxoState> _selectedUtxoList = [];
  List<UtxoState> get selectedUtxoList => _selectedUtxoList;
  int get selectedUtxoListLength => _selectedUtxoList.length;

  /// 사용자가 설정한 순서대로 정렬한 지갑 목록
  late List<WalletListItemBase> _orderedRegisteredWallets;
  List<WalletListItemBase> get orderedRegisteredWallets => _orderedRegisteredWallets;

  List<bool> _walletAddressNeedsUpdate = [];
  Map<int, WalletAddressInfo> _registeredWalletAddressMap = {};
  Map<int, WalletAddressInfo> get registeredWalletAddressMap => _registeredWalletAddressMap;

  WalletListItemBase? get selectedWalletItem => _selectedWalletItem;

  int get selectedWalletId => _selectedWalletItem != null ? _selectedWalletItem!.id : -1;
  bool get isUtxoSelectionAuto => _isUtxoSelectionAuto;

  RecommendedFeeFetchStatus _recommendedFeeFetchStatus = RecommendedFeeFetchStatus.fetching;
  RecommendedFeeFetchStatus get recommendedFeeFetchStatus => _recommendedFeeFetchStatus;

  List<FeeInfoWithLevel> feeInfos = [
    FeeInfoWithLevel(level: TransactionFeeLevel.fastest),
    FeeInfoWithLevel(level: TransactionFeeLevel.halfhour),
    FeeInfoWithLevel(level: TransactionFeeLevel.hour),
  ];

  TransactionBuilder? _txBuilder;
  String _feeRateText = "";
  String _changeAddressDerivationPath = "";

  int? _estimatedFee;
  int? get estimatedFeeInSats => _estimatedFee;
  double get _estimatedFeeByUnit {
    int estimatedFeeInInt = _estimatedFee ?? 0;
    return isBtcUnit ? UnitUtil.convertSatoshiToBitcoin(estimatedFeeInInt) : estimatedFeeInInt.toDouble();
  }

  bool _isFeeRateLowerThanMin = false;
  bool get isFeeRateLowerThanMin => _isFeeRateLowerThanMin;

  double? _minimumFeeRate;
  double? get minimumFeeRate => _minimumFeeRate;

  late bool? _isNetworkOn;
  late BitcoinUnit _currentUnit;
  int _confirmedBalance = 0;
  int _incomingBalance = 0;
  int selectedUtxoAmountSum = 0;

  int get balance {
    return isUtxoSelectionAuto ? _confirmedBalance : selectedUtxoAmountSum;
  }

  int get incomingBalance => _incomingBalance;

  AmountError _isAmountSumExceedsBalance = AmountError.none;
  AmountError _isLastAmountInsufficient = AmountError.none;

  String _finalErrorMessage = "";
  String get finalErrorMessage => _finalErrorMessage;

  bool get isTotalSendAmountExceedsBalance => _isAmountSumExceedsBalance.isError;
  bool get isLastAmountInsufficient => _isLastAmountInsufficient.isError;

  bool _showFeeBoard = false;
  bool get showFeeBoard => _showFeeBoard;

  bool get isBtcUnit => _currentUnit == BitcoinUnit.btc;
  BitcoinUnit get currentUnit => _currentUnit;
  bool get isSatsUnit => !isBtcUnit;

  bool get isNetworkOn => _isNetworkOn == true;
  num get _dustLimitDenominator => (isBtcUnit ? 1e8 : 1);
  bool get isAmountDisabled => _isMaxMode && _currentIndex == lastIndex;
  bool get isEstimatedFeeGreaterThanBalance => balance < (_estimatedFee ?? 0);
  bool get hasValidRecipient => validRecipientList.isNotEmpty;

  int? _unintendedDustFee;
  int? get unintendedDustFee => _unintendedDustFee;

  TransactionBuildResult? _txBuildResult;
  int? _transactionDraftId;

  List<RecipientInfo> get validRecipientList {
    return _recipientList
        .where(
          (e) =>
              e.address.isNotEmpty &&
              e.amount.isNotEmpty &&
              e.addressError.isNotError &&
              e.minimumAmountError.isNotError,
        )
        .toList();
  }

  Map<String, int> get recipientMap {
    final Map<String, int> recipientMap = {};
    for (final recipient in validRecipientList) {
      recipientMap[recipient.address] =
          (isBtcUnit ? UnitUtil.convertBitcoinToSatoshi(double.parse(recipient.amount)) : int.parse(recipient.amount));
    }
    return recipientMap;
  }

  double get _amountSumExceptLast {
    double sumExceptLast = 0;
    for (int i = 0; i < lastIndex; ++i) {
      if (_recipientList[i].amount.isNotEmpty) {
        sumExceptLast += double.parse(_recipientList[i].amount);
      }
    }
    return sumExceptLast.roundTo8Digits();
  }

  bool get isReadyToSend {
    if (_isAmountSumExceedsBalance.isError || _isLastAmountInsufficient.isError) {
      return false;
    }

    for (final recipient in _recipientList) {
      if (!recipient.isInputValid) {
        return false;
      }
    }

    if (_estimatedFee == null) {
      return false;
    }

    if ((double.tryParse(_feeRateText) ?? 0) < 0.1) {
      return false;
    }

    return true;
  }

  bool get isSelectedWalletNull => _selectedWalletItem == null;

  bool get canGoNext => !isWalletWithoutMfp(_selectedWalletItem) && isReadyToSend && _finalErrorMessage.isEmpty;

  /// 초기화를 비동기로 진행하므로 null이면 아직 초기화 완료 안된 것으로 판단.
  List<TransactionDraft>? _drafts;
  List<TransactionDraft>? get drafts => _drafts;
  bool? get hasDrafts => _drafts?.isNotEmpty;
  bool get isSaved => _transactionDraftId != null;

  bool isMaxModeLastIndex(int index) {
    return _isMaxMode && index == lastIndex;
  }

  bool isAmountInsufficient(int index) {
    if (index != lastIndex) return false;
    return _isMaxMode && _recipientList[index].amount == '0';
  }

  SendViewModel(
    this._walletProvider,
    this._sendInfoProvider,
    this._preferenceProvider,
    this._transactionDraftRepository,
    this._utxoRepository,
    this._walletPreferencesRepository,
    this._isNetworkOn,
    this._onAmountTextUpdate,
    this._onFeeRateTextUpdate,
    this._onRecipientPageDeleted,
    int? walletId,
    SendEntryPoint sendEntryPoint,
    this._transactionDraftId,
  ) {
    _sendInfoProvider.clear();
    _sendInfoProvider.setSendEntryPoint(sendEntryPoint);
    _currentUnit = _preferenceProvider.currentUnit;

    if (walletId != null) {
      final walletIndex = _walletProvider.walletItemList.indexWhere((e) => e.id == walletId);
      if (walletIndex != -1) _initializeWithSelectedWallet(walletIndex);

      _isUtxoSelectionAuto = !_walletPreferencesRepository.isManualUtxoSelection(walletId);

      // 수동 UTXO 선택 모드인 경우, 초기에는 선택된 UTXO가 없어야 함
      if (!_isUtxoSelectionAuto) {
        _selectedUtxoList = [];
        selectedUtxoAmountSum = 0;
      }
    }

    _recipientList = [RecipientInfo()];

    _initBalances();
    _setRecommendedFees().whenComplete(() {
      notifyListeners();
    });

    _loadDrafts();
  }

  List<WalletListItemBase> _getOrderedRegisteredWallets() {
    final walletList = _walletProvider.walletItemList;
    final order = _preferenceProvider.walletOrder;

    if (order.isEmpty) {
      return walletList;
    }

    return order.map((id) => walletList.firstWhere((e) => e.id == id)).toList();
  }

  void _initRegisteredWalletsAddress() {
    if (_selectedWalletItem == null) {
      return;
    }

    final selectedWalletId = _selectedWalletItem!.id;
    final walletAddressMap = _walletProvider.getReceiveAddressMap();
    final order = _preferenceProvider.walletOrder;
    assert(order.isNotEmpty);

    _registeredWalletAddressMap = {
      selectedWalletId: WalletAddressInfo(
        walletAddress: walletAddressMap[selectedWalletId]!,
        name: _selectedWalletItem!.name,
      ),
    };
    for (int i = 0; i < order.length; i++) {
      if (order[i] == selectedWalletId) continue;
      _registeredWalletAddressMap[order[i]] = WalletAddressInfo(
        walletAddress: walletAddressMap[order[i]]!,
        name: _orderedRegisteredWallets.firstWhere((e) => e.id == order[i]).name,
      );
    }

    _walletAddressNeedsUpdate = List.filled(_registeredWalletAddressMap.length, false);
  }

  void _initializeWithSelectedWallet(int index) {
    if (index == -1) return;
    if (_selectedWalletItem != null && _selectedWalletItem!.id == _walletProvider.walletItemList[index].id) return;

    _orderedRegisteredWallets = _getOrderedRegisteredWallets();
    _selectedWalletItem = _walletProvider.walletItemList[index];
    _initRegisteredWalletsAddress();
    _sendInfoProvider.setWalletId(_selectedWalletItem!.id);
    _changeAddressDerivationPath = _walletProvider.getChangeAddress(_selectedWalletItem!.id).derivationPath;

    // UTXO 자동 선택 모드이므로 전체 UTXO 리스트 설정
    _selectedUtxoList = _walletProvider.getUtxoList(_selectedWalletItem!.id);
    selectedUtxoAmountSum = _selectedUtxoList.fold<int>(0, (totalAmount, utxo) => totalAmount + utxo.amount);
  }

  void setSelectedUtxoList(List<UtxoState> list) {
    _selectedUtxoList = list;
    selectedUtxoAmountSum = _selectedUtxoList.fold<int>(0, (totalAmount, utxo) => totalAmount + utxo.amount);
    setIsUtxoSelectionAuto(false);
    notifyListeners();
  }

  void setIsUtxoSelectionAuto(bool value, {bool isFromPulldownMenu = false}) async {
    final wasAuto = _isUtxoSelectionAuto;
    _isUtxoSelectionAuto = value;

    // 자동 → 수동 전환 시
    if (wasAuto && !value) {
      // switch 버튼을 통해 전환한 경우 초기화
      // 앱 바를 통해 utxo 선택 후 _selectedUtxoList가 있을 때는 초기화하지 않음
      if (isFromPulldownMenu || _selectedUtxoList.isEmpty && selectedUtxoAmountSum == 0) {
        _selectedUtxoList = [];
        selectedUtxoAmountSum = 0;
      }
    }

    if (wasAuto != value) {
      if (_selectedWalletItem != null) {
        await _walletPreferencesRepository.toggleManualUtxoSelection(_selectedWalletItem!.id);
      }
    }
    notifyListeners();
  }

  /// TransactionDraft를 조회하고 UTXO 상태를 확인하여 반환
  /// 사용불가 UTXO는 제외하고 유효한 목록과 제외 상태를 함께 반환
  (TransactionDraft, List<UtxoState>, SelectedUtxoExcludedStatus?) _getDraft(int draftId) {
    assert(_selectedWalletItem != null);

    final draft = _transactionDraftRepository.getUnsignedTransactionDraft(draftId);
    if (draft == null) {
      throw StateError('Transaction draft not found: $draftId');
    }

    // UTXO 상태 확인 및 유효한 UTXO 목록 반환 (사용불가 UTXO 제외)
    final (validUtxoList, excludedStatus) = _utxoRepository.getValidatedSelectedUtxoList(
      _selectedWalletItem!.id,
      draft.selectedUtxoIds.toList(),
    );

    return (draft, validUtxoList, excludedStatus);
  }

  /// TransactionDraft를 로드하여 SendViewModel 상태에 반영
  /// 사용불가 UTXO가 제외된 경우 해당 상태를 반환 (토스트 표시용)
  SelectedUtxoExcludedStatus? loadTransactionDraft(int draftId) {
    final (draft, validatedUtxoList, excludedUtxoStatus) = _getDraft(draftId);

    // 1. 지갑 선택 및 초기화
    final walletIndex = _walletProvider.walletItemList.indexWhere((e) => e.id == draft.walletId);
    if (walletIndex == -1) return null;
    _initializeWithSelectedWallet(walletIndex);

    // 2. Draft ID 설정
    _sendInfoProvider.setUnsignedDraftId(draft.id);

    // 3. 비트코인 단위 설정 (수신자 금액 변환 전에 먼저 설정)
    if (draft.bitcoinUnit != null && draft.bitcoinUnit != _currentUnit) {
      _currentUnit = draft.bitcoinUnit!;
    }

    // 4. 수신자 목록 설정 (sats → 현재 단위 문자열로 변환)
    _recipientList =
        draft.recipients.map((r) {
          final amountStr =
              _currentUnit == BitcoinUnit.sats
                  ? r.amount.toString()
                  : UnitUtil.convertSatoshiToBitcoin(r.amount).toString();
          return RecipientInfo(address: r.address, amount: amountStr);
        }).toList();

    // 5. 수수료율 설정 (setFeeRateText 대신 직접 설정하여 _buildTransaction 중복 호출 방지)
    _feeRateText = draft.feeRate.toString();
    try {
      final feeRateValue = double.parse(_feeRateText);
      _isFeeRateLowerThanMin = _minimumFeeRate != null && feeRateValue < _minimumFeeRate!;
    } catch (e) {
      Logger.error(e);
      _isFeeRateLowerThanMin = false;
    }

    // 6. UTXO 선택 모드 및 목록 설정 (_getDraft에서 검증된 목록 활용)
    if (validatedUtxoList.isNotEmpty) {
      _isUtxoSelectionAuto = false;
      _selectedUtxoList = validatedUtxoList;
    } else if (excludedUtxoStatus != null) {
      _isUtxoSelectionAuto = false;
      _selectedUtxoList.clear();
    } else {
      _isUtxoSelectionAuto = true;
      _selectedUtxoList = _walletProvider.getUtxoList(draft.walletId);
    }
    selectedUtxoAmountSum = _selectedUtxoList.fold<int>(0, (totalAmount, utxo) => totalAmount + utxo.amount);

    // 7. 수수료 차감 설정
    _isFeeSubtractedFromSendAmount = draft.isFeeSubtractedFromSendAmount == true;

    // 8. 모두 보내기 모드 설정 (setMaxMode 대신 직접 설정하여 _buildTransaction 중복 호출 방지)
    _isMaxMode = draft.isMaxMode == true;
    if (_isMaxMode) {
      _previousIsFeeSubtractedFromSendAmount = _isFeeSubtractedFromSendAmount;
      _isFeeSubtractedFromSendAmount = true;
    }

    // 9. 잔액 초기화
    _initBalances();

    // 10. 모두 보내기 모드면 마지막 수신자 금액 재계산
    if (_isMaxMode) {
      _adjustLastReceiverAmount(recipientIndex: lastIndex);
    }
    // 11. 트랜잭션 빌드 (딱 1번만 호출)
    _buildTransaction();
    _transactionDraftId = draftId;

    // 12. 유효성 검증 상태 업데이트
    _updateAmountValidationState();

    // 13. UI 상태 업데이트
    _showAddressBoard = false;
    _showFeeBoard = recipientList.length > 1 || recipientList.any((r) => r.amount.isNotEmpty && r.address.isNotEmpty);

    // 14. 페이지 초기화 및 컨트롤러 동기화
    _currentIndex = 0;
    _onRecipientPageDeleted(0);
    _onAmountTextUpdate(_recipientList[_currentIndex].amount);
    _onFeeRateTextUpdate(_feeRateText);

    notifyListeners();

    return excludedUtxoStatus;
  }

  void _setEstimatedFee(int? estimatedFee) {
    if (_estimatedFee == estimatedFee) return;

    _estimatedFee = estimatedFee;

    if (_isMaxMode) {
      _adjustLastReceiverAmount();
    } else {
      _updateAmountValidationState();
    }
  }

  void _buildTransaction() {
    if (_selectedWalletItem == null ||
        !hasValidRecipient ||
        _feeRateText.isEmpty ||
        _feeRateText == "0" ||
        _changeAddressDerivationPath.isEmpty) {
      _setEstimatedFee(null);
      return;
    }

    final feeRate = double.parse(_feeRateText);
    _txBuilder = TransactionBuilder(
      availableUtxos: _selectedUtxoList,
      recipients: _getRecipientMapForTx(recipientMap),
      feeRate: feeRate,
      changeDerivationPath: _changeAddressDerivationPath,
      walletListItemBase: _selectedWalletItem!,
      isFeeSubtractedFromAmount: _isFeeSubtractedFromSendAmount,
      isUtxoFixed: !_isUtxoSelectionAuto,
    );

    _txBuildResult = _txBuilder!.build();
    _setEstimatedFee(_txBuildResult!.estimatedFee - (_txBuildResult!.unintendedDustFee ?? 0));
    _setUnintendedDustFee((_txBuildResult!.unintendedDustFee ?? 0) == 0 ? null : _txBuildResult!.unintendedDustFee);
    _updateFinalErrorMessage();
    Logger.log(_txBuilder.toString());
  }

  void _setUnintendedDustFee(int? unintendedDustFee) {
    if (_unintendedDustFee == unintendedDustFee) return;
    _unintendedDustFee = unintendedDustFee;
    notifyListeners();
  }

  void _updateWalletAddressList() {
    for (int i = 0; i < _walletAddressNeedsUpdate.length; ++i) {
      if (!_walletAddressNeedsUpdate[i]) continue;
      final walletId = _registeredWalletAddressMap.keys.toList()[i];
      final nextAddressIndex = _registeredWalletAddressMap.entries.toList()[i].value.walletAddress.index + 1;
      final walletListItem = _walletProvider.getWalletById(walletId);
      final walletAddress = _walletProvider.generateAddress(walletListItem.walletBase, nextAddressIndex, false);
      _registeredWalletAddressMap[walletListItem.id] = WalletAddressInfo(
        walletAddress: walletAddress,
        name: _registeredWalletAddressMap[walletListItem.id]!.name,
      );

      _walletAddressNeedsUpdate[i] = false;
    }

    notifyListeners();
  }

  void markWalletAddressForUpdate(int index) {
    _walletAddressNeedsUpdate[index] = true;
  }

  Future<void> refreshRecommendedFees() async {
    if (_recommendedFeeFetchStatus == RecommendedFeeFetchStatus.fetching) return;
    await _setRecommendedFees();
    notifyListeners();
  }

  Future<bool> _setRecommendedFees() async {
    _recommendedFeeFetchStatus = RecommendedFeeFetchStatus.fetching;

    final recommendedFees = await FeeService().getRecommendedFees();

    if (recommendedFees == null) {
      _recommendedFeeFetchStatus = RecommendedFeeFetchStatus.failed;
      return false;
    }

    feeInfos[0].satsPerVb = recommendedFees.fastestFee?.toDouble();
    feeInfos[1].satsPerVb = recommendedFees.halfHourFee?.toDouble();
    feeInfos[2].satsPerVb = recommendedFees.hourFee?.toDouble();
    _minimumFeeRate = recommendedFees.hourFee?.toDouble();

    final defaultFeeRate = recommendedFees.halfHourFee?.toString();
    if (defaultFeeRate != null && _transactionDraftId == null) {
      _feeRateText = defaultFeeRate;
      _onFeeRateTextUpdate(_feeRateText);
    }
    _recommendedFeeFetchStatus = RecommendedFeeFetchStatus.succeed;
    return true;
  }

  void setCurrentPage(int index) {
    _currentIndex = index;

    // 수신자 추가가 표시되어 있으면 주소 보드를 닫는다.
    if (index == recipientList.length) {
      setShowAddressBoard(false);
    } else {
      _onAmountTextUpdate(recipientList[_currentIndex].amount);
    }
    notifyListeners();
  }

  void setShowAddressBoard(bool isEnabled) {
    if (_showAddressBoard == isEnabled) return;
    _showAddressBoard = isEnabled;
    if (_showAddressBoard) _updateWalletAddressList();
    notifyListeners();
  }

  void _adjustLastReceiverAmount({int? recipientIndex}) {
    double amountSumExceptLast = _amountSumExceptLast;
    int estimatedFeeInSats = _estimatedFee ?? 0;
    int maxBalanceInSats =
        balance -
        (isBtcUnit ? UnitUtil.convertBitcoinToSatoshi(amountSumExceptLast) : amountSumExceptLast).toInt() -
        estimatedFeeInSats;
    _recipientList[lastIndex].amount =
        maxBalanceInSats > dustLimit
            ? (isBtcUnit
                    ? BalanceFormatUtil.formatSatoshiToReadableBitcoin(maxBalanceInSats).replaceAll(' ', '')
                    : maxBalanceInSats)
                .toString()
            : "0";

    if (_currentIndex == lastIndex) {
      _onAmountTextUpdate(recipientList[lastIndex].amount);
    }

    _updateAmountValidationState(recipientIndex: recipientIndex);
  }

  void setMaxMode(bool isEnabled, {bool skipAmountReset = false}) {
    if (_isMaxMode == isEnabled) return;

    _isMaxMode = isEnabled;
    if (_isMaxMode) {
      _adjustLastReceiverAmount(recipientIndex: lastIndex);
      _updateFeeBoardVisibility();
      _previousIsFeeSubtractedFromSendAmount = _isFeeSubtractedFromSendAmount;
      _isFeeSubtractedFromSendAmount = true;
    } else {
      /// maxMode 꺼지면 마지막 수신자 금액 초기화 (skipAmountReset이 true면 스킵)
      if (!skipAmountReset) {
        if (_recipientList.isNotEmpty && lastIndex >= 0) {
          _recipientList[lastIndex].amount = "";
          if (_currentIndex == lastIndex) {
            _onAmountTextUpdate(_recipientList[lastIndex].amount);
          }
        }
      }
      _isFeeSubtractedFromSendAmount = _previousIsFeeSubtractedFromSendAmount;
    }

    _buildTransaction();
    _updateAmountValidationState();
    vibrateLight();
    notifyListeners();
  }

  void addRecipient() {
    final newList = [..._recipientList, RecipientInfo(address: '', amount: '')];
    _recipientList = newList;
    _updateFinalErrorMessage();
    vibrateLight();
    notifyListeners();
  }

  void deleteRecipient() {
    _recipientList.removeAt(_currentIndex);
    _recipientList = [..._recipientList];
    if (lastIndex >= 0) _currentIndex = lastIndex;
    setCurrentPage(_currentIndex);
    _onRecipientPageDeleted(_currentIndex);

    _buildTransaction();

    /// AddressError.duplicate였던 것을 해제
    checkAndSetDuplicationError();
    _updateAmountValidationState();
    vibrateLight();
    notifyListeners();
  }

  void _updateFeeBoardVisibility() {
    if (_showFeeBoard) return;

    _showFeeBoard = hasValidRecipient;
    if (_showFeeBoard) _buildTransaction();
    notifyListeners();
  }

  void _updateFinalErrorMessage() {
    String message = "";
    // [전체] 충분하지 않은 Balance 입력 > [수신자] dust 보다 적은 금액을 입력 > [마지막 수신자] 전송 금액 - 예상 수수료가 dustLimit보다 크지 않음 > [수신자] 주소에 에러가 있는 경우 > 최소값보다 낮은 수수료 입력
    if (_isAmountSumExceedsBalance.isError) {
      message = _isAmountSumExceedsBalance.getMessage(currentUnit);
    } else if (_recipientList.any((r) => r.minimumAmountError.isError)) {
      message = AmountError.minimumAmount.getMessage(currentUnit);
    } else if (_isLastAmountInsufficient.isError) {
      message = _isLastAmountInsufficient.getMessage(currentUnit);
    } else if (_recipientList.any((r) => r.addressError.isError)) {
      int addressErrorIndex = _recipientList.indexWhere((r) => r.addressError.isError);
      if (addressErrorIndex != -1) {
        message = _recipientList[addressErrorIndex].addressError.getMessage();
      }
    } else if (_txBuildResult?.exception != null && _recipientList.every((r) => r.isInputValid)) {
      // 모든 수신자 카드 amount, address가 유효한 경우에만 메시지 보여주기
      message = _txBuildResult!.exception.toString();
    }

    _finalErrorMessage = message;
    notifyListeners();
  }

  void checkAndSetDuplicationError() {
    // 주소별 갯수 집계
    final Map<String, int> addressCount = {};
    for (final recipient in _recipientList) {
      if (recipient.address.isEmpty) continue;
      addressCount[recipient.address] = (addressCount[recipient.address] ?? 0) + 1;
    }

    for (int i = 0; i < _recipientList.length; i++) {
      final recipient = _recipientList[i];
      if (recipient.address.isEmpty) continue;
      if (recipient.addressError != AddressError.none && recipient.addressError != AddressError.duplicated) {
        // 중복 오류가 아닌 다른 오류는 건드리지 않음
        continue;
      }

      if (addressCount[recipient.address]! >= 2) {
        // 중복인 경우 duplicated 오류 설정
        _setAddressError(AddressError.duplicated, i);
      } else {
        // 더 이상 중복이 아니면 오류 해제
        _setAddressError(AddressError.none, i);
      }
    }
  }

  /// recipientIndex 유효성 검사
  bool _isValidRecipientIndex(int recipientIndex, String methodName) {
    if (recipientIndex < 0 || recipientIndex >= _recipientList.length) {
      debugPrint(
        '$methodName: Invalid recipientIndex $recipientIndex, _recipientList.length: ${_recipientList.length}',
      );
      return false;
    }
    return true;
  }

  void setAddressText(String text, int recipientIndex) {
    if (!_isValidRecipientIndex(recipientIndex, 'setAddressText')) return;
    if (_recipientList[recipientIndex].address == text) return;
    _recipientList[recipientIndex].address = text;
    if (text.isEmpty) {
      _txBuildResult = null;
    }
    notifyListeners();
  }

  /// bip21 url에서 amount값 파싱 성공했을 때 사용
  void setAmountText(int satoshi, int recipientIndex) {
    if (!_isValidRecipientIndex(recipientIndex, 'setAmountText')) return;
    if (currentUnit == BitcoinUnit.sats) {
      _recipientList[recipientIndex].amount = satoshi.toString();
    } else {
      _recipientList[recipientIndex].amount = UnitUtil.convertSatoshiToBitcoin(satoshi).toString();
    }
    notifyListeners();
  }

  void setFeeRateText(String feeRate) {
    _feeRateText = feeRate;

    try {
      var feeRateValue = double.parse(feeRate);
      _isFeeRateLowerThanMin = _minimumFeeRate != null && feeRateValue < _minimumFeeRate!;
    } catch (e) {
      Logger.error(e);
      _isFeeRateLowerThanMin = false;
    }

    _buildTransaction();
    notifyListeners();
  }

  void toggleUnit() {
    // 너무 큰 수가 입력된 경우: Positive input exceeds the limit of integer
    try {
      _currentUnit = isBtcUnit ? BitcoinUnit.sats : BitcoinUnit.btc;
      for (RecipientInfo recipient in recipientList) {
        if (recipient.amount.isNotEmpty && recipient.amount != '0') {
          recipient.amount =
              (isBtcUnit
                      ? UnitUtil.convertSatoshiToBitcoin(int.parse(recipient.amount))
                      : UnitUtil.convertBitcoinToSatoshi(double.parse(recipient.amount)))
                  .toString();

          // sats to btc 변환에서 지수로 표현되는 경우에는 다시 변환한다.
          if (recipient.amount.contains('e')) {
            recipient.amount = double.parse(recipient.amount).toStringAsFixed(8);
          }
        }
      }

      if (currentIndex != recipientList.length) {
        _onAmountTextUpdate(recipientList[_currentIndex].amount);
      }

      vibrateLight();
      notifyListeners();
    } catch (e) {
      Logger.error(e);
    }
  }

  void setIsFeeSubtractedFromSendAmount(bool isEnabled) {
    if (_isFeeSubtractedFromSendAmount == isEnabled) return;
    _isFeeSubtractedFromSendAmount = isEnabled;
    _buildTransaction();
    _updateAmountValidationState();
    notifyListeners();
  }

  void onKeyTap(String newInput) {
    if (_currentIndex == _recipientList.length) return;
    if (isSatsUnit && newInput == '.') return;

    final recipient = _recipientList[_currentIndex];
    if (newInput == '<') {
      if (recipient.amount.isNotEmpty) {
        recipient.amount = recipient.amount.substring(0, recipient.amount.length - 1);
      }
    } else if (newInput == '.') {
      if (recipient.amount.isEmpty) {
        recipient.amount = '0.';
      } else {
        if (!recipient.amount.contains('.')) {
          recipient.amount += newInput;
        }
      }
    } else {
      if (recipient.amount.isEmpty) {
        /// 첫 입력이 0인 경우는 바로 추가
        if (newInput == '0') {
          recipient.amount += newInput;
        } else if (newInput != '0' || recipient.amount.contains('.')) {
          recipient.amount += newInput;
        }
      } else if (recipient.amount == '0' && newInput != '.') {
        /// 첫 입력이 0이고, 그 후 0이 아닌 숫자가 올 경우에는 기존 0을 대체
        recipient.amount = newInput;
      } else if (recipient.amount.contains('.')) {
        /// 소수점 이후 숫자가 8자리 이하인 경우 추가
        int decimalIndex = recipient.amount.indexOf('.');
        if (recipient.amount.length - decimalIndex <= 8) {
          recipient.amount += newInput;
        }
      } else {
        /// 자연수인 경우 BTC 8자리 제한, sats 16자리 제한
        if (recipient.amount.length < (isBtcUnit ? 8 : 16)) {
          recipient.amount += newInput;
        }
      }
    }
    notifyListeners();
  }

  void validateAllFieldsOnFocusLost() {
    if (_isMaxMode) _adjustLastReceiverAmount();
    for (int i = 0; i < _recipientList.length; ++i) {
      _updateAmountValidationState(recipientIndex: i);
      validateAddress(_recipientList[i].address, i);
    }
    checkAndSetDuplicationError();
    _buildTransaction();
    _updateFeeBoardVisibility();
  }

  void clearAmountText() {
    if (_currentIndex == _recipientList.length) return;
    _recipientList[_currentIndex].amount = "";
    _updateAmountValidationState(recipientIndex: _currentIndex);
    _txBuildResult = null;
    _updateFinalErrorMessage();
    notifyListeners();
  }

  void setIsNetworkOn(bool? isNetworkOn) {
    _isNetworkOn = isNetworkOn;
    if (isNetworkOn == true && _recommendedFeeFetchStatus == RecommendedFeeFetchStatus.failed) {
      refreshRecommendedFees();
    }
    notifyListeners();
  }

  void _initBalances() {
    if (_selectedWalletItem == null) {
      _confirmedBalance = 0;
      _incomingBalance = 0;
      return;
    }

    List<UtxoState> utxos = _walletProvider.getUtxoList(_selectedWalletItem!.id);
    int unspentBalance = 0, incomingBalance = 0;
    for (UtxoState utxo in utxos) {
      if (utxo.status == UtxoStatus.unspent) {
        unspentBalance += utxo.amount;
      } else if (utxo.status == UtxoStatus.incoming) {
        incomingBalance += utxo.amount;
      }
    }

    _confirmedBalance = _isUtxoSelectionAuto ? unspentBalance : 0;
    _incomingBalance = incomingBalance;
  }

  void _updateAmountSum() {
    double amountSum = recipientList
        .where((r) => r.amount.isNotEmpty)
        .fold(0, (sum, r) => sum + double.parse(r.amount));
    amountSum = amountSum.roundTo8Digits();
    _amountSum = isBtcUnit ? UnitUtil.convertBitcoinToSatoshi(amountSum) : amountSum.toInt();

    _updateIsAmountSumExceedsBalance(amountSum);
    notifyListeners();
  }

  void _updateIsAmountSumExceedsBalance(double amountSum) {
    // 수수료가 아직 계산되지 않았으면 잔액 검증을 하지 않음
    if (_estimatedFee == null && !_isFeeSubtractedFromSendAmount) {
      _isAmountSumExceedsBalance = AmountError.none;
      return;
    }

    double total = _isFeeSubtractedFromSendAmount ? amountSum : amountSum + _estimatedFeeByUnit;
    double balanceInUnit = balance / _dustLimitDenominator;
    _isAmountSumExceedsBalance =
        total > 0 && total > balanceInUnit ? AmountError.insufficientBalance : AmountError.none;
  }

  void _validateOneAmount(int recipientIndex) {
    assert(recipientIndex != -1);
    final recipient = recipientList[recipientIndex];
    if (recipient.amount.isNotEmpty && double.parse(recipient.amount) > 0) {
      if (double.parse(recipient.amount) <= dustLimit / _dustLimitDenominator) {
        recipient.minimumAmountError = AmountError.minimumAmount;
      } else {
        recipient.minimumAmountError = AmountError.none;
      }
    } else {
      recipient.minimumAmountError = AmountError.none;
    }
  }

  // 마지막 수신자의 전송 금액을 확인한다. (전송 금액 - 예상 수수료 <= dust)
  // _isFeeSubtractedFromSendAmount가 true일 때만 체크되어야 함
  void _updateLastAmountErrorIfInsufficient() {
    if (!_isFeeSubtractedFromSendAmount) {
      if (_isLastAmountInsufficient.isError) {
        _isLastAmountInsufficient = AmountError.none;
      }
      return;
    }

    if (_recipientList[lastIndex].amount.isNotEmpty) {
      double amount = double.parse(_recipientList[lastIndex].amount);
      int estimatedFeeInSats = _estimatedFee ?? 0;
      bool isAmountInsufficientForFee =
          (isBtcUnit ? UnitUtil.convertBitcoinToSatoshi(amount) : amount).toInt() - estimatedFeeInSats <= dustLimit;

      _isLastAmountInsufficient = isAmountInsufficientForFee ? AmountError.insufficientBalance : AmountError.none;
      Logger.log("_insufficientBalanceErrorOfLastRecipient: $_isLastAmountInsufficient");
    }
  }

  void _updateAmountValidationState({int? recipientIndex}) {
    _updateAmountSum();
    if (recipientIndex != null) {
      _validateOneAmount(recipientIndex);
    }
    _updateLastAmountErrorIfInsufficient();

    _updateFinalErrorMessage();
    notifyListeners();
  }

  void _setAddressError(AddressError error, int index) {
    debugPrint('setAddressError: $error, $index');
    if (!_isValidRecipientIndex(index, '_setAddressError')) return;
    if (_recipientList[index].addressError != error) {
      _recipientList[index].addressError = error;
      _updateFinalErrorMessage();
      notifyListeners();
    }
  }

  AddressValidationError? validateScannedAddress(String address) {
    return AddressValidator.validateAddress(address, NetworkType.currentNetworkType);
  }

  bool validateAddress(String address, int recipientIndex) {
    if (!_isValidRecipientIndex(recipientIndex, 'validateAddress')) return false;

    AddressValidationError? error = AddressValidator.validateAddress(address, NetworkType.currentNetworkType);

    switch (error) {
      case AddressValidationError.notTestnetAddress:
      case AddressValidationError.notMainnetAddress:
      case AddressValidationError.notRegtestnetAddress:
        _setAddressError(AddressError.invalidNetworkAddress, recipientIndex);
        return false;
      case AddressValidationError.minimumLength:
      case AddressValidationError.unknown:
        _setAddressError(AddressError.invalid, recipientIndex);
        return false;
      case AddressValidationError.empty:
      default:
        break;
    }

    _setAddressError(AddressError.none, recipientIndex);
    return true;
  }

  Map<String, int> _getRecipientMapForTx(Map<String, int> map) {
    final Map<String, int> normalizedMap = {for (var entry in map.entries) normalizeAddress(entry.key): entry.value};

    if (!_isMaxMode) return normalizedMap;

    final double amountSumExceptLast = _amountSumExceptLast;
    final int maxBalanceInSats =
        balance - (isBtcUnit ? UnitUtil.convertBitcoinToSatoshi(amountSumExceptLast) : amountSumExceptLast).toInt();
    final String lastRecipientAddress = normalizeAddress(_recipientList[lastIndex].address);

    normalizedMap[lastRecipientAddress] = maxBalanceInSats;
    return normalizedMap;
  }

  void saveSendInfo() {
    assert(_txBuildResult!.isSuccess);

    final recipientMapInBtc = recipientMap.map((key, value) => MapEntry(key, UnitUtil.convertSatoshiToBitcoin(value)));

    // 모두 보내기 모드가 아니고 수수료 수신자 부담 옵션을 활성화한 경우, 마지막 수신자의 amount에서 수수료를 뺀다. (보기용)
    if (!_isMaxMode && _isFeeSubtractedFromSendAmount) {
      String lastRecipientAddress = _recipientList[lastIndex].address;
      recipientMapInBtc[lastRecipientAddress] =
          (recipientMapInBtc[lastRecipientAddress]! - UnitUtil.convertSatoshiToBitcoin(estimatedFeeInSats!))
              .roundTo8Digits();
    }

    // 이전에 사용한 정보 초기화
    _sendInfoProvider.setRecipientsForBatch(null);
    _sendInfoProvider.setRecipientAddress(null);
    _sendInfoProvider.setAmount(null);

    if (isBatchMode) {
      _sendInfoProvider.setRecipientsForBatch(recipientMapInBtc);
    } else {
      final firstEntry = recipientMapInBtc.entries.first;
      _sendInfoProvider.setRecipientAddress(firstEntry.key);
      _sendInfoProvider.setAmount(firstEntry.value);
    }

    _sendInfoProvider.setTransaction(_txBuildResult!.transaction!);
    _sendInfoProvider.setIsMultisig(_selectedWalletItem!.walletType == WalletType.multiSignature);
    _sendInfoProvider.setWalletImportSource(_selectedWalletItem!.walletImportSource);
    _sendInfoProvider.setFeeRate(double.parse(_feeRateText));
    _sendInfoProvider.setIsMaxMode(_isMaxMode);
    _sendInfoProvider.setUnsignedDraftId(_transactionDraftId);
  }

  /// --------------- 임시 저장 / 불러오기 --------------- ///
  Future<TransactionDraft> saveNewDraft() async {
    assert(_selectedWalletItem != null);

    final result = await _transactionDraftRepository.saveUnsignedDraft(
      walletId: selectedWalletItem!.id,
      feeRate: double.parse(_feeRateText),
      isMaxMode: _isMaxMode,
      isFeeSubtractedFromSendAmount: _isFeeSubtractedFromSendAmount,
      recipients:
          _recipientList.map((r) => RecipientDraft.fromRecipientInfo(r.address, r.amount, _currentUnit)).toList(),
      bitcoinUnit: _currentUnit,
      selectedUtxoIds: _isUtxoSelectionAuto ? null : _selectedUtxoList.map((utxo) => utxo.utxoId).toList(),
    );

    if (result.isSuccess) {
      _transactionDraftId = result.value.id;
      _loadDrafts();
      return result.value;
    } else {
      throw Exception(result.error.message);
    }
  }

  Future<TransactionDraft> updateDraft() async {
    assert(_selectedWalletItem != null);
    assert(_transactionDraftId != null);

    final result = await _transactionDraftRepository.updateUnsignedDraft(
      draftId: _transactionDraftId!,
      feeRate: double.parse(_feeRateText),
      isMaxMode: _isMaxMode,
      isFeeSubtractedFromSendAmount: _isFeeSubtractedFromSendAmount,
      recipients:
          _recipientList.map((r) => RecipientDraft.fromRecipientInfo(r.address, r.amount, _currentUnit)).toList(),
      bitcoinUnit: _currentUnit,
      selectedUtxoIds: _isUtxoSelectionAuto ? null : _selectedUtxoList.map((utxo) => utxo.utxoId).toList(),
    );

    if (result.isSuccess) {
      _loadDrafts();
      return result.value;
    } else {
      throw Exception(result.error.message);
    }
  }

  Future<void> _loadDrafts() async {
    if (_selectedWalletItem == null) return;
    try {
      _drafts = _transactionDraftRepository.getUnsignedTransactionDraftsByWalletId(_selectedWalletItem!.id);
    } catch (e) {
      // ignore
    }
  }

  Future<void> deleteDraft(int draftId) async {
    final result = await _transactionDraftRepository.deleteUnsignedTransactionDraft(draftId);
    if (result.isSuccess) {
      await _loadDrafts();
    }
  }
}

class RecipientInfo {
  String address;
  String amount;
  AddressError addressError;
  AmountError minimumAmountError; // 전송량이 적은 경우

  RecipientInfo({
    this.address = '',
    this.amount = '',
    this.addressError = AddressError.none,
    this.minimumAmountError = AmountError.none,
  });

  bool get isInputValid {
    final amountDecimal = Decimal.tryParse(amount);
    return address.trim().isNotEmpty &&
        amount.trim().isNotEmpty &&
        amountDecimal != null &&
        amountDecimal != Decimal.zero &&
        addressError.isNotError &&
        minimumAmountError.isNotError;
  }
}

class WalletAddressInfo {
  WalletAddress walletAddress;
  String name;

  WalletAddressInfo({required this.walletAddress, required this.name});
}
