import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/core/exceptions/rbf_creation/rbf_creation_exception.dart';
import 'package:coconut_wallet/core/exceptions/transaction_creation/transaction_creation_exception.dart'
    as TxCreationException;
import 'package:coconut_wallet/core/transaction/transaction_builder.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/model/wallet/transaction_address.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/wallet/wallet_address.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/providers/view_model/wallet_detail/fee_bumping_view_model.dart';
import 'package:coconut_wallet/utils/logger.dart';

class RbfBuildResult {
  final Transaction? transaction;
  final Exception? exception;

  final bool isOnlyChangeOutputUsed;
  final bool isSelfOutputsUsed;
  final List<UtxoState>? addedUtxos;
  final int? deficitAmount;

  bool get isSuccess => transaction != null;
  bool get isFailure => transaction == null;

  RbfBuildResult({
    required this.transaction,
    this.isOnlyChangeOutputUsed = false,
    this.isSelfOutputsUsed = false,
    this.exception,
    this.addedUtxos,
    this.deficitAmount,
  });
}

class RbfBuilder {
  final TransactionRecord pendingTx;
  final WalletListItemBase walletListItemBase;
  final int dustLimit;

  /// vsize 증가량은 밖에서 계산해서 주입 (테스트를 위해 순수 함수로 유지)
  final int vSizeIncreasePerInput;

  final List<UtxoState> inputUtxos;

  final bool Function(String address, {bool isChange}) isMyAddress;

  final WalletAddress nextChangeAddress;

  final String Function(int walletId, String address) getDerivationPath;

  late double _estimatedVSize;

  /// ----------- Output -----------
  List<TransactionAddress>? _nonChangeOutputs;
  List<TransactionAddress> get nonChangeOutputs {
    _ensureOutputsComputed();
    return _nonChangeOutputs!;
  }

  Map<String, int>? _recipientMap;
  Map<String, int> get recipientMap {
    if (_recipientMap != null) {
      return _recipientMap!;
    }
    _recipientMap = {};
    for (var output in nonChangeOutputs) {
      _recipientMap![output.address] = output.amount;
    }
    return _recipientMap!;
  }

  int? _nonChangeOutputsSum;
  int get nonChangeOutputsSum {
    _ensureOutputsComputed();
    return _nonChangeOutputsSum!;
  }

  TransactionAddress? _changeOutput;
  TransactionAddress? get changeOutput {
    _ensureOutputsComputed();
    return _changeOutput;
  }

  String? _changeOutputDerivationPath;
  String? get changeOutputDerivationPath {
    _ensureOutputsComputed();
    return _changeOutputDerivationPath;
  }

  List<TransactionAddress>? _selfOutputs;
  List<TransactionAddress>? _externalOutputs;
  List<TransactionAddress>? get selfOutputs {
    _ensureSelfAndExternalOutputsComputed();
    if (_selfOutputs!.isEmpty) {
      return null;
    }
    return _selfOutputs;
  }

