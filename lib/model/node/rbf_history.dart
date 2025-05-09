class RbfHistory {
  final int _id;
  final int walletId;
  final String originalTransactionHash;
  final String transactionHash;
  final double feeRate;
  final DateTime timestamp;

  int get id => _id;

  RbfHistory({
    required this.walletId,
    required this.originalTransactionHash,
    required this.transactionHash,
    required this.feeRate,
    required this.timestamp,
  }) : _id = Object.hash(
          walletId,
          originalTransactionHash,
          transactionHash,
        );
}
