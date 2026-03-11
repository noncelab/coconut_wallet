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

  TransactionBuildResult? _trySelfOutputReductionSweep(
    Map<String, int> recipients,
    TransactionAddress lastSelfOutput,
    double feeRate,
  ) {
    final sweepRecipients = _createSweepRecipients(recipients, lastSelfOutput);
    final result = _buildTransaction(feeRate, sweepRecipients, [], isSweep: true);
    if (result.isSuccess) {
      final tx = result.transaction!;
      final actualVSize = tx.estimateVirtualByteForWallet(walletListItemBase);
      final actualFee = tx.totalInputAmount - tx.outputs.fold(0, (sum, output) => sum + output.amount);
      final minimumRequiredFee = _pendingTx.fee + actualVSize;

      // RBF 최소 조건을 만족하지 못하면 더 높은 feeRate로 재빌드
      if (actualFee < minimumRequiredFee) {
        final requiredFeeRate = FeeRateUtils.ceilFeeRate(minimumRequiredFee / actualVSize);
        final retryResult = _buildTransaction(requiredFeeRate, sweepRecipients, [], isSweep: true);
        if (retryResult.isSuccess) {
          return retryResult;
        }
      }

      return result;
    }

    return null;
  }

  /// selfOutput의 amount를 줄이거나 제거하여 deficitAmount를 줄이는 함수.
  ///
  /// - 부분 차감: selfOutput.amount - deficit > dustLimit → amount만 줄임 (vSize 변화 없음)
  /// - 전체 제거: 위 조건 불만족 → output 전체 제거.
  ///   deficit -= (selfOutput.amount + ceil(outputBytes * feeRate))
  ///   output이 제거되면 vSize가 줄어들고, 그 절약된 fee도 deficit 감소에 기여함.
  /// params estimatedAdditionalFee: 처음에 예상했던 수수료
  ({Map<String, int>? newRecipients, int remainingDeficit, int vSizeReduced, TransactionBuildResult? txBuildResult})
  _tryWithSelfOutputReduction(int deficitAmount, double feeRate, int estimatedAdditionalFee) {
    if (selfOutputs?.isNotEmpty != true) {
      return (newRecipients: null, remainingDeficit: deficitAmount, vSizeReduced: 0, txBuildResult: null);
    }

    Map<String, int> newRecipients = Map.from(recipientMap);
    int leftDeficit = deficitAmount;
    int vSizeReduced = 0;
    final feeSavedByRemoval = (_vSizeChangeOutput * feeRate).ceil();
    for (int i = selfOutputs!.length - 1; i >= 0; i--) {
      final selfOutput = selfOutputs![i];
      if (selfOutput.amount - leftDeficit >= dustLimit) {
        // TODO: 테스트 필요 (externalOutputs == null인지 확인 없이 Sweep으로 처리해본다.)
        final txBuildResult = _trySelfOutputReductionSweep(newRecipients, selfOutput, feeRate);
        if (txBuildResult != null) {
          return (
            newRecipients: txBuildResult.transaction!.outputs.fold(<String, int>{}, (
              previousValue,
              TransactionOutput element,
            ) {
              previousValue![element.getAddress()] = element.amount;
              return previousValue;
            }),
            remainingDeficit: 0,
            vSizeReduced: vSizeReduced,
            txBuildResult: txBuildResult,
          );
        }
      }
      // recipients에 selfOutput 1개만 남은 경우
      if (newRecipients.length == 1) {
        // TODO: external output 없이 self output만 있는 경우 sweep tx 처리 필요
        // TODO: 테스트 필요
        newRecipients = _createSweepRecipients(newRecipients, selfOutput);
        leftDeficit -= feeSavedByRemoval;
        vSizeReduced += _vSizeChangeOutput;
        break;
      }
      // 전체 제거: output 금액 + output byte 제거로 절약되는 fee가 함께 deficit 감소에 기여
      newRecipients.removeWhere((key, value) => key == selfOutput.address && value == selfOutput.amount);
      leftDeficit -= selfOutput.amount + feeSavedByRemoval;
      vSizeReduced += _vSizeChangeOutput;
      if (leftDeficit <= 0) {
        leftDeficit = 0;
        break;
      }
    }

    assert(newRecipients.isNotEmpty);
    return (
      newRecipients: newRecipients,
      remainingDeficit: leftDeficit,
      vSizeReduced: vSizeReduced,
      txBuildResult: null,
    );
  }

  ({List<UtxoState> addedUtxos, int remainingDeficit, double updatedVSize}) _selectAdditionalUtxos({
    required int deficitAmount,
    required double feeRatePerInput,
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
          remaining += (_vSizeIncreasePerInput * feeRatePerInput).ceil();
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
    if (changeOutput != null) {
      if (changeOutput!.amount >= deficitAmount) {
        final txBuildResult = _buildTransaction(minimumFeeRate, recipientMap, []);
        if (txBuildResult.isSuccess) {
          final tx = txBuildResult.transaction!;
          _cachedBaseline = RbfBuildResult(
            transaction: tx,
            isOnlyChangeOutputUsed: true,
            minimumFeeRate: txBuildResult.getFeeRate(walletListItemBase)!,
            estimatedVSize: tx.estimateVirtualByteForWallet(walletListItemBase),
          );
          return _cachedBaseline!;
        } else if (txBuildResult.exception != null &&
            txBuildResult.exception is! tx_creation_exception.InsufficientBalanceException) {
          // TODO: FixedBottomButon 윗부분에 붉은색으로 표기되도록 하기!!
          throw 'RbfBuilder.getBaselineTransaction / changeOutput is enough but failed creationg tx / ${txBuildResult.exception.toString()}';
        }
      } else {
        deficitAmount -= changeOutput!.amount;
      }
    }

    // selfOutput 조작: deficitAmount를 selfOutput 차감/제거로 줄임
    Map<String, int> effectiveRecipients = recipientMap;
    if (selfOutputs?.isNotEmpty == true) {
      final (
        :newRecipients,
        remainingDeficit: deficitAfterSelfOutputReduction,
        :vSizeReduced,
        :txBuildResult,
      ) = _tryWithSelfOutputReduction(deficitAmount, minimumFeeRate, additionalFee);

      // 추가됨
      if (txBuildResult != null) {
        return RbfBuildResult(
          transaction: txBuildResult.transaction!,
          isSelfOutputsUsed: true,
          minimumFeeRate: txBuildResult.getFeeRate(walletListItemBase)!,
          estimatedVSize: txBuildResult.transaction!.estimateVirtualByteForWallet(walletListItemBase),
        );
      }
      // 추가됨

      if (newRecipients != null) {
        effectiveRecipients = newRecipients;
        deficitAmount = deficitAfterSelfOutputReduction;
        newTxVSize -= vSizeReduced;
        if (deficitAmount == 0) {
          final txBuildResult = _buildTransaction(_calculateMinimumFeeRate(newTxVSize), effectiveRecipients, []);
          if (txBuildResult.isSuccess) {
            final tx = txBuildResult.transaction!;
            _cachedBaseline = RbfBuildResult(
              transaction: tx,
              isSelfOutputsUsed: true,
              minimumFeeRate: txBuildResult.getFeeRate(walletListItemBase)!,
              estimatedVSize: tx.estimateVirtualByteForWallet(walletListItemBase),
            );
            return _cachedBaseline!;
          } else if (txBuildResult.exception != null && txBuildResult.exception is! InsufficientBalanceException) {
            throw 'RbfBuilder.getBaselineTransaction / selfOutput reduction but failed creating tx / ${txBuildResult.exception.toString()}';
          }
        }
      }
    }

    final (:addedUtxos, :remainingDeficit, :updatedVSize) = _selectAdditionalUtxos(
      deficitAmount: deficitAmount,
      feeRatePerInput: incrementalRelayFeeRate,
      currentVSize: newTxVSize,
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
        _calculateMinimumFeeRate(newTxVSize),
        effectiveRecipients,
        addedUtxos,
        isSweep: isSweep,
      );
      if (txBuildResult.isSuccess) {
        final tx = txBuildResult.transaction!;
        _cachedBaseline = RbfBuildResult(
          transaction: tx,
          isSelfOutputsUsed: _isSelfOutputUsed(effectiveRecipients),
          minimumFeeRate: txBuildResult.getFeeRate(walletListItemBase)!,
          addedInputs: addedUtxos.isEmpty ? null : addedUtxos,
          estimatedVSize: tx.estimateVirtualByteForWallet(walletListItemBase),
        );
        return _cachedBaseline!;
      } else if (txBuildResult.exception != null && txBuildResult.exception is! InsufficientBalanceException) {
        // TODO: FixedBottomButon 윗부분에 붉은색으로 표기되도록 하기!!
        throw 'RbfBuilder.getBaselineTransaction / AdditionalSpendable enough but failed creating tx / ${txBuildResult.exception.toString()}';
      }
    }

    // 추가 UTXO가 필요한 상황이어서 더해줌
    newTxVSize += _vSizeIncreasePerInput;
    deficitAmount += _vSizeIncreasePerInput;
    _cachedBaseline = RbfBuildResult(
      minimumFeeRate: _calculateMinimumFeeRate(newTxVSize),
      addedInputs: addedUtxos.isEmpty ? null : addedUtxos,
      deficitAmount: deficitAmount,
      estimatedVSize: newTxVSize,
    );
    return _cachedBaseline!;
  }

  RbfBuildResult changeAdditionalSpendable(List<UtxoState> utxos) {
    _assertAllUnspent(utxos);
    _additionalSpendable = [...utxos]..sort((a, b) => b.amount.compareTo(a.amount));
    _cachedBaseline = getBaselineTransaction(isForce: true);
    return _cachedBaseline!;
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
      if (changeOutput != null) {
        if (changeOutput!.amount >= deficitAmount) {
          final txBuildResult = _buildTransaction(newFeeRate, recipientMap, []);
          if (txBuildResult.isSuccess) {
            final tx = txBuildResult.transaction!;
            return RbfBuildResult(
              transaction: tx,
              isOnlyChangeOutputUsed: true,
              minimumFeeRate: _cachedBaseline!.minimumFeeRate,
              estimatedVSize: tx.estimateVirtualByteForWallet(walletListItemBase),
            );
          } else if (txBuildResult.exception != null && txBuildResult.exception is! InsufficientBalanceException) {
            // TODO: FixedBottomButon 윗부분에 붉은색으로 표기되도록 하기!!
            throw 'RbfBuilder.build / changeOutput is enough but failed creationg tx / ${txBuildResult.exception.toString()}';
          }
        } else {
          deficitAmount -= changeOutput!.amount;
        }
      }

      // selfOutput 조작: deficitAmount를 selfOutput 차감/제거로 줄임
      Map<String, int> effectiveRecipients = recipientMap;
      double baseVSize = _cachedBaseline!.estimatedVSize;
      if (selfOutputs?.isNotEmpty == true) {
        final (
          :newRecipients,
          remainingDeficit: deficitAfterSelfOutputReduction,
          :vSizeReduced,
          :txBuildResult,
        ) = _tryWithSelfOutputReduction(deficitAmount, newFeeRate, additionalFee);

        // 추가됨
        if (txBuildResult != null) {
          return RbfBuildResult(
            transaction: txBuildResult.transaction!,
            isSelfOutputsUsed: true,
            minimumFeeRate: _cachedBaseline!.minimumFeeRate,
            estimatedVSize: txBuildResult.transaction!.estimateVirtualByteForWallet(walletListItemBase),
          );
        }
        // 추가됨

        if (newRecipients != null) {
          effectiveRecipients = newRecipients;
          deficitAmount = deficitAfterSelfOutputReduction;
          baseVSize -= vSizeReduced;
          if (deficitAmount == 0) {
            final txBuildResult = _buildTransaction(newFeeRate, effectiveRecipients, []);
            if (txBuildResult.isSuccess) {
              final tx = txBuildResult.transaction!;
              return RbfBuildResult(
                transaction: tx,
                isSelfOutputsUsed: true,
                minimumFeeRate: _cachedBaseline!.minimumFeeRate,
                estimatedVSize: tx.estimateVirtualByteForWallet(walletListItemBase),
              );
            } else if (txBuildResult.exception != null &&
                txBuildResult.exception is! tx_creation_exception.InsufficientBalanceException) {
              throw 'RbfBuilder.build / selfOutput reduction but failed creating tx / ${txBuildResult.exception.toString()}';
            }
          }
        }
      }

      // getBaselineTransaction()에서 모자란 경우 첫 번째 input의 overhead를 이미 반영했으므로 skip
      final (:addedUtxos, :remainingDeficit, updatedVSize: newTxVSize) = _selectAdditionalUtxos(
        deficitAmount: deficitAmount,
        feeRatePerInput: newFeeRate,
        currentVSize: baseVSize,
        skipFirstInputOverhead: _cachedBaseline!.deficitAmount != null,
      );
      deficitAmount = remainingDeficit;

      if (deficitAmount == 0) {
        bool isSweep = false;
        if (externalOutputs == null) {
          final addedUtxosSum = addedUtxos.fold<int>(0, (sum, utxo) => sum + utxo.amount);
          final lastEntry = effectiveRecipients.entries.last;
          effectiveRecipients = {...effectiveRecipients, lastEntry.key: lastEntry.value + addedUtxosSum};
          isSweep = true;
        }
        final txBuildResult = _buildTransaction(newFeeRate, effectiveRecipients, addedUtxos, isSweep: isSweep);
        if (txBuildResult.isSuccess) {
          final tx = txBuildResult.transaction!;
          return RbfBuildResult(
            transaction: tx,
            isSelfOutputsUsed: _isSelfOutputUsed(effectiveRecipients),
            minimumFeeRate: _cachedBaseline!.minimumFeeRate,
            addedInputs: addedUtxos.isEmpty ? null : addedUtxos,
            estimatedVSize: tx.estimateVirtualByteForWallet(walletListItemBase),
          );
        } else if (txBuildResult.exception != null &&
            txBuildResult.exception is! tx_creation_exception.InsufficientBalanceException) {
          // TODO: FixedBottomButon 윗부분에 붉은색으로 표기되도록 하기!!
          throw 'RbfBuilder.build / AdditionalSpendable enough but failed creating tx / ${txBuildResult.exception.toString()}';
        }
      }

      return RbfBuildResult(
        minimumFeeRate: _cachedBaseline!.minimumFeeRate,
        addedInputs: addedUtxos.isEmpty ? null : addedUtxos,
        deficitAmount: deficitAmount + (_vSizeIncreasePerInput * newFeeRate).ceil(),
        estimatedVSize: newTxVSize + _vSizeIncreasePerInput,
        isSelfOutputsUsed: selfOutputs != null,
        exception: const InsufficientBalanceException(),
      );
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

class _AdjustedRecipients {
  final Map<String, int> recipients;
  final List<TransactionAddress> removedSelfOutputs;
  final List<TransactionAddress> reducedSelfOutputs;

  _AdjustedRecipients({required this.recipients, required this.removedSelfOutputs, required this.reducedSelfOutputs});
}
