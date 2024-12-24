class UTXO {
  final int index;
  final String timestamp;
  final String blockHeight;
  final int amount;
  final String to; // 소유 주소
  final String derivationPath;
  final String txHash;
  List<String>? tags;

  UTXO(this.index, this.timestamp, this.blockHeight, this.amount, this.to,
      this.derivationPath, this.txHash,
      {this.tags});
}
