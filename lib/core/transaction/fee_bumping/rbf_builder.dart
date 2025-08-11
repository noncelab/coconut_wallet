import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/constants/bitcoin_network_rules.dart';
import 'package:coconut_wallet/model/wallet/transaction_address.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/repository/realm/service/realm_id_service.dart';
import 'package:coconut_wallet/utils/coconut_lib_exception_parser.dart';
import 'package:coconut_wallet/utils/transaction_util.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:flutter/foundation.dart';

enum PaymentType {
  sweep,
  singlePayment,
  batchPayment,
}

enum TransactionType {
  single,
  sweep,
  batch,
}

class RbfTransactionResult {
  final Transaction transaction;
  final TransactionType type;
  final String? recipientAddress;
  final double? amount;
  final Map<String, double>? recipientsForBatch;

  RbfTransactionResult({
    required this.transaction,
    required this.type,
    this.recipientAddress,
    this.amount,
    this.recipientsForBatch,
  });
}

// RBF 컨텍스트 데이터 클래스
class _RbfContext {
  final List<Utxo> utxoList;
  final List<TransactionAddress> externalOutputs;
  final List<TransactionAddress> newOutputList;
  final List<TransactionAddress> selfOutputs;
  final double inputSum;
  final double outputSum;
  final double estimatedVSize;
  final double requiredFee;
  final double externalSendingAmount;
  final String changeAddress;
  final int changeAmount;
  final bool hasChange;
  final bool containsSelfOutputs;
  final PaymentType type;

  _RbfContext({
    required this.utxoList,
    required this.externalOutputs,
    required this.newOutputList,
    required this.selfOutputs,
    required this.inputSum,
    required this.outputSum,
    required this.estimatedVSize,
    required this.requiredFee,
    required this.externalSendingAmount,
    required this.changeAddress,
    required this.changeAmount,
    required this.hasChange,
    required this.containsSelfOutputs,
    required this.type,
  });

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.writeln("┌──────────────── RbfContext Info ────────────────┐");
    buffer.writeln("│ utxoList = $utxoList");
    buffer.writeln("│ externalOutputs = $externalOutputs");
    buffer.writeln("│ newOutputList = $newOutputList");
    buffer.writeln("│ selfOutputs = $selfOutputs");
    buffer.writeln("│ inputSum = $inputSum");
    buffer.writeln("│ outputSum = $outputSum");
    buffer.writeln("│ estimatedVSize = $estimatedVSize");
    buffer.writeln("│ requiredFee = $requiredFee");
    buffer.writeln("│ externalSendingAmount = $externalSendingAmount");
    buffer.writeln("│ changeAddress = $changeAddress");
    buffer.writeln("│ changeAmount = $changeAmount");
    buffer.writeln("│ hasChange = $hasChange");
    buffer.writeln("│ containsSelfOutputs = $containsSelfOutputs");
    buffer.writeln("│ type = $type");
    buffer.writeln("└───────────────────────────────────────────────────────────────┘");
    return buffer.toString();
  }
}

// Change 정보 데이터 클래스
class _ChangeInfo {
  final int changeOutputIndex;
  final String changeAddress;
  final double changeAmount;
  final bool hasChange;

  _ChangeInfo({
    required this.changeOutputIndex,
    required this.changeAddress,
    required this.changeAmount,
    required this.hasChange,
  });
}

class RbfBuilder {
  final Function(int, String, {bool? isChange}) _containsAddress;
  final Function(int) _getChangeAddress;
  final Function(String) _getTransaction;
  final Function(int, String) _getDerivationPath;
  final Function(int, UtxoStatus) _getUtxosByStatus;
  final Function(int, String) _getUtxoState;
  final TransactionRecord _pendingTx;
  final int _walletId;
  final double feeRate;
  final WalletListItemBase _walletListItemBase;

  Transaction? _bumpingTransaction;
  bool _insufficientUtxos = false;
  bool get insufficientUtxos => _insufficientUtxos;

  RbfBuilder(
    this._containsAddress,
    this._getChangeAddress,
    this._getTransaction,
    this._getDerivationPath,
    this._getUtxosByStatus,
    this._getUtxoState,
    this._pendingTx,
    this._walletId,
    this.feeRate,
    this._walletListItemBase,
  );