  List<TransactionAddress>? get externalOutputs {
    _ensureSelfAndExternalOutputsComputed();
    if (_externalOutputs!.isEmpty) {
      return null;
    }
    return _externalOutputs;
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
  int? _inputSum;
  int get inputSum {
    _inputSum ??= inputUtxos.fold<int>(0, (sum, utxo) => sum + utxo.amount);
    return _inputSum!;
  }

  /// ----------- Input -----------

  RbfBuilder({
    required this.pendingTx,
    required this.walletListItemBase,
    required this.vSizeIncreasePerInput,
    required this.isMyAddress,
    required this.inputUtxos,
    required this.nextChangeAddress,
    required this.getDerivationPath,
    required this.dustLimit,
  }) {
    _estimatedVSize = pendingTx.vSize;
  }

  /// - [newFeeRate]: 새로 적용할 fee rate (sats/vB)
  /// - [additionalSpendable]: 추가로 사용할 수 있는 UTXO 풀
  /// - [getDerivationPath]: 특정 주소의 derivation path를 반환하는 콜백
  Future<RbfBuildResult> buildRbfTransaction({
    required double newFeeRate,
    required List<UtxoState> additionalSpendable,
  }) async {
    if (newFeeRate <= pendingTx.feeRate) {
      throw const FeeRateTooLowException();
    }

    int estimatedRequiredFee = _getEstimatedRequiredFee(newFeeRate, recipientMap);
    if (estimatedRequiredFee < pendingTx.fee + 1) {
      throw const FeeRateTooLowException();
    }

    int additionalFee = estimatedRequiredFee - pendingTx.fee;
    int left = inputSum - nonChangeOutputsSum - pendingTx.fee;

    bool isInputAmountEnough = inputSum >= nonChangeOutputsSum + estimatedRequiredFee;
    if (isInputAmountEnough) {
      // 1. 잔돈을 줄여서 트랜잭션 생성하기
      final tx = _buildTransaction(newFeeRate, recipientMap);
      if (tx.isSuccess) {
        return RbfBuildResult(transaction: tx.transaction, isOnlyChangeOutputUsed: true);
      } else {
        // INFO: 이 지점에 도달할 일이 없을 거라고 예상됨 TODO: 이 지점에 도달 시 원인 파악 후 추가 예외 처리 필요
        return RbfBuildResult(transaction: null, exception: tx.exception);
      }
    }

    // 2-1. deficitAmount만큼 selfOutput 1개에서 amount를 일부 줄여서 트랜잭션 생성 성공
    // 2-2-1. deficitAmount만큼 selfOutput N개를 통째로 없애야 트랜잭션 생성 성공 > 이 때 output이 줄어들어 vSize가 줄어들고 필요한 수수료도 줄어들게 되는데, 반드시 기존 수수료보다 +1 이상 큰지 확인 후 부족하면 추가해야함. 그렇지 않으면 네트워크에서 전송 거절됨
    // 2-2-2. output 개수가 줄어들면서 requiredFee가 감소할 수도 있음
    // 2-3. selfOutput 모두 차감으로 부족
    // (2-4. externalOutput이 null이고 selfOutput을 모두 deficit 충당으로 사용해버렸다면 결국 내가 받을 수 있는 금액이 0이 되어버리는 상황 -> 무조건 input 추가해야함 -> 특별히 처리하진 않음)
    int deficitAmount = (nonChangeOutputsSum + estimatedRequiredFee) - inputSum;
    Map<String, int> newRecipients = Map<String, int>.from(recipientMap);
    _SweepResult? oneSelfOutputSweepResult;
    if (selfOutputs != null) {
      // selfOutput만 1개인 경우 sweep 트랜잭션 생성
      if (selfOutputs!.length == 1 && externalOutputs == null) {
        final result = _handleSingleSelfOutputSweep(newFeeRate: newFeeRate, selfOutputAddress: selfOutputs![0].address);
        if (result.rbfBuildResult.isSuccess) {
          return result.rbfBuildResult;
        } else {
          oneSelfOutputSweepResult = result;
        }
      } else {
        // 가장 마지막 selfOutput에서부터 차감
        for (int i = selfOutputs!.length - 1; i >= 0; i--) {
          final leftOutput = selfOutputs![i].amount - deficitAmount;
          if (leftOutput <= dustLimit) {
            newRecipients.remove(selfOutputs![i].address);

            // 현재 selfOutputs![i]가 output에서 제거되었을 때 변화된 requiredFee를 재계산한다.
            final txBuildResult = _buildTransaction(newFeeRate, newRecipients);
            final newRequiredFee = txBuildResult.estimatedFee - (txBuildResult.unintendedDustFee ?? 0);
            // [디버그 중] 기존 수수료보다 큰 지 체크
            if (changeOutput != null) {
              Logger.log('changeOutput: ${changeOutput!.amount}, newRequiredFee: $newRequiredFee');
              assert(changeOutput!.amount < newRequiredFee);
            }

            if (leftOutput >= 0) {
              if (txBuildResult.isSuccess) {
                // TODO: 하지만 estimatedFee가 기존 Fee보다 큰지 반드시 확인해야함 크지 않으면 조정이 필요함
                return RbfBuildResult(transaction: txBuildResult.transaction, isSelfOutputsUsed: true);
              } else {
                // INFO: 이 지점에 도달할 일이 없을 거라고 예상됨 TODO: 이 지점에 도달 시 원인 파악 후 추가 예외 처리 필요
                return RbfBuildResult(transaction: null, exception: txBuildResult.exception);
              }
            }

            // output이 1개 줄어들어 deficitAmount가 얼마나 줄어들었는지 계산
            assert(newRequiredFee < estimatedRequiredFee);
            final reducedFee = estimatedRequiredFee - newRequiredFee;

            // output 개수가 줄어서 deficitAmount가 줄어들기 때문에 여기서 종료될 수 있는지 파악이 필요함
            if (reducedFee >= leftOutput.abs()) {
              if (txBuildResult.isSuccess) {
                return RbfBuildResult(transaction: txBuildResult.transaction, isSelfOutputsUsed: true);
              } else {
                // INFO: 이 지점에 도달할 일이 없을 거라고 예상됨 TODO: 이 지점에 도달 시 원인 파악 후 추가 예외 처리 필요
                return RbfBuildResult(transaction: null, exception: txBuildResult.exception);
              }
            }

            deficitAmount -= reducedFee;
            // selfOutput이 더 있다면 추가로 차감하거나 input이 더 필요한 상황
          } else {
            // 현재 selfOutputs![i]의 amount를 leftOutput으로 변경하여 트랜잭션 생성 성공 // TODO: return;
            newRecipients[selfOutputs![i].address] = leftOutput;
            final txBuildResult = _buildTransaction(newFeeRate, newRecipients);
            if (txBuildResult.isSuccess) {
              return RbfBuildResult(transaction: txBuildResult.transaction, isSelfOutputsUsed: true);
            } else {
              // INFO: 이 지점에 도달할 일이 없을 거라고 예상됨 TODO: 이 지점에 도달 시 원인 파악 후 추가 예외 처리 필요
              return RbfBuildResult(transaction: null, exception: txBuildResult.exception);
            }
          }
        }
      }
    }

    // 3. selfOutput이 있었다면 사용한 만큼 deficitAmount가 차감된 상태
    if (additionalSpendable.isNotEmpty) {
      // 3-1. additionalSpendable로 deficitAmount 이상 채울 수 있으면 추가 utxo를 활용하여 트랜잭션 생성 성공. 큰 금액의 utxo부터 사용
    }

    // input에 UTXO 무조건 추가해야함
    return RbfBuildResult(transaction: null);
  }

  _SweepResult _handleSingleSelfOutputSweep({required double newFeeRate, required String selfOutputAddress}) {
    final newRecipients = {selfOutputAddress: inputSum};
    final txBuildResult = _buildSweepTransaction(newFeeRate, newRecipients);
    if (txBuildResult.isSuccess) {
      return _SweepResult(
        rbfBuildResult: RbfBuildResult(transaction: txBuildResult.transaction, isSelfOutputsUsed: true),
        newRecipients: newRecipients,
      );
    } else {
      if (txBuildResult.exception is TxCreationException.SendAmountTooLowException) {
        final estimatedFee = (txBuildResult.exception as TxCreationException.SendAmountTooLowException).estimatedFee;
        final deficitAmount = (dustLimit + 1) + estimatedFee - inputSum;
        return _SweepResult(
          rbfBuildResult: RbfBuildResult(
            transaction: null,
            exception: txBuildResult.exception,
            deficitAmount: deficitAmount,
          ),
          newRecipients: newRecipients,
        );
      } else {
        // INFO: 이 지점에 도달할 일이 없을 거라고 예상됨 TODO: 이 지점에 도달 시 원인 파악 후 추가 예외 처리 필요
        throw txBuildResult.exception!;
      }
    }
  }

  int _getEstimatedRequiredFee(double newFeeRate, Map<String, int> recipients) {
    final txBuildResult = _buildTransaction(newFeeRate, recipients);
    return txBuildResult.estimatedFee - (txBuildResult.unintendedDustFee ?? 0);
  }

  TransactionBuildResult _buildTransaction(double newFeeRate, Map<String, int> recipients) {
    final changeDerivationPath = changeOutput == null ? nextChangeAddress.derivationPath : changeOutputDerivationPath!;

    return TransactionBuilder(
      availableUtxos: inputUtxos,
      recipients: recipients,
      feeRate: newFeeRate,
      changeDerivationPath: changeDerivationPath,
      walletListItemBase: walletListItemBase,
      isFeeSubtractedFromAmount: false,
      isUtxoFixed: true,
    ).build();
  }

  TransactionBuildResult _buildSweepTransaction(double newFeeRate, Map<String, int> recipients) {
    final changeDerivationPath = changeOutput == null ? nextChangeAddress.derivationPath : changeOutputDerivationPath!;

    return TransactionBuilder(
      availableUtxos: inputUtxos,
      recipients: recipients,
      feeRate: newFeeRate,
      changeDerivationPath: changeDerivationPath,
      walletListItemBase: walletListItemBase,
      isFeeSubtractedFromAmount: true,
      isUtxoFixed: true,
    ).build();
  }

  // TODO: 필요 없어질 수도 있음
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
    if (_nonChangeOutputs != null || _changeOutput != null) {
      return;
    }

    final outputs = pendingTx.outputAddressList;
    // change output 찾기
    final changeIndex = outputs.lastIndexWhere((output) => isMyAddress(output.address, isChange: true));
    if (changeIndex != -1) {
      _changeOutput = outputs[changeIndex];
      _changeOutputDerivationPath = getDerivationPath(walletListItemBase.id, _changeOutput!.address);
      if (_changeOutputDerivationPath == null || _changeOutputDerivationPath!.isEmpty) {
        throw const InvalidChangeOutputException();
      }
    }
    // change output 을 제외한 나머지 = nonChangeOutputs
    int outputSum = 0;
    _nonChangeOutputs =
        outputs.asMap().entries.where((entry) => entry.key != changeIndex).map((entry) {
          outputSum += entry.value.amount;
          return entry.value;
        }).toList();
    _nonChangeOutputsSum = outputSum;
  }

  void _ensureSelfAndExternalOutputsComputed() {
    if (_selfOutputs != null || _externalOutputs != null) {
      return;
    }

    final List<TransactionAddress> selfOutputs = [];
    final List<TransactionAddress> externalOutputs = [];
    for (var output in nonChangeOutputs) {
      if (isMyAddress(output.address)) {
        selfOutputs.add(output);
      } else {
        externalOutputs.add(output);
      }
    }

    _selfOutputs = selfOutputs;
    _externalOutputs = externalOutputs;
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

class _SweepResult {
  final Map<String, int> newRecipients;
  final RbfBuildResult rbfBuildResult;
  _SweepResult({required this.newRecipients, required this.rbfBuildResult});
}
