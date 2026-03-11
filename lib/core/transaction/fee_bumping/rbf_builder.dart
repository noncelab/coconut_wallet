import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/constants/bitcoin_network_rules.dart';
import 'package:coconut_wallet/core/transaction/fee_bumping/rbf_preparer.dart';
import 'package:coconut_wallet/extensions/transaction_extension.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/core/exceptions/rbf_creation/rbf_creation_exception.dart';
import 'package:coconut_wallet/core/transaction/transaction_builder.dart';
import 'package:coconut_wallet/core/transaction/fee_bumping/output_analysis.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/model/wallet/transaction_address.dart';
import 'package:coconut_wallet/model/wallet/wallet_address.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/utils/bitcoin/transaction_util.dart';
import 'package:coconut_wallet/utils/fee_rate_util.dart';
import 'package:coconut_wallet/core/exceptions/transaction_creation/transaction_creation_exception.dart'
    as tx_creation_exception;
import 'package:coconut_wallet/utils/logger.dart';

class RbfBuildResult {
  final Transaction? transaction;
  final double minimumFeeRate;
  final Exception? exception;

  final bool isOnlyChangeOutputUsed;
  final bool isSelfOutputsUsed;
  final List<UtxoState>? addedInputs;
  final int? deficitAmount;
  final double estimatedVSize;

  bool get isSuccess => transaction != null;
  bool get isFailure => transaction == null;

  int? get estimatedFee {
    if (transaction == null) return null;
    final totalOutputAmount = transaction!.outputs.fold(0, (sum, output) => sum + output.amount);
    return transaction!.totalInputAmount - totalOutputAmount;
  }

  RbfBuildResult({
    required this.minimumFeeRate,
    this.transaction,
    this.isOnlyChangeOutputUsed = false,
    this.isSelfOutputsUsed = false,
    this.exception,
    this.addedInputs,
    this.deficitAmount,
    required this.estimatedVSize,
  });

  RbfBuildResult copyWith({double? minimumFeeRate}) {
    return RbfBuildResult(
      minimumFeeRate: minimumFeeRate ?? this.minimumFeeRate,
      transaction: transaction,
      isOnlyChangeOutputUsed: isOnlyChangeOutputUsed,
      isSelfOutputsUsed: isSelfOutputsUsed,
      exception: exception,
      addedInputs: addedInputs,
      deficitAmount: deficitAmount,
      estimatedVSize: estimatedVSize,
    );
  }
}

class RbfBuilder {
  static const double incrementalRelayFeeRate = 1.0; // 1 sat/vB (Bitcoin Core 기본값)

  final WalletListItemBase walletListItemBase;
  final WalletAddress nextChangeAddress;

  late final TransactionRecord _pendingTx;
  late final List<UtxoState> _inputUtxos;
  late final int _vSizeIncreasePerInput;
  late final int _vSizeChangeOutput;
  late List<UtxoState> _additionalSpendable;

  /// ----------- Output -----------
  late final OutputAnalysis _outputAnalysis;

  List<TransactionAddress> get nonChangeOutputs => [..._outputAnalysis.externalOutputs, ..._outputAnalysis.selfOutputs];

  Map<String, int> get recipientMap => _outputAnalysis.recipientMap;

  int get nonChangeOutputsSum => _outputAnalysis.nonChangeSum;

  TransactionAddress? get changeOutput => _outputAnalysis.changeOutput;

  String? get changeOutputDerivationPath => _outputAnalysis.changeDerivationPath;

  List<TransactionAddress>? get selfOutputs => _outputAnalysis.selfOutputs.isEmpty ? null : _outputAnalysis.selfOutputs;

  List<TransactionAddress>? get externalOutputs =>
      _outputAnalysis.externalOutputs.isEmpty ? null : _outputAnalysis.externalOutputs;

  // int get sendAmount {
  //   return nonChangeOutputs.fold(0, (sum, output) => sum + output.amount);
  // }

  /// ----------- Output -----------
  /// ----------- Input -----------
  int? _inputSum;
  int get inputSum {
    _inputSum ??= _inputUtxos.fold<int>(0, (sum, utxo) => sum + utxo.amount);
    return _inputSum!;
  }

