import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/transaction_enums.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/send/fee_info.dart';
import 'package:coconut_wallet/model/wallet/transaction_address.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/providers/transaction_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/repository/realm/address_repository.dart';
import 'package:coconut_wallet/repository/realm/utxo_repository.dart';
import 'package:coconut_wallet/screens/wallet_detail/transaction_fee_bumping_screen.dart';
import 'package:coconut_wallet/utils/derivation_path_util.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:flutter/material.dart';

enum TransactionType {
  forSweep,
  forSinglePayment,
  forBatchPayment,
}

class FeeBumpingViewModel extends ChangeNotifier {
  final FeeBumpingType _type;
  final TransactionRecord _transaction;
  final NodeProvider _nodeProvider;
  final WalletProvider _walletProvider;
  final SendInfoProvider _sendInfoProvider;
  final TransactionProvider _txProvider;
  final AddressRepository _addressRepository;
  final UtxoRepository _utxoRepository;
  final int _walletId;
  late Transaction? _bumpingTransaction;

  final List<FeeInfoWithLevel> _feeInfos = [
    FeeInfoWithLevel(level: TransactionFeeLevel.fastest),
    FeeInfoWithLevel(level: TransactionFeeLevel.halfhour),
    FeeInfoWithLevel(level: TransactionFeeLevel.hour),
  ];
  bool _didFetchRecommendedFeesSuccessfully =
      true; // 화면이 전환되는 시점에 순간적으로 수수료 조회 실패가 뜨는것 처럼 보이기 때문에 기본값을 true 설정

  late WalletListItemBase _walletListItemBase;
  FeeBumpingViewModel(
    this._type,
    this._transaction,
    this._walletId,
    this._nodeProvider,
    this._sendInfoProvider,
    this._txProvider,
    this._walletProvider,
    this._addressRepository,
    this._utxoRepository,
  ) {
    _walletListItemBase = _walletProvider.getWalletById(_walletId);
    _fetchRecommendedFees(); // 현재 수수료 조회
  }

  int get recommendFeeRate => _getRecommendedFeeRate();
  String get recommendFeeRateDescription => _type == FeeBumpingType.cpfp
      ? _getRecommendedFeeRateDescriptionForCpfp()
      : t.transaction_fee_bumping_screen.recommend_fee_info_rbf;

  // Utxo? get currentUtxo => _currentUtxo;
  List<FeeInfoWithLevel> get feeInfos => _feeInfos;
  bool get didFetchRecommendedFeesSuccessfully =>
      _didFetchRecommendedFeesSuccessfully;

  TransactionRecord get transaction => _transaction;
  int get walletId => _walletId;

  WalletListItemBase get walletListItemBase => _walletListItemBase;

  void updateProvider() {
    _onFeeUpdated();
    notifyListeners();
  }

  // pending상태였던 Tx가 confirmed 되었는지 조회
  bool hasTransactionConfirmed() {
    TransactionRecord? tx = _txProvider.getTransactionRecord(
        _walletId, transaction.transactionHash);
    if (tx == null || tx.blockHeight! <= 0) return false;
    return true;
  }

  // unsinged psbt 생성
  Future<String> generateUnsignedPsbt(
      int newTxFeeRate, FeeBumpingType feeBumpingType) async {
    _generateTransaction(newTxFeeRate);
    if (_bumpingTransaction != null) {
      _updateSendInfoProvider(newTxFeeRate, feeBumpingType);

      return Psbt.fromTransaction(
              _bumpingTransaction!, walletListItemBase.walletBase)
          .serialize();
    }

    return '';
  }

  // 수수료 입력 시 예상 총 수수료 계산
  int getTotalEstimatedFee(int newFeeRate) {
    if (newFeeRate == 0) {
      return 0;
    }
    if (_bumpingTransaction == null) {
      _generateTransaction(newFeeRate);
    }

    if (_type == FeeBumpingType.rbf) {
      return (_transaction.vSize * newFeeRate).ceil();
    } else {
      return (_bumpingTransaction!.getVirtualByte() * newFeeRate).ceil();
    }
  }

