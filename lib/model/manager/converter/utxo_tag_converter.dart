import 'package:coconut_wallet/model/manager/realm/model/coconut_wallet_data.dart';
import 'package:coconut_wallet/model/utxo_tag.dart';

UtxoTag mapRealmUtxoTagToUtxoTag(RealmUtxoTag utxoTag) {
  return UtxoTag(
    name: utxoTag.name,
    colorIndex: utxoTag.colorIndex,
    utxoIdList: utxoTag.utxoIdList.map((e) => e.id).toList(),
  );
}

RealmUtxoId mapStringToRealmUtxoId(String id) {
  return RealmUtxoId(id);
}
