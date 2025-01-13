import 'package:coconut_wallet/repository/realm/model/coconut_wallet_data.dart';
import 'package:realm/realm.dart';

int generateNextId(Realm realm, String key) {
  // 해당 key에 대한 ID 값 조회
  final counter =
      realm.all<RealmIntegerId>().query(r'key == $0', [key]).firstOrNull;
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

void saveNextId(Realm realm, String key, int nextId) {
  final counter = realm.all<RealmIntegerId>().query(r'key == $0', [key]).first;
  realm.write(() {
    counter.value = nextId;
  });
}
