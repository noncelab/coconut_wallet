class FetchTransactionResponse {
  final String transactionHash;
  final int height;
  final int addressIndex;
  final bool isChange;

  FetchTransactionResponse({
    required this.transactionHash,
    required this.height,
    required this.addressIndex,
    required this.isChange,
  });

  @override
  bool operator ==(covariant FetchTransactionResponse other) {
    return transactionHash == other.transactionHash && height == other.height;
  }

  @override
  int get hashCode => Object.hash(transactionHash, height);
}
