import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/core/exceptions/rbf_creation/rbf_creation_exception.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/core/transaction/fee_bumping/output_analysis.dart';
import 'package:coconut_wallet/repository/realm/service/realm_id_service.dart';

class RbfPreparer {
  final TransactionRecord pendingTx;
  final List<UtxoState> inputUtxos;
  final OutputAnalysis outputAnalysis;

  RbfPreparer({required this.pendingTx, required this.inputUtxos, required this.outputAnalysis});

  factory RbfPreparer.fromPendingTx({
    required TransactionRecord pendingTx,
    required String rawTx,
    required UtxoState? Function(String utxoId) getUtxos,
    required bool Function(String address, {bool isChange}) isMyAddress,
    required String Function(String address) getDerivationPath,
  }) {
    // Input UTXOs 계산
    final Transaction tx = Transaction.parse(rawTx);
    if (tx.transactionHash != pendingTx.transactionHash) throw ArgumentError('pendingTx and rawTx does not match');
    List<UtxoState> inputUtxoList = [];
    for (var input in tx.inputs) {
      var utxo = getUtxos(getUtxoId(input.transactionHash, input.index));
      if (utxo == null) {
        throw UtxoNotFoundException(utxoId: getUtxoId(input.transactionHash, input.index));
      }
      inputUtxoList.add(utxo);
    }

    // OutputAnalysis 생성
    final outputAnalysis = OutputAnalysis.fromPendingTx(
      pendingTx: pendingTx,
      isMyAddress: isMyAddress,
      getDerivationPath: getDerivationPath,
    );

    return RbfPreparer(pendingTx: pendingTx, inputUtxos: inputUtxoList, outputAnalysis: outputAnalysis);
  }

  bool get hasDuplicatedOutput => outputAnalysis.hasDuplicatedOutput;
}
