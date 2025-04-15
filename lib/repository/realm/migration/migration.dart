import 'package:coconut_wallet/constants/realm_constants.dart';
import 'package:coconut_wallet/repository/realm/model/coconut_wallet_model.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:realm/realm.dart';

/// Realm 마이그레이션 주의사항
///
/// 마이그레이션 동작 순서
/// 1. [kRealmVersion] 버전이 수정되면 [defaultMigration] 함수가 호출됨
/// 2. 버전이 다를 경우 지갑 정보를 제외한 나머지 데이터 삭제
/// 3. 지갑 정보가 달라질 경우 별도 마이그레이션 코드가 필요함
/// 4. 지갑 정보 이외의 나머지 코드들은 모두 지우고 새로 동기화 (마이그레이션 관리 포인트를 줄이기 위함)
/// 5. 지갑별 최초 주소 20개가 필요하여 주소 데이터도 지우지 않고 사용 여부, 잔액만 초기화
void defaultMigration(Migration migration, int oldVersion) {
  if (canSkipMigration(migration, oldVersion)) {
    return;
  }

  try {
    resetWithoutWallet(migration.newRealm);
  } catch (e, stackTrace) {
    Logger.log('Migration error: $e\n$stackTrace');
    rethrow;
  }
}

bool canSkipMigration(Migration migration, int oldVersion) {
  return oldVersion == kRealmVersion;
}

void resetWithoutWallet(Realm realm) {
  // 지갑과 주소는 삭제하지 않으며, 모든 작업을 하나의 트랜잭션 내에서 처리
  realm.all<RealmWalletBase>().forEach((walletBase) {
    walletBase.usedReceiveIndex = -1;
    walletBase.usedChangeIndex = -1;
  });

  // 주소 데이터 초기화
  realm.all<RealmWalletAddress>().forEach((walletAddress) {
    walletAddress.confirmed = 0;
    walletAddress.unconfirmed = 0;
    walletAddress.total = 0;
    walletAddress.isUsed = false;
  });

  // 나머지 데이터 삭제
  realm.deleteAll<RealmTransaction>();
  realm.deleteAll<RealmUtxoTag>();
  realm.deleteAll<RealmWalletBalance>();
  realm.deleteAll<RealmUtxo>();
  realm.deleteAll<RealmScriptStatus>();
  realm.deleteAll<RealmBlockTimestamp>();
  realm.deleteAll<RealmIntegerId>();
  realm.deleteAll<TempBroadcastTimeRecord>();
  realm.deleteAll<RealmRbfHistory>();
  realm.deleteAll<RealmCpfpHistory>();
}
