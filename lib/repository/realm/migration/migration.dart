import 'package:coconut_wallet/constants/realm_constants.dart';
import 'package:coconut_wallet/repository/realm/model/coconut_wallet_model.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:realm/realm.dart';

/// Realm 마이그레이션 주의사항
///
/// 마이그레이션 동작 순서
/// [kRealmVersion] 버전이 수정되면 [defaultMigration] 함수가 호출됨
///
/// 특정 스키마의 속성 추가/삭제: 스키마 버전을 올리면 자동으로 마이그레이션
/// 특정 스키마의 속성 이름 변경: migration.renameProperty
/// 특정 스키마 자체를 삭제: migration.deleteType
/// 기타 마이그레이션: realm 정보를 토대로 수정(기존 속성 타입 변경 등)
/// https://www.mongodb.com/ko-kr/docs/atlas/device-sdks/sdk/flutter/realm-database/model-data/update-realm-object-schema/#std-label-flutter-automatically-update-schema
///
/// [resetExceptForWallet] (1 -> 2)
/// 1. 지갑 정보를 제외한 나머지 데이터 삭제
/// 2. 지갑 정보가 달라질 경우 별도 마이그레이션 코드가 필요함
/// 3. 지갑 정보 이외의 나머지 코드들은 모두 지우고 새로 동기화 (마이그레이션 관리 포인트를 줄이기 위함)
/// 4. 지갑별 최초 주소 20개가 필요하여 주소 데이터도 지우지 않고 사용 여부, 잔액만 초기화
///
/// [removeIsLatestTxBlockHeightZero] (2 -> 3)
/// 1. RealmWalletBase isLatestTxBlockHeightZero 필드를 삭제합니다.
///
void defaultMigration(Migration migration, int oldVersion) {
  if (oldVersion == kRealmVersion) {
    return;
  }

  try {
    Logger.log('oldVersion: $oldVersion');
    if (oldVersion < 2) resetExceptForWallet(migration.newRealm);
    if (oldVersion < 3) removeIsLatestTxBlockHeightZero(migration.newRealm);
  } catch (e, stackTrace) {
    Logger.log('Migration error: $e\n$stackTrace');
    rethrow;
  }
}

void removeIsLatestTxBlockHeightZero(Realm realm) {
  Logger.log("removeIsLatestTxBlockHeightZero");
}

void resetExceptForWallet(Realm realm) {
  Logger.log("resetExceptForWallet");

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
