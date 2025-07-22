/// Base exception class for all transaction creation related exceptions
class TransactionCreationException implements Exception {
  final String message;
  final int estimatedFee;

  const TransactionCreationException({
    required this.message,
    required this.estimatedFee,
  });

  @override
  String toString() => message;
}

/// Exception thrown when there is not enough amount for transaction
class InsufficientBalanceException extends TransactionCreationException {
  const InsufficientBalanceException({
    super.message = 'Not enough balance for sending.',
    required super.estimatedFee,
  });
}

class SendAmountTooLowException extends TransactionCreationException {
  const SendAmountTooLowException({
    super.message = 'Send amount is too low.',
    required super.estimatedFee,
  });
}
