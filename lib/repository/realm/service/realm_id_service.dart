import 'package:coconut_wallet/repository/realm/model/coconut_wallet_model.dart';
import 'package:coconut_wallet/utils/hash_util.dart';
import 'package:realm/realm.dart';

int getLastId(Realm realm, String key) {
  // 다른 Realm 인스턴스의 쓰기 결과가 반영된 트랜잭션 안에서 존재 여부를 확인한다.
  return realm.write(() {
    final counter = realm.find<RealmIntegerId>(key);
    if (counter != null) return counter.value;
    realm.add(RealmIntegerId(key, 1));
    return 1;
  });
}

void saveLastId(Realm realm, String key, int lastId) {
  final counter = realm.query<RealmIntegerId>(r'key == $0', [key]).first;
  realm.write(() {
    counter.value = lastId;
  });
}

int getTransactionMemoId(String transactionHash, int walletId) {
  return generateHashInt([transactionHash, walletId]);
}

String getUtxoId(String transactionHash, int index) {
  return '$transactionHash$index';
}

/// Realm 안에서 동일 outpoint를 여러 지갑이 각각 소유할 수 있도록 사용하는 저장용 ID.
///
/// [getUtxoId]는 PSBT 및 UTXO 태그 등 도메인 영역에서 사용하는 outpoint ID이므로
/// 변경하지 않고, Realm의 primary key에만 walletId를 포함한다.
String getRealmUtxoId(int walletId, String transactionHash, int index) {
  return '$walletId:${getUtxoId(transactionHash, index)}';
}

int getCpfpHistoryId(int walletId, String parentTransactionHash, String childTransactionHash) {
  return generateHashInt([walletId, parentTransactionHash, childTransactionHash]);
}

int getRbfHistoryId(int walletId, String originalTransactionHash, String transactionHash) {
  return generateHashInt([walletId, originalTransactionHash, transactionHash]);
}

int getRealmTransactionId(int walletId, String transactionHash) {
  return generateHashInt([walletId, transactionHash]);
}

int getWalletAddressId(int walletId, int index, String address) {
  return generateHashInt([walletId, index, address]);
}