  Future<RbfTransactionResult?> build() async {
    await _initializeTransaction(feeRate);
    if (_bumpingTransaction == null) return null;

    return _createTransactionResult();
  }

  RbfTransactionResult _createTransactionResult() {
    // 트랜잭션 타입을 판단하기 위해 PaymentType을 확인
    final paymentType = _getPaymentType();

    switch (paymentType) {
      case PaymentType.singlePayment:
        return RbfTransactionResult(
          transaction: _bumpingTransaction!,
          type: TransactionType.single,
          amount: _bumpingTransaction!.outputs.first.amount.toDouble(),
        );
      case PaymentType.sweep:
        return RbfTransactionResult(
          transaction: _bumpingTransaction!,
          type: TransactionType.sweep,
          recipientAddress: _bumpingTransaction!.outputs.first.getAddress(),
        );
      case PaymentType.batchPayment:
        final recipientsForBatch = <String, double>{};
        for (var output in _bumpingTransaction!.outputs) {
          recipientsForBatch[output.getAddress()] = output.amount.toDouble();
        }
        return RbfTransactionResult(
          transaction: _bumpingTransaction!,
          type: TransactionType.batch,
          recipientsForBatch: recipientsForBatch,
        );
      default:
        return RbfTransactionResult(
          transaction: _bumpingTransaction!,
          type: TransactionType.single,
        );
    }
  }

  RbfBuilder copyWith({
    double? feeRate,
  }) {
    return RbfBuilder(
      _containsAddress,
      _getChangeAddress,
      _getTransaction,
      _getDerivationPath,
      _getUtxosByStatus,
      _getUtxoState,
      _pendingTx,
      _walletId,
      feeRate ?? this.feeRate,
      _walletListItemBase,
    );
  }

  Future<void> _initializeTransaction(double newFeeRate) async {
    final type = _getPaymentType();
    if (type == null) return;

    final rbfContext = await _prepareRbfContext(newFeeRate);
    if (rbfContext == null) return;

    debugPrint(rbfContext.toString());

    if (rbfContext.inputSum < rbfContext.outputSum + rbfContext.requiredFee) {
      debugPrint('RBF:: ❌ input이 부족함');
      await _handleInsufficientInputs(rbfContext, newFeeRate);
    } else {
      debugPrint(
          'RBF:: [$rbfContext.inputSum 합계 > $rbfContext.outputSum 합계] 또는 [if (inputSum < outputSum) 문 빠져나옴!!]');
      await _handleSufficientInputs(rbfContext, newFeeRate);
    }
  }

  // RBF 컨텍스트 준비
  Future<_RbfContext?> _prepareRbfContext(double newFeeRate) async {
    final externalOutputs = _getExternalOutputs();
    final externalSendingAmount = externalOutputs.fold(0, (sum, output) => sum + output.amount);

    final changeInfo = _getChangeInfo();
    final utxoList = await _getUtxoList();
    final inputSum = utxoList.fold(0, (sum, utxo) => sum + utxo.amount);
    final estimatedVSize = _bumpingTransaction == null
        ? _pendingTx.vSize.toDouble()
        : _estimateVirtualByte(_bumpingTransaction!);

    final selfOutputs =
        externalOutputs.where((output) => _containsAddress(_walletId, output.address)).toList();
    final containsSelfOutputs = selfOutputs.isNotEmpty;

    final newOutputList = _getNewOutputList(changeInfo.changeOutputIndex);
    final outputSum = newOutputList.fold(0, (sum, utxo) => sum + utxo.amount);
    final requiredFee = estimatedVSize * newFeeRate;

    debugPrint(
        'RBF:: inputSum ($inputSum) outputSum ($outputSum) requiredFee ($requiredFee) newFeeRate ($newFeeRate)');

    return _RbfContext(
      utxoList: utxoList,
      externalOutputs: externalOutputs,
      newOutputList: newOutputList,
      selfOutputs: selfOutputs,
      inputSum: inputSum.toDouble(),
      outputSum: outputSum.toDouble(),
      estimatedVSize: estimatedVSize,
      requiredFee: requiredFee,
      externalSendingAmount: externalSendingAmount.toDouble(),
      changeAddress: changeInfo.changeAddress,
      changeAmount: changeInfo.changeAmount.toInt(),
      hasChange: changeInfo.hasChange,
      containsSelfOutputs: containsSelfOutputs,
      type: _getPaymentType()!,
    );
  }

