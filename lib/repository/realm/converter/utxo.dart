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
  );
}