  void _onFeeUpdated() {
    if (feeInfos[1].satsPerVb != null) {
      Logger.log('현재 수수료(보통) 업데이트 됨 >> ${feeInfos[1].satsPerVb}');
      _generateTransaction(feeInfos[1].satsPerVb!);
    } else {
      _fetchRecommendedFees();
    }
  }

  void _updateSendInfoProvider(
      int newTxFeeRate, FeeBumpingType feeBumpingType) {
    debugPrint('updateSendInfoProvider');
    bool isMultisig =
        walletListItemBase.walletType == WalletType.multiSignature;
    _sendInfoProvider.setWalletId(_walletId);
    _sendInfoProvider.setIsMultisig(isMultisig);
    _sendInfoProvider.setFeeRate(newTxFeeRate);
    _sendInfoProvider.setTxWaitingForSign(Psbt.fromTransaction(
            _bumpingTransaction!, walletListItemBase.walletBase)
        .serialize());
    _sendInfoProvider.setFeeBumptingType(feeBumpingType);

    if (_type == FeeBumpingType.rbf) {
      _sendInfoProvider.setAmount(_transaction.amount!.toDouble());
    } else {
      _sendInfoProvider
          .setAmount(_bumpingTransaction!.outputs[0].amount.toDouble());
    }
  }

  TransactionType? _getTransactionType() {
    int inputCount = transaction.inputAddressList.length;
    int outputCount = transaction.outputAddressList.length;

    if (inputCount >= 1 && outputCount == 1) {
      return TransactionType.forSweep; // 여러 개의 UTXO를 하나의 주소로 보내는 경우
    } else if (inputCount >= 1 && outputCount == 2) {
      return TransactionType.forSinglePayment; // 하나의 수신자 + 잔돈 주소
    } else if (inputCount >= 1 && outputCount > 2) {
      return TransactionType.forBatchPayment; // 여러 개의 수신자가 있는 경우
    }

    return null;
  }

  // 노드 프로바이더에서 추천 수수료 조회
  Future<void> _fetchRecommendedFees() async {
    final recommendedFeesResult = await _nodeProvider.getRecommendedFees();
    if (recommendedFeesResult.isFailure) {
      _didFetchRecommendedFeesSuccessfully = false;
      notifyListeners();
      return;
    }

    final recommendedFees = recommendedFeesResult.value;

    _feeInfos[0].satsPerVb = recommendedFees.fastestFee;
    _feeInfos[1].satsPerVb = recommendedFees.halfHourFee;
    _feeInfos[2].satsPerVb = recommendedFees.hourFee;
    _didFetchRecommendedFeesSuccessfully = true;
    _generateTransaction(_feeInfos[1].satsPerVb!);
    notifyListeners();
  }

  // 새 수수료로 트랜잭션 생성
  void _generateTransaction(int newFeeRate) {
    if (hasTransactionConfirmed()) return;
    if (_type == FeeBumpingType.cpfp) {
      _generateCpfpTransaction(newFeeRate);
    } else if (_type == FeeBumpingType.rbf) {
      _generateRbfTransaction(newFeeRate);
    }
  }

