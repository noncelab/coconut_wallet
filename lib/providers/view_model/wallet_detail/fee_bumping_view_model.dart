import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/transaction_enums.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/send/fee_info.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/providers/transaction_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/repository/realm/address_repository.dart';
import 'package:coconut_wallet/repository/realm/utxo_repository.dart';
import 'package:coconut_wallet/screens/wallet_detail/transaction_fee_bumping_screen.dart';
import 'package:coconut_wallet/utils/recommended_fee_util.dart';
import 'package:coconut_wallet/utils/transaction_util.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:coconut_wallet/core/transaction/fee_bumping/rbf_builder.dart';
import 'package:coconut_wallet/core/transaction/fee_bumping/cpfp_builder.dart';
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
  Transaction? _bumpingTransaction;
  late WalletListItemBase _walletListItemBase;
  late bool? _isNetworkOn;

  final List<FeeInfoWithLevel> _feeInfos = [
    FeeInfoWithLevel(level: TransactionFeeLevel.fastest),
    FeeInfoWithLevel(level: TransactionFeeLevel.halfhour),
    FeeInfoWithLevel(level: TransactionFeeLevel.hour),
  ];
  bool? _isFeeFetchSuccess;
  bool? _isInitializedSuccess;
  double? _recommendedFeeRate;
  String? _recommendedFeeRateDescription;

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
    this._isNetworkOn,
  ) {
    _walletListItemBase = _walletProvider.getWalletById(_walletId);
  }

  double? get recommendFeeRate => _recommendedFeeRate;
  String? get recommendFeeRateDescription => _recommendedFeeRateDescription;

  // Utxo? get currentUtxo => _currentUtxo;
  List<FeeInfoWithLevel> get feeInfos => _feeInfos;
  bool? get didFetchRecommendedFeesSuccessfully => _isFeeFetchSuccess;
  bool? get isInitializedSuccess => _isInitializedSuccess;
  bool get isNetworkOn => _isNetworkOn == true;

  TransactionRecord get transaction => _pendingTx;
  int get walletId => _walletId;

  WalletListItemBase get walletListItemBase => _walletListItemBase;

  bool _insufficientUtxos = false;
  bool get insufficientUtxos => _insufficientUtxos;

  Future<void> initialize() async {
    await _fetchRecommendedFees(); // _isFeeFetchSuccess로 성공 여부 기록함
    if (_isFeeFetchSuccess == true) {
      await initializeBumpingTransaction(_feeInfos[2].satsPerVb!.toDouble());
      if (_bumpingTransaction == null) {
        _isInitializedSuccess = false;
        return;
      }
      _recommendedFeeRate = _getRecommendedFeeRate(_bumpingTransaction!);
      _recommendedFeeRateDescription = _type == FeeBumpingType.cpfp
          ? _getRecommendedFeeRateDescriptionForCpfp()
          : t.transaction_fee_bumping_screen.recommend_fee_info_rbf;
      _isInitializedSuccess = true;
    } else {
      _isInitializedSuccess = false;
    }
    notifyListeners();
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
    assert(_bumpingTransaction != null);
    try {
      await initializeBumpingTransaction(newTxFeeRate);
      _updateSendInfoProvider(newTxFeeRate, _type);
      return true;
    } catch (e) {
      return false;
    }
  }

  // 수수료 입력 시 예상 총 수수료 계산
  int getTotalEstimatedFee(double newFeeRate) {
    assert(_bumpingTransaction != null);

    if (newFeeRate == 0) {
      return 0;
    }

    return _bumpingTransaction != null
        ? (_estimateVirtualByte(_bumpingTransaction!) * newFeeRate).ceil().toInt()
        : 0;
  }

  void _updateSendInfoProvider(double newTxFeeRate, FeeBumpingType feeBumpingType) {
    _sendInfoProvider.setWalletId(_walletId);
    _sendInfoProvider.setIsMultisig(_walletListItemBase.walletType == WalletType.multiSignature);
    _sendInfoProvider.setTxWaitingForSign(
        Psbt.fromTransaction(_bumpingTransaction!, _walletListItemBase.walletBase).serialize());
    _sendInfoProvider.setFeeBumpfingType(feeBumpingType);
    _sendInfoProvider.setWalletImportSource(_walletListItemBase.walletImportSource);
  }

  void setIsNetworkOn(bool? isNetworkOn) {
    _isNetworkOn = isNetworkOn;
    notifyListeners();
  }

  // 새 수수료로 트랜잭션 생성
  Future<void> initializeBumpingTransaction(double newFeeRate) async {
    if (_type == FeeBumpingType.cpfp) {
      await _initializeCpfpTransaction(newFeeRate);
    } else if (_type == FeeBumpingType.rbf) {
      await _initializeRbfTransaction(newFeeRate);
    }
  }

  Future<void> _initializeRbfTransaction(double newFeeRate) async {
    final rbfBuilder = RbfBuilder(
      _walletProvider.containsAddress,
      _walletProvider.getChangeAddress,
      _nodeProvider.getTransaction,
      _addressRepository.getDerivationPath,
      _utxoRepository.getUtxosByStatus,
      _utxoRepository.getUtxoState,
      _pendingTx,
      _walletId,
      newFeeRate,
      _walletListItemBase,
    );

    // RbfBuilder를 사용하여 RBF 트랜잭션 초기화
    final rbfResult = await rbfBuilder.build();

    if (rbfResult != null) {
      _bumpingTransaction = rbfResult.transaction;

      // 트랜잭션 타입에 따라 _sendInfoProvider 설정
      switch (rbfResult.type) {
        case TransactionType.single:
          if (rbfResult.amount != null) {
            _sendInfoProvider
                .setAmount(UnitUtil.convertSatoshiToBitcoin(rbfResult.amount!.toInt()));
          }
          _sendInfoProvider.setIsMaxMode(false);
          break;
        case TransactionType.sweep:
          if (rbfResult.recipientAddress != null) {
            _sendInfoProvider.setRecipientAddress(rbfResult.recipientAddress!);
          }
          _sendInfoProvider.setIsMaxMode(true);
          break;
        case TransactionType.batch:
          if (rbfResult.recipientsForBatch != null) {
            _sendInfoProvider.setRecipientsForBatch(rbfResult.recipientsForBatch!);
          }
          _sendInfoProvider.setIsMaxMode(false);
          break;
      }
    }

    // RbfBuilder의 insufficientUtxos 상태를 FeeBumpingViewModel에 반영
    _setInsufficientUtxo(rbfBuilder.insufficientUtxos);
  }

  Future<void> _initializeCpfpTransaction(double newFeeRate) async {
    final cpfpBuilder = CpfpBuilder(
      _walletProvider.containsAddress,
      _walletProvider.getReceiveAddress,
      _pendingTx,
      _walletId,
      newFeeRate,
      _utxoRepository,
      _walletListItemBase,
    );

    // CpfpBuilder를 사용하여 CPFP 트랜잭션 초기화
    final cpfpResult = await cpfpBuilder.build();

    if (cpfpResult != null) {
      _bumpingTransaction = cpfpResult.transaction;

      // CPFP 트랜잭션에 따라 _sendInfoProvider 설정
      _sendInfoProvider.setRecipientAddress(cpfpResult.recipientAddress);
      _sendInfoProvider.setIsMaxMode(true);
      _sendInfoProvider.setAmount(UnitUtil.convertSatoshiToBitcoin(cpfpResult.amount.toInt()));
    }

    // CpfpBuilder의 insufficientUtxos 상태를 FeeBumpingViewModel에 반영
    _setInsufficientUtxo(cpfpBuilder.insufficientUtxos);
  }

  void _setInsufficientUtxo(bool value) {
    _insufficientUtxos = value;
    notifyListeners();
  }

  // 노드 프로바이더에서 추천 수수료 조회
  Future<void> _fetchRecommendedFees() async {
    final recommendedFees = await getRecommendedFees(_nodeProvider);

    // TODO: 테스트 코드 - 추천수수료 mock
    // final recommendedFees = await DioClient().getRecommendedFee();

    _feeInfos[0].satsPerVb = recommendedFees.fastestFee.toDouble();
    _feeInfos[1].satsPerVb = recommendedFees.halfHourFee.toDouble();
    _feeInfos[2].satsPerVb = recommendedFees.hourFee.toDouble();
    _isFeeFetchSuccess = true;
  }

  // 추천 수수료
  double _getRecommendedFeeRate(Transaction transaction) {
    if (_type == FeeBumpingType.cpfp) {
      return _getRecommendedFeeRateForCpfp(transaction);
    }
    return _getRecommendedFeeRateForRbf(transaction);
  }

  double _getRecommendedFeeRateForCpfp(Transaction transaction) {
    final recommendedFeeRate = _feeInfos[2].satsPerVb; // 느린 수수료

    if (recommendedFeeRate == null) {
      return 0;
    }
    if (recommendedFeeRate < _pendingTx.feeRate) {
      return _pendingTx.feeRate;
    }

    double cpfpTxSize = _estimateVirtualByte(transaction);
    double totalFee = (_pendingTx.vSize + cpfpTxSize) * recommendedFeeRate;
    double cpfpTxFee = totalFee - _pendingTx.fee.toDouble();
    double cpfpTxFeeRate = cpfpTxFee / cpfpTxSize;

    if (cpfpTxFeeRate < recommendedFeeRate || cpfpTxFeeRate < 0) {
      return (recommendedFeeRate * 100).ceilToDouble() / 100;
    }

    return (cpfpTxFeeRate * 100).ceilToDouble() / 100;
  }

  /// 새로운 트랜잭션이 기존 트랜잭션보다 추가 지불하는 수수료양이 "새로운 트랜잭션 크기"이상이어야 합니다.
  /// 그렇지 않으면 브로드캐스팅 실패합니다.
  double _getRecommendedFeeRateForRbf(Transaction transaction) {
    final recommendedFeeRate = _feeInfos[2].satsPerVb; // 느린 수수료

    if (recommendedFeeRate == null) {
      return 0;
    }

    double estimatedVirtualByte = _estimateVirtualByte(transaction);
    double minimumRequiredFee = _pendingTx.fee.toDouble() + estimatedVirtualByte;
    // double mempoolRecommendedFee = estimatedVirtualByte * recommendedFeeRate;

    // if (mempoolRecommendedFee < minimumRequiredFee) {
    double feePerVByte = minimumRequiredFee / estimatedVirtualByte;
    double roundedFee = (feePerVByte * 100).ceilToDouble() / 100;

    // 계산된 추천 수수료가 현재 멤풀 수수료보다 작은 경우, 기존 수수료보다 1s/vb 높은 수수료로 설정
    // FYI, 이 조건에서 트랜잭션이 이미 처리되었을 것이므로 메인넷에서는 거의 발생 확률이 낮음
    // if (feePerVByte < _pendingTx.feeRate) {
    // roundedFee = ((_pendingTx.feeRate + 1) * 100).ceilToDouble() / 100;
    // }
    return double.parse((roundedFee).toStringAsFixed(2));
    // }

    // return recommendedFeeRate.toDouble();
  }

  double _estimateVirtualByte(Transaction transaction) {
    return TransactionUtil.estimateVirtualByteByWallet(walletListItemBase, transaction);
  }

  String _getRecommendedFeeRateDescriptionForCpfp() {
    assert(_recommendedFeeRate != null);
    assert(_bumpingTransaction != null);

    final recommendedFeeRate = _recommendedFeeRate!;
    // 추천 수수료가 현재 수수료보다 작은 경우
    // FYI, 이 조건에서 트랜잭션이 이미 처리되었을 것이므로 메인넷에서는 발생하지 않는 상황
    // 하지만, regtest에서 임의로 마이닝을 중지하는 경우 발생하여 예외 처리
    // 예) (pending tx fee rate) = 4 s/vb, (recommended fee rate) = 1 s/vb
    if (recommendedFeeRate < _pendingTx.feeRate) {
      return t.transaction_fee_bumping_screen.recommended_fee_less_than_pending_tx_fee;
    }

    final cpfpTxSize = _estimateVirtualByte(_bumpingTransaction!);
    final cpfpTxFee = cpfpTxSize * recommendedFeeRate;
    final cpfpTxFeeRate = cpfpTxFee / cpfpTxSize;
    final totalRequiredFee =
        _pendingTx.vSize * _pendingTx.feeRate + cpfpTxSize * recommendedFeeRate;

    if (cpfpTxFeeRate < recommendedFeeRate || cpfpTxFeeRate < 0) {
      return t.transaction_fee_bumping_screen.recommended_fee_less_than_network_fee;
    }

    String inequalitySign = cpfpTxFeeRate % 1 == 0 ? "=" : "≈";
    return t.transaction_fee_bumping_screen.recommend_fee_info_cpfp(
      newTxSize: _formatNumber(cpfpTxSize),
      recommendedFeeRate: _formatNumber(recommendedFeeRate),
      originalTxSize: _formatNumber(_pendingTx.vSize.toDouble()),
      originalFee: _formatNumber((_pendingTx.fee).toDouble()),
      totalRequiredFee: _formatNumber(totalRequiredFee.toDouble()),
      newTxFee: _formatNumber(cpfpTxFee),
      newTxFeeRate: _formatNumber(cpfpTxFeeRate),
      inequalitySign: inequalitySign,
    );
  }

  String _formatNumber(double value) {
    return value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(2);
  }
}
