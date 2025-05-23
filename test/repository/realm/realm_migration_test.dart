import 'package:coconut_wallet/constants/realm_constants.dart';
import 'package:coconut_wallet/repository/realm/model/coconut_wallet_model.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:realm/realm.dart';
import 'package:coconut_wallet/repository/realm/migration/migration.dart';
import 'dart:io';

import '../../mock/realm/realm_wallet_base_mock.dart';
import '../../mock/realm/realm_wallet_address_mock.dart';
import '../../mock/realm/realm_transaction_mock.dart';
import '../../mock/realm/realm_utxo_mock.dart';

/// Realm 마이그레이션 테스트
///
/// 명령어: flutter test test/repository/realm/realm_migration_test.dart
///
/// 테스트 실행에 필요한 다이나믹 라이브러리가 필요합니다.
/// `dart run realm install`
///
/// 테스트 실패 시 로컬 Realm 파일을 수동으로 삭제하는 명령어
/// `cd <project_root>`
/// `sudo rm -rf ./test/mock/realm/migration*`
///
void deleteRealmFiles(String path) {
  if (File(path).existsSync()) {
    Realm.deleteRealm(path);

    // 기타 연관된 파일 삭제
    final lockFile = File('$path.lock');
    if (lockFile.existsSync()) {
      lockFile.deleteSync();
    }

    final managementDir = Directory('$path.management');
    if (managementDir.existsSync()) {
      managementDir.deleteSync(recursive: true);
    }
  }
}

String getUniqueRealmPath(String testName) {
  return 'test/mock/realm/${testName.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch % 10000}.realm';
}

void main() {
  late Configuration config;
  late Realm realm;
  String? testPath;

  void realmSetup({required int initialVersion}) {
    // 테스트용 Realm 설정
    config = Configuration.local(
      realmAllSchemas,
      schemaVersion: initialVersion,
      path: testPath,
    );

    // 새로운 Realm 인스턴스 생성
    realm = Realm(config);
  }

  setUp(() async {
    // 매 테스트마다 고유한 파일 경로 사용 (타임스탬프 추가)
    testPath = getUniqueRealmPath('migration');

    // 기존 파일이 있는 경우 삭제 시도
    final file = File(testPath!);
    if (await file.exists()) {
      await file.delete();
    }
  });

  tearDown(() {
    // Realm 인스턴스 정리
    if (!realm.isClosed) {
      realm.close();
    }

    // 테스트 종료 후 Realm 파일 정리
    deleteRealmFiles(testPath!);
  });

  group('Realm migration test', () {
    group("[Migration O]", () {
      test("[0 -> kRealmVersion]", () {
        realmSetup(initialVersion: 0);
        migrationFrom0ToLatest(realm, kRealmVersion, testPath!);
      });

      test('[1 -> kRealmVersion]', () {
        realmSetup(initialVersion: 1);
        migrationFrom1toLatest(realm, kRealmVersion, testPath!);
      });

      test("[2 -> kRealmVersion]", () {
        realmSetup(initialVersion: 2);
        migrationFrom2toLatest(realm, kRealmVersion, testPath!);
      });
    });

    group("[Migration X]", () {
      setUp(() {
        Logger.log("============ Migration X ============");
      });

      test("[0 -> 0]", () {
        realmSetup(initialVersion: 0);
        migrationFrom0ToLatest(realm, 0, testPath!);
      });

      test('[1 -> 1]', () {
        realmSetup(initialVersion: 1);
        migrationFrom1toLatest(realm, 1, testPath!);
      });

      test("[2 -> 2]", () {
        realmSetup(initialVersion: 2);
        migrationFrom2toLatest(realm, 2, testPath!);
      });
    });
  });
}

// migrationFrom2To3 테스트는 기본 검증 코드라 1to2 코드로 검증
void migrationFrom0ToLatest(Realm originalRealm, int newRealmVersion, String newRealmPath) {
  migrationFrom1toLatest(originalRealm, newRealmVersion, newRealmPath);
}

