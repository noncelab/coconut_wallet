import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/model/wallet/transaction_address.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/providers/view_model/wallet_detail/fee_bumping_view_model.dart';
import 'package:flutter/material.dart';

enum RbfPlanType { sweep, singlePayment, batchPayment }

class RbfBuildResult {
  final Transaction? transaction;
  final bool insufficientUtxos;
  final RbfPlanType? planType;

  /// single/sweep: recipient 하나 + amount
  final String? recipient;
  final int? amount;

  /// batch: 주소별 amount
  final Map<String, int>? paymentMap;

  RbfBuildResult({
    required this.transaction,
    required this.insufficientUtxos,
    required this.planType,
    this.recipient,
    this.amount,
    this.paymentMap,
  });
}

class RbfBuilder {
  final TransactionRecord pendingTx;
  final WalletType walletType;
  final WalletBase walletBase;
  final int dustLimit;

  /// vsize 증가량은 밖에서 계산해서 주입 (테스트를 위해 순수 함수로 유지)
  final int vsizeIncreasePerInput;

  final List<Utxo> inputUtxos;

  final bool Function(String address, {bool isChange}) isMyAddress;

  late double _estimatedVSize;

  /// ----------- Output -----------
  List<TransactionAddress>? _nonChangeOutputs;
  List<TransactionAddress> get nonChangeOutputs {
    _ensureOutputsComputed();
    return _nonChangeOutputs!;
  }

  double? _nonChangeOutputsSum;
  double get nonChangeOutputsSum {
    _ensureOutputsComputed();
    return _nonChangeOutputsSum!;
  }

  TransactionAddress? _changeOutput;
  TransactionAddress? get changeOutput {
    _ensureOutputsComputed();
    return _changeOutput;
  }

  List<TransactionAddress>? _selfOutputs;
  List<TransactionAddress>? get selfOutputs {
    _selfOutputs ??= nonChangeOutputs.where((output) => isMyAddress(output.address)).toList();
    if (_selfOutputs!.isEmpty) {
      return null;
    }
    return _selfOutputs;
  }

  PaymentType? _paymentType;
  PaymentType get paymentType {
    _paymentType ??= _determinePaymentType();
    return _paymentType!;
  }

  int get sendAmount {
    return nonChangeOutputs.fold(0, (sum, output) => sum + output.amount);
  }

  /// ----------- Output -----------
  /// ----------- Input -----------
  double? _inputSum;
  double get inputSum {
    _inputSum ??= inputUtxos.fold<double>(0, (sum, utxo) => sum + utxo.amount);
    return _inputSum!;
  }

  /// ----------- Input -----------

  RbfBuilder({
    required this.pendingTx,
    required this.walletType,
    required this.walletBase,
    required this.dustLimit,
    required this.vsizeIncreasePerInput,
    required this.isMyAddress,
    required this.inputUtxos,
  }) {
    _estimatedVSize = pendingTx.vSize;
  }

