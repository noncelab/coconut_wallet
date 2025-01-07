import 'package:coconut_wallet/model/utxo_tag.dart';

class UTXO {
  final String timestamp;
  final String blockHeight;
  final int amount;
  final String to; // 소유 주소
  final String derivationPath;
  final String txHash;
  final int index;
  List<UtxoTag>? tags;

  UTXO(this.timestamp, this.blockHeight, this.amount, this.to,
      this.derivationPath, this.txHash, this.index,
      {this.tags});
}
