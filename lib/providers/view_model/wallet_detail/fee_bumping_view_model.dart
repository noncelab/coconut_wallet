import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/constants/bitcoin_network_rules.dart';
import 'package:coconut_wallet/core/exceptions/cpfp_creation/cpfp_creation_exception.dart';
import 'package:coconut_wallet/core/exceptions/rbf_creation/rbf_creation_exception.dart';
import 'package:coconut_wallet/core/transaction/fee_bumping/cpfp_builder.dart';
import 'package:coconut_wallet/core/transaction/fee_bumping/cpfp_preparer.dart';
import 'package:coconut_wallet/core/transaction/fee_bumping/rbf_builder.dart';
import 'package:coconut_wallet/core/transaction/fee_bumping/rbf_preparer.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/enums/transaction_enums.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/send/fee_info.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/providers/transaction_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/repository/realm/address_repository.dart';
import 'package:coconut_wallet/repository/realm/utxo_repository.dart';
import 'package:coconut_wallet/repository/realm/wallet_preferences_repository.dart';
import 'package:coconut_wallet/screens/wallet_detail/transaction_fee_bumping_screen.dart';
import 'package:coconut_wallet/services/fee_service.dart';
import 'package:coconut_wallet/services/model/response/recommended_fee.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/utils/wallet_util.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class FeeBumpingViewModel extends ChangeNotifier {
  final FeeBumpingType _type;
  final TransactionRecord _pendingTx;
  final WalletProvider _walletProvider;
  final NodeProvider _nodeProvider;
  final SendInfoProvider _sendInfoProvider;
  final TransactionProvider _txProvider;
  final AddressRepository _addressRepository;
  final UtxoRepository _utxoRepository;
  final int _walletId;
  final PreferenceProvider _preferenceProvider;
  final WalletPreferencesRepository _walletPreferencesRepository;

  late final List<UtxoState> _availableUtxos;
  late WalletListItemBase _walletListItemBase;
  late bool? _isNetworkOn;
  late bool _isUtxoSelectionAuto = true;

  final List<FeeInfoWithLevel> _feeInfos = [
    FeeInfoWithLevel(level: TransactionFeeLevel.fastest),
    FeeInfoWithLevel(level: TransactionFeeLevel.halfhour),
    FeeInfoWithLevel(level: TransactionFeeLevel.hour),
  ];
  bool? _isFeeFetchSuccess;
  bool? _isInitializedSuccess;
  double? _recommendedFeeRate;
  String? _recommendedFeeRateDescription;

  List<UtxoState> _selectedUtxoList = [];
  double? _lastInputFeeRate;

  RbfBuilder? _rbfBuilder;
  RbfBuildResult? _rbfBuildResult;
  RbfBuildResult? _rbfBaseline;

  CpfpBuilder? _cpfpBuilder;
  CpfpBuildResult? _cpfpBuildResult;
  CpfpBuildResult? _cpfpBaseline;

  FeeBumpingViewModel(
    this._type,
    this._pendingTx,
    this._walletId,
    this._sendInfoProvider,
    this._nodeProvider,
    this._txProvider,
    this._walletProvider,
    this._addressRepository,
    this._utxoRepository,
    this._preferenceProvider,
    this._walletPreferencesRepository,
    this._isNetworkOn,
  ) {
    _walletListItemBase = _walletProvider.getWalletById(_walletId);
    _isUtxoSelectionAuto = !_walletPreferencesRepository.isManualUtxoSelection(_walletId);
    _availableUtxos = _utxoRepository.getUtxosByStatus(_walletId, UtxoStatus.unspent);
  }

  bool get isRbf => _type == FeeBumpingType.rbf;

  double? get recommendFeeRate => _recommendedFeeRate;
  String? get recommendFeeRateDescription => _recommendedFeeRateDescription;

  // Utxo? get currentUtxo => _currentUtxo;
  List<FeeInfoWithLevel> get feeInfos => _feeInfos;
  bool? get didFetchRecommendedFeesSuccessfully => _isFeeFetchSuccess;
  bool? get isInitializedSuccess => _isInitializedSuccess;
  bool get isNetworkOn => _isNetworkOn == true;

  TransactionRecord get transaction => _pendingTx;
  int get walletId => _walletId;

  bool get hasMfp => !isWalletWithoutMfp(_walletListItemBase);

  /// 빌드 결과에 서명 가능한 트랜잭션이 있는지 (prepareToSend 호출 가능 여부)
  bool get hasValidTransaction {
    if (isRbf) {
      return _rbfBuildResult != null && _rbfBuildResult!.isSuccess;
    } else {
      return _cpfpBuildResult != null && _cpfpBuildResult!.isSuccess;
    }
  }

  Exception? get unexpectedError {
    if (isRbf) {
      final exception = _rbfBuildResult?.exception;
      if (exception != null && exception is UseChangeOutputFailureException || exception is! RbfCreationException) {
        return exception;
      }
    } else {
      final exception = _cpfpBuildResult?.exception;
      if (exception != null && exception is! CpfpCreationException) {
        return exception;
      }
    }
    return null;
  }

  int? get deficitSats {
    if (isRbf) {
      if (_rbfBuildResult?.deficitAmount == null) return null;
      return _rbfBuildResult!.deficitAmount;
    } else {
      if (_cpfpBuildResult?.deficitAmount == null) return null;
      return _cpfpBuildResult!.deficitAmount;
    }
  }

  bool get isFeeBumpingImpossible {
    if (isRbf) {
      return _rbfBaseline != null && _rbfBaseline!.deficitAmount != null && _availableUtxos.isEmpty;
    } else {
      return _cpfpBaseline != null && _cpfpBaseline!.deficitAmount != null && _availableUtxos.isEmpty;
    }
  }

  bool get isAdditionalInputRequired {
    if (isRbf) {
      if (_rbfBaseline != null && (_rbfBaseline!.addedInputs != null || _rbfBaseline!.deficitAmount != null)) {
        return true;
      }
      if (_rbfBuildResult != null && (_rbfBuildResult!.addedInputs != null || _rbfBuildResult!.deficitAmount != null)) {
        return true;
      }
      return false;
    } else {
      if (_cpfpBaseline != null && (_cpfpBaseline!.addedInputs != null || _cpfpBaseline!.deficitAmount != null)) {
        return true;
      }
      if (_cpfpBuildResult != null &&
          (_cpfpBuildResult!.addedInputs != null || _cpfpBuildResult!.deficitAmount != null)) {
        return true;
      }
      return false;
    }
  }

  bool get isUtxoInsufficient {
    if (isRbf) {
      if (_rbfBuildResult != null && _rbfBuildResult!.deficitAmount != null) return true;
      if (_rbfBaseline != null && _rbfBaseline!.deficitAmount != null) return true;
    } else {
      if (_cpfpBuildResult != null && _cpfpBuildResult!.deficitAmount != null) return true;
      if (_cpfpBaseline != null && _cpfpBaseline!.deficitAmount != null) return true;
    }

    return false;
  }

  BitcoinUnit get currentUnit => _preferenceProvider.currentUnit;

  bool get isUtxoSelectionAuto => _isUtxoSelectionAuto;
  List<UtxoState> get selectedUtxoList => _selectedUtxoList;
  List<UtxoState> get availableUtxos => _availableUtxos;

  void toggleUtxoSelectionAuto() {
    _isUtxoSelectionAuto = !_isUtxoSelectionAuto;
    if (_isUtxoSelectionAuto) {
      _selectedUtxoList = [];
    }
    assert(_rbfBuilder != null || _cpfpBuilder != null);
    _updateAdditionalSpendable(_isUtxoSelectionAuto ? _availableUtxos : []);

    notifyListeners();
  }

  void _updateRbfBaseline(RbfBuildResult result) {
    _rbfBaseline = result;
    _recommendedFeeRate = _rbfBaseline!.minimumFeeRate;
    // notifyListeners();
  }

  void _updateCpfpBaseline(CpfpBuildResult result) {
    _cpfpBaseline = result;
    _recommendedFeeRate = _cpfpBaseline!.minimumFeeRate;
    _recommendedFeeRateDescription = _getRecommendedFeeRateDescriptionForCpfp(result);
  }

  void _updateAdditionalSpendable(List<UtxoState> utxos) {
    if (_type == FeeBumpingType.rbf) {
      _updateRbfBaseline(_rbfBuilder!.changeAdditionalSpendable(utxos));
      if (_lastInputFeeRate != null && _lastInputFeeRate! > 0) {
        _rbfBuildResult = _rbfBuilder!.build(newFeeRate: _lastInputFeeRate!);
      }
    } else {
      _updateCpfpBaseline(_cpfpBuilder!.changeAdditionalSpendable(utxos));
      if (_lastInputFeeRate != null && _lastInputFeeRate! > 0) {
        _cpfpBuildResult = _cpfpBuilder!.build(newFeeRate: _lastInputFeeRate!);
      }
    }
    notifyListeners();
  }

  /// UTXO 수동 선택일 때만 호출됨
  void updateSelectedUtxos(List<UtxoState> list) {
    _selectedUtxoList = list;

    if (_type == FeeBumpingType.rbf) {
      _updateRbfBaseline(_rbfBuilder!.changeAdditionalSpendable(_selectedUtxoList));
      if (_lastInputFeeRate != null && _lastInputFeeRate! > 0) {
        _rbfBuildResult = _rbfBuilder!.build(newFeeRate: _lastInputFeeRate!);
      }
    } else {
      _updateCpfpBaseline(_cpfpBuilder!.changeAdditionalSpendable(_selectedUtxoList));
      if (_lastInputFeeRate != null && _lastInputFeeRate! > 0) {
        _cpfpBuildResult = _cpfpBuilder!.build(newFeeRate: _lastInputFeeRate!);
      }
    }
    notifyListeners();
  }

  Future<RbfBuilder> _initRbfBuilder() async {
    final txResult = await _nodeProvider.getTransaction(_pendingTx.transactionHash);
    if (txResult.isFailure) {
      throw Exception('Failed to get transaction');
    }

    final preparer = RbfPreparer.fromPendingTx(
      pendingTx: _pendingTx,
      rawTx: txResult.value,
      getUtxos: (String utxoId) {
        return _utxoRepository.getUtxoState(_walletId, utxoId);
      },
      isMyAddress:
          (String address, {bool isChange = false}) =>
              _walletProvider.containsAddress(_walletId, address, isChange: isChange),
      getDerivationPath: (String address) => _addressRepository.getDerivationPath(_walletId, address),
    );

    if (preparer.hasDuplicatedOutput) {
      throw const DuplicatedOutputException();
    }

    return RbfBuilder(
      preparer: preparer,
      walletListItemBase: _walletListItemBase,
      nextChangeAddress: _addressRepository.getChangeAddress(walletId),
      additionalSpendable: _isUtxoSelectionAuto ? _availableUtxos : [],
    );
  }

  CpfpBuilder _initCpfpBuilder(double slowFeeRate) {
    final preparer = CpfpPreparer.fromPendingTx(
      pendingTx: _pendingTx,
      incomingUtxos: _utxoRepository.getUtxosByStatus(_walletId, UtxoStatus.incoming),
      isMyAddress:
          (String address, {bool isChange = false}) =>
              _walletProvider.containsAddress(_walletId, address, isChange: isChange),
    );

    return CpfpBuilder(
      preparer: preparer,
      walletListItemBase: _walletListItemBase,
      nextReceiveAddress: _addressRepository.getReceiveAddress(_walletId),
      minimumFeeRate: slowFeeRate,
      additionalSpendable: _isUtxoSelectionAuto ? _availableUtxos : [],
    );
  }

  Future<void> initialize() async {
    await _fetchRecommendedFees();
    if (_isFeeFetchSuccess == true) {
      double initialFee = _feeInfos[2].satsPerVb!.toDouble();
      if (_type == FeeBumpingType.rbf) {
        _recommendedFeeRateDescription = t.transaction_fee_bumping_screen.recommend_fee_info_rbf;
        _rbfBuilder = await _initRbfBuilder();
        _updateRbfBaseline(_rbfBuilder!.getBaselineTransaction());
      } else {
        _cpfpBuilder = _initCpfpBuilder(initialFee);
        _updateCpfpBaseline(_cpfpBuilder!.getBaselineTransaction());
      }

      _isInitializedSuccess = true;
      _lastInputFeeRate = initialFee;
    } else {
      _isInitializedSuccess = false;
    }
    notifyListeners();
  }

  void onFeeRateIsNull() {
    Logger.log('[FeeBumping] onFeeRateIsNull: build result 초기화 (null로 설정)');
    _lastInputFeeRate = null;
    _rbfBuildResult = null;
    _cpfpBuildResult = null;
    //notifyListeners();
  }

  dynamic onFeeRateChanged(double? newFeeRate) {
    if (isRbf) {
      return onRbfFeeRateChanged(newFeeRate);
    } else {
      return onCpfpFeeRateChanged(newFeeRate);
    }
  }

  RbfBuildResult? onRbfFeeRateChanged(double? newFeeRate) {
    assert(_rbfBuilder != null);
    _lastInputFeeRate = newFeeRate;
    if (newFeeRate == null) {
      Logger.log('[FeeBumping] onRbfFeeRateChanged: newFeeRate=null → null 반환');
      _rbfBuildResult = null;
      return null;
    }

    _rbfBuildResult = _rbfBuilder!.build(newFeeRate: newFeeRate);
    if (_rbfBuildResult!.isFailure) {
      Logger.log(
        '[FeeBumping] onRbfFeeRateChanged: build 실패 (transaction=null) feeRate=$newFeeRate exception=${_rbfBuildResult!.exception}',
      );
    }
    return _rbfBuildResult;
  }

  CpfpBuildResult? onCpfpFeeRateChanged(double? newFeeRate) {
    assert(_cpfpBuilder != null);
    _lastInputFeeRate = newFeeRate;
    if (newFeeRate == null) {
      Logger.log('[FeeBumping] onCpfpFeeRateChanged: newFeeRate=null → null 반환');
      _cpfpBuildResult = null;
      return null;
    }

    _cpfpBuildResult = _cpfpBuilder!.build(newFeeRate: newFeeRate);
    if (_cpfpBuildResult!.isFailure) {
      Logger.log(
        '[FeeBumping] onCpfpFeeRateChanged: build 실패 (transaction=null) feeRate=$newFeeRate exception=${_cpfpBuildResult!.exception}',
      );
    }
    return _cpfpBuildResult;
  }

  bool isFeeRateTooLow(double feeRate) {
    assert(_isInitializedSuccess == true);
    assert(_recommendedFeeRate != null);

    return feeRate < _recommendedFeeRate! || feeRate < _pendingTx.feeRate;
  }

  // pending상태였던 Tx가 confirmed 되었는지 조회
  bool hasTransactionConfirmed() {
    return _txProvider.hasTransactionConfirmed(_walletId, transaction.transactionHash);
  }

  Future<bool> prepareToSend(double newTxFeeRate) async {
    Logger.log(
      '[FeeBumping] prepareToSend: newTxFeeRate=$newTxFeeRate hasValidTransaction=$hasValidTransaction '
      'rbfBuildResult=${_rbfBuildResult != null} rbfSuccess=${_rbfBuildResult?.isSuccess} '
      'cpfpBuildResult=${_cpfpBuildResult != null} cpfpSuccess=${_cpfpBuildResult?.isSuccess}',
    );
    _sendInfoProvider.setWalletId(_walletId);
    _sendInfoProvider.setIsMultisig(_walletListItemBase.walletType == WalletType.multiSignature);
    final transaction = isRbf ? _rbfBuildResult!.transaction! : _cpfpBuildResult!.transaction!;
    _sendInfoProvider.setTxWaitingForSign(
      Psbt.fromTransaction(transaction, _walletListItemBase.walletBase).serialize(),
    );
    _sendInfoProvider.setFeeBumpfingType(_type);
    _sendInfoProvider.setWalletImportSource(_walletListItemBase.walletImportSource);
    return true;
  }

  int? getTotalEstimatedFeeOfRbf() {
    if (_rbfBuildResult == null) {
      Logger.log('[FeeBumping] getTotalEstimatedFeeOfRbf: _rbfBuildResult==null → null 반환');
      return null;
    }
    if (_rbfBuildResult!.isFailure) {
      Logger.log('[FeeBumping] getTotalEstimatedFeeOfRbf: isFailure → null 반환');
      return null;
    }
    return _rbfBuildResult!.estimatedFee;
  }

  int? getTotalEstimatedFeeOfCpfp() {
    if (_cpfpBuildResult == null) {
      Logger.log('[FeeBumping] getTotalEstimatedFeeOfCpfp: _cpfpBuildResult==null → null 반환');
      return null;
    }
    if (_cpfpBuildResult!.isFailure) {
      Logger.log('[FeeBumping] getTotalEstimatedFeeOfCpfp: isFailure → null 반환');
      return null;
    }
    return _cpfpBuildResult!.estimatedFee;
  }

  // 수수료 입력 시 예상 총 수수료 계산
  int getTotalEstimatedFee(double newFeeRate) {
    final fee = _type == FeeBumpingType.rbf ? getTotalEstimatedFeeOfRbf() : getTotalEstimatedFeeOfCpfp();
    if (fee == null) {
      Logger.log('[FeeBumping] getTotalEstimatedFee: null → 0 반환 (type=$_type)');
      return 0;
    }
    return fee;
  }

  void setIsNetworkOn(bool? isNetworkOn) {
    _isNetworkOn = isNetworkOn;
    notifyListeners();
  }

  bool makeDust(List<Utxo> utxoList, double outputSum, double requiredFee) {
    return utxoList.fold(0, (sum, utxo) => sum + utxo.amount) - outputSum - requiredFee < dustLimit;
  }

  // 노드 프로바이더에서 추천 수수료 조회
  Future<void> _fetchRecommendedFees() async {
    final RecommendedFee? recommendedFees = await FeeService().getRecommendedFees();

    if (recommendedFees == null) {
      _isFeeFetchSuccess = false;
      return;
    }
    // TODO: 테스트 코드 - 추천수수료 mock
    // final recommendedFees = await DioClient().getRecommendedFee();
    if (recommendedFees.fastestFee == null || recommendedFees.halfHourFee == null || recommendedFees.hourFee == null) {
      _isFeeFetchSuccess = false;
      return;
    }

    _feeInfos[0].satsPerVb = recommendedFees.fastestFee?.toDouble();
    _feeInfos[1].satsPerVb = recommendedFees.halfHourFee?.toDouble();
    _feeInfos[2].satsPerVb = recommendedFees.hourFee?.toDouble();

    _isFeeFetchSuccess = true;
  }

  String _getRecommendedFeeRateDescriptionForCpfp(CpfpBuildResult baseline) {
    assert(_recommendedFeeRate != null);

    // 기다리면 블록에 담길 트랜잭션
    if (!baseline.isCpfpNeeded) {
      return t.transaction_fee_bumping_screen.recommended_fee_less_than_network_fee;
    }

    final totalRequiredFee = (_pendingTx.vSize + baseline.estimatedVSize) * _recommendedFeeRate!;
    String inequalitySign = baseline.minimumFeeRate % 1 == 0 ? "=" : "≈";
    return t.transaction_fee_bumping_screen.recommend_fee_info_cpfp(
      newTxSize: _formatNumber(baseline.estimatedVSize),
      recommendedFeeRate: _formatNumber(_recommendedFeeRate!),
      originalTxSize: _formatNumber(_pendingTx.vSize),
      originalFee: _pendingTx.fee,
      totalRequiredFee: _formatNumber(totalRequiredFee),
      newTxFee: _formatNumber(baseline.estimatedVSize * baseline.minimumFeeRate),
      newTxFeeRate: _formatNumber(baseline.minimumFeeRate),
      inequalitySign: inequalitySign,
    );
  }

  String _formatNumber(double value) {
    return value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(2);
  }
}
