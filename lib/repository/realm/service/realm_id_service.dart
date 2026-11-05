import 'package:coconut_wallet/repository/realm/model/coconut_wallet_model.dart';
import 'package:coconut_wallet/utils/hash_util.dart';
import 'package:realm/realm.dart';

int getLastId(Realm realm, String key) {
  // 해당 key에 대한 ID 값 조회
  final counter = realm.find<RealmIntegerId>(key);
  if (counter == null) {
    // ID 카운터가 없다면 새로운 카운터 추가
    realm.write(() {
      realm.add(RealmIntegerId(key, 1)); // 첫 번째 ID는 1로 시작
    });
    return 1; // 첫 번째 ID
  } else {
    return counter.value;
  }
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
