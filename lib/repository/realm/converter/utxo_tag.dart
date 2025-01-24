import 'package:coconut_wallet/repository/realm/model/coconut_wallet_model.dart';
import 'package:coconut_wallet/model/utxo/utxo_tag.dart';

UtxoTag mapRealmUtxoTagToUtxoTag(RealmUtxoTag utxoTag) {
  return UtxoTag(
    id: utxoTag.id,
    walletId: utxoTag.walletId,
    name: utxoTag.name,
    colorIndex: utxoTag.colorIndex,
    utxoIdList: utxoTag.utxoIdList,
  );
}
