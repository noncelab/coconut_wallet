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
      final remainingLastSelfOutput = selfOutputs!.reversed.cast<TransactionAddress?>().firstWhere(
        (output) => newRecipients.containsKey(output!.address),
        orElse: () => null,
      );
      if (remainingLastSelfOutput != null) {
        final (:result, :recipients) = _trySelfOutputReductionSweep(newRecipients, remainingLastSelfOutput, feeRate);
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
        Logger.log('_tryBuildTransactionWithFeeAdjusting 재보정 시도');
        final requiredFeeRate = FeeRateUtils.ceilFeeRate(minimumRequiredFee / actualVSize);
        final retryResult = _buildTransaction(requiredFeeRate, recipients, utxos ?? [], isSweep: isSweep);
        if (retryResult.isSuccess) {
          Logger.log('_tryBuildTransactionWithFeeAdjusting 재보정 성공 🟢');
          return retryResult;
        } else {
          Logger.log('_tryBuildTransactionWithFeeAdjusting 재보정 실패 🔴');
          return null;
        }
      }

      return txBuildResult;
    } else if (txBuildResult.exception != null &&
        txBuildResult.exception is! tx_creation_exception.InsufficientBalanceException) {
      Logger.error('_tryBuildTransactionWithFeeAdjusting failed: ${txBuildResult.exception.toString()}');
    }
    return null;
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
        if (externalOutputs == null && recipientMap.length == 1) {
          final addedUtxosSum = addedUtxos.fold<int>(0, (sum, utxo) => sum + utxo.amount);
          final sweepAddr = recipientMap.keys.first;
          final sweepRecipients = {sweepAddr: inputSum + addedUtxosSum};
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
    } while (i < _additionalSpendable.length && remaining > 0);

    return (result: null, remainingDeficit: remaining, addedUtxos: addedUtxos, estimatedTxSize: vSize);
  }

  ({RbfBuildResult? result, int? remainingDeficit}) _tryWithChangeOutput({
    required int deficitAmount,
    required double feeRate,
    required Map<String, int> recipientMap,
  }) {
    if (changeOutput!.amount >= deficitAmount) {
      final TransactionBuildResult? txBuildResult = _tryBuildTransactionWithFeeAdjusting(recipientMap, feeRate);
      if (txBuildResult != null) {
        final tx = txBuildResult.transaction!;
        final result = RbfBuildResult(
          transaction: tx,
          isOnlyChangeOutputUsed: true,
          minimumFeeRate: txBuildResult.getFeeRate(walletListItemBase)!,
          estimatedVSize: tx.estimateVirtualByteForWallet(walletListItemBase),
        );
        return (result: result, remainingDeficit: null);
      } else {
        // TODO: FixedBottomButon 윗부분에 붉은색으로 표기되도록 하기!!
        throw '⚠️ ChangeOutput is enough but failed creationg tx';
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
  }

  /// pendingTx를 이용해서 RBF에 필요한 임시 추가 수수료와 임시 최소 수수료율을 계산한다.
  ({int initialAdditionalFee, double initialRbfFeeRate}) _getAdditionalFeeAndRate() {
    double newTxVSize = _pendingTx.vSize;
    if (changeOutput == null) {
      // RBF 최소 수수료율을 구할 때는 changeOutput이 있다고 가정하고 보수적으로 계산
      newTxVSize += _vSizeChangeOutput;
    }

    int additionalFee = _calculateMinAdditionalFee(newTxSize: newTxVSize);
    int minimumFee = _calculateMinimumRbfFee(newTxVSize: newTxVSize);

    return (initialAdditionalFee: additionalFee, initialRbfFeeRate: FeeRateUtils.ceilFeeRate(minimumFee / newTxVSize));
  }

  RbfBuildResult getBaselineTransaction({bool isForce = false}) {
    if (!isForce && _cachedBaseline != null) return _cachedBaseline!;

    double newTxVSize = _pendingTx.vSize;
    if (changeOutput == null) {
      // RBF 최소 수수료율을 구할 때는 changeOutput이 있다고 가정하고 보수적으로 계산
      newTxVSize += _vSizeChangeOutput;
    }

    final (:initialAdditionalFee, :initialRbfFeeRate) = _getAdditionalFeeAndRate();
    int deficitAmount = initialAdditionalFee;

    _cachedBaseline = _buildRbf(deficitAmount, incrementalRelayFeeRate, newTxVSize, isBaseline: true);
    return _cachedBaseline!;
  }

  RbfBuildResult changeAdditionalSpendable(List<UtxoState> utxos) {
    _assertAllUnspent(utxos);
    _additionalSpendable = [...utxos]..sort((a, b) => b.amount.compareTo(a.amount));
    return getBaselineTransaction(isForce: true);
  }

  RbfBuildResult build({required double newFeeRate}) {
    _cachedBaseline ??= getBaselineTransaction();
    if (newFeeRate < _cachedBaseline!.minimumFeeRate) {
      throw const FeeRateTooLowException();
    }

    int requiredFee = (_cachedBaseline!.estimatedVSize * newFeeRate).ceil();
    int additionalFee = requiredFee - _pendingTx.fee;
    final (:initialAdditionalFee, :initialRbfFeeRate) = _getAdditionalFeeAndRate();
    // self output 사용으로 _cachedBaseline.estimatedVSize가 처음 계산할 때보다 작아진 경우를 대비
    // 적은 requiredFee로 RBF Tx 생성 시 잘못된 결과가 반환되기 때문
    if (additionalFee < initialAdditionalFee) {
      additionalFee = initialAdditionalFee;
    }
    int deficitAmount = additionalFee;

    return _buildRbf(deficitAmount, newFeeRate, _cachedBaseline!.estimatedVSize, isBaseline: false);
  }

  TransactionBuildResult _buildTransaction(
    double newFeeRate,
    Map<String, int> recipients,
    List<UtxoState> additionalUtxos, {
    bool isSweep = false,
  }) {
    Logger.log(
      '[_buildTx] feeRate: $newFeeRate / recipients: ${recipients.length} / addedUtxo: ${additionalUtxos.length} / isSweep: $isSweep',
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
