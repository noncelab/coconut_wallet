import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/constants/bitcoin_network_rules.dart';
import 'package:coconut_wallet/core/transaction/utxo_selector.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/utils/coconut_lib_exception_parser.dart';
import 'package:coconut_wallet/core/exceptions/transaction_creation/transaction_creation_exception.dart';

class TransactionBuildResult {
  final Transaction? transaction;
  final List<UtxoState>? selectedUtxos;
  final int estimatedFee;
  final Exception? exception;

  bool get isSuccess => transaction != null;
  bool get isFailure => transaction == null;

  const TransactionBuildResult({
    required this.transaction,
    required this.selectedUtxos,
    required this.estimatedFee,
    this.exception,
  });

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.writeln("┌──────────────── Transaction Build Result Info ────────────────┐");
    buffer.writeln("│ isSuccess = $isSuccess");
    if (transaction == null) buffer.writeln("│ transaction = null");
    if (selectedUtxos == null) {
      buffer.writeln("│ selectedUtxos = null");
    } else {
      buffer.writeln("│ selectedUtxos(${selectedUtxos!.length}):");
      for (var utxo in selectedUtxos!) {
        buffer.writeln("│   - amount: ${utxo.amount}");
      }
    }
    buffer.writeln("│ estimatedFee = $estimatedFee");
    buffer.writeln("│ exception = $exception");
    buffer.writeln("└───────────────────────────────────────────────────────────────┘");
    return buffer.toString();
  }
}

/// [SingleTx]
/// 1-1. utxo 자동 선택 보내기 - 수수료 수신자 부담 off
/// 1-2. utxo 자동 선택 보내기 - 수수료 수신자 부담 on
/// 2-1. utxo 선택 보내기 - 수수료 수신자 부담 off
/// 2-2. utxo 선택 보내기 - 수수료 수신자 부담 on
/// [BatchTx]
/// 3-1. utxo 자동 선택 보내기 - 수수료 수신자 부담 off
/// 3-2. utxo 자동 선택 보내기 - 수수료 수신자 부담 on
/// 4-1. utxo 선택 보내기 - 수수료 수신자 부담 off
/// 4-2. utxo 선택 보내기 - 수수료 수신자 부담 on
///
/// 모두 보내기 일 때는 수수료 수신자 부담 on
class TransactionBuilder {
  static const int _maxIterationCount = 10;

  final List<UtxoState> availableUtxos;
  final Map<String, int> recipients;
  final double feeRate;
  final String changeDerivationPath;
  final WalletListItemBase walletListItemBase;
  final bool isFeeSubtractedFromAmount;
  final bool isUtxoFixed;

  List<UtxoState>? _selectedUtxos;
  Transaction? _transaction;
  int? _estimatedFeeByFeeEstimator; // 처음엔 추정된 값으로 초기화됨
  int? _estimatedFeeByTransaction; // 트랜잭션 생성 후에 Transaction 객체에서 추정한 값 (더 정확)

  TransactionBuilder({
    required this.availableUtxos,
    required this.recipients,
    required this.feeRate,
    required this.changeDerivationPath,
    required this.walletListItemBase,
    required this.isFeeSubtractedFromAmount,
    required this.isUtxoFixed,
  }) : assert(recipients.isNotEmpty);

  TransactionBuildResult build() {
    try {
      if (isUtxoFixed) {
        _selectedUtxos = availableUtxos;
        double virtualByte = WalletUtility.estimateVirtualByte(
          walletListItemBase.walletType.addressType,
          _selectedUtxos!.length,
          recipients.length + 1,
          requiredSignature: walletListItemBase.multisigConfig?.requiredSignature,
          totalSigner: walletListItemBase.multisigConfig?.totalSigner,
        ); // change output 있다고 가정
        _estimatedFeeByFeeEstimator = (virtualByte * feeRate).ceil();
      } else {
        final utxoSelectionResult = UtxoSelector.selectOptimalUtxos(
            availableUtxos, recipients, feeRate, walletListItemBase.walletType,
            multisigConfig: walletListItemBase.multisigConfig,
            isFeeSubtractedFromAmount: isFeeSubtractedFromAmount);
        _selectedUtxos = utxoSelectionResult.selectedUtxos;
        _estimatedFeeByFeeEstimator = utxoSelectionResult.estimatedFee;
      }

      _createTransaction();

      return TransactionBuildResult(
        transaction: _transaction,
        selectedUtxos: _selectedUtxos!,
        estimatedFee: _estimatedFeeByTransaction!,
        exception: null,
      );
    } on TransactionCreationException catch (e) {
      return TransactionBuildResult(
        transaction: _transaction,
        selectedUtxos: _selectedUtxos,
        estimatedFee: e.estimatedFee,
        exception: e,
      );
    }
  }

