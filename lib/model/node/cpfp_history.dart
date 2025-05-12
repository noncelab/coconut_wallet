class CpfpHistory {
  final int _id;
  final int walletId;
  final String parentTransactionHash;
  final String childTransactionHash;
  final double originalFee;
  final double newFee;
  final DateTime timestamp;

  int get id => _id;

  CpfpHistory({
    required this.walletId,
    required this.parentTransactionHash,
    required this.childTransactionHash,
    required this.originalFee,
    required this.newFee,
    required this.timestamp,
  }) : _id = Object.hash(
          walletId,
          parentTransactionHash,
          childTransactionHash,
        );
}