void migrationFrom1toLatest(Realm originalRealm, int newRealmVersion, String newRealmPath) {
  // Given
  int usedReceiveIndex = 5;
  int usedChangeIndex = 3;

  originalRealm.write(() {
    originalRealm.add(RealmWalletBaseMock.getMock(
        name: 'Test Wallet', usedReceiveIndex: usedReceiveIndex, usedChangeIndex: usedChangeIndex));
    originalRealm.add(
        RealmWalletAddressMock.getUsedMock(id: 1, address: 'address1', index: 0, isChange: false));
    originalRealm.add(
        RealmWalletAddressMock.getUsedMock(id: 2, address: 'address2', index: 0, isChange: true));
    originalRealm.add(RealmTransactionMock.getMock());
    originalRealm.add(RealmUtxoMock.getMock());
  });

  expect(originalRealm.all<RealmWalletBase>().length, 1);
  var walletBeforeMigration = originalRealm.all<RealmWalletBase>().first;
  expect(walletBeforeMigration.usedReceiveIndex, usedReceiveIndex);
  expect(walletBeforeMigration.usedChangeIndex, usedChangeIndex);
  expect(originalRealm.all<RealmWalletAddress>().length, 2);
  expect(originalRealm.all<RealmTransaction>().length, 1);
  expect(originalRealm.all<RealmUtxo>().length, 1);

  // When
  if (!originalRealm.isClosed) {
    originalRealm.close();
  }

  // 직접 resetWithoutWallet 함수를 적용한 후 검증
  // 이전 버전으로 설정하여 마이그레이션이 실행되도록 함
  final newRealmConfig = Configuration.local(realmAllSchemas,
      schemaVersion: newRealmVersion, migrationCallback: defaultMigration, path: newRealmPath);

  // 마이그레이션이 동작하는 새 Realm 인스턴스 생성 (이 시점에 마이그레이션은 이미 실행됨)
  final newRealm = Realm(newRealmConfig);

  if (newRealmVersion > 1) {
    // Then - 마이그레이션 후 검증
    // 1. 지갑 정보는 유지되어야 함
    expect(newRealm.all<RealmWalletBase>().length, 1, reason: '지갑 정보는 유지되어야 함');
    final migratedWallet = newRealm.all<RealmWalletBase>().first;
    expect(migratedWallet.name, 'Test Wallet', reason: '지갑 이름은 유지되어야 함');

    // usedReceiveIndex 확인 - 초기화 후에는 -1이어야 함
    expect(migratedWallet.usedReceiveIndex, -1, reason: 'usedReceiveIndex가 -1로 초기화되어야 함');
    expect(migratedWallet.usedChangeIndex, -1, reason: 'usedChangeIndex가 -1로 초기화되어야 함');

    // 2. 주소 정보는 유지되지만 초기화되어야 함
    expect(newRealm.all<RealmWalletAddress>().length, 2, reason: '주소 정보는 유지되어야 함');
    final migratedAddress = newRealm.all<RealmWalletAddress>().first;
    expect(migratedAddress.address, 'address1', reason: '주소 값은 유지되어야 함');
    expect(migratedAddress.isUsed, false, reason: 'isUsed가 false로 초기화되어야 함');
    expect(migratedAddress.confirmed, 0, reason: 'confirmed가 0으로 초기화되어야 함');
    expect(migratedAddress.unconfirmed, 0, reason: 'unconfirmed가 0으로 초기화되어야 함');
    expect(migratedAddress.total, 0, reason: 'total이 0으로 초기화되어야 함');
    final migratedAddress2 = newRealm.all<RealmWalletAddress>().last;
    expect(migratedAddress2.address, 'address2', reason: '주소 값은 유지되어야 함');
    expect(migratedAddress2.isUsed, false, reason: 'isUsed가 false로 초기화되어야 함');
    expect(migratedAddress2.confirmed, 0, reason: 'confirmed가 0으로 초기화되어야 함');
    expect(migratedAddress2.unconfirmed, 0, reason: 'unconfirmed가 0으로 초기화되어야 함');
    expect(migratedAddress2.total, 0, reason: 'total이 0으로 초기화되어야 함');

    // 3. 나머지는 삭제
    expect(newRealm.all<RealmTransaction>().isEmpty, isTrue, reason: '트랜잭션이 삭제되어야 함');
    expect(newRealm.all<RealmUtxo>().isEmpty, isTrue, reason: 'UTXO가 삭제되어야 함');
  } else {
    // Then - 마이그레이션 후 검증
    // 1. 지갑 정보 유지
    expect(newRealm.all<RealmWalletBase>().length, 1);
    final migratedWallet = newRealm.all<RealmWalletBase>().first;
    expect(migratedWallet.name, 'Test Wallet');
    expect(migratedWallet.usedReceiveIndex, usedReceiveIndex);
    expect(migratedWallet.usedChangeIndex, usedChangeIndex);

    // 2. 주소 정보 유지
    expect(newRealm.all<RealmWalletAddress>().length, 2);
    final migratedAddress = newRealm.all<RealmWalletAddress>().first;
    expect(migratedAddress.address, 'address1');
    expect(migratedAddress.isUsed, true);
    expect(migratedAddress.confirmed, 1000);
    expect(migratedAddress.unconfirmed, 500);
    expect(migratedAddress.total, 1500);
    final migratedAddress2 = newRealm.all<RealmWalletAddress>().last;
    expect(migratedAddress2.address, 'address2');
    expect(migratedAddress2.isUsed, true);
    expect(migratedAddress2.confirmed, 1000);
    expect(migratedAddress2.unconfirmed, 500);
    expect(migratedAddress2.total, 1500);

    // 3. 나머지 정보도 유지
    expect(newRealm.all<RealmTransaction>().length, 1, reason: '트랜잭션 정보는 유지되어야 함');
    expect(newRealm.all<RealmUtxo>().length, 1, reason: 'UTXO 정보는 유지되어야 함');
  }

  newRealm.close();
}