  TransactionBuilder copyWith({
    List<UtxoState>? availableUtxos,
    Map<String, int>? recipients,
    double? feeRate,
    String? changeDerivationPath,
    WalletListItemBase? walletListItemBase,
    bool? isFeeSubtractedFromAmount,
    bool? isUtxoFixed,
  }) {
    return TransactionBuilder(
      availableUtxos: availableUtxos ?? this.availableUtxos,
      recipients: recipients ?? this.recipients,
      feeRate: feeRate ?? this.feeRate,
      changeDerivationPath: changeDerivationPath ?? this.changeDerivationPath,
      walletListItemBase: walletListItemBase ?? this.walletListItemBase,
      isFeeSubtractedFromAmount: isFeeSubtractedFromAmount ?? this.isFeeSubtractedFromAmount,
      isUtxoFixed: isUtxoFixed ?? this.isUtxoFixed,
    );
  }

  Transaction? _createTransaction() {
    assert(_estimatedFeeByFeeEstimator != null);
    List<UtxoState>? leftAvailableUtxos;

    /// 1. 선택한 utxo를 이용해서 트랜잭션을 생성한다.
    while (true) {
      try {
        _transaction = recipients.length > 1
            ? (isFeeSubtractedFromAmount
                ? _createBatchWhenFeeSubtractedFromAmount()
                : _createBatchTransaction())
            : (isFeeSubtractedFromAmount
                ? _createSingleWhenFeeSubtractedFromAmount()
                : _createSingleTransaction());

        /// 수수료 수신자 부담일 때는 생성 시 할당한 값이 _estimatedFeeByTransaction에 미리 할당된 상태이므로
        /// null일 때만 _estimateFee() 결과를 할당합니다.
        _estimatedFeeByTransaction ??= _estimateFee();

        return _transaction!;
      } on Exception catch (e) {
        final int? estimatedFee = extractEstimatedFeeFromException(e);

        /// 수수료 수신자 부담인 경우에는 utxo 추가할 수 없음
        /// utxo 고정인 경우에는 추가할 utxo가 없음
        if (!isFeeSubtractedFromAmount || !isUtxoFixed) {
          /// 2. 트랜잭션 생성 에러가 나고, 그게 잔액 문제이면 utxo를 추가로 선택할 수 있는지 확인한다.
          if (estimatedFee != null) {
            /// 3. 선택할 수 있으면 다시 트랜잭션을 생성한다.
            leftAvailableUtxos ??= UtxoSelector.sortUtxos(_getLeftAvailableUtxos());
            if (leftAvailableUtxos.isNotEmpty) {
              _selectedUtxos!.add(leftAvailableUtxos.removeAt(0));
              continue;
            }
          }

          /// 4. 더이상 추가로 사용할 수 있는 utxo가 없음
          //_estimatedFeeByTransaction = estimatedFee;
          throw InsufficientBalanceException(
              estimatedFee: estimatedFee ?? _estimatedFeeByFeeEstimator!);
        }

        if (e is TransactionCreationException) {
          rethrow;
        }

        /// TODO: TEST
        throw TransactionCreationException(
            message: e.toString(), estimatedFee: estimatedFee ?? _estimatedFeeByFeeEstimator!);
      }
    }
  }

  Transaction _createSingleTransaction() => Transaction.forSinglePayment(
      _selectedUtxos!,
      recipients.entries.first.key,
      changeDerivationPath,
      recipients.entries.first.value,
      feeRate,
      walletListItemBase.walletBase);

  Transaction _createBatchTransaction() => Transaction.forBatchPayment(
      _selectedUtxos!, recipients, changeDerivationPath, feeRate, walletListItemBase.walletBase);