  // Change 정보 추출
  _ChangeInfo _getChangeInfo() {
    final changeOutputIndex = _pendingTx.outputAddressList.lastIndexWhere((output) {
      return _containsAddress(_walletId, output.address, isChange: true);
    });

    final changeTxAddress = changeOutputIndex == -1
        ? TransactionAddress('', 0)
        : _pendingTx.outputAddressList[changeOutputIndex];

    final changeAddress = changeTxAddress.address;
    final changeAmount = changeTxAddress.amount;
    final hasChange = changeAddress.isNotEmpty && changeAmount > 0;

    return _ChangeInfo(
      changeOutputIndex: changeOutputIndex,
      changeAddress: changeAddress,
      changeAmount: changeAmount.toDouble(),
      hasChange: hasChange,
    );
  }

  // 새로운 Output 리스트 생성
  List<TransactionAddress> _getNewOutputList(int changeOutputIndex) {
    final newOutputList = List<TransactionAddress>.from(_pendingTx.outputAddressList);
    if (changeOutputIndex != -1) {
      newOutputList.removeAt(changeOutputIndex);
    }
    return newOutputList;
  }

  // Input이 부족한 경우 처리
  Future<void> _handleInsufficientInputs(_RbfContext context, double newFeeRate) async {
    if (context.hasChange) {
      await _handleInsufficientInputsWithChange(context, newFeeRate);
    } else if (context.containsSelfOutputs) {
      debugPrint('RBF:: 3️⃣ 내 아웃풋이 있음!');
      final success = _handleTransactionWithSelfOutputs(context.type, context.utxoList,
          context.newOutputList, context.selfOutputs, newFeeRate, context.estimatedVSize);
      if (!success) {
        debugPrint('RBF:: ❌ _handleTransactionWithSelfOutputs 실패');
      }
    } else {
      debugPrint('RBF:: 4️⃣ change도 없고, 내 아웃풋도 없음 >>> utxo 추가!');
      if (!_ensureSufficientUtxos(
          context.utxoList, context.outputSum, context.estimatedVSize, newFeeRate)) {
        return;
      }
      // changeAddress는 _ensureSufficientUtxos에서 설정됨
    }
  }

  // Change가 있는 경우 Input 부족 처리
  Future<void> _handleInsufficientInputsWithChange(_RbfContext context, double newFeeRate) async {
    if (context.changeAmount >= context.requiredFee) {
      debugPrint('RBF:: 1️⃣ Change로 충당 가능함');
      await _handleSufficientChange(context, newFeeRate);
    } else {
      debugPrint('RBF:: 2️⃣ Change로는 부족');
      await _handleInsufficientChange(context, newFeeRate);
    }
  }

  // 충분한 Change가 있는 경우 처리
  Future<void> _handleSufficientChange(_RbfContext context, double newFeeRate) async {
    if (context.type == PaymentType.batchPayment) {
      debugPrint('RBF:: 1.1.1. 배치 트잭');
      _generateBatchTransation(context.utxoList,
          _createPaymentMapForRbfBatchTx(context.newOutputList), context.changeAddress, newFeeRate);
      return;
    }

    if (context.changeAmount == context.requiredFee) {
      debugPrint('RBF:: 1.1.2. Change = newFee >>> 스윕 트잭');
      _generateSweepPayment(context.utxoList, context.externalOutputs[0].address, newFeeRate);
      return;
    }

    debugPrint('RBF:: 1.1.3. Change > newFee >>> 싱글 트잭');
    if (_makeDust(context.utxoList, context.outputSum, context.requiredFee)) {
      _generateSweepTransaction(context.type, context.utxoList, context.externalOutputs, newFeeRate,
          context.newOutputList, context.outputSum, context.estimatedVSize, context.changeAddress);
      return;
    }

    _generateSinglePayment(context.utxoList, context.externalOutputs[0].address,
        context.changeAddress, newFeeRate, context.externalSendingAmount.toInt());
  }

