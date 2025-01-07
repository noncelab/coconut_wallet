import 'package:coconut_lib/coconut_lib.dart';

class UTXO {
  final String timestamp;
  final String blockHeight;
  final int amount;
  final String to; // 소유 주소
  final String derivationPath;
  final String txHash;
  List<String>? tags;

  UTXO(this.timestamp, this.blockHeight, this.amount, this.to,
      this.derivationPath, this.txHash,
      {this.tags});
}
