import 'dart:async';
import 'dart:convert';

import 'package:coconut_wallet/constants/shared_pref_keys.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/wallet/transaction_address.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/repository/realm/address_repository.dart';
import 'package:coconut_wallet/repository/realm/service/realm_id_service.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:coconut_wallet/model/node/cpfp_history.dart';
import 'package:coconut_wallet/model/node/rbf_history.dart';
import 'package:coconut_wallet/model/wallet/singlesig_wallet_item.dart';
import 'package:coconut_wallet/repository/realm/model/coconut_wallet_model.dart';
import 'package:coconut_wallet/repository/realm/transaction_repository.dart';
import 'package:coconut_wallet/services/model/response/block_timestamp.dart';
import 'package:coconut_wallet/services/model/response/fetch_transaction_response.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../mock/transaction_mock.dart';
import '../../mock/wallet_mock.dart';
import 'test_realm_manager.dart';

void main() {
  late TestRealmManager realmManager;
  late TransactionRepository transactionRepository;
  SinglesigWalletItem testWalletItem = WalletMock.createSingleSigWalletItem();

  setUp(() async {
    // 테스트 실행 전 셋업
    realmManager = await setupTestRealmManager();
    transactionRepository = TransactionRepository(realmManager);

    // 테스트용 지갑 생성
    realmManager.realm.write(() {
      realmManager.realm.add(
        RealmWalletBase(
          testWalletItem.id,
          testWalletItem.colorIndex,
          testWalletItem.iconIndex,
          testWalletItem.descriptor,
          testWalletItem.name,
          WalletType.singleSignature.name,
        ),
      );
    });
  });

  tearDown(() {
    // 테스트 실행 후 정리
    realmManager.reset();
    realmManager.dispose();
  });

  group('받기 금액은 저장하는 쓰기 안에서 지금의 내 주소로 맞춘다', () {
    late AddressRepository addresses;
    late String a0, a1;
    final hash = 'ab' * 32;
    TransactionRecord received(int height, int amount) => TransactionRecord.fromTransactions(
      transactionHash: hash,
      timestamp: DateTime.utc(2026),
      blockHeight: height,
      transactionType: TransactionType.received,
      amount: amount,
      fee: 1000,
      inputAddressList: [TransactionAddress('external-in', 200000)],
      outputAddressList: [TransactionAddress(a0, 20000), TransactionAddress(a1, 20000), TransactionAddress('ext', 159000)],
      vSize: 141,
    );
    Future<void> addReceive1() => addresses.addAddressesWithGapLimit(
      walletItemBase: testWalletItem,
      newAddresses: [addresses.generateAddress(testWalletItem.walletBase, 1, false)],
      isChange: false,
    );

    setUp(() async {
      addresses = AddressRepository(realmManager);
      await addresses.ensureAddressesInit(walletItemBase: testWalletItem); // receive 0
      a0 = testWalletItem.walletBase.getAddress(0);
      a1 = testWalletItem.walletBase.getAddress(1);
    });

    test('계산 뒤 저장 전에 다른 isolate가 더한 주소도 센다', () async {
      // a1을 모를 때 20,000으로 계산됐고, 저장 전에 a1이 더해졌다(그때는 고칠 기록이 없었다).
      await addReceive1();
      await transactionRepository.addAllTransactions(testWalletItem.id, [received(0, 20000)]);
      expect(transactionRepository.getTransactionRecord(testWalletItem.id, hash)!.amount, 40000);

      // 확정 때 오래된 금액을 다시 넘겨도 낮아지지 않는다.
      await transactionRepository.addAllTransactions(testWalletItem.id, [received(101, 20000)]);
      final stored = transactionRepository.getTransactionRecord(testWalletItem.id, hash)!;
      expect([stored.blockHeight, stored.amount, stored.fee, stored.transactionType], [
        101,
        40000,
        1000,
        TransactionType.received,
      ]);
    });

    test('확정 시 저장된 기록을 재사용해도 낮게 저장된 금액을 바로잡는다', () async {
      await transactionRepository.addAllTransactions(testWalletItem.id, [received(0, 20000)]); // a1 모름
      await addReceive1();
      final realm = realmManager.realm;
      final row = realm.find<RealmTransaction>(getRealmTransactionId(testWalletItem.id, hash))!;
      realm.write(() => row.amount = 20000); // 이 수정 전 버전이 남긴 값

      await transactionRepository.addAllTransactions(testWalletItem.id, [received(101, 20000)]);
      expect([row.blockHeight, row.amount, row.fee], [101, 40000, 1000]);
    });

    test('주소 목록 더 보기로 나중에 더한 주소도 이미 저장된 받기 기록에 반영한다', () async {
      await transactionRepository.addAllTransactions(testWalletItem.id, [received(0, 20000)]); // a1을 모를 때
      expect(transactionRepository.getTransactionRecord(testWalletItem.id, hash)!.amount, 20000);

      await addReceive1(); // addAddressesWithGapLimit: 주소 쪽 재계산(접두어 조회)

      expect(transactionRepository.getTransactionRecord(testWalletItem.id, hash)!.amount, 40000);
    });

    test('입력에 내 주소가 있거나 RECEIVED가 아니면 그대로 둔다', () async {
      await addReceive1();
      final sent = TransactionRecord.fromTransactions(
        transactionHash: 'cd' * 32,
        timestamp: DateTime.utc(2026),
        blockHeight: 0,
        transactionType: TransactionType.sent,
        amount: -31000,
        fee: 1000,
        inputAddressList: [],
        outputAddressList: [TransactionAddress(a0, 69000), TransactionAddress('ext', 30000)],
        vSize: 141,
      );
      final mixed = TransactionRecord.fromTransactions(
        transactionHash: 'ef' * 32,
        timestamp: DateTime.utc(2026),
        blockHeight: 0,
        transactionType: TransactionType.received,
        amount: 99000,
        fee: 1000,
        inputAddressList: [TransactionAddress(a1, 100000)],
        outputAddressList: [TransactionAddress(a0, 199000)],
        vSize: 141,
      );
      await transactionRepository.addAllTransactions(testWalletItem.id, [sent, mixed]);
      expect(transactionRepository.getTransactionRecord(testWalletItem.id, 'cd' * 32)!.amount, -31000);
      expect(transactionRepository.getTransactionRecord(testWalletItem.id, 'ef' * 32)!.amount, 99000);
    });
  });

  group('앱 시작 때 한 번 받기 금액 바로잡기', () {
    test('입력이 빠진 예전 기록은 그대로 두고 낮은 받기 기록만 올린 뒤, 다음 시작에는 다시 보지 않는다', () async {
      SharedPreferences.setMockInitialValues({});
      // ignore: deprecated_member_use_from_same_package
      final prefs = SharedPrefsRepository()..setSharedPreferencesForTest(await SharedPreferences.getInstance());
      final realm = realmManager.realm;
      final walletId = testWalletItem.id;
      String entry(String address, int amount) => jsonEncode({'address': address, 'amount': amount});
      RealmTransaction row(int id, String type, int amount, List<String> inputs, List<String> outputs) =>
          RealmTransaction(id, 'tx$id', walletId, DateTime.utc(2026), 100, type, amount, 1000, 141, DateTime.utc(2026),
              inputAddressList: inputs, outputAddressList: outputs);
      realm.write(() {
        for (final (index, address) in ['own0', 'own1'].indexed) {
          realm.add(RealmWalletAddress(index, walletId, address, index, false, 'm/0/$index', true, 0, 0, 0));
        }
        // 529254318 이전에는 부모를 못 받은 입력을 빼고 저장했고 유형은 원래 입력 수로 정했다.
        realm.add(row(1, 'SENT', -31000, [], [entry('own0', 69000), entry('external', 30000)]));
        realm.add(row(2, 'SELF', -1000, [], [entry('own0', 99000)]));
        realm.add(row(3, 'RECEIVED', 99000, [entry('own0', 100000)], [entry('own0', 199000)]));
        realm.add(row(4, 'RECEIVED', 5000000000, [], [entry('own0', 5000000000)])); // coinbase
        // own1이 주소 창 밖일 때 기록돼 own0만 셌다.
        realm.add(row(5, 'RECEIVED', 20000, [entry('external', 50000)], [
          entry('own0', 20000),
          entry('own1', 20000),
          entry('external', 9000),
        ]));
        realm.add(row(6, 'RECEIVED', 90000, [entry('external', 99000)], [entry('own0', 20000)])); // 내리지 않는다
      });

      await healReceiveOnlyAmountsOnce(realm, prefs);

      List<Object> rows() => [
        for (var id = 1; id <= 6; id++) ...[realm.find<RealmTransaction>(id)!.transactionType, realm.find<RealmTransaction>(id)!.amount],
      ];
      expect(rows(), ['SENT', -31000, 'SELF', -1000, 'RECEIVED', 99000, 'RECEIVED', 5000000000, 'RECEIVED', 40000, 'RECEIVED', 90000]);
      expect(realm.all<RealmTransaction>().map((tx) => tx.fee), everyElement(1000));
      expect(prefs.getBool(SharedPrefKeys.kHealedReceiveOnlyAmounts), isTrue);

      realm.write(() => realm.find<RealmTransaction>(5)!.amount = 20000);
      await healReceiveOnlyAmountsOnce(realm, prefs);
      expect(realm.find<RealmTransaction>(5)!.amount, 20000, reason: 'the full pass runs once, not on every start');
    });

    test('200개씩 나눠 쓰고 사이마다 양보하며 모든 묶음의 받기 기록을 바로잡는다', () async {
      SharedPreferences.setMockInitialValues({});
      // ignore: deprecated_member_use_from_same_package
      final prefs = SharedPrefsRepository()..setSharedPreferencesForTest(await SharedPreferences.getInstance());
      final realm = realmManager.realm;
      final walletId = testWalletItem.id;
      String entry(String address, int amount) => jsonEncode({'address': address, 'amount': amount});
      realm.write(() {
        realm.add(RealmWalletAddress(0, walletId, 'own0', 0, false, 'm/0/0', true, 0, 0, 0));
        realm.add(RealmWalletAddress(1, walletId, 'own1', 1, false, 'm/0/1', true, 0, 0, 0));
        for (var id = 1; id <= 450; id++) {
          realm.add(
            RealmTransaction(id, 'tx$id', walletId, DateTime.utc(2026), 100, 'RECEIVED', 20000, 1000, 141,
                DateTime.utc(2026),
                inputAddressList: [entry('external', 50000)],
                outputAddressList: [entry('own0', 20000), entry('own1', 20000), entry('external', 9000)]),
          );
        }
      });
      var ticks = 0;
      final ticker = Timer.periodic(Duration.zero, (_) => ticks++);

      await healReceiveOnlyAmountsOnce(realm, prefs);
      ticker.cancel();

      expect(realm.all<RealmTransaction>().map((tx) => tx.amount).toSet(), {40000});
      expect(ticks, greaterThanOrEqualTo(2), reason: 'the event loop ran between the three chunks');
      expect(prefs.getBool(SharedPrefKeys.kHealedReceiveOnlyAmounts), isTrue);
    });
  });

  group('트랜잭션 기본 CRUD 테스트', () {
    test('새 트랜잭션을 추가하고 조회할 수 있어야 함', () async {
      // 테스트용 트랜잭션 생성
      final testTransaction = TransactionMock.createMockTransactionRecord();

      // 트랜잭션 추가
      await transactionRepository.addAllTransactions(testWalletItem.id, [testTransaction]);

      // 트랜잭션 조회
      final transactions = transactionRepository.getTransactionRecordList(testWalletItem.id);

      // 검증
      expect(transactions, isNotEmpty);
      expect(transactions.length, 1);
      expect(transactions[0].transactionHash, testTransaction.transactionHash);
    });
  });

  group('트랜잭션 상태 업데이트 테스트', () {
    test('미확인 트랜잭션이 확인 상태로 업데이트되어야 함', () async {
      // 미확인 트랜잭션 생성
      final testTransaction = TransactionMock.createUnconfirmedTransactionRecord();

      // 트랜잭션 추가
      transactionRepository.addAllTransactions(testWalletItem.id, [testTransaction]);

      // 블록 타임스탬프 데이터 생성
      const blockHeight = 680000;
      final blockTimestamp = BlockTimestamp(blockHeight, DateTime.fromMillisecondsSinceEpoch(1625097600 * 1000));

      // 블록 타임스탬프 저장
      realmManager.realm.write(() {
        realmManager.realm.add(RealmBlockTimestamp(blockHeight, blockTimestamp.timestamp));
      });

      // 트랜잭션 상태 업데이트 데이터 준비
      final fetchedTxMap = {
        testTransaction.transactionHash: FetchTransactionResponse(
          transactionHash: testTransaction.transactionHash,
          height: blockHeight,
          addressIndex: 0,
          isChange: false,
        ),
      };

      final blockTimestampMap = {blockHeight: blockTimestamp};

      // 지갑의 최근 트랜잭션 상태 플래그 설정
      realmManager.realm.write(() {
        realmManager.realm.find<RealmWalletBase>(testWalletItem.id);
      });

      // 트랜잭션 상태 업데이트
      await transactionRepository.updateTransactionStates(
        testWalletItem.id,
        [testTransaction.transactionHash], // 업데이트할 트랜잭션
        [], // 삭제할 트랜잭션 없음
        fetchedTxMap,
        blockTimestampMap,
      );

      // 업데이트된 트랜잭션 조회
      final updatedTransaction = transactionRepository.getTransactionRecord(
        testWalletItem.id,
        testTransaction.transactionHash,
      );
      realmManager.realm.find<RealmWalletBase>(testWalletItem.id);

      // 검증
      expect(updatedTransaction?.blockHeight, blockHeight);

      // 타임스탬프 비교 (null 안전하게 처리)
      final actualTimestamp = updatedTransaction?.timestamp;
      expect(actualTimestamp, isNotNull);
      if (actualTimestamp != null) {
        expect(actualTimestamp.millisecondsSinceEpoch ~/ 1000, blockTimestamp.timestamp.millisecondsSinceEpoch ~/ 1000);
      }
    });
  });

  group('RBF 기능 테스트', () {
    test('RBF 내역을 일괄 추가할 수 있어야 함', () async {
      // 테스트용 RBF DTO 생성
      final rbfDtoList = [
        RbfHistory(
          walletId: testWalletItem.id,
          originalTransactionHash: 'original_tx_1',
          transactionHash: 'new_tx_1',
          feeRate: 5.0,
          timestamp: DateTime.now(),
        ),
        RbfHistory(
          walletId: testWalletItem.id,
          originalTransactionHash: 'original_tx_2',
          transactionHash: 'new_tx_2',
          feeRate: 7.5,
          timestamp: DateTime.now(),
        ),
      ];

      // RBF 내역 일괄 추가
      transactionRepository.addAllRbfHistory(rbfDtoList);

      // RBF 내역 조회
      final rbfHistory1 = transactionRepository.getRbfHistoryList(testWalletItem.id, 'new_tx_1');
      final rbfHistory2 = transactionRepository.getRbfHistoryList(testWalletItem.id, 'new_tx_2');

      // 검증
      expect(rbfHistory1, isNotEmpty);
      expect(rbfHistory2, isNotEmpty);
      expect(rbfHistory1.length, 1);
      expect(rbfHistory2.length, 1);
      expect(rbfHistory1[0].originalTransactionHash, 'original_tx_1');
      expect(rbfHistory2[0].originalTransactionHash, 'original_tx_2');
    });

    test('RBF 내역을 조회할 때 연관된 RBF 내역도 함께 조회되어야 함', () async {
      // 테스트용 RBF DTO 생성
      final rbfDtoList = [
        RbfHistory(
          walletId: testWalletItem.id,
          originalTransactionHash: 'original_tx_1',
          transactionHash: 'new_tx_1',
          feeRate: 5.0,
          timestamp: DateTime.now(),
        ),
        RbfHistory(
          walletId: testWalletItem.id,
          originalTransactionHash: 'original_tx_1',
          transactionHash: 'new_tx_2',
          feeRate: 7.5,
          timestamp: DateTime.now(),
        ),
        RbfHistory(
          walletId: testWalletItem.id,
          originalTransactionHash: 'original_tx_1',
          transactionHash: 'new_tx_3',
          feeRate: 10.0,
          timestamp: DateTime.now(),
        ),
      ];

      // RBF 내역 일괄 추가
      transactionRepository.addAllRbfHistory(rbfDtoList);

      // RBF 내역 조회
      final rbfHistory = transactionRepository.getRbfHistoryList(testWalletItem.id, 'new_tx_1');

      // 검증
      expect(rbfHistory, isNotEmpty);
      expect(rbfHistory.length, 3);
      expect(rbfHistory[2].originalTransactionHash, 'original_tx_1');
      expect(rbfHistory[2].transactionHash, 'new_tx_1');
      expect(rbfHistory[1].originalTransactionHash, 'original_tx_1');
      expect(rbfHistory[1].transactionHash, 'new_tx_2');
      expect(rbfHistory[0].originalTransactionHash, 'original_tx_1');
      expect(rbfHistory[0].transactionHash, 'new_tx_3');
    });

    test('RBF 내역 조회 시 수수료 내림차순으로 정렬되어야 함', () async {
      // 테스트용 RBF DTO 생성
      final rbfDtoList = [
        RbfHistory(
          walletId: testWalletItem.id,
          originalTransactionHash: 'original_tx_1',
          transactionHash: 'new_tx_2',
          feeRate: 5.0,
          timestamp: DateTime.now(),
        ),
        RbfHistory(
          walletId: testWalletItem.id,
          originalTransactionHash: 'original_tx_1',
          transactionHash: 'new_tx_1',
          feeRate: 3.5,
          timestamp: DateTime.now(),
        ),
        RbfHistory(
          walletId: testWalletItem.id,
          originalTransactionHash: 'original_tx_1',
          transactionHash: 'new_tx_3',
          feeRate: 10.0,
          timestamp: DateTime.now(),
        ),
      ];

      // RBF 내역 일괄 추가
      transactionRepository.addAllRbfHistory(rbfDtoList);

      // RBF 내역 조회
      final rbfHistory = transactionRepository.getRbfHistoryList(testWalletItem.id, 'new_tx_1');

      // 검증
      expect(rbfHistory, isNotEmpty);
      expect(rbfHistory.length, 3);
      expect(rbfHistory[0].feeRate, 10.0);
      expect(rbfHistory[1].feeRate, 5.0);
      expect(rbfHistory[2].feeRate, 3.5);
    });

    test('RBF 내역 일괄 추가 시 중복은 무시되어야 함', () async {
      // 첫 번째 추가
      final rbfDto = RbfHistory(
        walletId: testWalletItem.id,
        originalTransactionHash: 'original_tx',
        transactionHash: 'new_tx',
        feeRate: 5.0,
        timestamp: DateTime.now(),
      );

      transactionRepository.addAllRbfHistory([rbfDto]);

      // 동일한 내역 다시 추가
      transactionRepository.addAllRbfHistory([rbfDto]);

      // RBF 내역 조회
      final rbfHistory = transactionRepository.getRbfHistoryList(testWalletItem.id, 'new_tx');

      // 검증 - 중복이 추가되지 않아야 함
      expect(rbfHistory.length, 1);
    });
  });

  group('CPFP 기능 테스트', () {
    test('CPFP 내역을 일괄 추가할 수 있어야 함', () async {
      // 테스트용 CPFP DTO 생성
      final cpfpDtoList = [
        CpfpHistory(
          walletId: testWalletItem.id,
          parentTransactionHash: 'parent_tx_1',
          childTransactionHash: 'child_tx_1',
          originalFee: 3.0,
          newFee: 10.0,
          timestamp: DateTime.now(),
        ),
        CpfpHistory(
          walletId: testWalletItem.id,
          parentTransactionHash: 'parent_tx_2',
          childTransactionHash: 'child_tx_2',
          originalFee: 4.0,
          newFee: 12.0,
          timestamp: DateTime.now(),
        ),
      ];

      // CPFP 내역 일괄 추가
      transactionRepository.addAllCpfpHistory(cpfpDtoList);

      // CPFP 내역 조회
      final cpfpHistory1 = transactionRepository.getCpfpHistory(testWalletItem.id, 'parent_tx_1');
      final cpfpHistory2 = transactionRepository.getCpfpHistory(testWalletItem.id, 'parent_tx_2');

      // 검증
      expect(cpfpHistory1, isNotNull);
      expect(cpfpHistory2, isNotNull);
      expect(cpfpHistory1?.parentTransactionHash, 'parent_tx_1');
      expect(cpfpHistory2?.parentTransactionHash, 'parent_tx_2');
      expect(cpfpHistory1?.childTransactionHash, 'child_tx_1');
      expect(cpfpHistory2?.childTransactionHash, 'child_tx_2');
    });

    test('CPFP 내역 일괄 추가 시 중복은 무시되어야 함', () async {
      // 첫 번째 추가
      final cpfpDto = CpfpHistory(
        walletId: testWalletItem.id,
        parentTransactionHash: 'parent_tx',
        childTransactionHash: 'child_tx',
        originalFee: 3.0,
        newFee: 10.0,
        timestamp: DateTime.now(),
      );

      transactionRepository.addAllCpfpHistory([cpfpDto]);

      // 동일한 내역 다시 추가
      transactionRepository.addAllCpfpHistory([cpfpDto]);

      // CPFP 내역 조회
      final allCpfpHistories = realmManager.realm.all<RealmCpfpHistory>();

      // 검증 - 중복이 추가되지 않아야 함
      expect(allCpfpHistories.length, 1);
    });
  });

  group('트랜잭션 목록 관련 테스트', () {
    test('미확인 트랜잭션과 확인된 트랜잭션이 정렬되어 반환되어야 함', () async {
      // 테스트용 트랜잭션 생성
      final confirmedTx1 = TransactionMock.createConfirmedTransactionRecord(
        transactionHash: 'confirmed_tx_1',
        timestamp: DateTime.fromMillisecondsSinceEpoch(1000),
        blockHeight: 680000,
      );

      final confirmedTx2 = TransactionMock.createConfirmedTransactionRecord(
        transactionHash: 'confirmed_tx_2',
        timestamp: DateTime.fromMillisecondsSinceEpoch(2000),
        blockHeight: 680001,
        amount: 2000000,
        fee: 20000,
      );

      final unconfirmedTx = TransactionMock.createUnconfirmedTransactionRecord(
        transactionHash: 'unconfirmed_tx',
        timestamp: DateTime.fromMillisecondsSinceEpoch(500),
      );

      // 트랜잭션 추가 (순서 섞어서)
      await transactionRepository.addAllTransactions(testWalletItem.id, [confirmedTx1, unconfirmedTx, confirmedTx2]);

      // 트랜잭션 목록 조회
      final transactions = transactionRepository.getTransactionRecordList(testWalletItem.id);

      // 검증: 미확인 트랜잭션이 먼저 나오고, 이후 확인된 트랜잭션이 타임스탬프 역순으로 정렬되어야 함
      expect(transactions.length, 3);
      expect(transactions[0].transactionHash, 'unconfirmed_tx');
      expect(transactions[1].transactionHash, 'confirmed_tx_2');
      expect(transactions[2].transactionHash, 'confirmed_tx_1');
    });

    test('getExistingConfirmedTxHashes는 확인된 트랜잭션 해시 목록을 반환해야 함', () async {
      // 테스트용 트랜잭션 생성 (확인된 것과 미확인된 것)
      final confirmedTx1 = TransactionMock.createConfirmedTransactionRecord(
        transactionHash: 'confirmed_tx_1',
        blockHeight: 680000,
      );

      final confirmedTx2 = TransactionMock.createConfirmedTransactionRecord(
        transactionHash: 'confirmed_tx_2',
        blockHeight: 680001,
        amount: 2000000,
        fee: 20000,
      );

      final unconfirmedTx = TransactionMock.createUnconfirmedTransactionRecord(transactionHash: 'unconfirmed_tx');

      // 트랜잭션 추가
      await transactionRepository.addAllTransactions(testWalletItem.id, [confirmedTx1, unconfirmedTx, confirmedTx2]);

      // 확인된 트랜잭션 해시 목록 조회
      final confirmedTxHashes = transactionRepository.getExistingConfirmedTxHashes(testWalletItem.id);

      // 검증
      expect(confirmedTxHashes.length, 2);
      expect(confirmedTxHashes.contains('confirmed_tx_1'), true);
      expect(confirmedTxHashes.contains('confirmed_tx_2'), true);
      expect(confirmedTxHashes.contains('unconfirmed_tx'), false);
    });
  });

  group('RBF 대체 표시 테스트', () {
    test('markAsRbfReplaced 함수가 트랜잭션에 대체 정보를 올바르게 설정해야 함', () async {
      // 테스트용 트랜잭션 생성 및 추가
      final originalTx = TransactionMock.createMockTransactionRecord(
        transactionHash: 'original_tx',
        blockHeight: 0, // 미확인 트랜잭션
      );

      final spentTx = TransactionMock.createMockTransactionRecord(transactionHash: 'spent_tx', blockHeight: 0);

      // 두 개의 원본 트랜잭션을 DB에 추가
      await transactionRepository.addAllTransactions(testWalletItem.id, [originalTx, spentTx]);

      // RBF 정보 맵 생성
      final rbfInfoMap = {
        'spent_tx': TransactionMock.createMockRbfInfo(
          originalTransactionHash: 'original_tx',
          previousTransactionHash: 'original_tx',
        ),
      };

      // markAsRbfReplaced 함수 호출
      await transactionRepository.markAsRbfReplaced(testWalletItem.id, rbfInfoMap);

      // 트랜잭션 조회 및 검증
      final updatedTx =
          realmManager.realm.query<RealmTransaction>(r'walletId == $0 AND transactionHash == $1', [
            testWalletItem.id,
            'original_tx',
          ]).first;
      // replaceByTransactionHash 필드가 올바르게 설정되었는지 확인
      expect(updatedTx.replaceByTransactionHash, 'spent_tx');
    });

    test('존재하지 않는 트랜잭션에 대한 RBF 정보는 처리되지 않아야 함', () async {
      // 테스트용 트랜잭션 추가 - 하나만 DB에 추가
      final originalTx = TransactionMock.createMockTransactionRecord(transactionHash: 'original_tx', blockHeight: 0);
      final spentTx = TransactionMock.createMockTransactionRecord(transactionHash: 'spent_tx', blockHeight: 0);
      final spentTx2 = TransactionMock.createMockTransactionRecord(transactionHash: 'spent_tx2', blockHeight: 0);

      await transactionRepository.addAllTransactions(testWalletItem.id, [originalTx, spentTx, spentTx2]);

      // 존재하는 트랜잭션과 존재하지 않는 트랜잭션에 대한 RBF 정보 맵 생성
      final rbfInfoMap = {
        'spent_tx': TransactionMock.createMockRbfInfo(
          originalTransactionHash: 'original_tx',
          previousTransactionHash: 'original_tx',
        ),
        'not_exists': TransactionMock.createMockRbfInfo(
          originalTransactionHash: 'original_tx',
          previousTransactionHash: 'spent_tx2',
        ),
      };

      // markAsRbfReplaced 함수 호출
      await transactionRepository.markAsRbfReplaced(testWalletItem.id, rbfInfoMap);

      // 존재하는 트랜잭션 조회 및 검증
      final updatedTx =
          realmManager.realm.query<RealmTransaction>(r'walletId == $0 AND transactionHash == $1', [
            testWalletItem.id,
            'original_tx',
          ]).first;

      // 존재하는 트랜잭션만 업데이트되었는지 확인
      expect(updatedTx.replaceByTransactionHash, 'spent_tx');

      // 존재하지 않는 트랜잭션에 대한 쿼리 실행 - 결과가 없어야 함
      final nonExistentTx = realmManager.realm.query<RealmTransaction>(r'walletId == $0 AND transactionHash == $1', [
        testWalletItem.id,
        'not_exists',
      ]);

      expect(nonExistentTx.isEmpty, true);
    });

    test('3회 RBF를 시도할 때에 1,2번째 RBF 트랜잭션에 대해서 처리되어야 함', () async {
      // 원본 트랜잭션
      final originalTx = TransactionMock.createMockTransactionRecord(
        transactionHash: 'original_tx',
        blockHeight: 0, // 미확인 트랜잭션
      );

      // RBF 1회차 트랜잭션
      final rbfTx1 = TransactionMock.createMockTransactionRecord(
        transactionHash: 'rbf_tx_1',
        blockHeight: 0, // 미확인 트랜잭션
      );

      await transactionRepository.addAllTransactions(testWalletItem.id, [originalTx, rbfTx1]);

      // RBF 1회차 정보 맵 생성
      final rbfInfoMap = {
        'rbf_tx_1': TransactionMock.createMockRbfInfo(
          originalTransactionHash: 'original_tx',
          previousTransactionHash: 'original_tx',
        ),
      };

      // markAsRbfReplaced 함수 호출
      await transactionRepository.markAsRbfReplaced(testWalletItem.id, rbfInfoMap);

      // RBF 1회차 트랜잭션
      final rbfTx2 = TransactionMock.createMockTransactionRecord(
        transactionHash: 'rbf_tx_2',
        blockHeight: 0, // 미확인 트랜잭션
      );

      await transactionRepository.addAllTransactions(testWalletItem.id, [rbfTx2]);

      // RBF 2회차 정보 맵 생성
      final rbfInfoMap2 = {
        'rbf_tx_2': TransactionMock.createMockRbfInfo(
          originalTransactionHash: 'original_tx',
          previousTransactionHash: 'rbf_tx_1',
        ),
      };

      // markAsRbfReplaced 함수 호출
      await transactionRepository.markAsRbfReplaced(testWalletItem.id, rbfInfoMap2);

      // RBF 3회차 트랜잭션
      final rbfTx3 = TransactionMock.createMockTransactionRecord(
        transactionHash: 'rbf_tx_3',
        blockHeight: 0, // 미확인 트랜잭션
      );

      await transactionRepository.addAllTransactions(testWalletItem.id, [rbfTx3]);

      // RBF 3회차 정보 맵 생성
      final rbfInfoMap3 = {
        'rbf_tx_3': TransactionMock.createMockRbfInfo(
          originalTransactionHash: 'original_tx',
          previousTransactionHash: 'rbf_tx_2',
        ),
      };

      // markAsRbfReplaced 함수 호출
      await transactionRepository.markAsRbfReplaced(testWalletItem.id, rbfInfoMap3);

      // 원본 트랜잭션 조회 및 검증
      final realmOriginalTx =
          realmManager.realm.query<RealmTransaction>(r'walletId == $0 AND transactionHash == $1', [
            testWalletItem.id,
            'original_tx',
          ]).first;

      expect(realmOriginalTx.replaceByTransactionHash, 'rbf_tx_1');

      // RBF 1회차 트랜잭션 조회 및 검증
      final realmRbfTx1 =
          realmManager.realm.query<RealmTransaction>(r'walletId == $0 AND transactionHash == $1', [
            testWalletItem.id,
            'rbf_tx_1',
          ]).first;

      expect(realmRbfTx1.replaceByTransactionHash, 'rbf_tx_2');

      // RBF 2회차 트랜잭션 조회 및 검증
      final realmRbfTx2 =
          realmManager.realm.query<RealmTransaction>(r'walletId == $0 AND transactionHash == $1', [
            testWalletItem.id,
            'rbf_tx_2',
          ]).first;

      expect(realmRbfTx2.replaceByTransactionHash, 'rbf_tx_3');

      // RBF 3회차 트랜잭션 조회 및 검증
      final realmRbfTx3 =
          realmManager.realm.query<RealmTransaction>(r'walletId == $0 AND transactionHash == $1', [
            testWalletItem.id,
            'rbf_tx_3',
          ]).first;

      expect(realmRbfTx3.replaceByTransactionHash, null);
    });
  });
}
