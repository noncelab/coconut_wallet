import 'package:coconut_wallet/constants/realm_constants.dart';
import 'package:coconut_wallet/repository/realm/model/coconut_wallet_model.dart';
import 'package:coconut_wallet/repository/realm/service/realm_id_service.dart';
import 'package:coconut_wallet/utils/hash_util.dart';
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
/// [addRealmTransactionMemo] (4 -> 5)
/// 1. RealmTransactionMemo 추가
/// 2. RealmTransaction 에서 memo 필드 삭제
/// 3. RealmTransaction 의 id 를 재생성
/// 4. RealmWalletAddress 의 id 를 재생성
/// 5. TempBroadcastTimeRecord 삭제
///
/// [addRealmTransactionDraft] (5 -> 6)
/// 1. RealmTransactionDraft 추가
/// 2. RealmWalletPreferences 에 manualUtxoSelectionWalletIds 필드 추가
void defaultMigration(Migration migration, int oldVersion) {
  if (oldVersion == kRealmVersion) {
    Logger.log('oldVersion: $oldVersion is same as kRealmVersion: $kRealmVersion');
    return;
  }

  try {
    Logger.log('oldVersion: $oldVersion');
    if (oldVersion < 2) resetExceptForWallet(migration.newRealm);
    if (oldVersion < 3) removeIsLatestTxBlockHeightZero(migration.newRealm);
    if (oldVersion < 4) addIsDeletedToUtxo(migration.newRealm);
    if (oldVersion < 5) migrationV5(migration);
  } catch (e, stackTrace) {
    Logger.error('Migration error: $e\n$stackTrace');
    rethrow;
  }
}

void migrationV5(Migration migration) {
  addRealmTransactionMemo(migration);
  resetTxRecordAndAddress(migration);
}

void resetTxRecordAndAddress(Migration migration) {
  Logger.log('resetTxRecordAndAddress migration start');
  final newRealm = migration.newRealm;

  // RealmTransaction 데이터 재생성
  final oldTransactions = newRealm.all<RealmTransaction>().toList();
  final newTransactions = <RealmTransaction>[];

  for (var oldTx in oldTransactions) {
    // transactionHash와 walletId를 조합하여 새로운 unique id 생성
    final newId = getRealmTransactionId(oldTx.walletId, oldTx.transactionHash);

    final newTx = RealmTransaction(
      newId,
      oldTx.transactionHash,
      oldTx.walletId,
      oldTx.timestamp,
      oldTx.blockHeight,
      oldTx.transactionType,
      oldTx.amount,
      oldTx.fee,
      oldTx.vSize,
      oldTx.createdAt,
      inputAddressList: oldTx.inputAddressList,
      outputAddressList: oldTx.outputAddressList,
      replaceByTransactionHash: oldTx.replaceByTransactionHash,
    );

    newTransactions.add(newTx);
  }

  // RealmWalletAddress 데이터 재생성
  final oldAddresses = newRealm.all<RealmWalletAddress>().toList();
  final newAddresses = <RealmWalletAddress>[];

  for (var oldAddr in oldAddresses) {
    // walletId, address, index를 조합하여 새로운 unique id 생성
    final newId = getWalletAddressId(oldAddr.walletId, oldAddr.index, oldAddr.address);

    final newAddr = RealmWalletAddress(
      newId,
      oldAddr.walletId,
      oldAddr.address,
      oldAddr.index,
      oldAddr.isChange,
      oldAddr.derivationPath,
      oldAddr.isUsed,
      oldAddr.confirmed,
      oldAddr.unconfirmed,
      oldAddr.total,
    );

    newAddresses.add(newAddr);
  }

  // 기존 데이터 삭제
  newRealm.deleteAll<RealmTransaction>();
  newRealm.deleteAll<RealmWalletAddress>();

  // 새 데이터 추가
  newRealm.addAll(newTransactions);
  newRealm.addAll(newAddresses);

  Logger.log('resetTxRecordAndAddress migration end');
}

void addRealmTransactionMemo(Migration migration) {
  Logger.log('RealmTransactionMemo migration start');
  final newRealm = migration.newRealm;
  final oldTxs = migration.oldRealm.all("RealmTransaction");
  final memos = List<RealmTransactionMemo>.empty(growable: true);
  for (var oldTx in oldTxs) {
    final memo = oldTx.dynamic.get("memo");
    if (memo != null) {
      final transactionHash = oldTx.dynamic.get("transactionHash") as String;
      final walletId = oldTx.dynamic.get("walletId") as int;
      final memoString = memo.toString();

      Logger.log('memo: $memoString - $transactionHash - $walletId');

      memos.add(
        RealmTransactionMemo(
          generateHashInt([transactionHash, walletId]),
          transactionHash,
          walletId,
          memoString,
          DateTime.now(),
        ),
      );
    }
  }

  newRealm.addAll(memos);
  Logger.log('RealmTransactionMemo migration end');
}

void addIsDeletedToUtxo(Realm realm) {
  final oldUtxos = realm.all<RealmUtxo>();
  for (var utxo in oldUtxos) {
    utxo.isDeleted = false;
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
  realm.deleteAll<RealmRbfHistory>();
  realm.deleteAll<RealmCpfpHistory>();
  realm.deleteAll<RealmTransactionMemo>();
}