  Transaction _createSingleWhenFeeSubtractedFromAmount() {
    final totalInputAmount =
        _selectedUtxos!.fold(0, (previousValue, element) => previousValue + element.amount);
    final maxUsedAmount = recipients.entries.first.value;

    if (totalInputAmount == maxUsedAmount) {
      try {
        final tx = Transaction.forSweep(
            _selectedUtxos!, recipients.entries.first.key, feeRate, walletListItemBase.walletBase);
        if (tx.outputs.first.amount <= dustLimit) {
          throw SendAmountTooLowException(
              estimatedFee: tx.estimateFee(feeRate, walletListItemBase.walletType.addressType));
        }
        return tx;
      } on Exception catch (e) {
        /// 보내는 수량 합 + 예상 수수료 > 잔액
        final int? estimatedFee = extractEstimatedFeeFromException(e);
        if (estimatedFee != null) {
          throw InsufficientBalanceException(estimatedFee: estimatedFee);
        } else {
          throw TransactionCreationException(
              message: e.toString(), estimatedFee: _estimatedFeeByFeeEstimator!);
        }
      }
    }

    int initialFee = _estimatedFeeByFeeEstimator!;
    int sendAmount = maxUsedAmount - initialFee;
    if (sendAmount <= dustLimit) {
      throw SendAmountTooLowException(estimatedFee: _estimatedFeeByFeeEstimator!);
    }

    Exception? exception;

    /// 최대 2회까지 조정되는 케이스 테스트 완료. 최대 몇회까지 조정될지 정확히 가늠하지 못해 10으로 임의 설정했습니다.
    /// transaction_builder_test.dart: Single / Auto Utxo / 수수료 수신자 부담 / Edge Case
    for (int i = 0; i < _maxIterationCount; i++) {
      try {
        Transaction tx = Transaction.forSinglePayment(_selectedUtxos!, recipients.entries.first.key,
            changeDerivationPath, sendAmount, feeRate, walletListItemBase.walletBase);
        final realEstimatedFee = tx.estimateFee(feeRate, walletListItemBase.walletType.addressType);
        if (initialFee != realEstimatedFee) {
          if (!tx.outputs.any((output) => output.isChangeOutput == true)) {
            return Transaction.forSweep(_selectedUtxos!, recipients.entries.first.key, feeRate,
                walletListItemBase.walletBase);
          }
          initialFee = realEstimatedFee;

          sendAmount = maxUsedAmount - realEstimatedFee;
          if (sendAmount <= dustLimit) {
            /// estimatedFee + sendAmount < maxUsedAmount이더라도 반환
            return tx;
          }
          continue;
        }
        // TODO: 추후 변경 가능성 있음
        //_estimatedFeeByTransaction = realEstimatedFee;
        return tx;
      } on Exception catch (e) {
        if (i == _maxIterationCount - 1) {
          exception = e;
          break;
        }

        final int? estimatedFee = extractEstimatedFeeFromException(e);
        if (estimatedFee != null) {
          initialFee = estimatedFee;
          sendAmount = maxUsedAmount - initialFee;
          if (sendAmount <= dustLimit) {
            throw SendAmountTooLowException(estimatedFee: initialFee);
          }
          continue;
        } else {
          throw TransactionCreationException(
              message: e.toString(), estimatedFee: _estimatedFeeByFeeEstimator!);
        }
      }
    }

    /// TODO: 여기 오는 상황이 있나?
    throw TransactionCreationException(
        message: exception?.toString() ??
            'Failed to create single transaction when fee subtracted from amount.',
        estimatedFee: initialFee);
  }

