/// Base exception class for all RBF transaction creation related exceptions
class RbfCreationException implements Exception {
  final String message;

  const RbfCreationException({required this.message});

  @override
  String toString() => message;
}

/// Exception thrown when there is not enough amount for transaction
class InsufficientBalanceException extends RbfCreationException {
  const InsufficientBalanceException({super.message = 'Not enough balance for sending.'});
}

class InvalidChangeOutputException extends RbfCreationException {
  const InvalidChangeOutputException({super.message = 'Invalid change output or derivation path finder.'});
}

class UseChangeOutputFailureException extends RbfCreationException {
  final int changeAmount;
  final int deficitAmount;

  UseChangeOutputFailureException({required this.changeAmount, required this.deficitAmount})
    : super(
        message:
            'Change output is sufficient, but RBF transaction creation failed. '
            '(changeAmount: $changeAmount, deficitAmount: $deficitAmount)',
      );
}

class DuplicatedOutputException extends RbfCreationException {
  const DuplicatedOutputException({super.message = 'RBF is not supported because duplicated outputs exist.'});
}

class UtxoNotFoundException extends RbfCreationException {
  final String utxoId;

  UtxoNotFoundException({required this.utxoId}) : super(message: 'UTXO not found: $utxoId');
}