  /// ----------- Input -----------
  RbfBuildResult? _cachedBaseline;

  RbfBuilder({
    required RbfPreparer preparer,
    required this.walletListItemBase,
    required this.nextChangeAddress,
    List<UtxoState> additionalSpendable = const [],
  }) {
    _pendingTx = preparer.pendingTx;
    _outputAnalysis = preparer.outputAnalysis;
    _inputUtxos = preparer.inputUtxos;

    _vSizeIncreasePerInput = estimateVSizePerInput(
      isMultisig: walletListItemBase.walletType != WalletType.singleSignature,
      requiredSignatureCount: walletListItemBase.multisigConfig?.requiredSignature,
      totalSignerCount: walletListItemBase.multisigConfig?.totalSigner,
    );
    _vSizeChangeOutput = walletListItemBase.walletType == WalletType.singleSignature ? 31 : 43;
    _assertAllUnspent(additionalSpendable);
    _additionalSpendable = [...additionalSpendable]..sort((a, b) => b.amount.compareTo(a.amount));
  }

  double _calculateMinimumFeeRate(double newTxVSize) {
    return FeeRateUtils.ceilFeeRate(_calculateMinimumRbfFee(newTxVSize: newTxVSize) / newTxVSize);
  }

  int _calculateMinimumRbfFee({required double newTxVSize}) {
    return _pendingTx.fee + (newTxVSize * incrementalRelayFeeRate).ceil();
  }

  int _calculateMinAdditionalFee({required double newTxSize}) {
    return (newTxSize * incrementalRelayFeeRate).ceil();
  }

  /// SelfOutput 중 대상을 맨 뒤로 보내고 amount를 Sweep용으로 설정
  Map<String, int> _createSweepRecipients(Map<String, int> originalRecipients, TransactionAddress lastSelfOutput) {
    Map<String, int> newRecipients = Map.from(originalRecipients);
    newRecipients.removeWhere((key, value) => key == lastSelfOutput.address && value == lastSelfOutput.amount);
    int lastAmount = inputSum;
    for (int i = 0; i < newRecipients.length; i++) {
      lastAmount -= newRecipients.values.elementAt(i);
    }
    newRecipients[lastSelfOutput.address] = lastAmount;
    return newRecipients;
  }

  ({RbfBuildResult? result, Map<String, int>? recipients}) _trySelfOutputReductionSweep(
    Map<String, int> recipients,
    TransactionAddress lastSelfOutput,
    double feeRate,
  ) {
    final sweepRecipients = _createSweepRecipients(recipients, lastSelfOutput);
    TransactionBuildResult? txBuildResult = _tryBuildTransactionWithFeeAdjusting(
      sweepRecipients,
      feeRate,
      isSweep: true,
    );
    if (txBuildResult != null) {
      final recipients = txBuildResult.transaction!.outputs.fold(<String, int>{}, (
        previousValue,
        TransactionOutput element,
      ) {
        previousValue[element.getAddress()] = element.amount;
        return previousValue;
      });

      return (
        result: RbfBuildResult(
          transaction: txBuildResult.transaction!,
          isSelfOutputsUsed: true,
          estimatedVSize: txBuildResult.transaction!.estimateVirtualByteForWallet(walletListItemBase),
          minimumFeeRate: txBuildResult.getFeeRate(walletListItemBase)!,
        ),
        recipients: recipients,
      );
    }

    return (result: null, recipients: null);
  }

