/// Base exception class for all CPFP transaction creation related exceptions
class CpfpCreationException implements Exception {
  final String message;

  const CpfpCreationException({required this.message});

  @override
  String toString() => message;
}

class CpfpFeeRateTooLowException extends CpfpCreationException {
  const CpfpFeeRateTooLowException({super.message = 'Fee rate is too low.'});
}

/// Exception thrown when the received UTXOs are insufficient to cover the child tx fee
class CpfpInsufficientFundsException extends CpfpCreationException {
  const CpfpInsufficientFundsException({
    super.message = 'Received UTXOs are insufficient to cover the child transaction fee.',
  });
}

/// Exception thrown when no CPFP-eligible outputs are found in the pending transaction
class NoCpfpableOutputException extends CpfpCreationException {
  const NoCpfpableOutputException({super.message = 'No CPFP-eligible outputs found in the pending transaction.'});
}