  // cpfp 트랜잭션 만들기
  void _generateCpfpTransaction(int newFeeRate) {
    if (newFeeRate == 0) {
      newFeeRate = _getRecommendedFeeRate();
    }

    // output에서 내 주소 찾기
    final myAddressList = _transaction.outputAddressList.where(
        (output) => _walletProvider.containsAddress(_walletId, output.address));

    // 내 주소와 일치하는 utxo 찾기
    List<Utxo> utxoList = [];
    for (var address in myAddressList) {
      final utxoStateList = _utxoRepository.getUtxoStateList(_walletId);
      for (var utxoState in utxoStateList) {
        if (address.address == utxoState.to) {
          var utxo = Utxo(
            utxoState.transactionHash,
            utxoState.index,
            utxoState.amount,
            _addressRepository.getDerivationPath(_walletId, address.address),
          );
          utxoList.add(utxo);
        }
      }
    }

    assert(utxoList.isNotEmpty);

    // Transaction 생성
    final recipient = _walletProvider.getReceiveAddress(_walletId).address;
    _bumpingTransaction = Transaction.forSweep(
        utxoList, recipient, newFeeRate, walletListItemBase.walletBase);
    _sendInfoProvider.setRecipientAddress(recipient);
    _sendInfoProvider.setIsMaxMode(true);
  }

  // rbf 트랜잭션 만들기
  void _generateRbfTransaction(int newFeeFate) {
    var changeAddress = '';
    var recipientAddress = '';
    var amount = 0;

    // output 정보 추출
    if (_transaction.transactionType == 'SELF') {
      _extractSelfTxData(transaction.outputAddressList,
          onChangeAddressFound: (address) => changeAddress = address,
          onRecipientAddressAndAmountFound: (transactionAddress) {
            recipientAddress = transactionAddress.address;
            amount = transactionAddress.amount;
          });
    } else {
      recipientAddress = transaction.outputAddressList
          .map((e) => e.address)
          .firstWhere((address) =>
              !_walletProvider.containsAddress(_walletId, address));
      amount = transaction.outputAddressList
          .firstWhere((output) => output.address == recipientAddress)
          .amount;
      changeAddress = transaction.outputAddressList
          .map((e) => e.address)
          .firstWhere(
              (address) => _walletProvider.containsAddress(_walletId, address));
    }

    // input 정보 추출
    List<Utxo> utxoList = _getUtxoListForRbf(transaction.inputAddressList);

    // transaction type에 따라 트랜잭션
    switch (_getTransactionType()) {
      case TransactionType.forSweep:
        _bumpingTransaction = Transaction.forSweep(utxoList, recipientAddress,
            newFeeFate, walletListItemBase.walletBase);
        _sendInfoProvider.setRecipientAddress(recipientAddress);
        _sendInfoProvider.setIsMaxMode(true);
        break;
      case TransactionType.forSinglePayment:
        _bumpingTransaction = Transaction.forSinglePayment(
            utxoList,
            recipientAddress,
            _addressRepository.getDerivationPath(_walletId, changeAddress),
            amount,
            newFeeFate,
            walletListItemBase.walletBase);
        _sendInfoProvider.setRecipientAddress(recipientAddress);
        _sendInfoProvider.setIsMaxMode(false);
        break;
      case TransactionType.forBatchPayment:
        Map<String, int> paymentMap =
            _createPaymentMapForRbfBatchTx(transaction.outputAddressList);

        _bumpingTransaction = Transaction.forBatchPayment(utxoList, paymentMap,
            changeAddress, newFeeFate, walletListItemBase.walletBase);

        _sendInfoProvider.setRecipientsForBatch(
            paymentMap.map((key, value) => MapEntry(key, value.toDouble())));
        _sendInfoProvider.setIsMaxMode(false);
        break;
      default:
        break;
    }
  }

  Map<String, int> _createPaymentMapForRbfBatchTx(
      List<TransactionAddress> outputAddressList) {
    Map<String, int> paymentMap = {};

    for (TransactionAddress addressInfo in outputAddressList) {
      paymentMap[addressInfo.address] = addressInfo.amount;
    }

    return paymentMap;
  }

