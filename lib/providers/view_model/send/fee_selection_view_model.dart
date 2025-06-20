import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/constants/bitcoin_network_rules.dart';
import 'package:coconut_wallet/enums/transaction_enums.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/send/fee_info.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/services/model/response/recommended_fee.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:coconut_wallet/utils/fiat_util.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/utils/transaction_util.dart';
import 'package:flutter/material.dart';

class FeeSelectionViewModel extends ChangeNotifier {
  final SendInfoProvider _sendInfoProvider;
  final WalletProvider _walletProvider;
  final NodeProvider _nodeProvider;
  final int Function(double)? _externalEstimateFee;

  late final WalletListItemBase _walletListItemBase;
  late AddressType _walletAddressType;
  late int _confirmedBalance;
  late int? _bitcoinPriceKrw;
  late bool _isMultisigWallet;
  late bool _isMaxMode;
  late int _walletId;
  late double _amount;
  String? _recipientAddress;
  late String _input;
  late bool? _isNetworkOn;
  bool _isBatchTx = false;
  bool _disposed = false;

  static const int _maxFeeLimit = 1000000; // sats, 사용자가 실수로 너무 큰 금액을 수수료로 지불하지 않도록 지정했습니다.

  int _estimatedFee = 0;
  bool _isCustomFeeTooLow = false;
  bool _isLoading = false;
  bool _isCustomSelected = false;
  String? _selectedFeeLevelText;

  TransactionFeeLevel? _selectedLevel;

  late List<FeeInfoWithLevel> _feeInfos;
  late FeeInfo? _customFeeInfo;
  late int? _minimumSatsPerVb;
  late bool? _isRecommendedFeeFetchSuccess;

  int get maxFeeLimit => _maxFeeLimit;
  int? get estimatedFee => _estimatedFee;
  int? get minimumSatsPerVb => _minimumSatsPerVb;
  bool get isCustomFeeTooLow => _isCustomFeeTooLow;
  bool get isLoading => _isLoading;
  bool get isCustomSelected => _isCustomSelected;
  bool? get isRecommendedFeeFetchSuccess => _isRecommendedFeeFetchSuccess;
  String? get selectedFeeLevelText => _selectedFeeLevelText;

  List<FeeInfoWithLevel> get feeInfos => _feeInfos;
  TransactionFeeLevel? get selectedLevel => _selectedLevel;
  FeeInfo? get customFeeInfo => _customFeeInfo;

