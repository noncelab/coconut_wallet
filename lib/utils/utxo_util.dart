import 'package:coconut_lib/coconut_lib.dart';

extension UTXOExtension on UTXO {
  String get utxoId => '$transactionHash$index';
}

String makeUtxoId(String transactionHash, int index) {
  return '$transactionHash$index';
}
