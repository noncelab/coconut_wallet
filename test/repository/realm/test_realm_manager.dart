import 'package:coconut_wallet/repository/realm/model/coconut_wallet_model.dart';
import 'package:coconut_wallet/repository/realm/realm_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:realm/realm.dart';

/// 테스트용 RealmManager 클래스
///
/// 인메모리 Realm 데이터베이스를 사용하여 테스트 환경을 제공합니다.
class TestRealmManager implements RealmManager {
  final Realm _realm;

  TestRealmManager()
      : _realm = Realm(
          Configuration.inMemory(realmAllSchemas),
        );

  @override
  Realm get realm => _realm;

  @override
  void reset() {
    realm.write(() {
      realm.deleteAll<RealmWalletBase>();
      realm.deleteAll<RealmMultisigWallet>();
      realm.deleteAll<RealmExternalWallet>();
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