void migrationFrom2toLatest(Realm originalRealm, int newRealmVersion, String newRealmPath) {
  originalRealm.write(() {
    originalRealm.add(RealmWalletBaseMock.getMock(
      name: 'Test Wallet1',
      id: 1,
    ));
    originalRealm.add(RealmWalletBaseMock.getMock(
      name: 'Test Wallet2',
      id: 2,
    ));
  });

  final testWallet1BeforeMigration = originalRealm
      .query<RealmWalletBase>(
        'id == 1',
      )
      .first;

  final testWallet2BeforeMigration = originalRealm
      .query<RealmWalletBase>(
        'id == 2',
      )
      .first;

  expect(testWallet1BeforeMigration.name, 'Test Wallet1');
  expect(testWallet1BeforeMigration.id, 1);
  expect(testWallet2BeforeMigration.name, 'Test Wallet2');
  expect(testWallet2BeforeMigration.id, 2);

  if (!originalRealm.isClosed) {
    originalRealm.close();
  }

  // Change RealmConfig
  final newRealmConfig = Configuration.local(realmAllSchemas,
      schemaVersion: newRealmVersion, migrationCallback: defaultMigration, path: newRealmPath);
  final newRealm = Realm(newRealmConfig);

  final testWallet1AfterMigration = newRealm
      .query<RealmWalletBase>(
        'id == 1',
      )
      .first;

  final testWallet2AfterMigration = newRealm
      .query<RealmWalletBase>(
        'id == 2',
      )
      .first;

  expect(testWallet1AfterMigration.name, 'Test Wallet1');
  expect(testWallet1AfterMigration.id, 1);
  expect(testWallet2AfterMigration.name, 'Test Wallet2');
  expect(testWallet2AfterMigration.id, 2);

  newRealm.close();
}