  /// selfOutput의 amount를 줄이거나 제거하여 deficitAmount를 줄이는 함수.
  ///
  /// - 부분 차감: selfOutput.amount - deficit > dustLimit → amount만 줄임 (vSize 변화 없음)
  /// - 전체 제거: 위 조건 불만족 → output 전체 제거.
  ///   deficit -= (selfOutput.amount + ceil(outputBytes * feeRate))
  ///   output이 제거되면 vSize가 줄어들고, 그 절약된 fee도 deficit 감소에 기여함.
  /// params estimatedAdditionalFee: 처음에 예상했던 수수료
  ({RbfBuildResult? result, Map<String, int> newRecipients, int remainingDeficit, int vSizeReduced})
  _tryWithSelfOutputReduction(int deficitAmount, double feeRate) {
    assert(selfOutputs?.isNotEmpty == true);
    Logger.log('_tryWithSelfOutputReduction: deficitAmount: $deficitAmount, feeRate: $feeRate');
    Map<String, int> newRecipients = Map.from(recipientMap);
    int leftDeficit = deficitAmount;
    int vSizeReduced = 0;
    final feeSavedByOneRemoval = (_vSizeChangeOutput * feeRate).ceil();
    int index = selfOutputs!.length - 1;
    for (; index >= 0; index--) {
      final selfOutput = selfOutputs![index];
      if (selfOutput.amount - leftDeficit >= dustLimit) {
        // TODO: 테스트 필요 (externalOutputs == null인지 확인 없이 Sweep으로 처리해본다.)
        final (:result, :recipients) = _trySelfOutputReductionSweep(newRecipients, selfOutput, feeRate);
        if (result != null) {
          return (result: result, newRecipients: recipients!, remainingDeficit: 0, vSizeReduced: vSizeReduced);
        }
      }
      // recipients에 selfOutput 1개만 남은 경우
      if (newRecipients.length == 1) {
        if (selfOutput.amount <= dustLimit + 1) {
          // 0 ~ 547
          break;
        } else {
          const int lastSelfOutputAmount = dustLimit + 1;
          newRecipients[selfOutput.address] = lastSelfOutputAmount;
          leftDeficit -= (selfOutput.amount - lastSelfOutputAmount);
        }
        //newRecipients.entries.first
        // TODO: external output 없이 self output만 있는 경우 sweep tx 처리 필요
        // TODO: 테스트 필요
        //newRecipients = _createSweepRecipients(newRecipients, selfOutput);
        // TODO: 여기서 값을 차감하는 것은 생략해야 할 것 같은데...
        //leftDeficit -= feeSavedByOneRemoval;
        //vSizeReduced += _vSizeChangeOutput;
        break;
      }
      // 전체 제거: output 금액 + output byte 제거로 절약되는 fee가 함께 deficit 감소에 기여
      newRecipients.removeWhere((key, value) => key == selfOutput.address && value == selfOutput.amount);
      leftDeficit -= selfOutput.amount + feeSavedByOneRemoval;
      vSizeReduced += _vSizeChangeOutput;
      if (leftDeficit <= 0) {
        leftDeficit = 0;
        break;
      }
    }

    if (leftDeficit == 0) {
      // newRecipients에서 남아있는 selfOutput 찾기
      final remainingSelfOutput = selfOutputs!.cast<TransactionAddress?>().firstWhere(
        (output) => newRecipients.containsKey(output!.address),
        orElse: () => null,
      );
      if (remainingSelfOutput != null) {
        // TODO: 테스트 필요
        final (:result, :recipients) = _trySelfOutputReductionSweep(newRecipients, selfOutputs![index], feeRate);
        if (result != null) {
          // sweep은 마지막 recipients에서 수수료 차감되므로 recipients를 받아야함
          return (result: result, newRecipients: recipients!, remainingDeficit: 0, vSizeReduced: vSizeReduced);
        }
      } else {
        // selfOutput 모두 제거됨
        final TransactionBuildResult? result = _tryBuildTransactionWithFeeAdjusting(newRecipients, feeRate);
        if (result != null) {
          final rbfBuildResult = RbfBuildResult(
            transaction: result.transaction!,
            isSelfOutputsUsed: true,
            estimatedVSize: result.transaction!.estimateVirtualByteForWallet(walletListItemBase),
            minimumFeeRate: result.getFeeRate(walletListItemBase)!,
          );
          return (
            result: rbfBuildResult,
            newRecipients: newRecipients,
            remainingDeficit: 0,
            vSizeReduced: vSizeReduced,
          );
        }
      }
    }

    assert(newRecipients.isNotEmpty);
    return (result: null, newRecipients: newRecipients, remainingDeficit: leftDeficit, vSizeReduced: vSizeReduced);
  }

