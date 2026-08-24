import 'package:coconut_wallet/repository/realm/model/coconut_wallet_model.dart';
import 'package:coconut_wallet/repository/realm/realm_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:realm/realm.dart';

/// 테스트용 RealmManager 클래스
///
/// 인메모리 Realm 데이터베이스를 사용하여 테스트 환경을 제공합니다.
class TestRealmManager implements RealmManager {
  static int _instanceCounter = 0;

  final Realm _realm;

  // path 없이 Configuration.inMemory()를 쓰면 모든 인스턴스가 이름 없는 같은 in-memory DB를
  // 공유한다. 이 공유 범위는 Dart isolate가 아니라 "실행 중인 프로세스 전체"라서, flutter
  // test가 여러 테스트 파일을 각자 isolate로 나눠 동시에 돌려도 서로 격리되지 않는다.
  // 그 결과 한 파일의 tearDown(realm.close())이 아직 같은 DB를 쓰고 있는 다른 파일의
  // 테스트를 깨뜨린다(RealmException: invalidated or deleted object).
  // → 인스턴스마다 고유한 path를 줘서 완전히 별도의 DB로 분리한다.
  TestRealmManager()
    : _realm = Realm(
        Configuration.inMemory(
          realmAllSchemas,
          path: 'test_${DateTime.now().microsecondsSinceEpoch}_${_instanceCounter++}.realm',
        ),
      );

  @override
  Realm get realm => _realm;

  @override
  void reset() {
    realm.write(() {
      realm.deleteAll<RealmWalletBase>();
      realm.deleteAll<RealmMultisigWallet>();
      realm.deleteAll<RealmExternalWallet>();
      realm.deleteAll<RealmTaprootWallet>();
      realm.deleteAll<RealmTransaction>();
      realm.deleteAll<RealmUtxoTag>();
      realm.deleteAll<RealmWalletBalance>();
      realm.deleteAll<RealmWalletAddress>();
      realm.deleteAll<RealmUtxo>();
      realm.deleteAll<RealmScriptStatus>();
      realm.deleteAll<RealmBlockTimestamp>();
      realm.deleteAll<RealmIntegerId>();
      realm.deleteAll<RealmRbfHistory>();
      realm.deleteAll<RealmCpfpHistory>();
      realm.deleteAll<RealmTransactionMemo>();
    });
  }

  Future<void> encrypt(String hashedPin) async {
    // 테스트에서는 실제 암호화를 수행하지 않음
    return Future.value();
  }

  Future<void> decrypt() async {
    // 테스트에서는 실제 복호화를 수행하지 않음
    return Future.value();
  }

  @override
  void dispose() {
    realm.close();
  }
}

/// 테스트용 RealmManager 생성 헬퍼 함수
Future<TestRealmManager> setupTestRealmManager() async {
  final realmManager = TestRealmManager();
  return realmManager;
}
