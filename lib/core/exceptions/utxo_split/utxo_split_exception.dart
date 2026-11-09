/// Base exception class for all UTXO split related exceptions
class UtxoSplitException implements Exception {
  final String message;
  final double? estimatedFee;

  const UtxoSplitException({required this.message, required this.estimatedFee});

  @override
  String toString() => message;
}

/// Exception thrown when split would create dust outputs (<=546 sats)
class SplitOutputDustException extends UtxoSplitException {
  const SplitOutputDustException({super.message = 'Split would create dust outputs.', super.estimatedFee});
}

/// Exception thrown when input amounts + fee exceed UTXO amount
class SplitInsufficientAmountException extends UtxoSplitException {
  const SplitInsufficientAmountException({
    super.message = 'Input amounts + fee exceed UTXO amount.',
    super.estimatedFee,
  });
}

/// Exception thrown when the estimated fee alone exceeds the UTXO amount
class FeeExceedsUtxoAmountException extends UtxoSplitException {
  const FeeExceedsUtxoAmountException({super.message = 'Estimated fee exceeds UTXO amount.', super.estimatedFee});
}

/// Exception thrown when the split tx would exceed the standard tx size (100,000 vB)
class SplitTxTooLargeException extends UtxoSplitException {
  const SplitTxTooLargeException({super.message = 'Split tx exceeds the standard tx size.', super.estimatedFee});
}
