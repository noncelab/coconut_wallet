import 'package:coconut_lib/coconut_lib.dart';

extension UtxoExtension on Utxo {
  String get utxoId => '$transactionHash$index';
}

String makeUtxoId(String transactionHash, int index) {
  return '$transactionHash$index';
}
