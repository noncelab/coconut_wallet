import 'package:coconut_wallet/core/exceptions/cpfp_creation/cpfp_creation_exception.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';

class CpfpPreparer {
  final TransactionRecord pendingTx;

  /// 부모 tx에서 내 지갑이 받은 UTXO 목록 (child tx의 input이 됨)
  final List<UtxoState> receivedUtxos;

  CpfpPreparer({required this.pendingTx, required this.receivedUtxos}) {
    if (receivedUtxos.isEmpty) {
      throw const NoCpfpableOutputException();
    }
  }

  factory CpfpPreparer.fromPendingTx({
    required TransactionRecord pendingTx,
    required List<UtxoState> incomingUtxos,
    required bool Function(String address, {bool isChange}) isMyAddress,
  }) {
    final List<UtxoState> receivedUtxos = [];

    for (int i = 0; i < pendingTx.outputAddressList.length; i++) {
      final output = pendingTx.outputAddressList[i];
      if (isMyAddress(output.address) || isMyAddress(output.address, isChange: true)) {
        final utxo =
            incomingUtxos
                .where(
                  (u) =>
                      u.to == output.address &&
                      u.amount == output.amount &&
                      u.transactionHash == pendingTx.transactionHash &&
                      pendingTx.outputAddressList[u.index].address == u.to,
                )
                .firstOrNull;
        if (utxo != null) {
          receivedUtxos.add(utxo);
        }
      }
    }

    return CpfpPreparer(pendingTx: pendingTx, receivedUtxos: receivedUtxos);
  }
}
