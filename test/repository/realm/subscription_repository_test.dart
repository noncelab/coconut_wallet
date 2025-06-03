import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/node/script_status.dart';
import 'package:coconut_wallet/model/wallet/singlesig_wallet_list_item.dart';
import 'package:coconut_wallet/repository/realm/model/coconut_wallet_model.dart';
import 'package:coconut_wallet/repository/realm/subscription_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../mock/script_status_mock.dart';
import '../../mock/wallet_mock.dart';
import 'test_realm_manager.dart';

void main() {
  late TestRealmManager realmManager;
  late SubscriptionRepository subscriptionRepository;
  SinglesigWalletListItem testWalletItem = WalletMock.createSingleSigWalletItem();

  setUp(() async {
    // 테스트 실행 전 셋업
    realmManager = await setupTestRealmManager();
    subscriptionRepository = SubscriptionRepository(realmManager);

    // 테스트용 지갑 생성
    realmManager.realm.write(() {
      realmManager.realm.add(RealmWalletBase(
          testWalletItem.id,
          testWalletItem.colorIndex,
          testWalletItem.iconIndex,
          testWalletItem.descriptor,
          testWalletItem.name,
          WalletType.singleSignature.name));
    });
  });

  tearDown(() {
    // 테스트 실행 후 정리
    realmManager.reset();
    realmManager.dispose();
  });

  group('updateScriptStatusList 테스트', () {
    test('새로운 스크립트 상태 추가 테스트', () async {
      // Given
      final newScriptStatuses = [
        ScriptStatusMock.createMockScriptStatus(testWalletItem, 0),
        ScriptStatusMock.createMockScriptStatus(testWalletItem, 1),
      ];

      final beforeStatuses = realmManager.realm.query<RealmScriptStatus>(
        r'walletId == $0',
        [testWalletItem.id],
      ).toList();

      expect(beforeStatuses.length, 0);

      // When
      final result = await subscriptionRepository.updateScriptStatusList(
        testWalletItem.id,
        newScriptStatuses,
      );

      // Then
      expect(result.isSuccess, true);

      final savedStatuses = realmManager.realm.query<RealmScriptStatus>(
        r'walletId == $0',
        [testWalletItem.id],
      ).toList();

      expect(savedStatuses.length, 2);

      final firstStatus = savedStatuses
          .firstWhere((status) => status.scriptPubKey == newScriptStatuses[0].scriptPubKey);
      expect(firstStatus.status, newScriptStatuses[0].status);

      final secondStatus = savedStatuses
          .firstWhere((status) => status.scriptPubKey == newScriptStatuses[1].scriptPubKey);
      expect(secondStatus.status, newScriptStatuses[1].status);
    });

    test('기존 스크립트 상태 업데이트 테스트', () async {
      // Given
      final mockScriptStatus = ScriptStatusMock.createMockScriptStatus(testWalletItem, 0);
      final existingStatus = RealmScriptStatus(
        mockScriptStatus.scriptPubKey,
        "oldStatus",
        testWalletItem.id,
        DateTime.now().subtract(const Duration(hours: 1)),
      );
      realmManager.realm.write(() {
        realmManager.realm.add(existingStatus);
      });

      final updatedScriptStatuses = [
        ScriptStatusMock.createMockScriptStatus(testWalletItem, 0, status: "newStatus"),
      ];

      // When
      final result = await subscriptionRepository.updateScriptStatusList(
        testWalletItem.id,
        updatedScriptStatuses,
      );

      // Then
      expect(result.isSuccess, true);

      final updatedStatus =
          realmManager.realm.find<RealmScriptStatus>(mockScriptStatus.scriptPubKey);
      expect(updatedStatus?.status, "newStatus");
      expect(updatedStatus?.scriptPubKey, mockScriptStatus.scriptPubKey);
    });

    test('업데이트 필요 없는 경우 테스트', () async {
      // Given
      final mockScriptStatus = ScriptStatusMock.createMockScriptStatus(testWalletItem, 0);
      final existingStatus = RealmScriptStatus(
        mockScriptStatus.scriptPubKey,
        mockScriptStatus.status!,
        testWalletItem.id,
        DateTime.now().subtract(const Duration(hours: 1)),
      );
      realmManager.realm.write(() {
        realmManager.realm.add(existingStatus);
      });

      final sameScriptStatuses = [
        mockScriptStatus,
      ];

      // When
      final result = await subscriptionRepository.updateScriptStatusList(
        testWalletItem.id,
        sameScriptStatuses,
      );

      // Then
      expect(result.isSuccess, true);

      final unchangedStatus =
          realmManager.realm.find<RealmScriptStatus>(mockScriptStatus.scriptPubKey);
      expect(unchangedStatus?.status, mockScriptStatus.status);
    });

    test('지갑이 삭제된 경우 관련 스크립트 상태 삭제 테스트', () async {
      // Given
      final mockScriptStatus = ScriptStatusMock.createMockScriptStatus(testWalletItem, 0);
      final existingStatus = RealmScriptStatus(
        mockScriptStatus.scriptPubKey,
        mockScriptStatus.status!,
        testWalletItem.id,
        DateTime.now(),
      );
      realmManager.realm.write(() {
        realmManager.realm.add(existingStatus);
      });

      final wallet = realmManager.realm.find<RealmWalletBase>(testWalletItem.id);
      realmManager.realm.write(() {
        realmManager.realm.delete(wallet!);
      });

      final scriptStatuses = [
        ScriptStatusMock.createMockScriptStatus(testWalletItem, 0, status: "newStatus"),
      ];

      // When
      final result = await subscriptionRepository.updateScriptStatusList(
        testWalletItem.id,
        scriptStatuses,
      );

      // Then
      expect(result.isSuccess, true);

      final deletedStatuses = realmManager.realm.query<RealmScriptStatus>(
        r'walletId == $0',
        [testWalletItem.id],
      ).toList();
      expect(deletedStatuses.length, 0);
    });

    test('추가와 업데이트가 혼합된 경우 테스트', () async {
      // Given
      final existingMockStatus = ScriptStatusMock.createMockScriptStatus(testWalletItem, 0);
      final existingStatus = RealmScriptStatus(
        existingMockStatus.scriptPubKey,
        "oldStatus",
        testWalletItem.id,
        DateTime.now().subtract(const Duration(hours: 1)),
      );
      realmManager.realm.write(() {
        realmManager.realm.add(existingStatus);
      });

      final mixedScriptStatuses = [
        ScriptStatusMock.createMockScriptStatus(testWalletItem, 0, status: "updatedStatus"),
        ScriptStatusMock.createMockScriptStatus(testWalletItem, 1, status: "newStatus"),
      ];

      // When
      final result = await subscriptionRepository.updateScriptStatusList(
        testWalletItem.id,
        mixedScriptStatuses,
      );

      // Then
      expect(result.isSuccess, true);

      final updatedStatus =
          realmManager.realm.find<RealmScriptStatus>(existingMockStatus.scriptPubKey);
      expect(updatedStatus?.status, "updatedStatus");

      final newMockStatus = mixedScriptStatuses[1];
      final newStatus = realmManager.realm.find<RealmScriptStatus>(newMockStatus.scriptPubKey);
      expect(newStatus?.status, "newStatus");

      final allStatuses = realmManager.realm.query<RealmScriptStatus>(
        r'walletId == $0',
        [testWalletItem.id],
      ).toList();
      expect(allStatuses.length, 2);
    });

    test('빈 스크립트 상태 목록 처리 테스트', () async {
      // Given
      final emptyScriptStatuses = <ScriptStatus>[];

      // When
      final result = await subscriptionRepository.updateScriptStatusList(
        testWalletItem.id,
        emptyScriptStatuses,
      );

      // Then
      expect(result.isSuccess, true);

      final savedStatuses = realmManager.realm.query<RealmScriptStatus>(
        r'walletId == $0',
        [testWalletItem.id],
      ).toList();
      expect(savedStatuses.length, 0);
    });

    test('동일한 scriptPubKey에 대한 status 변경 감지 테스트', () async {
      // Given
      final originalMockStatus =
          ScriptStatusMock.createMockScriptStatus(testWalletItem, 0, status: "originalStatus");
      final existingStatus = RealmScriptStatus(
        originalMockStatus.scriptPubKey,
        "originalStatus",
        testWalletItem.id,
        DateTime.now().subtract(const Duration(hours: 1)),
      );
      realmManager.realm.write(() {
        realmManager.realm.add(existingStatus);
      });

      final updatedMockStatus =
          ScriptStatusMock.createMockScriptStatus(testWalletItem, 0, status: "changedStatus");

      // When
      final result = await subscriptionRepository.updateScriptStatusList(
        testWalletItem.id,
        [updatedMockStatus],
      );

      // Then
      expect(result.isSuccess, true);

      final changedStatus =
          realmManager.realm.find<RealmScriptStatus>(originalMockStatus.scriptPubKey);
      expect(changedStatus?.status, "changedStatus");
      expect(changedStatus?.walletId, testWalletItem.id);
    });

    test('여러 스크립트에 대한 부분적 업데이트 테스트', () async {
      // Given: 여러 기존 스크립트 상태 저장
      final existingMock1 =
          ScriptStatusMock.createMockScriptStatus(testWalletItem, 0, status: "status1");
      final existingMock2 =
          ScriptStatusMock.createMockScriptStatus(testWalletItem, 1, status: "status2");
      final existingMock3 =
          ScriptStatusMock.createMockScriptStatus(testWalletItem, 2, status: "status3");

      realmManager.realm.write(() {
        realmManager.realm.addAll([
          RealmScriptStatus(
              existingMock1.scriptPubKey, "status1", testWalletItem.id, DateTime.now()),
          RealmScriptStatus(
              existingMock2.scriptPubKey, "status2", testWalletItem.id, DateTime.now()),
          RealmScriptStatus(
              existingMock3.scriptPubKey, "status3", testWalletItem.id, DateTime.now()),
        ]);
      });

      // 일부만 업데이트 (인덱스 1만 변경, 0과 2는 동일)
      final partialUpdateStatuses = [
        existingMock1, // 동일한 상태
        ScriptStatusMock.createMockScriptStatus(testWalletItem, 1,
            status: "updatedStatus2"), // 변경된 상태
        existingMock3, // 동일한 상태
      ];

      // When: 스크립트 상태 업데이트 실행
      final result = await subscriptionRepository.updateScriptStatusList(
        testWalletItem.id,
        partialUpdateStatuses,
      );

      // Then: 성공 결과 확인
      expect(result.isSuccess, true);

      // 변경되지 않은 상태들 확인
      final unchangedStatus1 =
          realmManager.realm.find<RealmScriptStatus>(existingMock1.scriptPubKey);
      expect(unchangedStatus1?.status, "status1");

      final unchangedStatus3 =
          realmManager.realm.find<RealmScriptStatus>(existingMock3.scriptPubKey);
      expect(unchangedStatus3?.status, "status3");

      // 변경된 상태 확인
      final changedStatus2 = realmManager.realm.find<RealmScriptStatus>(existingMock2.scriptPubKey);
      expect(changedStatus2?.status, "updatedStatus2");

      // 전체 개수 확인
      final allStatuses = realmManager.realm.query<RealmScriptStatus>(
        r'walletId == $0',
        [testWalletItem.id],
      ).toList();
      expect(allStatuses.length, 3);
    });
  });

  group('deleteScriptStatusIfWalletDeleted 테스트', () {
    test('지갑이 존재하는 경우 스크립트 상태 유지 테스트', () async {
      // Given
      final mockScriptStatus = ScriptStatusMock.createMockScriptStatus(testWalletItem, 0);
      final existingStatus = RealmScriptStatus(
        mockScriptStatus.scriptPubKey,
        mockScriptStatus.status!,
        testWalletItem.id,
        DateTime.now(),
      );
      realmManager.realm.write(() {
        realmManager.realm.add(existingStatus);
      });

      // When
      await subscriptionRepository.deleteScriptStatusIfWalletDeleted(testWalletItem.id);

      // Then
      final remainingStatuses = realmManager.realm.query<RealmScriptStatus>(
        r'walletId == $0',
        [testWalletItem.id],
      ).toList();
      expect(remainingStatuses.length, 1);
      expect(remainingStatuses[0].scriptPubKey, mockScriptStatus.scriptPubKey);
    });

    test('지갑이 삭제된 경우 관련 스크립트 상태 삭제 테스트', () async {
      // Given
      final mockScriptStatus1 = ScriptStatusMock.createMockScriptStatus(testWalletItem, 0);
      final mockScriptStatus2 = ScriptStatusMock.createMockScriptStatus(testWalletItem, 1);

      realmManager.realm.write(() {
        realmManager.realm.addAll([
          RealmScriptStatus(mockScriptStatus1.scriptPubKey, mockScriptStatus1.status!,
              testWalletItem.id, DateTime.now()),
          RealmScriptStatus(mockScriptStatus2.scriptPubKey, mockScriptStatus2.status!,
              testWalletItem.id, DateTime.now()),
        ]);
      });

      // 지갑 삭제
      final wallet = realmManager.realm.find<RealmWalletBase>(testWalletItem.id);
      realmManager.realm.write(() {
        realmManager.realm.delete(wallet!);
      });

      // When
      await subscriptionRepository.deleteScriptStatusIfWalletDeleted(testWalletItem.id);

      // Then
      final deletedStatuses = realmManager.realm.query<RealmScriptStatus>(
        r'walletId == $0',
        [testWalletItem.id],
      ).toList();
      expect(deletedStatuses.length, 0);
    });

    test('여러 지갑 중 특정 지갑만 삭제된 경우 테스트', () async {
      // Given
      final secondWalletItem = WalletMock.createSingleSigWalletItem(randomDescriptor: true);

      final secondWalletId = testWalletItem.id + 1;

      realmManager.realm.write(() {
        realmManager.realm.add(RealmWalletBase(
          secondWalletId,
          secondWalletItem.colorIndex,
          secondWalletItem.iconIndex,
          secondWalletItem.descriptor,
          secondWalletItem.name,
          WalletType.singleSignature.name,
        ));
      });

      final firstWalletStatus = ScriptStatusMock.createMockScriptStatus(testWalletItem, 0);
      final secondWalletStatus = ScriptStatusMock.createMockScriptStatus(secondWalletItem, 0);

      realmManager.realm.write(() {
        realmManager.realm.addAll([
          RealmScriptStatus(firstWalletStatus.scriptPubKey, firstWalletStatus.status!,
              testWalletItem.id, DateTime.now()),
          RealmScriptStatus(secondWalletStatus.scriptPubKey, secondWalletStatus.status!,
              secondWalletId, DateTime.now()),
        ]);
      });

      final firstWallet = realmManager.realm.find<RealmWalletBase>(testWalletItem.id);
      realmManager.realm.write(() {
        realmManager.realm.delete(firstWallet!);
      });

      // When
      await subscriptionRepository.deleteScriptStatusIfWalletDeleted(testWalletItem.id);

      // Then
      final firstWalletStatuses = realmManager.realm.query<RealmScriptStatus>(
        r'walletId == $0',
        [testWalletItem.id],
      ).toList();
      expect(firstWalletStatuses.length, 0);

      final secondWalletStatuses = realmManager.realm.query<RealmScriptStatus>(
        r'walletId == $0',
        [secondWalletId],
      ).toList();
      expect(secondWalletStatuses.length, 1);
      expect(secondWalletStatuses[0].scriptPubKey, secondWalletStatus.scriptPubKey);
    });

    test('지갑은 삭제되었지만 스크립트 상태가 없는 경우 테스트', () async {
      // Given
      final wallet = realmManager.realm.find<RealmWalletBase>(testWalletItem.id);
      realmManager.realm.write(() {
        realmManager.realm.delete(wallet!);
      });

      // When
      await subscriptionRepository.deleteScriptStatusIfWalletDeleted(testWalletItem.id);

      // Then: 오류 없이 완료되어야 함
      final deletedStatuses = realmManager.realm.query<RealmScriptStatus>(
        r'walletId == $0',
        [testWalletItem.id],
      ).toList();
      expect(deletedStatuses.length, 0);
    });

    test('대량의 스크립트 상태 삭제 테스트', () async {
      // Given: 대량의 스크립트 상태 생성
      final largeScriptStatuses = <RealmScriptStatus>[];
      for (int i = 0; i < 100; i++) {
        final mockStatus = ScriptStatusMock.createMockScriptStatus(testWalletItem, i);
        largeScriptStatuses.add(RealmScriptStatus(
          "${mockStatus.scriptPubKey}_$i", // 유니크한 scriptPubKey
          mockStatus.status!,
          testWalletItem.id,
          DateTime.now(),
        ));
      }

      realmManager.realm.write(() {
        realmManager.realm.addAll(largeScriptStatuses);
      });

      final beforeStatuses = realmManager.realm.query<RealmScriptStatus>(
        r'walletId == $0',
        [testWalletItem.id],
      ).toList();
      expect(beforeStatuses.length, 100);

      // 지갑 삭제
      final wallet = realmManager.realm.find<RealmWalletBase>(testWalletItem.id);
      realmManager.realm.write(() {
        realmManager.realm.delete(wallet!);
      });

      // When
      await subscriptionRepository.deleteScriptStatusIfWalletDeleted(testWalletItem.id);

      // Then
      final remainingStatuses = realmManager.realm.query<RealmScriptStatus>(
        r'walletId == $0',
        [testWalletItem.id],
      ).toList();
      expect(remainingStatuses.length, 0);
    });
  });
}