  bool _meetsMinimumRbfFee(TransactionBuildResult txBuildResult) {
    assert(txBuildResult.isSuccess);
    final tx = txBuildResult.transaction!;
    final actualVSize = tx.estimateVirtualByteForWallet(walletListItemBase);
    final actualFee = tx.totalInputAmount - tx.outputs.fold(0, (sum, output) => sum + output.amount);
    final minimumRequiredFee = _pendingTx.fee + actualVSize;
    return actualFee >= minimumRequiredFee;
  }

  TransactionBuildResult? _tryBuildTransactionWithFeeAdjusting(
    Map<String, int> recipients,
    double feeRate, {
    List<UtxoState>? utxos,
    bool isSweep = false,
  }) {
    final txBuildResult = _buildTransaction(feeRate, recipients, utxos ?? [], isSweep: isSweep);
    if (txBuildResult.isSuccess) {
      final tx = txBuildResult.transaction!;
      final actualVSize = tx.estimateVirtualByteForWallet(walletListItemBase);
      final minimumRequiredFee = _pendingTx.fee + actualVSize;

      if (!_meetsMinimumRbfFee(txBuildResult)) {
        Logger.log('_trySelfOutputReductionSweep 재보정 시도');
        final requiredFeeRate = FeeRateUtils.ceilFeeRate(minimumRequiredFee / actualVSize);
        final retryResult = _buildTransaction(requiredFeeRate, recipients, utxos ?? [], isSweep: isSweep);
        if (retryResult.isSuccess) {
          Logger.log('_trySelfOutputReductionSweep 재보정 성공 🟢');
          return retryResult;
        } else {
          Logger.log('_trySelfOutputReductionSweep 재보정 실패 🔴');
          return null;
        }
      }

      return txBuildResult;
    } else if (txBuildResult.exception != null &&
        txBuildResult.exception is! tx_creation_exception.InsufficientBalanceException) {
      Logger.error('_tryBuildTransaction failed: ${txBuildResult.exception.toString()}');
    }
    return null;
  }

  ({List<UtxoState> addedUtxos, int remainingDeficit, double updatedVSize}) _selectAdditionalUtxos({
    required int deficitAmount,
    required double feeRate,
    required double currentVSize,
    bool skipFirstInputOverhead = false,
  }) {
    final List<UtxoState> addedUtxos = [];
    int remaining = deficitAmount;
    double vSize = currentVSize;

    if (_additionalSpendable.isNotEmpty) {
      int i = 0;
      do {
        addedUtxos.add(_additionalSpendable[i]);
        if (!skipFirstInputOverhead || i != 0) {
          vSize += _vSizeIncreasePerInput;
          remaining += (_vSizeIncreasePerInput * feeRate).ceil();
        }
        if (_additionalSpendable[i].amount >= remaining) {
          remaining = 0;
        } else {
          remaining -= _additionalSpendable[i].amount;
        }
        i++;
      } while (i < _additionalSpendable.length && remaining > 0);
    }

    return (addedUtxos: addedUtxos, remainingDeficit: remaining, updatedVSize: vSize);
  }

  bool _isSelfOutputUsed(Map<String, int> changedRecipients) {
    return selfOutputs?.any((output) {
          if (changedRecipients[output.address] == null) return true;
          if (changedRecipients[output.address] != output.amount) return true;
          return false;
        }) ??
        false;
  }