  FeeSelectionViewModel(
    this._sendInfoProvider,
    this._walletProvider,
    this._nodeProvider,
    this._bitcoinPriceKrw,
    this._isNetworkOn, {
    List<FeeInfoWithLevel>? feeInfos,
    FeeInfo? customFeeInfo,
    int? minimumSatsPerVb,
    bool? isRecommendedFeeFetchSuccess,
    List<UtxoState>? selectedUtxo,
    int Function(double)? estimateFee,
  }) : _externalEstimateFee = estimateFee {
    _feeInfos = feeInfos ??
        [
          FeeInfoWithLevel(level: TransactionFeeLevel.fastest),
          FeeInfoWithLevel(level: TransactionFeeLevel.halfhour),
          FeeInfoWithLevel(level: TransactionFeeLevel.hour),
        ];
    _customFeeInfo = customFeeInfo;
    _minimumSatsPerVb = minimumSatsPerVb;
    _isRecommendedFeeFetchSuccess = isRecommendedFeeFetchSuccess;

    _input = '';
    _walletListItemBase = _walletProvider.getWalletById(_sendInfoProvider.walletId!);
    _walletAddressType = _walletListItemBase.walletType == WalletType.singleSignature
        ? AddressType.p2wpkh
        : AddressType.p2wsh;
    _confirmedBalance =
        _walletProvider.getUtxoList(_sendInfoProvider.walletId!).fold<int>(0, (sum, utxo) {
      if (utxo.status == UtxoStatus.unspent) {
        return sum + utxo.amount;
      }
      return sum;
    });
    _isMultisigWallet = _walletListItemBase.walletType == WalletType.multiSignature;
    _bitcoinPriceKrw = _bitcoinPriceKrw;
    _walletId = _sendInfoProvider.walletId!;
    if (_sendInfoProvider.recipientsForBatch != null) {
      _isBatchTx = true;
      _setBatchTxParams();
    } else {
      _setSingleTxParams();
    }
    _isNetworkOn = isNetworkOn;
    _updateSendInfoProvider();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_disposed) {
      super.notifyListeners();
    }
  }

  double get amount => _amount;
  int? get bitcoinPriceKrw => _bitcoinPriceKrw;
  bool get isNetworkOn => _isNetworkOn == true;
  WalletProvider get walletProvider => _walletProvider;
  NodeProvider get nodeprovider => _nodeProvider;
  String get input => addThousandsSeparator(_input);

  int estimateFee(
    double satsPerVb,
  ) {
    if (_externalEstimateFee != null) {
      return _externalEstimateFee(satsPerVb);
    }

    final transaction = _createTransaction(
      satsPerVb,
    );

    if (_isMultisigWallet) {
      final multisigWallet = _walletListItemBase.walletBase as MultisignatureWallet;
      return transaction.estimateFee(satsPerVb, _walletAddressType,
          requiredSignature: multisigWallet.requiredSignature,
          totalSigner: multisigWallet.totalSigner);
    }

    return transaction.estimateFee(satsPerVb, _walletAddressType);
  }

  Transaction _createTransaction(double satsPerVb) {
    final utxoPool = _walletProvider.getUtxoListByStatus(_walletId, UtxoStatus.unspent);
    final wallet = _walletProvider.getWalletById(_walletId);
    final changeAddress = _walletProvider.getChangeAddress(_walletId);
    final amount = UnitUtil.bitcoinToSatoshi(_amount);

    if (_isBatchTx) {
      return Transaction.forBatchPayment(
          TransactionUtil.selectOptimalUtxos(utxoPool, amount, satsPerVb, _walletAddressType),
          _sendInfoProvider.recipientsForBatch!
              .map((key, value) => MapEntry(key, UnitUtil.bitcoinToSatoshi(value))),
          changeAddress.derivationPath,
          satsPerVb.toDouble(),
          _walletListItemBase.walletBase);
    }

    return _isMaxMode
        ? Transaction.forSweep(
            utxoPool, _recipientAddress!, satsPerVb.toDouble(), wallet.walletBase)
        : Transaction.forSinglePayment(
            TransactionUtil.selectOptimalUtxos(utxoPool, amount, satsPerVb, _walletAddressType),
            _recipientAddress!,
            changeAddress.derivationPath,
            amount,
            satsPerVb.toDouble(),
            _walletListItemBase.walletBase);
  }

  void _setSingleTxParams() {
    _amount = _sendInfoProvider.amount!;
    _recipientAddress = _sendInfoProvider.recipientAddress!;
    _isMaxMode = _confirmedBalance == UnitUtil.bitcoinToSatoshi(_amount);
  }

  void _setBatchTxParams() {
    _amount = _sendInfoProvider.recipientsForBatch!.values.fold(0, (sum, value) => sum + value);
    //_recipientAddresses = _sendInfoProvider.recipientsForBatch!.keys.toList();
    _isMaxMode = false;
  }

  void _setFeeInfo(FeeInfo feeInfo, int? estimatedFee) {
    if (estimatedFee == null) return;
    feeInfo.estimatedFee = estimatedFee;
    feeInfo.fiatValue = bitcoinPriceKrw != null
        ? FiatUtil.calculateFiatAmount(estimatedFee, bitcoinPriceKrw!)
        : null;

    if (feeInfo is FeeInfoWithLevel && feeInfo.level == _selectedLevel) {
      setEstimatedFee(estimatedFee);
      return;
    }

    if (feeInfo is! FeeInfoWithLevel) {
      setSelectedFeeLevelText(t.input_directly);
      setEstimatedFee(estimatedFee);
      setCustomSelected(true);
    }
  }

  Future<void> _setRecommendedFees() async {
    final recommendedFeesResult = await nodeprovider.getRecommendedFees();
    if (recommendedFeesResult.isFailure) {
      _setRecommendedFeeFetchSuccess(false);
      return;
    }

    final RecommendedFee recommendedFees = recommendedFeesResult.value;
    feeInfos[0].satsPerVb = recommendedFees.fastestFee.toDouble();
    feeInfos[1].satsPerVb = recommendedFees.halfHourFee.toDouble();
    feeInfos[2].satsPerVb = recommendedFees.hourFee.toDouble();

    _setMinimumSatsPerVb(recommendedFees.minimumFee);

    for (var feeInfo in feeInfos) {
      try {
        int estimatedFee = estimateFee(feeInfo.satsPerVb!);
        _setFeeInfo(feeInfo, estimatedFee);
        _setRecommendedFeeFetchSuccess(true);
      } catch (error) {
        int? estimatedFee = _handleFeeEstimationError(error as Exception);
        _setFeeInfo(feeInfo, estimatedFee);
      }
    }
  }

  int? _handleFeeEstimationError(Exception e) {
    try {
      if (e.toString().contains("Insufficient amount. Estimated fee is")) {
        // get finalFee from error message : 'Insufficient amount. Estimated fee is $finalFee'
        var estimatedFee =
            int.parse(e.toString().split("Insufficient amount. Estimated fee is ")[1]);
        return estimatedFee;
      }

      if (e.toString().contains("Not enough amount for sending. (Fee")) {
        // get finalFee from error message : 'Not enough amount for sending. (Fee : $finalFee)'
        var estimatedFee = int.parse(
            e.toString().split("Not enough amount for sending. (Fee : ")[1].split(")")[0]);
        return estimatedFee;
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  Future<void> startToSetRecommendedFee() async {
    setLoading(true);
    await _setRecommendedFees();
    setLoading(false);
  }

  void onKeyTap(String newInput) {
    setCustomSelected(true);
    if (newInput == ' ') return;
    if (newInput == '<') {
      if (_input.isNotEmpty) {
        _input = _input.substring(0, _input.length - 1);
      }
    } else if (newInput == '.') {
      if (_input.isEmpty) {
        _input = '0.';
      } else {
        if (!_input.contains('.')) {
          _input += newInput;
        }
      }
    } else {
      if (_input.isEmpty) {
        /// 첫 입력이 0인 경우는 바로 추가
        if (newInput == '0') {
          _input += newInput;
        } else if (newInput != '0' || _input.contains('.')) {
          _input += newInput;
        }
      } else if (_input == '0' && newInput != '.') {
        /// 첫 입력이 0이고, 그 후 0이 아닌 숫자가 올 경우에는 기존 0을 대체
        _input = newInput;
      } else if (_input.contains('.')) {
        /// 소수점 이후 숫자가 2자리 이하인 경우 추가
        int decimalIndex = _input.indexOf('.');
        if (_input.length - decimalIndex <= 2) {
          _input += newInput;
        }
      } else {
        /// 일반적인 경우 추가
        _input += newInput;
      }
    }

    _handleCustomFeeInput(_input);
    notifyListeners();
  }

  void _handleCustomFeeInput(String input) async {
    if (input.isEmpty) {
      setEstimatedFee(0);
      return;
    }

    double customSatsPerVb = double.parse(input.trim());

    if (_minimumSatsPerVb != null && customSatsPerVb < _minimumSatsPerVb! && customSatsPerVb != 0) {
      if (!_isCustomFeeTooLow) {
        _isCustomFeeTooLow = true;
      }
      return;
    } else if (_isCustomFeeTooLow) {
      _isCustomFeeTooLow = false;
    }

    setLoading(true);

    try {
      int estimatedFee = estimateFee(customSatsPerVb);
      _setCustomFeeInfo(FeeInfo(satsPerVb: customSatsPerVb));
      _setFeeInfo(_customFeeInfo!, estimatedFee);
    } catch (error) {
      int? estimatedFee = _handleFeeEstimationError(error as Exception);
      _setCustomFeeInfo(FeeInfo(satsPerVb: customSatsPerVb));
      _setFeeInfo(_customFeeInfo!, estimatedFee);
    }
    setLoading(false);
  }

  bool isBalanceEnough(int? estimatedFee) {
    if (estimatedFee == null || estimatedFee == 0) return false;
    if (_isMaxMode) return (_confirmedBalance - estimatedFee) > dustLimit;
    Logger.log('--> ${UnitUtil.bitcoinToSatoshi(amount)} $estimatedFee $_confirmedBalance');
    return (UnitUtil.bitcoinToSatoshi(amount) + estimatedFee) <= _confirmedBalance;
  }

  bool canGoNext() {
    if (_selectedLevel == null && !isCustomSelected) return false;

    double? recommendedSatsPerVb = _minimumSatsPerVb!.toDouble();
    if (!isCustomSelected) {
      recommendedSatsPerVb =
          _feeInfos.firstWhere((element) => element.level == _selectedLevel).satsPerVb;
    }

    double? finalFeeRate = _isCustomSelected ? _customFeeInfo?.satsPerVb : recommendedSatsPerVb;

    return isNetworkOn &&
        finalFeeRate != null &&
        finalFeeRate > 0 &&
        _estimatedFee < maxFeeLimit &&
        isBalanceEnough(estimatedFee) &&
        !isLoading;
  }

  FeeInfoWithLevel findFeeInfoWithLevel() {
    return feeInfos.firstWhere((feeInfo) => feeInfo.level == _selectedLevel);
  }

  void setBitcoinPriceKrw(int price) {
    _bitcoinPriceKrw = price;
    notifyListeners();
  }

  void saveFinalSendInfo(int estimatedFee, double satsPerVb) {
    double finalAmount =
        _isMaxMode ? UnitUtil.satoshiToBitcoin(_confirmedBalance - estimatedFee) : _amount;
    _sendInfoProvider.setAmount(finalAmount);
    _sendInfoProvider.setEstimatedFee(estimatedFee);
    _sendInfoProvider.setTransaction(_createTransaction(satsPerVb));
    _sendInfoProvider.setFeeBumpfingType(null);
    _sendInfoProvider.setWalletImportSource(_walletListItemBase.walletImportSource);
  }

  void setIsNetworkOn(bool? isNetworkOn) {
    _isNetworkOn = isNetworkOn;
    notifyListeners();
  }

  void _updateSendInfoProvider() {
    _sendInfoProvider.setIsMultisig(_isMultisigWallet);
    _sendInfoProvider.setIsMaxMode(_isMaxMode);
  }

  void _setMinimumSatsPerVb(int value) {
    _minimumSatsPerVb = value;
    notifyListeners();
  }

  void setEstimatedFee(int value) {
    _estimatedFee = value;
    notifyListeners();
  }

  void setCustomSelected(bool value) {
    _isCustomSelected = value;
    notifyListeners();
  }

  void _setRecommendedFeeFetchSuccess(bool value) {
    _isRecommendedFeeFetchSuccess = value;
    notifyListeners();
  }

  void _setCustomFeeInfo(FeeInfo value) {
    _customFeeInfo = value;
    notifyListeners();
  }

  void setSelectedFeeLevelText(String value) {
    _selectedFeeLevelText = value;
    notifyListeners();
  }

  void setSelectedLevel(FeeInfoWithLevel value) {
    _selectedLevel = value.level;
    _input = value.satsPerVb.toString();
    if (isCustomFeeTooLow && value.satsPerVb! >= _minimumSatsPerVb!.toDouble()) {
      _isCustomFeeTooLow = false;
    }

    setCustomSelected(false);
    notifyListeners();
  }

  void setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
