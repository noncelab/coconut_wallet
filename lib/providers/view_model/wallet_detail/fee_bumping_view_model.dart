import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/transaction_enums.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/send/fee_info.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
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

  double get recommendFeeRate => _getRecommendedFeeRate();
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
      double newTxFeeRate, FeeBumpingType feeBumpingType) async {
    _generateTransaction(newTxFeeRate.toDouble());
    if (_bumpingTransaction != null) {
      _updateSendInfoProvider(newTxFeeRate, feeBumpingType);

      return Psbt.fromTransaction(
              _bumpingTransaction!, walletListItemBase.walletBase)
          .serialize();
    }

    return '';
  }

  // 수수료 입력 시 예상 총 수수료 계산
  int getTotalEstimatedFee(double newFeeRate) {
    if (newFeeRate == 0) {
      return 0;
    }
    if (_bumpingTransaction == null) {
      _generateTransaction(newFeeRate.toDouble());
    }

    double estimatedVirtualByte = _estimateVirtualByte(_bumpingTransaction!);

    return (estimatedVirtualByte * newFeeRate).ceil();
  }

  void _onFeeUpdated() {
    if (feeInfos[1].satsPerVb != null) {
      Logger.log('현재 수수료(보통) 업데이트 됨 >> ${feeInfos[1].satsPerVb}');
      _generateTransaction(feeInfos[1].satsPerVb!.toDouble());
    } else {
      _fetchRecommendedFees();
    }
  }

  void _updateSendInfoProvider(
      double newTxFeeRate, FeeBumpingType feeBumpingType) {
    bool isMultisig =
        walletListItemBase.walletType == WalletType.multiSignature;
    _sendInfoProvider.setWalletId(_walletId);
    _sendInfoProvider.setIsMultisig(isMultisig);
    _sendInfoProvider.setFeeRate(newTxFeeRate.toInt()); // fixme
    _sendInfoProvider.setTxWaitingForSign(Psbt.fromTransaction(
            _bumpingTransaction!, walletListItemBase.walletBase)
        .serialize());
    _sendInfoProvider.setFeeBumptingType(feeBumpingType);

    // fixme: transaction.amount는 sat 단위 _sendInfoProvider.setAmount는 btc 단위 의도
    // 문제가 없는 것으로 보아 send flow에서 사용되지 않는 것으로 추측됨
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
    _generateTransaction(_feeInfos[1].satsPerVb!.toDouble());
    notifyListeners();
  }

  // 새 수수료로 트랜잭션 생성
  void _generateTransaction(double newFeeRate) {
    if (hasTransactionConfirmed()) return;
    if (_type == FeeBumpingType.cpfp) {
      _generateCpfpTransaction(newFeeRate);
    } else if (_type == FeeBumpingType.rbf) {
      _generateRbfTransaction(newFeeRate);
    }
  }

  // cpfp 트랜잭션 만들기
  void _generateCpfpTransaction(double newFeeRate) {
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
  void _generateRbfTransaction(double newFeeRate) {
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
    List<Utxo> utxoList =
        _getUtxoListForRbf(transaction.inputAddressList); // pending tx의 input

    double inputSum = utxoList.fold(0, (sum, utxo) => sum + utxo.amount);
    double outputSum = amount + _transaction.vSize * newFeeRate;

    if (inputSum < outputSum) {
      // recipient가 내 주소인 경우 amount 조정
      if (_walletProvider.containsAddress(_walletId, recipientAddress)) {
        amount = (inputSum - _transaction.vSize * newFeeRate).toInt();
        debugPrint('amount 조정됨 $amount');
      } else {
        // repicient가 다른 주소인 경우 utxo 추가
        // todo: utxo lock 기능 추가 시 utxo 제외 로직 필요
        final utxoStateList =
            _utxoRepository.getUtxosByStatus(_walletId, UtxoStatus.unspent);
        if (utxoStateList.isNotEmpty) {
          utxoStateList.sort((a, b) => a.amount.compareTo(b.amount));
          final utxo = utxoStateList[0];
          utxoList.add(Utxo(
            utxo.transactionHash,
            utxo.index,
            utxo.amount,
            _addressRepository.getDerivationPath(_walletId, utxo.to),
          ));
          debugPrint('utxo 추가됨 : utxo id${utxo.transactionHash}:${utxo.index}');
          changeAddress = _walletProvider.getChangeAddress(_walletId).address;
        }
      }
    }

    if (_getTransactionType() == TransactionType.forSweep &&
        changeAddress.isEmpty) {
      _bumpingTransaction = Transaction.forSweep(utxoList, recipientAddress,
          newFeeRate, walletListItemBase.walletBase);
      _sendInfoProvider.setRecipientAddress(recipientAddress);
      _sendInfoProvider.setIsMaxMode(true);
      return;
    }

    if (changeAddress.isEmpty) {
      changeAddress = _walletProvider.getChangeAddress(_walletId).address;
    }

    switch (_getTransactionType()) {
      case TransactionType.forSweep:
      case TransactionType.forSinglePayment:
        _bumpingTransaction = Transaction.forSinglePayment(
            utxoList,
            recipientAddress,
            _addressRepository.getDerivationPath(_walletId, changeAddress),
            amount,
            newFeeRate,
            walletListItemBase.walletBase);
        _sendInfoProvider.setRecipientAddress(recipientAddress);
        _sendInfoProvider.setIsMaxMode(false);
        break;
      case TransactionType.forBatchPayment:
        Map<String, int> paymentMap =
            _createPaymentMapForRbfBatchTx(transaction.outputAddressList);

        _bumpingTransaction = Transaction.forBatchPayment(utxoList, paymentMap,
            changeAddress, newFeeRate, walletListItemBase.walletBase);

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
  double _getRecommendedFeeRate() {
    if (_type == FeeBumpingType.cpfp) {
      return _getRecommendedFeeRateForCpfp();
    }
    return _getRecommendedFeeRateForRbf();
  }

  double _getRecommendedFeeRateForCpfp() {
    final recommendedFeeRate = _feeInfos[1].satsPerVb; // 보통 수수료

    if (recommendedFeeRate == null) {
      return 0;
    }

    _generateCpfpTransaction(recommendedFeeRate.toDouble());

    double cpfpTxSize = _estimateVirtualByte(_bumpingTransaction!);
    double totalFee = (_transaction.vSize + cpfpTxSize) * recommendedFeeRate;
    double cpfpTxFee = totalFee - _transaction.fee!.toDouble();
    double cpfpTxFeeRate = cpfpTxFee / cpfpTxSize;

    if (recommendedFeeRate < _transaction.feeRate + 0.1) {
      return _transaction.feeRate + 0.1;
    }
    if (cpfpTxFeeRate < recommendedFeeRate || cpfpTxFeeRate < 0) {
      return recommendedFeeRate.toDouble();
    }

    return cpfpTxFeeRate;
  }

  double _getRecommendedFeeRateForRbf() {
    final recommendedFeeRate = _feeInfos[2].satsPerVb; // 느린 수수료

    if (recommendedFeeRate == null) {
      return 0;
    }

    double temporalFeeRate = _transaction.feeRate + 1;

    _generateRbfTransaction(temporalFeeRate); // 임시 최소 수수료율로 트랜잭션 생성

    double estimatedVirtualByte = _estimateVirtualByte(_bumpingTransaction!);
    double expectedFee = _transaction.fee!.toDouble() + estimatedVirtualByte;

    double requiredFee = estimatedVirtualByte * temporalFeeRate;

    if (requiredFee < expectedFee) {
      return double.parse(
          (expectedFee / estimatedVirtualByte).toStringAsFixed(2));
    }

    return double.parse(temporalFeeRate.toStringAsFixed(2));
  }

  double _estimateVirtualByte(Transaction transaction) {
    double estimatedVirtualByte;
    switch (_walletListItemBase.walletType) {
      case WalletType.singleSignature:
        estimatedVirtualByte =
            transaction.estimateVirtualByte(AddressType.p2wpkh);
        break;
      case WalletType.multiSignature:
        final multisigWallet =
            _walletListItemBase.walletBase as MultisignatureWallet;
        estimatedVirtualByte = transaction.estimateVirtualByte(
            AddressType.p2wsh,
            requiredSignature: multisigWallet.requiredSignature,
            totalSigner: multisigWallet.totalSigner);
        break;
      default:
        throw Exception('Unknown wallet type');
    }
    return estimatedVirtualByte;
  }

  String _getRecommendedFeeRateDescriptionForCpfp() {
    final recommendedFeeRate = _feeInfos[1].satsPerVb; // 보통 수수료

    if (recommendedFeeRate == null) {
      return t.transaction_fee_bumping_screen.recommended_fees_is_null;
    }

    if (recommendedFeeRate < _transaction.feeRate) {
      return t.transaction_fee_bumping_screen
          .recommended_fee_less_than_pending_tx_fee;
    }

    _generateCpfpTransaction(recommendedFeeRate.toDouble());

    final cpfpTxSize = _estimateVirtualByte(_bumpingTransaction!);
    final cpfpTxFee = cpfpTxSize * recommendedFeeRate;
    final cpfpTxFeeRate = cpfpTxFee / cpfpTxSize;
    final totalRequiredFee = _transaction.vSize * _transaction.feeRate +
        cpfpTxSize * recommendedFeeRate;

    if (cpfpTxFeeRate < recommendedFeeRate || cpfpTxFeeRate < 0) {
      return t
          .transaction_fee_bumping_screen.recommended_fee_less_than_network_fee;
    }

    String inequalitySign = cpfpTxFeeRate % 1 == 0 ? "=" : "≈";
    return t.transaction_fee_bumping_screen.recommend_fee_info_cpfp(
      newTxSize: _formatNumber(cpfpTxSize),
      recommendedFeeRate: _formatNumber(_getRecommendedFeeRate().toDouble()),
      originalTxSize: _formatNumber(_getRecommendedFeeRate().toDouble()),
      originalFee: _formatNumber((_transaction.fee ?? 0).toDouble()),
      totalRequiredFee: _formatNumber(totalRequiredFee.toDouble()),
      newTxFee: _formatNumber(cpfpTxFee),
      newTxFeeRate: _formatNumber(cpfpTxFeeRate),
      inequalitySign: inequalitySign,
    );
  }

  String _formatNumber(double value) {
    return value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(1);
  }
}