  ({RbfBuildResult? result, int remainingDeficit, List<UtxoState> addedUtxos, double estimatedTxSize})
  _tryWithAdditionalSpendable({
    required int deficitAmount,
    required double feeRate,
    required double estimatedTxSize,
    required Map<String, int> recipientMap,
    required bool isBaseline,
  }) {
    assert(_additionalSpendable.isNotEmpty);
    final List<UtxoState> addedUtxos = [];
    int remaining = deficitAmount;
    double vSize = estimatedTxSize;
    int i = 0;
    do {
      addedUtxos.add(_additionalSpendable[i]);
      // getBaselineTransaction()에서 모자란 경우 첫 번째 input의 overhead를 이미 반영했으므로 skip
      if (isBaseline || i != 0) {
        vSize += _vSizeIncreasePerInput;
        remaining += (_vSizeIncreasePerInput * feeRate).ceil();
      }
      if (_additionalSpendable[i].amount >= remaining) {
        final finalFeeRate = isBaseline ? _calculateMinimumFeeRate(vSize) : feeRate;
        TransactionBuildResult? txBuildResult;
        // TODO 만약 recipients가 selfOutput 1개로만 이루어진 경우 Sweep을 해야함
        if (externalOutputs == null && recipientMap.length == 1) {
          final sweepRecipients = _createSweepRecipients(
            recipientMap,
            selfOutputs!.firstWhere((output) => output.address == recipientMap.keys.first),
          );
          txBuildResult = _tryBuildTransactionWithFeeAdjusting(
            sweepRecipients,
            finalFeeRate,
            utxos: addedUtxos,
            isSweep: true,
          );
        } else {
          txBuildResult = _tryBuildTransactionWithFeeAdjusting(recipientMap, finalFeeRate, utxos: addedUtxos);
        }

        if (txBuildResult?.isSuccess == true) {
          final rbfBuildResult = RbfBuildResult(
            transaction: txBuildResult!.transaction,
            minimumFeeRate:
                isBaseline ? txBuildResult.getFeeRate(walletListItemBase)! : _cachedBaseline!.minimumFeeRate,
            estimatedVSize: txBuildResult.transaction!.estimateVirtualByteForWallet(walletListItemBase),
            isSelfOutputsUsed: selfOutputs != null,
            addedInputs: addedUtxos,
          );

          return (result: rbfBuildResult, remainingDeficit: 0, addedUtxos: addedUtxos, estimatedTxSize: vSize);
        }
      }

      remaining -= _additionalSpendable[0].amount;
      i++;
    } while (i < _additionalSpendable.length && remaining > 0); // TODO: remaining <= 0 인데도 실패하는 경우가 있을까??

    return (result: null, remainingDeficit: remaining, addedUtxos: addedUtxos, estimatedTxSize: vSize);
  }

  ({RbfBuildResult? result, int? remainingDeficit}) _tryWithChangeOutput({
    required int deficitAmount,
    required double feeRate,
    required Map<String, int> recipientMap,
  }) {
    if (changeOutput!.amount >= deficitAmount) {
      final txBuildResult = _buildTransaction(feeRate, recipientMap, []);
      if (txBuildResult.isSuccess) {
        final tx = txBuildResult.transaction!;
        final result = RbfBuildResult(
          transaction: tx,
          isOnlyChangeOutputUsed: true,
          minimumFeeRate: txBuildResult.getFeeRate(walletListItemBase)!,
          estimatedVSize: tx.estimateVirtualByteForWallet(walletListItemBase),
        );
        return (result: result, remainingDeficit: null);
      } else if (txBuildResult.exception != null &&
          txBuildResult.exception is! tx_creation_exception.InsufficientBalanceException) {
        // TODO: FixedBottomButon 윗부분에 붉은색으로 표기되도록 하기!!
        throw '⚠️ ChangeOutput is enough but failed creationg tx / ${txBuildResult.exception.toString()}';
      }
    }

    return (result: null, remainingDeficit: deficitAmount - changeOutput!.amount);
  }

