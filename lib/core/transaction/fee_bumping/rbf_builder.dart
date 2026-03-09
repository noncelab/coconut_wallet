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

  ({TransactionBuildResult? txBuildResult, Map<String, int>? newRecipients, int? leftDeficit})
  _tryWithSelfOutputReduction(int deficitAmount, double feeRate) {
    if (selfOutputs?.isNotEmpty != true) return (txBuildResult: null, newRecipients: null, leftDeficit: null);

    // if (selfOutputs!.length == 1 && externalOutputs == null) {
    //    final result = _handleSingleSelfOutputSweep(feeRate: feeRate, selfOutputAddress: selfOutputAddress)
    // }

    Map<String, int> newRecipients = Map.from(recipientMap);
    int leftDeficit = deficitAmount;
    for (int i = selfOutputs!.length - 1; i >= 0; i--) {
      if (selfOutputs![i].amount >= leftDeficit && selfOutputs![i].amount - leftDeficit > dustLimit) {
        final result = _buildSweepTransaction(feeRate, newRecipients, []);
        if (result.isSuccess) {
          return (txBuildResult: result, newRecipients: newRecipients, leftDeficit: 0);
        } else {
          // INFO: 이 지점에 도달할 일이 없을 거라고 예상됨 TODO: 이 지점에 도달 시 원인 파악 후 추가 예외 처리 필요
          throw '_tryWithSelfOutputReduction _buildSweepTx result.isFailure: ${result.exception.toString()}';
        }
      } else {
        // 남은게 dustlimit보다 작으면 제거
        newRecipients.remove(selfOutputs![i].address);
        leftDeficit -= selfOutputs![i].amount;
        // TODO: 이렇게 해도 괜찮은건지 지금 판단이 안됨....
        leftDeficit -= (_vSizeChangeOutput * feeRate).toInt();
      }
    }

    if (newRecipients.isEmpty) {
      newRecipients.addEntries([MapEntry(selfOutputs![0].address, selfOutputs![0].amount)]);
    }

    return (txBuildResult: null, newRecipients: newRecipients, leftDeficit: leftDeficit);
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

    for (int i = 0; i < _additionalSpendable.length && remaining > 0; i++) {
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
    }

    return (addedUtxos: addedUtxos, remainingDeficit: remaining, updatedVSize: vSize);
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
    if (changeOutput != null) {
      if (changeOutput!.amount >= deficitAmount) {
        double minimumFeeRate = FeeRateUtils.ceilFeeRate(minimumFee / newTxVSize);
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
        } else if (txBuildResult.exception != null && txBuildResult.exception is! InsufficientBalanceException) {
          // TODO: FixedBottomButon 윗부분에 붉은색으로 표기되도록 하기!!
          throw 'RbfBuilder.getBaselineTransaction / changeOutput is enough but failed creationg tx / ${txBuildResult.exception.toString()}';
        }
      } else {
        deficitAmount -= changeOutput!.amount;
      }
    }

    // TODO: self Output 조작을 우선 생략...

    final (:addedUtxos, :remainingDeficit, :updatedVSize) = _selectAdditionalUtxos(
      deficitAmount: deficitAmount,
      feeRatePerInput: incrementalRelayFeeRate,
      currentVSize: newTxVSize,
    );
    deficitAmount = remainingDeficit;
    newTxVSize = updatedVSize;

    if (deficitAmount == 0) {
      final txBuildResult = _buildTransaction(_calculateMinimumFeeRate(newTxVSize), recipientMap, addedUtxos);
      if (txBuildResult.isSuccess) {
        final tx = txBuildResult.transaction!;
        _cachedBaseline = RbfBuildResult(
          transaction: tx,
          minimumFeeRate: txBuildResult.getFeeRate(walletListItemBase)!,
          addedInputs: addedUtxos.isEmpty ? null : addedUtxos,
          estimatedVSize: tx.estimateVirtualByteForWallet(walletListItemBase),
        );
        return _cachedBaseline!;
      } else if (txBuildResult.exception != null && txBuildResult.exception is! InsufficientBalanceException) {
        // TODO: FixedBottomButon 윗부분에 붉은색으로 표기되도록 하기!!
        throw 'RbfBuilder.getBaselineTransaction / AdditionalSpendable enough but failed creationg tx / ${txBuildResult.exception.toString()}';
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

      // TODO: self Output 조작을 우선 생략...

      // getBaselineTransaction()에서 모자란 경우 첫 번째 input의 overhead를 이미 반영했으므로 skip
      final (:addedUtxos, :remainingDeficit, updatedVSize: newTxVSize) = _selectAdditionalUtxos(
        deficitAmount: deficitAmount,
        feeRatePerInput: newFeeRate,
        currentVSize: _cachedBaseline!.estimatedVSize,
        skipFirstInputOverhead: _cachedBaseline!.deficitAmount != null,
      );
      deficitAmount = remainingDeficit;

      if (deficitAmount == 0) {
        final txBuildResult = _buildTransaction(newFeeRate, recipientMap, addedUtxos);
        if (txBuildResult.isSuccess) {
          final tx = txBuildResult.transaction!;
          return RbfBuildResult(
            transaction: tx,
            minimumFeeRate: _cachedBaseline!.minimumFeeRate,
            addedInputs: addedUtxos.isEmpty ? null : addedUtxos,
            estimatedVSize: tx.estimateVirtualByteForWallet(walletListItemBase),
          );
        } else if (txBuildResult.exception != null && txBuildResult.exception is! InsufficientBalanceException) {
          // TODO: FixedBottomButon 윗부분에 붉은색으로 표기되도록 하기!!
          throw 'RbfBuilder.build / AdditionalSpendable enough but failed creationg tx / ${txBuildResult.exception.toString()}';
        }
      }

      return RbfBuildResult(
        minimumFeeRate: _cachedBaseline!.minimumFeeRate,
        addedInputs: addedUtxos.isEmpty ? null : addedUtxos,
        deficitAmount: deficitAmount + (_vSizeIncreasePerInput * newFeeRate).ceil(),
        estimatedVSize: newTxVSize + _vSizeIncreasePerInput,
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
    List<UtxoState> additionalUtxos,
  ) {
    final changeDerivationPath = changeOutput == null ? nextChangeAddress.derivationPath : changeOutputDerivationPath!;

    return TransactionBuilder(
      availableUtxos: [..._inputUtxos, ...additionalUtxos],
      recipients: recipients,
      feeRate: newFeeRate,
      changeDerivationPath: changeDerivationPath,
      walletListItemBase: walletListItemBase,
      isFeeSubtractedFromAmount: false,
      isUtxoFixed: true,
    ).build();
  }

  TransactionBuildResult _buildSweepTransaction(
    double newFeeRate,
    Map<String, int> recipients,
    List<UtxoState> additionalUtxos,
  ) {
    final changeDerivationPath = changeOutput == null ? nextChangeAddress.derivationPath : changeOutputDerivationPath!;

    return TransactionBuilder(
      availableUtxos: [..._inputUtxos, ...additionalUtxos],
      recipients: recipients,
      feeRate: newFeeRate,
      changeDerivationPath: changeDerivationPath,
      walletListItemBase: walletListItemBase,
      isFeeSubtractedFromAmount: true,
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
