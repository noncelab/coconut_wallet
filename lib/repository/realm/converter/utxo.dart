import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/repository/realm/model/coconut_wallet_model.dart';
import 'package:coconut_wallet/model/utxo/utxo_tag.dart';
import 'package:coconut_wallet/utils/utxo_util.dart';

UtxoTag mapRealmUtxoTagToUtxoTag(RealmUtxoTag utxoTag) {
  return UtxoTag(
    id: utxoTag.id,
    walletId: utxoTag.walletId,
    name: utxoTag.name,
    colorIndex: utxoTag.colorIndex,
    utxoIdList: utxoTag.utxoIdList,
  );
}

RealmUtxo mapUtxoToRealmUtxo(int walletId, UtxoState utxo) {
  return RealmUtxo(
    makeUtxoId(utxo.transactionHash, utxo.index),
    walletId,
    utxo.to,
    utxo.amount,
    utxo.timestamp,
    utxo.transactionHash,
    utxo.index,
    utxo.derivationPath,
    utxo.blockHeight,
    utxoStatusToString(utxo.status),
    spentByTransactionHash: utxo.spentByTransactionHash,
  );
}

UtxoState mapRealmToUtxoState(RealmUtxo utxo) {
  final utxoState = UtxoState(
    transactionHash: utxo.transactionHash,
    index: utxo.index,
    derivationPath: utxo.derivationPath,
    blockHeight: utxo.blockHeight,
    amount: utxo.amount,
    to: utxo.address,
    timestamp: utxo.timestamp,
    status: stringToUtxoStatus(utxo.status),
    spentByTransactionHash: utxo.spentByTransactionHash,
  );

  return utxoState;
}

String utxoStatusToString(UtxoStatus status) {
  switch (status) {
    case UtxoStatus.unspent:
      return 'unspent';
    case UtxoStatus.outgoing:
      return 'outgoing';
    case UtxoStatus.incoming:
      return 'incoming';
  }
}

UtxoStatus stringToUtxoStatus(String status) {
  switch (status) {
    case 'unspent':
      return UtxoStatus.unspent;
    case 'outgoing':
      return UtxoStatus.outgoing;
    case 'incoming':
      return UtxoStatus.incoming;
    default:
      return UtxoStatus.unspent; // 기본값
  }
}
