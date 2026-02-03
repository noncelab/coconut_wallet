import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/constants/bitcoin_network_rules.dart';
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
import 'package:coconut_wallet/repository/realm/service/realm_id_service.dart';
import 'package:coconut_wallet/repository/realm/utxo_repository.dart';
import 'package:coconut_wallet/screens/wallet_detail/transaction_fee_bumping_screen.dart';
import 'package:coconut_wallet/services/fee_service.dart';
import 'package:coconut_wallet/services/model/response/recommended_fee.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:coconut_wallet/utils/coconut_lib_exception_parser.dart';
import 'package:coconut_wallet/utils/transaction_util.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

enum PaymentType { sweep, singlePayment, batchPayment }

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
      _recommendedFeeRateDescription =
          _type == FeeBumpingType.cpfp
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

    return _bumpingTransaction != null ? (_estimateVirtualByte(_bumpingTransaction!) * newFeeRate).ceil().toInt() : 0;
  }

  void _updateSendInfoProvider(double newTxFeeRate, FeeBumpingType feeBumpingType) {
    _sendInfoProvider.setWalletId(_walletId);
    _sendInfoProvider.setIsMultisig(_walletListItemBase.walletType == WalletType.multiSignature);
    _sendInfoProvider.setTxWaitingForSign(
      Psbt.fromTransaction(_bumpingTransaction!, _walletListItemBase.walletBase).serialize(),
    );
    _sendInfoProvider.setFeeBumpfingType(feeBumpingType);
    _sendInfoProvider.setWalletImportSource(_walletListItemBase.walletImportSource);
  }

  void setIsNetworkOn(bool? isNetworkOn) {
    _isNetworkOn = isNetworkOn;
    notifyListeners();
  }

  List<TransactionAddress> _getExternalOutputs() =>
      _pendingTx.outputAddressList
          .where((output) => !_walletProvider.containsAddress(_walletId, output.address, isChange: true))
          .toList();

  List<TransactionAddress> _getMyOutputs() =>
      _pendingTx.outputAddressList
          .where((output) => _walletProvider.containsAddress(_walletId, output.address))
          .toList();

  PaymentType? _getPaymentType() {
    int inputCount = _pendingTx.inputAddressList.length;
    int outputCount = _pendingTx.outputAddressList.length;

    if (inputCount == 0 || outputCount == 0) {
      return null; // wrong tx
    }

    final externalOutputs = _getExternalOutputs();

    switch (outputCount) {
      case 1:
        return PaymentType.sweep;
      case 2:
        if (externalOutputs.length == 1) {
          return PaymentType.singlePayment;
        }
      default:
        return PaymentType.batchPayment;
    }

    return null;
  }

  // 새 수수료로 트랜잭션 생성
  Future<void> initializeBumpingTransaction(double newFeeRate) async {
    if (_type == FeeBumpingType.cpfp) {
      _initializeCpfpTransaction(newFeeRate);
    } else if (_type == FeeBumpingType.rbf) {
      await _initializeRbfTransaction(newFeeRate);
    }
  }

  void _initializeCpfpTransaction(double newFeeRate) {
    final myAddressList = _getMyOutputs();
    int amount = myAddressList.fold(0, (sum, output) => sum + output.amount);
    final List<Utxo> utxoList = [];
    // 내 주소와 일치하는 utxo 찾기
    for (var myAddress in myAddressList) {
      final utxoStateList = _utxoRepository.getUtxosByStatus(_walletId, UtxoStatus.incoming);
      for (var utxoState in utxoStateList) {
        if (myAddress.address == utxoState.to &&
            myAddress.amount == utxoState.amount &&
            _pendingTx.transactionHash == utxoState.transactionHash &&
            _pendingTx.outputAddressList[utxoState.index].address == utxoState.to) {
          utxoList.add(utxoState);
        }
      }
    }

    assert(utxoList.isNotEmpty);

    // Transaction 생성
    final recipient = _walletProvider.getReceiveAddress(_walletId).address;
    double estimatedVSize;
    try {
      _bumpingTransaction = Transaction.forSweep(utxoList, recipient, newFeeRate, walletListItemBase.walletBase);
      estimatedVSize = _estimateVirtualByte(_bumpingTransaction!);
    } catch (e) {
      // insufficient utxo for sweep
      double inputSum = utxoList.fold(0, (sum, utxo) => sum + utxo.amount);
      estimatedVSize = _pendingTx.vSize.toDouble();

      debugPrint(
        '😇 CPFP utxo (${utxoList.length})개 input: $inputSum / output: $amount / 👉🏻 입력한 fee rate: $newFeeRate',
      );
      if (!_ensureSufficientUtxos(utxoList, amount.toDouble(), estimatedVSize, newFeeRate)) {
        debugPrint('❌ 사용할 수 있는 추가 UTXO가 없음!');
        return;
      }

      _bumpingTransaction = Transaction.forSweep(utxoList, recipient, newFeeRate, walletListItemBase.walletBase);
    }

    debugPrint('😇 CPFP utxo (${utxoList.length})개');
    _sendInfoProvider.setRecipientAddress(recipient);
    _sendInfoProvider.setIsMaxMode(true);
    _sendInfoProvider.setAmount(_bumpingTransaction!.outputs[0].amount.toDouble());
    _setInsufficientUtxo(false);
  }

  Future<void> _initializeRbfTransaction(double newFeeRate) async {
    final type = _getPaymentType();
    if (type == null) return;

    final externalOutputs = _getExternalOutputs();
    var externalSendingAmount = externalOutputs.fold(0, (sum, output) => sum + output.amount);

    final int changeOutputIndex = _pendingTx.outputAddressList.lastIndexWhere((output) {
      return _walletProvider.containsAddress(_walletId, output.address, isChange: true);
    });
    TransactionAddress changeTxAddress =
        changeOutputIndex == -1 ? TransactionAddress('', 0) : _pendingTx.outputAddressList[changeOutputIndex];
    var changeAddress = changeTxAddress.address;
    var changeAmount = changeTxAddress.amount;
    final bool hasChange = changeAddress.isNotEmpty && changeAmount > 0;

    //input 정보 추출
    List<Utxo> utxoList = await _getUtxoListForRbf();
    double inputSum = utxoList.fold(0, (sum, utxo) => sum + utxo.amount);
    double estimatedVSize =
        _bumpingTransaction == null ? _pendingTx.vSize.toDouble() : _estimateVirtualByte(_bumpingTransaction!);
    // 내 주소가 output에 있는지 확인
    final selfOutputs =
        externalOutputs.where((output) => _walletProvider.containsAddress(_walletId, output.address)).toList();
    final containsSelfOutputs = selfOutputs.isNotEmpty;

    List<TransactionAddress> newOutputList = List.from(_pendingTx.outputAddressList);
    if (changeOutputIndex != -1) {
      newOutputList.removeAt(changeOutputIndex);
    }
    double outputSum = newOutputList.fold(0, (sum, utxo) => sum + utxo.amount);

    double requiredFee = estimatedVSize * newFeeRate;
    debugPrint('RBF:: inputSum ($inputSum) outputSum ($outputSum) requiredFee ($requiredFee) newFeeRate ($newFeeRate)');
    if (inputSum < outputSum + requiredFee) {
      debugPrint('RBF:: ❌ input이 부족함');
      // 1. 충분한 잔돈이 있음 - singlePayment or batchPayment
      if (hasChange) {
        if (changeAmount >= requiredFee) {
          debugPrint('RBF:: 1️⃣ Change로 충당 가능함');
          if (type == PaymentType.batchPayment) {
            debugPrint('RBF:: 1.1.1. 배치 트잭');
            _generateBatchTransation(
              utxoList,
              _createPaymentMapForRbfBatchTx(newOutputList),
              changeAddress,
              newFeeRate,
            );
            return;
          }

          if (changeAmount == requiredFee) {
            debugPrint('RBF:: 1.1.2. Change = newFee >>> 스윕 트잭');
            _generateSweepPayment(utxoList, externalOutputs[0].address, newFeeRate);
            return;
          }

          debugPrint('RBF:: 1.1.3. Change > newFee >>> 싱글 트잭');
          if (makeDust(utxoList, outputSum, requiredFee)) {
            _generateSweepTransaction(
              type,
              utxoList,
              externalOutputs,
              newFeeRate,
              newOutputList,
              outputSum,
              estimatedVSize,
              changeAddress,
            );
            return;
          }

          _generateSinglePayment(
            utxoList,
            externalOutputs[0].address,
            changeAddress,
            newFeeRate,
            externalSendingAmount,
          );
          return;
        } else {
          debugPrint('RBF:: 2️⃣ Change로는 부족');
          if (containsSelfOutputs) {
            debugPrint('RBF::   내 아웃풋 조정');
            final success = _handleTransactionWithSelfOutputs(
              type,
              utxoList,
              newOutputList,
              selfOutputs,
              newFeeRate,
              estimatedVSize,
            );
            if (!success) {
              debugPrint('RBF:: ❌ _handleTransactionWithSelfOutputs 실패');
            }
            return;
          }
          debugPrint('RBF:: 2.2 내 아웃풋 없음');
          if (!_ensureSufficientUtxos(utxoList, outputSum, estimatedVSize, newFeeRate)) {
            return;
          }
        }
      }
      // 2. output에 내 주소가 있는 경우 amount 조정
      else if (containsSelfOutputs) {
        debugPrint('RBF:: 3️⃣ 내 아웃풋이 있음!');
        final success = _handleTransactionWithSelfOutputs(
          type,
          utxoList,
          newOutputList,
          selfOutputs,
          newFeeRate,
          estimatedVSize,
        );
        if (!success) {
          debugPrint('RBF:: ❌ _handleTransactionWithSelfOutputs 실패');
        }
        return;
      } else {
        debugPrint('RBF:: 4️⃣ change도 없고, 내 아웃풋도 없음 >>> utxo 추가!');
        if (!_ensureSufficientUtxos(utxoList, outputSum, estimatedVSize, newFeeRate)) {
          return;
        }
        changeAddress = _walletProvider.getChangeAddress(_walletId).address;
      }
    }

    debugPrint('RBF:: [$inputSum 합계 > $outputSum 합계] 또는 [if (inputSum < outputSum) 문 빠져나옴!!]');

    if (makeDust(utxoList, outputSum, requiredFee)) {
      _generateSweepTransaction(
        type,
        utxoList,
        externalOutputs,
        newFeeRate,
        newOutputList,
        outputSum,
        estimatedVSize,
        changeAddress,
      );
      return;
    }

    if (type == PaymentType.sweep && changeAddress.isEmpty) {
      _generateSweepPayment(utxoList, externalOutputs[0].address, newFeeRate);
      return;
    }

    if (changeAddress.isEmpty) {
      changeAddress = _walletProvider.getChangeAddress(_walletId).address;
    }

    switch (type) {
      case PaymentType.sweep:
      case PaymentType.singlePayment:
        _generateSinglePayment(utxoList, externalOutputs[0].address, changeAddress, newFeeRate, externalSendingAmount);
        break;
      case PaymentType.batchPayment:
        Map<String, int> paymentMap = _createPaymentMapForRbfBatchTx(newOutputList);
        _generateBatchTransation(utxoList, paymentMap, changeAddress, newFeeRate);
        break;
      default:
        break;
    }
  }

  void _generateSweepTransaction(
    PaymentType type,
    List<Utxo> utxoList,
    List<TransactionAddress> externalOutputs,
    double newFeeRate,
    List<TransactionAddress> newOutputList,
    double outputSum,
    double estimatedVSize,
    String changeAddress,
  ) {
    switch (type) {
      case PaymentType.sweep:
      case PaymentType.singlePayment:
        _generateSweepPayment(utxoList, externalOutputs[0].address, newFeeRate);
        break;
      case PaymentType.batchPayment:
        Map<String, int> paymentMap = _createPaymentMapForRbfBatchTx(newOutputList);
        final maxFee = utxoList.fold(0, (sum, utxo) => sum + utxo.amount) - outputSum;
        final maxFeeRate = maxFee / estimatedVSize;
        _generateBatchTransation(utxoList, paymentMap, changeAddress, maxFeeRate);
        break;
    }
    return;
  }

  bool makeDust(List<Utxo> utxoList, double outputSum, double requiredFee) {
    return utxoList.fold(0, (sum, utxo) => sum + utxo.amount) - outputSum - requiredFee < dustLimit;
  }

  bool _handleTransactionWithSelfOutputs(
    PaymentType type,
    List<Utxo> utxoList,
    List<TransactionAddress> newOutputList,
    List<TransactionAddress> selfOutputs,
    double newFeeRate,
    double estimatedVSize,
  ) {
    if (type == PaymentType.batchPayment) {
      debugPrint('RBF:: _handleBatchTransactionWithSelfOutputs 호출');
      return _handleBatchTransactionWithSelfOutputs(utxoList, newOutputList, selfOutputs, newFeeRate, estimatedVSize);
    }
    return _handleSingleOrSweepWithSelfOutputs(utxoList, newOutputList, selfOutputs, newFeeRate, estimatedVSize);
  }

  bool _handleBatchTransactionWithSelfOutputs(
    List<Utxo> utxoList,
    List<TransactionAddress> newOutputList,
    List<TransactionAddress> selfOutputs,
    double newFeeRate,
    double estimatedVSize,
  ) {
    Map<String, int> paymentMap = {};
    double inputSum = utxoList.fold(0, (sum, utxo) => sum + utxo.amount);
    double outputSum = newOutputList.fold(0, (sum, output) => sum + output.amount);

    // debugPrint(
    //     'RBF:: inputSum: $inputSum, outputSum: $outputSum fee current: ${outputSum - inputSum}');

    double requiredFee = estimatedVSize * newFeeRate;
    int remainingFee = (requiredFee - _pendingTx.fee).toInt();
    debugPrint('필요 : $requiredFee 기존: ${_pendingTx.fee} 추가할 remainingFee: $remainingFee');
    debugPrint('☑️ 기존 전송 정보');
    for (var output in newOutputList) {
      debugPrint('output: ${output.address} ${output.amount}');
    }

    for (var output in newOutputList) {
      if (selfOutputs.any((selfOutput) => selfOutput.address == output.address)) {
        debugPrint('내 리시빙 주소!');
        debugPrint('${output.address.substring(output.address.length - 5, output.address.length)} ${output.amount}');
        if (remainingFee == 0) {
          paymentMap[output.address] = output.amount;
        } else {
          int deduction = remainingFee > output.amount ? output.amount.toInt() : remainingFee.toInt();

          if (output.amount - deduction > 0) {
            paymentMap[output.address] = output.amount - deduction;
          }
          remainingFee -= deduction;
        }
      } else {
        debugPrint('남의 주소!');
        debugPrint('${output.address.substring(output.address.length - 5, output.address.length)} ${output.amount}');
        paymentMap[output.address] = output.amount;
      }
    }

    debugPrint('✅ 조정된 전송 정보');
    for (var output in paymentMap.entries) {
      debugPrint(
        'output: ${output.key} ${output.value} 내 주소? ${selfOutputs.any((selfOutput) => selfOutput.address == output.key)}',
      );
    }
    try {
      int totalAmount = paymentMap.values.reduce((a, b) => a + b);
      if (remainingFee > 0) {
        if (!_ensureSufficientUtxos(utxoList, totalAmount.toDouble(), estimatedVSize, newFeeRate)) {
          debugPrint('RBF:: ❌ _handleBatchTransactionWithSelfOutputs 실패');
          return false;
        }
      }
      debugPrint('✅ estimated fee: ${estimatedVSize * newFeeRate}');
      debugPrint('✅ total input/output  : $inputSum / $outputSum');
      debugPrint('✅ change  : ${inputSum - outputSum}');
      debugPrint('✅ total fee to send: $totalAmount');

      _generateBatchTransation(utxoList, paymentMap, _walletProvider.getChangeAddress(_walletId).address, newFeeRate);
    } catch (e) {
      _setInsufficientUtxo(true);
      debugPrint('RBF:: ❌ _handleBatchTransactionWithSelfOutputs 실패');
      return false;
    }

    return true;
  }

  bool _handleSingleOrSweepWithSelfOutputs(
    List<Utxo> utxoList,
    List<TransactionAddress> outputList,
    List<TransactionAddress> selfOutputs,
    double newFeeRate,
    double estimatedVSize,
  ) {
    double outputSum = outputList.fold(0, (sum, output) => sum + output.amount);
    final newFee = estimatedVSize * newFeeRate;
    final myOutputAmount = selfOutputs[0].amount;

    // debugPrint('RBF:: 싱글 또는 스윕 >> amount 조정 $externalSendingAmount');
    int adjustedMyOuputAmount = myOutputAmount - (newFee - _pendingTx.fee).toInt();
    debugPrint('RBF::                        조정 후 $adjustedMyOuputAmount');

    if (adjustedMyOuputAmount == 0) {
      debugPrint('RBF:: 조정해서 내가 받을 금액 0 - 남의 주소에게 보내는 스윕 트잭');
      _generateSweepPayment(utxoList, selfOutputs[0].address, newFeeRate);
      return true;
    }

    if (adjustedMyOuputAmount > 0 && adjustedMyOuputAmount > dustLimit) {
      debugPrint('RBF:: 금액 조정 - $adjustedMyOuputAmount');
      _generateSinglePayment(
        utxoList,
        selfOutputs[0].address,
        _walletProvider.getChangeAddress(_walletId).address,
        newFeeRate,
        adjustedMyOuputAmount,
      );
      return true;
    }

    debugPrint('RBF:: ❌ amount 조정해도 안됨 > utxo 추가 - amount 조정 없이 utxo 추가');
    if (!_ensureSufficientUtxos(utxoList, outputSum, estimatedVSize, newFeeRate)) {
      debugPrint('RBF:: ❌ _handleSingleOrSweepWithSelfOutputs 실패');
      return false;
    }
    debugPrint('RBF:: ✅ utxo 추가 완료 보낼 수량 ${outputList[0].amount}}');
    _generateSinglePayment(
      utxoList,
      outputList[0].address,
      _walletProvider.getChangeAddress(_walletId).address,
      newFeeRate,
      outputList[0].amount,
    );
    return true;
  }

  void _generateSinglePayment(List<Utxo> inputs, String recipient, String changeAddress, double feeRate, int amount) {
    try {
      _bumpingTransaction = Transaction.forSinglePayment(
        inputs,
        recipient,
        _addressRepository.getDerivationPath(_walletId, changeAddress),
        amount,
        feeRate,
        walletListItemBase.walletBase,
      );
      _sendInfoProvider.setAmount(UnitUtil.convertSatoshiToBitcoin(amount));
      _sendInfoProvider.setIsMaxMode(false);
      _setInsufficientUtxo(false);
      debugPrint('RBF::    ▶️ 싱글 트잭 생성(fee rate: $feeRate)');
    } on Exception catch (e) {
      int? estimatedFee = extractEstimatedFeeFromException(e);
      if (estimatedFee != null) {
        _generateSweepPayment(inputs, recipient, feeRate);
      }
    }
  }

  void _generateSweepPayment(List<Utxo> inputs, String recipient, double feeRate) {
    _bumpingTransaction = Transaction.forSweep(inputs, recipient, feeRate, _walletListItemBase.walletBase);
    _sendInfoProvider.setRecipientAddress(recipient);
    _sendInfoProvider.setIsMaxMode(true);
    _setInsufficientUtxo(false);
    debugPrint('RBF::    ▶️ 스윕 트잭 생성(fee rate: $feeRate)');
  }

  void _generateBatchTransation(List<Utxo> inputs, Map<String, int> paymentMap, String changeAddress, double feeRate) {
    _bumpingTransaction = Transaction.forBatchPayment(
      inputs,
      paymentMap,
      _addressRepository.getDerivationPath(_walletId, changeAddress),
      feeRate,
      _walletListItemBase.walletBase,
    );
    _sendInfoProvider.setRecipientsForBatch(paymentMap.map((key, value) => MapEntry(key, value.toDouble())));
    _sendInfoProvider.setIsMaxMode(false);
    _setInsufficientUtxo(false);
    debugPrint('RBF::    ▶️ 배치 트잭 생성(fee rate: $feeRate)');
  }

  bool _ensureSufficientUtxos(List<Utxo> utxoList, double outputSum, double estimatedVSize, double newFeeRate) {
    double inputSum = utxoList.fold(0, (sum, utxo) => sum + utxo.amount);
    double requiredAmount = outputSum + estimatedVSize * newFeeRate;

    List<UtxoState> unspentUtxos = _utxoRepository.getUtxosByStatus(_walletId, UtxoStatus.unspent);
    unspentUtxos.sort((a, b) => b.amount.compareTo(a.amount));
    int sublistIndex = 0; // for unspentUtxos
    while (inputSum <= requiredAmount && sublistIndex < unspentUtxos.length) {
      final additionalUtxos = _getAdditionalUtxos(unspentUtxos.sublist(sublistIndex), outputSum - inputSum);
      if (additionalUtxos.isEmpty) {
        debugPrint('❌ 사용할 수 있는 추가 UTXO가 없음!');
        _setInsufficientUtxo(true);
        return false;
      }
      utxoList.addAll(additionalUtxos);
      sublistIndex += additionalUtxos.length;

      int additionalVSize = _getVSizeIncreasement() * additionalUtxos.length;
      requiredAmount = outputSum + (estimatedVSize + additionalVSize) * newFeeRate;
      inputSum = utxoList.fold(0, (sum, utxo) => sum + utxo.amount);
    }

    if (inputSum <= requiredAmount) {
      _setInsufficientUtxo(true);
      return false;
    }

    _setInsufficientUtxo(false);
    return true;
  }

  void _setInsufficientUtxo(bool value) {
    _insufficientUtxos = value;
    notifyListeners();
  }

  int _getVSizeIncreasement() {
    switch (walletListItemBase.walletType) {
      case WalletType.singleSignature:
        return 68;
      case WalletType.multiSignature:
        final wallet = walletListItemBase.walletBase as MultisignatureWallet;
        final m = wallet.requiredSignature;
        final n = wallet.totalSigner;
        return 1 + (m * 73) + (n * 34) + 2;
      default:
        return 68;
    }
  }

  // todo: utxo lock 기능 추가 시 utxo 제외 로직 필요
  List<Utxo> _getAdditionalUtxos(List<Utxo> unspentUtxo, double requiredAmount) {
    List<Utxo> additionalUtxos = [];
    double sum = 0;
    if (unspentUtxo.isNotEmpty) {
      for (var utxo in unspentUtxo) {
        sum += utxo.amount;
        additionalUtxos.add(utxo);
        if (sum >= requiredAmount) {
          break;
        }
      }
    }

    if (sum < requiredAmount) {
      return [];
    }

    return additionalUtxos;
  }

  Map<String, int> _createPaymentMapForRbfBatchTx(List<TransactionAddress> outputAddressList) {
    Map<String, int> paymentMap = {};

    for (TransactionAddress addressInfo in outputAddressList) {
      paymentMap[addressInfo.address] = addressInfo.amount;
    }

    return paymentMap;
  }

  Future<List<Utxo>> _getUtxoListForRbf() async {
    final txResult = await _nodeProvider.getTransaction(_pendingTx.transactionHash);
    if (txResult.isFailure) {
      debugPrint('❌ 트랜잭션 조회 실패');
      return [];
    }

    final tx = txResult.value;
    final List<TransactionInput> inputList = Transaction.parse(tx).inputs;
    List<Utxo> utxoList = [];
    for (var input in inputList) {
      var utxo = _utxoRepository.getUtxoState(_walletId, getUtxoId(input.transactionHash, input.index));
      if (utxo != null) {
        utxoList.add(Utxo(utxo.transactionHash, utxo.index, utxo.amount, utxo.derivationPath));
      }
    }

    return utxoList;
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

    // cpfpTxSize가 0이거나 매우 작은 값인 경우 처리
    if (cpfpTxSize <= 0) {
      debugPrint('⚠️ _getRecommendedFeeRateForCpfp: cpfpTxSize가 0 이하입니다: $cpfpTxSize');
      throw Exception('cpfpTxSize가 0 이하입니다: recommendedFeeRate($recommendedFeeRate), cpfpTxSize($cpfpTxSize)');
    }

    double totalFee = (_pendingTx.vSize + cpfpTxSize) * recommendedFeeRate;
    double cpfpTxFee = totalFee - _pendingTx.fee.toDouble();
    double cpfpTxFeeRate = cpfpTxFee / cpfpTxSize;

    // NaN 또는 Infinity 체크
    if (cpfpTxFeeRate.isNaN || cpfpTxFeeRate.isInfinite) {
      debugPrint('⚠️ _getRecommendedFeeRateForCpfp: cpfpTxFeeRate가 유효하지 않습니다: $cpfpTxFeeRate');
      throw Exception(
        'cpfpTxFeeRate가 유효하지 않습니다: recommendedFeeRate($recommendedFeeRate), cpfpTxSize($cpfpTxSize),cpfpTxFee($cpfpTxFee), cpfpTxFeeRate($cpfpTxFeeRate), totalRequiredFee($totalFee)',
      );
    }

    if (cpfpTxFeeRate < recommendedFeeRate || cpfpTxFeeRate < 0) {
      return (recommendedFeeRate * 100).ceilToDouble() / 100;
    }

    double roundedFee = (cpfpTxFeeRate * 100).ceilToDouble() / 100;

    // roundedFee도 NaN/Infinity 체크
    if (roundedFee.isNaN || roundedFee.isInfinite) {
      debugPrint('⚠️ _getRecommendedFeeRateForCpfp: roundedFee가 유효하지 않습니다: $roundedFee');
      throw Exception(
        'roundedFee가 유효하지 않습니다: recommendedFeeRate($recommendedFeeRate), cpfpTxSize($cpfpTxSize),cpfpTxFee($cpfpTxFee), cpfpTxFeeRate($cpfpTxFeeRate), totalRequiredFee($totalFee)',
      );
    }

    return roundedFee;
  }

  /// 새로운 트랜잭션이 기존 트랜잭션보다 추가 지불하는 수수료양이 "새로운 트랜잭션 크기"이상이어야 합니다.
  /// 그렇지 않으면 브로드캐스팅 실패합니다.
  double _getRecommendedFeeRateForRbf(Transaction transaction) {
    final recommendedFeeRate = _feeInfos[2].satsPerVb; // 느린 수수료

    if (recommendedFeeRate == null) {
      return 0;
    }

    double estimatedVirtualByte = _estimateVirtualByte(transaction);

    // estimatedVirtualByte가 0이거나 매우 작은 값인 경우 처리
    if (estimatedVirtualByte <= 0) {
      debugPrint('⚠️ _getRecommendedFeeRateForRbf: estimatedVirtualByte가 0 이하입니다: $estimatedVirtualByte');
      throw Exception('estimatedVirtualByte가 0 이하입니다: $estimatedVirtualByte');
    }

    double minimumRequiredFee = _pendingTx.fee.toDouble() + estimatedVirtualByte;
    // double mempoolRecommendedFee = estimatedVirtualByte * recommendedFeeRate;

    // if (mempoolRecommendedFee < minimumRequiredFee) {
    double feePerVByte = minimumRequiredFee / estimatedVirtualByte;
    double roundedFee = (feePerVByte * 100).ceilToDouble() / 100;

    // NaN 또는 Infinity 체크
    if (roundedFee.isNaN || roundedFee.isInfinite) {
      debugPrint(
        '⚠️ _getRecommendedFeeRateForRbf: roundedFee가 유효하지 않습니다: $roundedFee (feePerVByte: $feePerVByte, estimatedVirtualByte: $estimatedVirtualByte)',
      );
      throw Exception(
        'roundedFee가 유효하지 않습니다: roundedFee($roundedFee), feePerVByte($feePerVByte), estimatedVirtualByte($estimatedVirtualByte)',
      );
    }

    // 계산된 추천 수수료가 현재 멤풀 수수료보다 작은 경우, 기존 수수료보다 1s/vb 높은 수수료로 설정
    // FYI, 이 조건에서 트랜잭션이 이미 처리되었을 것이므로 메인넷에서는 거의 발생 확률이 낮음
    // if (feePerVByte < _pendingTx.feeRate) {
    // roundedFee = ((_pendingTx.feeRate + 1) * 100).ceilToDouble() / 100;
    // }
    try {
      return double.parse((roundedFee).toStringAsFixed(2));
    } catch (e) {
      debugPrint('⚠️ _getRecommendedFeeRateForRbf: double.parse 실패: $e (roundedFee: $roundedFee)');
      throw Exception('_getRecommendedFeeRateForRbf: double.parse 실패: $e (roundedFee: $roundedFee)');
    }
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

    // cpfpTxSize가 0이거나 매우 작은 값인 경우 처리
    if (cpfpTxSize <= 0) {
      debugPrint('⚠️ _getRecommendedFeeRateDescriptionForCpfp: cpfpTxSize가 0 이하입니다: $cpfpTxSize');
      throw Exception('cpfpTxSize가 0 이하입니다: $cpfpTxSize');
    }

    final cpfpTxFee = cpfpTxSize * recommendedFeeRate;
    final cpfpTxFeeRate = cpfpTxFee / cpfpTxSize;
    final totalRequiredFee = _pendingTx.vSize * _pendingTx.feeRate + cpfpTxSize * recommendedFeeRate;

    // NaN 또는 Infinity 체크
    if (cpfpTxFeeRate.isNaN || cpfpTxFeeRate.isInfinite) {
      debugPrint('⚠️ _getRecommendedFeeRateDescriptionForCpfp: cpfpTxFeeRate가 유효하지 않습니다: $cpfpTxFeeRate');
      throw Exception(
        'cpfpTxFeeRate가 유효하지 않습니다: recommendedFeeRate($recommendedFeeRate), cpfpTxSize($cpfpTxSize),cpfpTxFee($cpfpTxFee), cpfpTxFeeRate($cpfpTxFeeRate), totalRequiredFee($totalRequiredFee)',
      );
    }

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