  RbfBuildResult _buildRbf(int initialDeficit, double newFeeRate, double initialVSize, {required bool isBaseline}) {
    int deficitAmount = initialDeficit;
    double newTxVSize = initialVSize;
    if (changeOutput != null) {
      final (:result, :remainingDeficit) = _tryWithChangeOutput(
        deficitAmount: deficitAmount,
        feeRate: newFeeRate,
        recipientMap: recipientMap,
      );
      if (result != null) {
        return result.copyWith(minimumFeeRate: isBaseline ? null : _cachedBaseline!.minimumFeeRate);
      } else {
        deficitAmount = remainingDeficit!;
      }
    }

    // selfOutput 조작: deficitAmount를 selfOutput 차감/제거로 줄임
    Map<String, int> effectiveRecipients = recipientMap;
    if (selfOutputs?.isNotEmpty == true) {
      final (:result, :newRecipients, :remainingDeficit, :vSizeReduced) = _tryWithSelfOutputReduction(
        deficitAmount,
        newFeeRate,
      );

      if (result != null) {
        return result.copyWith(minimumFeeRate: isBaseline ? null : _cachedBaseline!.minimumFeeRate);
      }

      effectiveRecipients = newRecipients;
      deficitAmount = remainingDeficit;
      newTxVSize -= vSizeReduced;
    }

    List<UtxoState> addedInputs = [];
    if (_additionalSpendable.isNotEmpty) {
      final (:result, :remainingDeficit, :addedUtxos, :estimatedTxSize) = _tryWithAdditionalSpendable(
        deficitAmount: deficitAmount,
        feeRate: newFeeRate,
        estimatedTxSize: newTxVSize,
        recipientMap: effectiveRecipients,
        isBaseline: isBaseline,
      );

      if (result != null) {
        return result.copyWith(minimumFeeRate: isBaseline ? null : _cachedBaseline!.minimumFeeRate);
      }

      deficitAmount = remainingDeficit;
      newTxVSize = estimatedTxSize;
      addedInputs = addedUtxos;
    }

    return RbfBuildResult(
      minimumFeeRate:
          isBaseline ? _calculateMinimumFeeRate(newTxVSize + _vSizeIncreasePerInput) : _cachedBaseline!.minimumFeeRate,
      addedInputs: addedInputs.isEmpty ? null : addedInputs,
      deficitAmount:
          deficitAmount + (_vSizeIncreasePerInput * (isBaseline ? incrementalRelayFeeRate : newFeeRate)).ceil(),
      estimatedVSize: newTxVSize + _vSizeIncreasePerInput,
      isSelfOutputsUsed: selfOutputs != null,
      exception: const InsufficientBalanceException(),
    );

    // getBaselineTransaction()에서 모자란 경우 첫 번째 input의 overhead를 이미 반영했으므로 skip
    final (:addedUtxos, :remainingDeficit, :updatedVSize) = _selectAdditionalUtxos(
      deficitAmount: deficitAmount,
      feeRate: isBaseline ? incrementalRelayFeeRate : newFeeRate,
      currentVSize: newTxVSize,
      skipFirstInputOverhead: isBaseline ? false : _cachedBaseline!.deficitAmount != null,
    );
    deficitAmount = remainingDeficit;
    newTxVSize = updatedVSize;

    if (deficitAmount == 0) {
      bool isSweep = false;
      // TODO: 테스트 필요
      if (externalOutputs == null) {
        final addedUtxosSum = addedUtxos.fold<int>(0, (sum, utxo) => sum + utxo.amount);
        final lastEntry = effectiveRecipients.entries.last;
        effectiveRecipients = {...effectiveRecipients, lastEntry.key: lastEntry.value + addedUtxosSum};
        isSweep = true;
      }
      final txBuildResult = _buildTransaction(
        isBaseline ? _calculateMinimumFeeRate(newTxVSize) : newFeeRate,
        effectiveRecipients,
        addedUtxos,
        isSweep: isSweep,
      );
      if (txBuildResult.isSuccess) {
        final tx = txBuildResult.transaction!;
        return RbfBuildResult(
          transaction: tx,
          isSelfOutputsUsed: _isSelfOutputUsed(effectiveRecipients),
          minimumFeeRate: isBaseline ? txBuildResult.getFeeRate(walletListItemBase)! : _cachedBaseline!.minimumFeeRate,
          addedInputs: addedUtxos.isEmpty ? null : addedUtxos,
          estimatedVSize: tx.estimateVirtualByteForWallet(walletListItemBase),
        );
      } else if (txBuildResult.exception != null &&
          txBuildResult.exception is! tx_creation_exception.InsufficientBalanceException) {
        // TODO: FixedBottomButon 윗부분에 붉은색으로 표기되도록 하기!!
        throw 'AdditionalSpendable enough but failed creating tx / ${txBuildResult.exception.toString()}';
      }
    }

    // 추가 UTXO가 필요한 상황이어서 _vSizeIncreasePerInput을 필요한 곳에 더해줌
    return RbfBuildResult(
      minimumFeeRate:
          isBaseline ? _calculateMinimumFeeRate(newTxVSize + _vSizeIncreasePerInput) : _cachedBaseline!.minimumFeeRate,
      addedInputs: addedUtxos.isEmpty ? null : addedUtxos,
      deficitAmount:
          deficitAmount + (_vSizeIncreasePerInput * (isBaseline ? incrementalRelayFeeRate : newFeeRate)).ceil(),
      estimatedVSize: newTxVSize + _vSizeIncreasePerInput,
      isSelfOutputsUsed: selfOutputs != null,
      exception: const InsufficientBalanceException(),
    );
  }