  /// RBF 트랜잭션 생성의 진입점
  ///
  /// - [newFeeRate]: 새로 적용할 fee rate (sats/vB)
  /// - [originalInputs]: 기존 트랜잭션이 사용한 UTXO 목록
  /// - [candidateUnspentUtxos]: 추가로 사용할 수 있는 UTXO 풀
  /// - [outputAddresses]: 기존 트랜잭션의 outputs
  /// - [isMyAddress]: 특정 주소가 내 주소인지 여부 (change 포함 여부는 호출자가 판단)
  /// - [initialChangeAddress]: 원래 트랜잭션의 change 주소 (없으면 빈 문자열)
  /// - [getChangeAddress]: UTXO 추가로 change를 새로 만들어야 할 때 사용할 주소 제공 콜백
  /// - [getDerivationPath]: 특정 주소의 derivation path를 반환하는 콜백
  Future<RbfBuildResult> buildRbfTransaction({
    required double newFeeRate,
    required List<Utxo> originalInputs,
    required List<Utxo> candidateUnspentUtxos,
    required List<TransactionAddress> outputAddresses,
    required String initialChangeAddress,
    required String Function() getChangeAddress,
    required String Function(String address) getDerivationPath,
  }) async {
    // 여기서 지금 FeeBumpingViewModel._initializeRbfTransaction 로직을
    // 그대로 옮겨오되, provider 호출 부분은 위 파라미터/콜백으로 대체하면 됩니다.
    //
    // 1. paymentType 계산 (sweep / single / batch)
    // 2. externalOutputs / selfOutputs / changeOutputIndex/amount 계산
    // 3. inputSum / outputSum / requiredFee 계산
    // 4. makeDust / _ensureSufficientUtxos / _handleTransactionWithSelfOutputs 등
    //    로직을 이 클래스 안의 private 메서드로 옮김
    // 5. 최종적으로 Transaction.forSinglePayment / forSweep / forBatchPayment 호출
    //    및 planType/recipient/amount/paymentMap 설정
    //
    // 현재는 초안이라 비워두지만, 실제 구현은 FeeBumpingViewModel의
    // _initializeRbfTransaction 이하 RBF 관련 메서드들을 이 클래스로 이동시키는 형태가 됩니다.

    // final externalOutputs = _getExternalOutputs();
    // var externalSendingAmount = externalOutputs.fold(0, (sum, output) => sum + output.amount);

    // final int changeOutputIndex = _pendingTx.outputAddressList.lastIndexWhere((output) {
    //   return _walletProvider.containsAddress(_walletId, output.address, isChange: true);
    // });
    // TransactionAddress changeTxAddress =
    //     changeOutputIndex == -1 ? TransactionAddress('', 0) : _pendingTx.outputAddressList[changeOutputIndex];
    // var changeAddress = changeTxAddress.address;
    // var changeAmount = changeTxAddress.amount;
    // final bool hasChange = changeAddress.isNotEmpty && changeAmount > 0;

    // //input 정보 추출
    // List<Utxo> utxoList = await _getUtxoListForRbf();
    // double inputSum = utxoList.fold(0, (sum, utxo) => sum + utxo.amount);
    // // ?? _bumpingTransaction이 null이 아닌 경우가 언제가 될 수 있는지 모르겠음
    // double estimatedVSize =
    //     _bumpingTransaction == null ? _pendingTx.vSize.toDouble() : _estimateVirtualByte(_bumpingTransaction!);
    // // 내 주소가 output에 있는지 확인
    // final selfOutputs =
    //     externalOutputs.where((output) => _walletProvider.containsAddress(_walletId, output.address)).toList();
    // final containsSelfOutputs = selfOutputs.isNotEmpty;

    // // output 중 내 change 주소가 있는 경우 제외하고 저장
    // List<TransactionAddress> newOutputList = List.from(_pendingTx.outputAddressList);
    // if (changeOutputIndex != -1) {
    //   newOutputList.removeAt(changeOutputIndex);
    // }
    // double outputSum = newOutputList.fold(0, (sum, utxo) => sum + utxo.amount);

    // double requiredFee = estimatedVSize * newFeeRate;
    // debugPrint('RBF:: inputSum ($inputSum) outputSum ($outputSum) requiredFee ($requiredFee) newFeeRate ($newFeeRate)');

    // if (inputSum < outputSum + requiredFee) {
    //   debugPrint('RBF:: ❌ input이 부족함');
    //   // 1. 충분한 잔돈이 있음 - singlePayment or batchPayment
    //   if (hasChange) {
    //     if (changeAmount >= requiredFee) {
    //       debugPrint('RBF:: 1️⃣ Change로 충당 가능함');
    //       if (type == PaymentType.batchPayment) {
    //         debugPrint('RBF:: 1.1.1. 배치 트잭');
    //         _generateBatchTransation(
    //           utxoList,
    //           _createPaymentMapForRbfBatchTx(newOutputList),
    //           changeAddress,
    //           newFeeRate,
    //         );
    //         return;
    //       }

    //       if (changeAmount == requiredFee) {
    //         debugPrint('RBF:: 1.1.2. Change = newFee >>> 스윕 트잭');
    //         _generateSweepPayment(utxoList, externalOutputs[0].address, newFeeRate);
    //         return;
    //       }

    //       debugPrint('RBF:: 1.1.3. Change > newFee >>> 싱글 트잭');
    //       if (makeDust(utxoList, outputSum, requiredFee)) {
    //         _generateSweepTransaction(
    //           type,
    //           utxoList,
    //           externalOutputs,
    //           newFeeRate,
    //           newOutputList,
    //           outputSum,
    //           estimatedVSize,
    //           changeAddress,
    //         );
    //         return;
    //       }

    //       _generateSinglePayment(
    //         utxoList,
    //         externalOutputs[0].address,
    //         changeAddress,
    //         newFeeRate,
    //         externalSendingAmount,
    //       );
    //       return;
    //     } else {
    //       debugPrint('RBF:: 2️⃣ Change로는 부족');
    //       if (containsSelfOutputs) {
    //         debugPrint('RBF::   내 아웃풋 조정');
    //         final success = _handleTransactionWithSelfOutputs(
    //           type,
    //           utxoList,
    //           newOutputList,
    //           selfOutputs,
    //           newFeeRate,
    //           estimatedVSize,
    //         );
    //         if (!success) {
    //           debugPrint('RBF:: ❌ _handleTransactionWithSelfOutputs 실패');
    //         }
    //         return;
    //       }
    //       debugPrint('RBF:: 2.2 내 아웃풋 없음');
    //       if (!_ensureSufficientUtxos(utxoList, outputSum, estimatedVSize, newFeeRate)) {
    //         return;
    //       }
    //     }
    //   }
    //   // 2. output에 내 주소가 있는 경우 amount 조정
    //   else if (containsSelfOutputs) {
    //     debugPrint('RBF:: 3️⃣ 내 아웃풋이 있음!');
    //     final success = _handleTransactionWithSelfOutputs(
    //       type,
    //       utxoList,
    //       newOutputList,
    //       selfOutputs,
    //       newFeeRate,
    //       estimatedVSize,
    //     );
    //     if (!success) {
    //       debugPrint('RBF:: ❌ _handleTransactionWithSelfOutputs 실패');
    //     }
    //     return;
    //   } else {
    //     debugPrint('RBF:: 4️⃣ change도 없고, 내 아웃풋도 없음 >>> utxo 추가!');
    //     if (!_ensureSufficientUtxos(utxoList, outputSum, estimatedVSize, newFeeRate)) {
    //       return;
    //     }
    //     changeAddress = _walletProvider.getChangeAddress(_walletId).address;
    //   }
    // }

    // debugPrint('RBF:: [$inputSum 합계 > $outputSum 합계] 또는 [if (inputSum < outputSum) 문 빠져나옴!!]');

    // if (makeDust(utxoList, outputSum, requiredFee)) {
    //   _generateSweepTransaction(
    //     type,
    //     utxoList,
    //     externalOutputs,
    //     newFeeRate,
    //     newOutputList,
    //     outputSum,
    //     estimatedVSize,
    //     changeAddress,
    //   );
    //   return;
    // }

    // if (type == PaymentType.singleSweep && changeAddress.isEmpty) {
    //   _generateSweepPayment(utxoList, externalOutputs[0].address, newFeeRate);
    //   return;
    // }

    // if (changeAddress.isEmpty) {
    //   changeAddress = _walletProvider.getChangeAddress(_walletId).address;
    // }

    // switch (type) {
    //   case PaymentType.singleSweep:
    //   case PaymentType.singlePayment:
    //     _generateSinglePayment(utxoList, externalOutputs[0].address, changeAddress, newFeeRate, externalSendingAmount);
    //     break;
    //   case PaymentType.batchPayment:
    //     Map<String, int> paymentMap = _createPaymentMapForRbfBatchTx(newOutputList);
    //     _generateBatchTransation(utxoList, paymentMap, changeAddress, newFeeRate);
    //     break;
    //   default:
    //     break;
    // }

    return RbfBuildResult(transaction: null, insufficientUtxos: true, planType: null);
  }