  List<Utxo> _getUtxoListForRbf(List<TransactionAddress> inputAddressList) {
    List<Utxo> utxoList = [];

    for (var inputAddress in inputAddressList) {
      var derivationPath =
          _addressRepository.getDerivationPath(_walletId, inputAddress.address);

      final utxoStateList = _utxoRepository.getUtxoStateList(_walletId);
      for (var utxoState in utxoStateList) {
        if (inputAddress.address == utxoState.to &&
            inputAddress.amount == utxoState.amount) {
          Utxo utxo = Utxo(
            utxoState.transactionHash,
            utxoState.index,
            utxoState.amount,
            derivationPath,
          );

          debugPrint('utxo add!!');
          utxoList.add(utxo);
        }
      }
    }

    return utxoList;
  }

  void _extractSelfTxData(List<TransactionAddress> outputs,
      {required Function(String) onChangeAddressFound,
      required Function(TransactionAddress) onRecipientAddressAndAmountFound}) {
    for (var address in outputs.where(
        (addr) => _walletProvider.containsAddress(walletId, addr.address))) {
      bool isChange = DerivationPathUtil.isChangeAddress(
          _addressRepository.getDerivationPath(_walletId, address.address));
      if (isChange) {
        onChangeAddressFound(address.address);
      } else {
        onRecipientAddressAndAmountFound(address);
      }
    }
  }

  // 추천 수수료
  int _getRecommendedFeeRate() {
    if (_type == FeeBumpingType.cpfp) {
      return _getRecommendedFeeRateForCpfp();
    }
    return _getRecommendedFeeRateForRbf();
  }

  int _getRecommendedFeeRateForCpfp() {
    final recommendedFeeRate = _feeInfos[1].satsPerVb; // 보통 수수료

    if (recommendedFeeRate == null) {
      return 0;
    }

    if (recommendedFeeRate <= _transaction.feeRate) {
      return _transaction.feeRate.toInt() + 1;
    }

    return recommendedFeeRate;
  }

  int _getRecommendedFeeRateForRbf() {
    final recommendedFeeRate = _feeInfos[2].satsPerVb; // 느린 수수료

    if (recommendedFeeRate == null) {
      return 0;
    }

    if (_transaction.feeRate + 1 > recommendedFeeRate) {
      return _transaction.feeRate.toInt() + 1;
    }

    return recommendedFeeRate;
  }

  String _getRecommendedFeeRateDescriptionForCpfp() {
    final recommendedFeeRate = _feeInfos[1].satsPerVb;

    if (recommendedFeeRate == null) {
      return t.transaction_fee_bumping_screen.recommended_fees_is_null;
    }
    if (recommendedFeeRate > _transaction.feeRate) {
      return t.transaction_fee_bumping_screen
          .recommended_fee_less_than_pending_tx_fee;
    }

    _generateCpfpTransaction(recommendedFeeRate);

    final cpfpTxSize = _bumpingTransaction!.getVirtualByte();
    final cpfpTxFee = cpfpTxSize * recommendedFeeRate;
    final cpfpTxFeeRate = cpfpTxFee / cpfpTxSize;
    final totalRequiredFee = _transaction.vSize * _transaction.feeRate +
        cpfpTxSize * recommendedFeeRate;

    String inequalitySign = cpfpTxFeeRate % 1 == 0 ? "=" : "≈";

    return t.transaction_fee_bumping_screen.recommend_fee_info_cpfp
        .replaceAll("{newTxSize}", _formatNumber(cpfpTxSize))
        .replaceAll("{recommendedFeeRate}",
            _formatNumber(_getRecommendedFeeRate().toDouble()))
        .replaceAll(
            "{originalTxSize}", _formatNumber(_transaction.vSize.toDouble()))
        .replaceAll(
            "{originalFee}", _formatNumber((_transaction.fee ?? 0).toDouble()))
        .replaceAll(
            "{totalRequiredFee}", _formatNumber(totalRequiredFee.toDouble()))
        .replaceAll("{newTxFee}", _formatNumber(cpfpTxFee))
        .replaceAll("{newTxFeeRate}", _formatNumber(cpfpTxFeeRate))
        .replaceAll("{inequalitySign}", inequalitySign);
  }

  String _formatNumber(double value) {
    return value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(1);
  }
}
