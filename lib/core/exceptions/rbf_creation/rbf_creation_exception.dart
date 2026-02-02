/// Base exception class for all RBF transaction creation related exceptions
class RbfCreationException implements Exception {
  final String message;

  const RbfCreationException({required this.message});

  @override
  String toString() => message;
}

class FeeRateTooLowException extends RbfCreationException {
  const FeeRateTooLowException({super.message = 'Fee rate is too low.'});
}

/// Exception thrown when there is not enough amount for transaction
class InsufficientBalanceException extends RbfCreationException {
  const InsufficientBalanceException({super.message = 'Not enough balance for sending.'});
}

class InvalidChangeOutputException extends RbfCreationException {
  const InvalidChangeOutputException({super.message = 'Invalid change output or derivation path finder.'});
}