  // 부족한 Change가 있는 경우 처리
  Future<void> _handleInsufficientChange(_RbfContext context, double newFeeRate) async {
    if (context.containsSelfOutputs) {
      debugPrint('RBF::   내 아웃풋 조정');
      final success = _handleTransactionWithSelfOutputs(
        context.type,
        context.utxoList,
        context.newOutputList,
        context.selfOutputs,
        newFeeRate,
        context.estimatedVSize,
      );
      if (!success) {
        debugPrint('RBF:: ❌ _handleTransactionWithSelfOutputs 실패');
      }
    } else {
      debugPrint('RBF:: 2.2 내 아웃풋 없음');
      if (!_ensureSufficientUtxos(
          context.utxoList, context.outputSum, context.estimatedVSize, newFeeRate)) {
        return;
      }
    }
  }

  // 충분한 Input이 있는 경우 처리
  Future<void> _handleSufficientInputs(_RbfContext context, double newFeeRate) async {
    if (_makeDust(context.utxoList, context.outputSum, context.requiredFee)) {
      _generateSweepTransaction(context.type, context.utxoList, context.externalOutputs, newFeeRate,
          context.newOutputList, context.outputSum, context.estimatedVSize, context.changeAddress);
      return;
    }

    if (context.type == PaymentType.sweep && context.changeAddress.isEmpty) {
      _generateSweepPayment(context.utxoList, context.externalOutputs[0].address, newFeeRate);
      return;
    }

    final finalChangeAddress =
        context.changeAddress.isEmpty ? _getChangeAddress(_walletId) : context.changeAddress;

    switch (context.type) {
      case PaymentType.sweep:
      case PaymentType.singlePayment:
        _generateSinglePayment(context.utxoList, context.externalOutputs[0].address,
            finalChangeAddress, newFeeRate, context.externalSendingAmount.toInt());
        break;
      case PaymentType.batchPayment:
        Map<String, int> paymentMap = _createPaymentMapForRbfBatchTx(context.newOutputList);
        _generateBatchTransation(context.utxoList, paymentMap, finalChangeAddress, newFeeRate);
        break;
      default:
        break;
    }
  }

  // 유틸리티 메서드들
  double _estimateVirtualByte(Transaction transaction) {
    return TransactionUtil.estimateVirtualByteByWallet(_walletListItemBase, transaction);
  }

  bool _makeDust(List<Utxo> utxoList, double outputSum, double requiredFee) {
    return utxoList.fold(0, (sum, utxo) => sum + utxo.amount) - outputSum - requiredFee < dustLimit;
  }

  void _setInsufficientUtxo(bool value) {
    _insufficientUtxos = value;
  }

  bool _ensureSufficientUtxos(
      List<Utxo> utxoList, double outputSum, double estimatedVSize, double newFeeRate) {
    double inputSum = utxoList.fold(0, (sum, utxo) => sum + utxo.amount);
    double requiredAmount = outputSum + estimatedVSize * newFeeRate;

    List<UtxoState> unspentUtxos = _getUtxosByStatus(_walletId, UtxoStatus.unspent);
    unspentUtxos.sort((a, b) => b.amount.compareTo(a.amount));
    int sublistIndex = 0;
    while (inputSum <= requiredAmount && sublistIndex < unspentUtxos.length) {
      final additionalUtxos =
          _getAdditionalUtxos(unspentUtxos.sublist(sublistIndex), outputSum - inputSum);
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

  int _getVSizeIncreasement() {
    switch (_walletListItemBase.walletType) {
      case WalletType.singleSignature:
        return 68;
      case WalletType.multiSignature:
        final wallet = _walletListItemBase.walletBase as MultisignatureWallet;
        final m = wallet.requiredSignature;
        final n = wallet.totalSigner;
        return 1 + (m * 73) + (n * 34) + 2;
      default:
        return 68;
    }
  }

  List<TransactionAddress> _getExternalOutputs() => _pendingTx.outputAddressList
      .where((output) => !_containsAddress(_walletId, output.address, isChange: true))
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

  void _generateSweepTransaction(
      PaymentType type,
      List<Utxo> utxoList,
      List<TransactionAddress> externalOutputs,
      double newFeeRate,
      List<TransactionAddress> newOutputList,
      double outputSum,
      double estimatedVSize,
      String changeAddress) {
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
      return _handleBatchTransactionWithSelfOutputs(
        utxoList,
        newOutputList,
        selfOutputs,
        newFeeRate,
        estimatedVSize,
      );
    }
    return _handleSingleOrSweepWithSelfOutputs(
        utxoList, newOutputList, selfOutputs, newFeeRate, estimatedVSize);
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
        debugPrint(
            '${output.address.substring(output.address.length - 5, output.address.length)} ${output.amount}');
        if (remainingFee == 0) {
          paymentMap[output.address] = output.amount;
        } else {
          int deduction =
              remainingFee > output.amount ? output.amount.toInt() : remainingFee.toInt();

          if (output.amount - deduction > 0) {
            paymentMap[output.address] = output.amount - deduction;
          }
          remainingFee -= deduction;
        }
      } else {
        debugPrint('남의 주소!');
        debugPrint(
            '${output.address.substring(output.address.length - 5, output.address.length)} ${output.amount}');
        paymentMap[output.address] = output.amount;
      }
    }

