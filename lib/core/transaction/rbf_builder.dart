import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/core/exceptions/rbf_creation/rbf_creation_exception.dart';
import 'package:coconut_wallet/core/transaction/transaction_builder.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/model/wallet/transaction_address.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/wallet/wallet_address.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/providers/view_model/wallet_detail/fee_bumping_view_model.dart';

class RbfBuildResult {
  final Transaction? transaction;
  final Exception? exception;

  final bool isChangeOutputUsed;
  final bool isSelfOutputsUsed;
  final List<UtxoState>? addedUtxos;
  final int? deficitAmount;

  bool get isSuccess => transaction != null;
  bool get isFailure => transaction == null;

  RbfBuildResult({
    required this.transaction,
    this.isChangeOutputUsed = false,
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

    int requiredFee = (_estimatedVSize * newFeeRate).ceil();
    if (requiredFee < pendingTx.fee + 1) {
      throw const FeeRateTooLowException();
    }

    int additionalFee = requiredFee - pendingTx.fee;
    int left = inputSum - nonChangeOutputsSum - pendingTx.fee;

    bool isInputAmountEnough = inputSum >= nonChangeOutputsSum + requiredFee;
    if (isInputAmountEnough) {
      // 1. 잔돈을 줄여서 트랜잭션 생성하기
      final tx = _buildTransaction(newFeeRate, recipientMap);
      if (tx.isSuccess) {
        return RbfBuildResult(transaction: tx.transaction, isChangeOutputUsed: true);
      } else {
        // INFO: 이 지점에 도달할 일이 없을 거라고 예상됨
        // TODO: 이 지점에 도달 시 예외 처리 필요
        return RbfBuildResult(transaction: null, exception: tx.exception);
      }
    }

    int deficitAmount = (nonChangeOutputsSum + requiredFee) - inputSum;
    // TODO: 어떤 SelfOutput에 얼마만큼의 변화가 일어났는지 변수로 보유하고 있어야함.
    if (selfOutputs != null) {
      // 가장 마지막 output부터 우선적으로 차감
      // 2-1. deficitAmount만큼 selfOutput 1개에서 amount를 일부 줄여서 트랜잭션 생성 성공
      // 2-2-1. deficitAmount만큼 selfOutput N개를 통째로 없애야 트랜잭션 생성 성공 > 이 때 output이 줄어들어 vSize가 줄어들고 필요한 수수료도 줄어들게 되는데, 반드시 기존 수수료보다 +1 이상 큰지 확인 후 부족하면 추가해야함. 그렇지 않으면 네트워크에서 전송 거절됨
      // 2-2-2. output 개수가 줄어들면서 requiredFee가 감소할 수도 있음
      // 2-3. selfOutput 모두 차감으로 부족
      // selfOutput 사용한 만큼 deficitAmount를 변경
      // (2-4. externalOutput이 null이고 selfOutput을 모두 deficit 충당으로 사용해버렸다면 결국 내가 받을 수 있는 금액이 0이 되어버리는 상황 -> 무조건 input 추가해야함)
    }

    // 3. selfOutput이 있었다면 사용한 만큼 deficitAmount가 차감된 상태
    if (additionalSpendable.isNotEmpty) {
      // 3-1. candidateUnspentUtxos로 deficitAmount 이상 채울 수 있으면 추가 utxo를 활용하여 트랜잭션 생성 성공. 큰 금액의 utxo부터 사용
    }

    // input에 UTXO 무조건 추가해야함
    return RbfBuildResult(transaction: null);
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