  RbfBuildResult getBaselineTransaction({bool isForce = false}) {
    if (!isForce && _cachedBaseline != null) return _cachedBaseline!;

    double newTxVSize = _pendingTx.vSize;
    if (changeOutput == null) {
      // RBF 최소 수수료율을 구할 때는 changeOutput이 있다고 가정하고 보수적으로 계산
      newTxVSize += _vSizeChangeOutput * _pendingTx.feeRate;
    }

    int additionalFee = _calculateMinAdditionalFee(newTxSize: newTxVSize);
    int minimumFee = _calculateMinimumRbfFee(newTxVSize: newTxVSize);
    int deficitAmount = additionalFee;
    double minimumFeeRate = FeeRateUtils.ceilFeeRate(minimumFee / newTxVSize);

    _cachedBaseline = _buildRbf(deficitAmount, minimumFeeRate, newTxVSize, isBaseline: true);
    return _cachedBaseline!;
  }

  RbfBuildResult changeAdditionalSpendable(List<UtxoState> utxos) {
    _assertAllUnspent(utxos);
    _additionalSpendable = [...utxos]..sort((a, b) => b.amount.compareTo(a.amount));
    return getBaselineTransaction(isForce: true);
  }

  RbfBuildResult build({required double newFeeRate}) {
    _cachedBaseline ??= getBaselineTransaction();
    try {
      if (newFeeRate < _cachedBaseline!.minimumFeeRate) {
        throw const FeeRateTooLowException();
      }

      final int requiredFee = (_cachedBaseline!.estimatedVSize * newFeeRate).ceil();
      final int additionalFee = requiredFee - _pendingTx.fee;
      int deficitAmount = additionalFee;

      return _buildRbf(deficitAmount, newFeeRate, _cachedBaseline!.estimatedVSize, isBaseline: false);
    } on RbfCreationException catch (e) {
      return RbfBuildResult(
        transaction: null,
        exception: e,
        minimumFeeRate: _cachedBaseline!.minimumFeeRate,
        estimatedVSize: _cachedBaseline!.estimatedVSize,
      );
    }
  }

  // int _getEstimatedRequiredFee(double newFeeRate, Map<String, int> recipients) {
  //   final txBuildResult = _buildTransaction(newFeeRate, recipients);
  //   return txBuildResult.estimatedFee - (txBuildResult.unintendedDustFee ?? 0);
  // }

  TransactionBuildResult _buildTransaction(
    double newFeeRate,
    Map<String, int> recipients,
    List<UtxoState> additionalUtxos, {
    bool isSweep = false,
  }) {
    Logger.log(
      '_buildTx: $newFeeRate / recipients: ${recipients.length} / addedUtxo: ${additionalUtxos.length} / $isSweep',
    );
    final changeDerivationPath = changeOutput == null ? nextChangeAddress.derivationPath : changeOutputDerivationPath!;

    return TransactionBuilder(
      availableUtxos: [..._inputUtxos, ...additionalUtxos],
      recipients: recipients,
      feeRate: newFeeRate,
      changeDerivationPath: changeDerivationPath,
      walletListItemBase: walletListItemBase,
      isFeeSubtractedFromAmount: isSweep,
      isUtxoFixed: true,
    ).build();
  }

  static void _assertAllUnspent(List<UtxoState> utxos) {
    for (final utxo in utxos) {
      if (utxo.status != UtxoStatus.unspent) {
        throw ArgumentError('additionalSpendable contains a non-unspent UTXO: ${utxo.transactionHash}:${utxo.index}');
      }
    }
  }
}