    debugPrint('✅ 조정된 전송 정보');
    for (var output in paymentMap.entries) {
      debugPrint(
          'output: ${output.key} ${output.value} 내 주소? ${selfOutputs.any((selfOutput) => selfOutput.address == output.key)}');
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

      _generateBatchTransation(
          utxoList, paymentMap, _getChangeAddress(_walletId).address, newFeeRate);
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
      _generateSinglePayment(utxoList, selfOutputs[0].address, _getChangeAddress(_walletId).address,
          newFeeRate, adjustedMyOuputAmount);
      return true;
    }

    debugPrint('RBF:: ❌ amount 조정해도 안됨 > utxo 추가 - amount 조정 없이 utxo 추가');
    if (!_ensureSufficientUtxos(
      utxoList,
      outputSum,
      estimatedVSize,
      newFeeRate,
    )) {
      debugPrint('RBF:: ❌ _handleSingleOrSweepWithSelfOutputs 실패');
      return false;
    }
    debugPrint('RBF:: ✅ utxo 추가 완료 보낼 수량 ${outputList[0].amount}}');
    _generateSinglePayment(utxoList, outputList[0].address, _getChangeAddress(_walletId).address,
        newFeeRate, outputList[0].amount);
    return true;
  }

  void _generateSinglePayment(
      List<Utxo> inputs, String recipient, String changeAddress, double feeRate, int amount) {
    try {
      _bumpingTransaction = Transaction.forSinglePayment(
          inputs,
          recipient,
          _getDerivationPath(_walletId, changeAddress),
          amount,
          feeRate,
          _walletListItemBase.walletBase);
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
    _bumpingTransaction =
        Transaction.forSweep(inputs, recipient, feeRate, _walletListItemBase.walletBase);
    _setInsufficientUtxo(false);
    debugPrint('RBF::    ▶️ 스윕 트잭 생성(fee rate: $feeRate)');
  }

  void _generateBatchTransation(
      List<Utxo> inputs, Map<String, int> paymentMap, String changeAddress, double feeRate) {
    _bumpingTransaction = Transaction.forBatchPayment(inputs, paymentMap,
        _getDerivationPath(_walletId, changeAddress), feeRate, _walletListItemBase.walletBase);
    _setInsufficientUtxo(false);
    debugPrint('RBF::    ▶️ 배치 트잭 생성(fee rate: $feeRate)');
  }

  Map<String, int> _createPaymentMapForRbfBatchTx(List<TransactionAddress> outputAddressList) {
    Map<String, int> paymentMap = {};

    for (TransactionAddress addressInfo in outputAddressList) {
      paymentMap[addressInfo.address] = addressInfo.amount;
    }

    return paymentMap;
  }

  Future<List<Utxo>> _getUtxoList() async {
    final txResult = await _getTransaction(_pendingTx.transactionHash);
    if (txResult.isFailure) {
      debugPrint('❌ 트랜잭션 조회 실패');
      return [];
    }

    final tx = txResult.value;
    final List<TransactionInput> inputList = Transaction.parse(tx).inputs;
    debugPrint('inputList:::::::::::: ${inputList.map((e) {
      var utxo = _getUtxoState(_walletId, getUtxoId(e.transactionHash, e.index));
      return utxo?.amount;
    })}');
    List<Utxo> utxoList = [];
    for (var input in inputList) {
      var utxo = _getUtxoState(_walletId, getUtxoId(input.transactionHash, input.index));
      if (utxo != null) {
        utxoList.add(Utxo(utxo.transactionHash, utxo.index, utxo.amount, utxo.derivationPath));
      }
    }

    return utxoList;
  }
}