  Transaction _createBatchWhenFeeSubtractedFromAmount() {
    final totalInputAmount =
        _selectedUtxos!.fold(0, (previousValue, element) => previousValue + element.amount);
    final maxUsedAmount =
        recipients.entries.fold(0, (previousValue, element) => previousValue + element.value);

    if (totalInputAmount == maxUsedAmount) {
      try {
        final tx = Transaction.forBatchSweep(
            _selectedUtxos!, recipients, feeRate, walletListItemBase.walletBase);
        if (tx.outputs.last.amount <= dustLimit) {
          throw SendAmountTooLowException(
              estimatedFee: tx.estimateFee(feeRate, walletListItemBase.walletType.addressType));
        }
        return tx;
      } on Exception catch (e) {
        /// 보내는 수량 합 + 예상 수수료 > 잔액
        final int? estimatedFee = extractEstimatedFeeFromException(e);
        if (estimatedFee != null) {
          throw InsufficientBalanceException(estimatedFee: estimatedFee);
        } else {
          throw TransactionCreationException(
              message: e.toString(), estimatedFee: _estimatedFeeByFeeEstimator!);
        }
      }
    }

    final lastRecipient = recipients.entries.last;
    int initialFee = _estimatedFeeByFeeEstimator!;
    int finalLastSendAmount = lastRecipient.value - initialFee;
    if (finalLastSendAmount <= dustLimit) {
      throw SendAmountTooLowException(estimatedFee: _estimatedFeeByFeeEstimator!);
    }

    final updatedRecipients = Map<String, int>.of(recipients);
    updatedRecipients[recipients.entries.last.key] = finalLastSendAmount;
    Exception? exception;

    /// 최대 2회까지 조정되는 케이스 테스트 완료. 최대 몇회까지 조정될지 정확히 가늠하지 못해 10으로 임의 설정했습니다.
    /// transaction_builder_test.dart: Batch / Auto Utxo / 수수료 수신자 부담 / Edge Case
    for (int i = 0; i < _maxIterationCount; i++) {
      try {
        Transaction tx = Transaction.forBatchPayment(_selectedUtxos!, updatedRecipients,
            changeDerivationPath, feeRate, walletListItemBase.walletBase);
        final realEstimatedFee = tx.estimateFee(feeRate, walletListItemBase.walletType.addressType);
        if (initialFee != realEstimatedFee) {
          if (!tx.outputs.any((output) => output.isChangeOutput == true)) {
            return Transaction.forBatchSweep(
                _selectedUtxos!, recipients, feeRate, walletListItemBase.walletBase);
          }
          initialFee = realEstimatedFee;
          finalLastSendAmount = lastRecipient.value - initialFee;
          if (finalLastSendAmount <= dustLimit) {
            return tx;
          }
          updatedRecipients[recipients.entries.last.key] = finalLastSendAmount;
          continue;
        }
        // TODO: 추후 변경 가능성 있음
        //_estimatedFeeByTransaction = realEstimatedFee;
        return tx;
      } on Exception catch (e) {
        if (i == _maxIterationCount - 1) {
          exception = e;
          break;
        }

        /// 보내는 수량 합 + 예상 수수료 > 잔액
        final int? estimatedFee = extractEstimatedFeeFromException(e);
        if (estimatedFee != null) {
          initialFee = estimatedFee;
          finalLastSendAmount = lastRecipient.value - initialFee;
          if (finalLastSendAmount <= dustLimit) {
            throw SendAmountTooLowException(estimatedFee: initialFee);
          }
          updatedRecipients[recipients.entries.last.key] = finalLastSendAmount;
          continue;
        } else {
          throw TransactionCreationException(
              message: e.toString(), estimatedFee: _estimatedFeeByFeeEstimator!);
        }
      }
    }

    throw TransactionCreationException(
        message: exception?.toString() ??
            'Failed to create batch transaction when fee subtracted from amount.',
        estimatedFee: _estimatedFeeByFeeEstimator!);
  }

  int _estimateFee() {
    assert(_transaction != null);

    /// change가 dust미만이어서 change output이 없는 경우는 그 금액이 수수료로 소진된다는 의미입니다.
    /// 하지만 _transaction의 estimatedFee 결과에는 change값이 포함되지 않으므로 아래와 같이 조치합니다.
    final hasChangeOutput = _transaction!.outputs.any((output) => output.isChangeOutput == true);
    if (!hasChangeOutput) {
      final inputSum =
          _selectedUtxos!.fold(0, (previousValue, element) => previousValue + element.amount);
      final outputSum =
          _transaction!.outputs.fold(0, (previousValue, element) => previousValue + element.amount);
      return inputSum - outputSum;
    }

    if (walletListItemBase.walletType == WalletType.multiSignature) {
      return _transaction!.estimateFee(feeRate, walletListItemBase.walletType.addressType,
          requiredSignature: walletListItemBase.multisigConfig!.requiredSignature,
          totalSigner: walletListItemBase.multisigConfig!.totalSigner);
    }
    return _transaction!.estimateFee(feeRate, walletListItemBase.walletType.addressType);
  }

  /// availableUtxos중 selectedUtxos를 제외한 utxo들을 id로 비교해서 반환한다.
  List<UtxoState> _getLeftAvailableUtxos() {
    if (isUtxoFixed) {
      return [];
    }

    final selectedUtxoIds = _selectedUtxos!.map((e) => e.utxoId).toSet();
    return availableUtxos.where((utxo) => !selectedUtxoIds.contains(utxo.utxoId)).toList();
  }

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.writeln("┌──────────────────── Transaction Builder Info ────────────────────┐");
    buffer.writeln("│ availableUtxos(${availableUtxos.length}):");
    for (var utxo in availableUtxos) {
      buffer.writeln("│   - amount: ${utxo.amount}");
    }
    buffer.writeln("│ recipients(${recipients.length}):");
    for (var entry in recipients.entries) {
      buffer.writeln("│   - ${entry.key}: ${entry.value}");
    }
    buffer.writeln("│ feeRate = $feeRate");
    buffer.writeln("│ changeDerivationPath = $changeDerivationPath");
    buffer.writeln("│ isFeeSubtractedFromAmount = $isFeeSubtractedFromAmount");
    buffer.writeln("│ isUtxoFixed = $isUtxoFixed");
    buffer.writeln("└─────────────────────────────────────────────────────────────────┘");
    return buffer.toString();
  }
}