  PaymentType _determinePaymentType() {
    int inputCount = pendingTx.inputAddressList.length;
    int outputCount = pendingTx.outputAddressList.length;

    if (inputCount == 0 || outputCount == 0) {
      throw Exception('Invalid transaction. Input $inputCount / Output $outputCount');
    }

    switch (outputCount) {
      case 1:
        return PaymentType.singleSweep;
      case 2:
        if (nonChangeOutputs.length == 1) {
          return PaymentType.singlePayment;
        }
    }
    return PaymentType.batchPayment;
  }

  void _ensureOutputsComputed() {
    // 이미 계산된 경우 재계산하지 않음
    if (_nonChangeOutputs != null || changeOutput != null) {
      return;
    }

    final outputs = pendingTx.outputAddressList;
    // change output 찾기
    final changeIndex = outputs.lastIndexWhere((output) => isMyAddress(output.address, isChange: true));
    if (changeIndex != -1) {
      _changeOutput = outputs[changeIndex];
    }
    // change output 을 제외한 나머지 = nonChangeOutputs
    double outputSum = 0;
    _nonChangeOutputs =
        outputs.asMap().entries.where((entry) => entry.key != changeIndex).map((entry) {
          outputSum += entry.value.amount;
          return entry.value;
        }).toList();
    _nonChangeOutputsSum = outputSum;
  }

  // - bool makeDust(...)
  // - bool _ensureSufficientUtxos(...)
  // - List<Utxo> _getAdditionalUtxos(...)
  // - int _getVSizeIncreasement(...)  → vsizeIncreasePerInput 로 대체 가능
  // - bool _handleTransactionWithSelfOutputs(...)
  // - bool _handleBatchTransactionWithSelfOutputs(...)
  // - bool _handleSingleOrSweepWithSelfOutputs(...)
  // - void _generateSinglePayment(...)
  // - void _generateSweepPayment(...)
  // - void _generateBatchTransation(...)
}
