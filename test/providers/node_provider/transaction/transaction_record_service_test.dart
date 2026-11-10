import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/model/safety/safety_check.dart';
import 'package:coconut_wallet/model/safety/safety_state.dart';
import 'package:coconut_wallet/model/wallet/singlesig_wallet_item.dart';
import 'package:coconut_wallet/model/wallet/transaction_address.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/providers/node_provider/transaction/transaction_record_service.dart';
import 'package:coconut_wallet/repository/realm/address_repository.dart';
import 'package:coconut_wallet/repository/realm/model/coconut_wallet_model.dart';
import 'package:coconut_wallet/repository/realm/transaction_repository.dart';
import 'package:coconut_wallet/services/electrum_service.dart';
import 'package:coconut_wallet/services/model/response/block_timestamp.dart';
import 'package:coconut_wallet/services/model/response/electrum_response_types.dart';
import 'package:coconut_wallet/services/safety/incident_detector.dart';
import 'package:coconut_wallet/services/safety/safety_engine.dart';
import 'package:coconut_wallet/services/safety/safety_inputs_collector.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import '../../../mock/transaction_mock.dart';
import '../../../mock/wallet_mock.dart';
import '../../../repository/realm/test_realm_manager.dart';
import '../../../services/safety/safety_fakes.dart';

// 모킹할 클래스 목록
@GenerateMocks([ElectrumService])
import 'transaction_record_service_test.mocks.dart';

void main() {
  late TestRealmManager realmManager;
  late AddressRepository addressRepository;
  late MockElectrumService electrumService;
  late TransactionRecordService transactionRecordService;

  const int testWalletId = 1;
  final SinglesigWalletItem testWalletItem = WalletMock.createSingleSigWalletItem(id: testWalletId);
  final SinglesigWalletItem testExternalWalletItem = WalletMock.createSingleSigWalletItem(
    randomDescriptor: true,
    id: testWalletId + 1,
  );
  final blockTimestamp = DateTime.parse('2025-01-01T00:00:00Z');

  setUp(() async {
    realmManager = await setupTestRealmManager();
    addressRepository = AddressRepository(realmManager);
    electrumService = MockElectrumService();

    transactionRecordService = TransactionRecordService(electrumService, addressRepository);

    realmManager.realm.write(() {
      realmManager.realm.add(
        RealmWalletBase(
          testWalletId,
          0, // colorIndex
          0, // iconIndex
          testWalletItem.descriptor,
          testWalletItem.name,
          testWalletItem.walletType.name,
        ),
      );
    });

    final testAddress = testWalletItem.walletBase.getAddress(0);
    realmManager.realm.write(() {
      realmManager.realm.add(
        RealmWalletAddress(
          1,
          testWalletId,
          testAddress,
          0, // index
          false, // isChange
          'm/0/0', // derivationPath
          false, // isUsed
          0, // confirmed
          0, // unconfirmed
          0, // total
        ),
      );
    });
  });

  tearDown(() {
    realmManager.reset();
    realmManager.dispose();
  });

  group('getTransactionRecord 테스트', () {
    test('컨펌 트랜잭션을 올바르게 조회하는지 확인', () async {
      // Given
      final testAddress = testWalletItem.walletBase.getAddress(0);
      const blockHeight = 700000;
      final prevTx = TransactionMock.createMockTransaction(
        toAddress: testExternalWalletItem.walletBase.getAddress(0),
        amount: 2000000,
      );
      final receiveTx = TransactionMock.createMockTransaction(
        toAddress: testAddress,
        amount: 1000000,
        inputTransactionHash: prevTx.transactionHash,
      );

      // Given - Mock 동작 설정
      when(electrumService.getTransaction(receiveTx.transactionHash)).thenAnswer((_) async => receiveTx.serialize());
      when(
        electrumService.getPreviousTransactions(any, existingTxList: anyNamed('existingTxList')),
      ).thenAnswer((_) async => [prevTx]);
      when(
        electrumService.getHistory(AddressType.p2wpkh, testAddress),
      ).thenAnswer((_) async => [GetTxHistoryRes(height: blockHeight, txHash: receiveTx.transactionHash)]);
      when(
        electrumService.getBlockTimestamp(blockHeight),
      ).thenAnswer((_) async => BlockTimestamp(blockHeight, blockTimestamp));

      // When
      final result = await transactionRecordService.getTransactionRecord(testWalletItem, receiveTx.transactionHash);

      TransactionRecord? updatedTx;
      if (result.isSuccess) {
        updatedTx = result.value;
      } else {
        fail('❌ result IS FAILED: ${result.error}');
      }

      // Then
      expect(updatedTx.transactionHash, receiveTx.transactionHash);
      expect(updatedTx.blockHeight, blockHeight);
      expect(updatedTx.timestamp.millisecondsSinceEpoch, blockTimestamp.millisecondsSinceEpoch);
      expect(updatedTx.transactionType, TransactionType.received);
      expect(updatedTx.amount, 1000000);

      verify(electrumService.getTransaction(receiveTx.transactionHash)).called(1);
      verify(electrumService.getPreviousTransactions(any, existingTxList: anyNamed('existingTxList'))).called(1);
      verify(electrumService.getHistory(AddressType.p2wpkh, testAddress)).called(1);
      verify(electrumService.getBlockTimestamp(blockHeight)).called(1);
    });

    test('언컨펌 트랜잭션을 올바르게 조회하는지 확인', () async {
      // Given
      final testAddress = testWalletItem.walletBase.getAddress(0);
      final externalAddress = testExternalWalletItem.walletBase.getAddress(0);
      final prevTx = TransactionMock.createMockTransaction(toAddress: testAddress, amount: 150000);
      final sendTx = TransactionMock.createMockTransaction(
        toAddress: externalAddress,
        amount: 140000,
        inputTransactionHash: prevTx.transactionHash,
      );

      // Given - Mock 동작 설정
      when(electrumService.getTransaction(sendTx.transactionHash)).thenAnswer((_) async => sendTx.serialize());
      when(
        electrumService.getPreviousTransactions(any, existingTxList: anyNamed('existingTxList')),
      ).thenAnswer((_) async => [prevTx]);
      when(electrumService.getHistory(AddressType.p2wpkh, testAddress)).thenAnswer(
        (_) async => [
          GetTxHistoryRes(height: 0, txHash: sendTx.transactionHash), // 미확인 트랜잭션
        ],
      );

      // When
      final result = await transactionRecordService.getTransactionRecord(testWalletItem, sendTx.transactionHash);

      // Then
      TransactionRecord? updatedTx;
      if (result.isSuccess) {
        updatedTx = result.value;
      } else {
        fail('❌ result IS FAILED: ${result.error}');
      }

      expect(updatedTx.transactionHash, sendTx.transactionHash);
      expect(updatedTx.blockHeight, 0);
      expect(updatedTx.transactionType, TransactionType.sent);
      expect(updatedTx.amount, -150000);

      verify(electrumService.getTransaction(sendTx.transactionHash)).called(1);
      verify(electrumService.getPreviousTransactions(any, existingTxList: anyNamed('existingTxList'))).called(1);
      verify(electrumService.getHistory(AddressType.p2wpkh, testAddress)).called(1);
    });

    test('히스토리에서 트랜잭션을 찾을 수 없는 경우 언컨펌으로 처리', () async {
      // Given
      final testAddress = testWalletItem.walletBase.getAddress(0);
      final externalAddress = testExternalWalletItem.walletBase.getAddress(0);
      final prevTx = TransactionMock.createMockTransaction(toAddress: externalAddress, amount: 1000000);
      final tx = TransactionMock.createMockTransaction(
        toAddress: testAddress,
        amount: 500000,
        inputTransactionHash: prevTx.transactionHash,
      );

      // Given - Mock 동작 설정 - 히스토리에서 해당 트랜잭션을 찾을 수 없음
      when(electrumService.getTransaction(tx.transactionHash)).thenAnswer((_) async => tx.serialize());
      when(
        electrumService.getPreviousTransactions(any, existingTxList: anyNamed('existingTxList')),
      ).thenAnswer((_) async => [prevTx]);
      when(electrumService.getHistory(AddressType.p2wpkh, testAddress)).thenAnswer((_) async => []); // 빈 히스토리

      // When
      final result = await transactionRecordService.getTransactionRecord(testWalletItem, tx.transactionHash);

      TransactionRecord? updatedTx;
      if (result.isSuccess) {
        updatedTx = result.value;
      } else {
        fail('❌ result IS FAILED: ${result.error}');
      }

      // Then
      expect(updatedTx.transactionHash, tx.transactionHash);
      expect(updatedTx.blockHeight, 0);
      expect(updatedTx.transactionType, TransactionType.received);

      verify(electrumService.getTransaction(tx.transactionHash)).called(1);
      verify(electrumService.getPreviousTransactions(any, existingTxList: anyNamed('existingTxList'))).called(1);
      verify(electrumService.getHistory(AddressType.p2wpkh, testAddress)).called(1);
    });
  });

  // M01: 주소 없는 출력(OP_RETURN·P2PK 등)은 주소를 비우되 금액은 남긴다. 값이 있으면 밖으로 나간 돈이고 수수료가 아니다
  test('Script 출력은 주소 없이 금액을 남기고 수수료 계산에서도 뺀다', () {
    final testAddress = testWalletItem.walletBase.getAddress(0);
    final prev = TransactionMock.createMockTransaction(toAddress: testAddress, amount: 100000);
    // ScriptPublicKey.parse는 길이(varint)가 앞에 붙은 스크립트를 받는다
    TransactionOutput script(int amount, String hex) =>
        TransactionOutput(Converter.intToLittleEndianBytes(amount, 8), ScriptPublicKey.parse(hex));
    final tx = Transaction.withInputsAndOutputs(
      [TransactionInput.forPayment(prev.transactionHash, 0)],
      [
        script(90000, '2321${'02${'11' * 32}'}ac'), // P2PK
        script(0, '066a04deadbeef'), // OP_RETURN
        TransactionOutput.forPayment(9000, testAddress),
      ],
      AddressType.p2wpkh,
    );

    final details = transactionRecordService.processTransactionDetails(tx, [prev], testWalletId);

    expect(details.outputAddressList.map((o) => (o.address, o.amount)), [('', 90000), ('', 0), (testAddress, 9000)]);
    expect(details.fee, 1000);
    expect(details.amount, -91000);
    expect(details.txType, TransactionType.sent);
  });

  // M01: 파싱·기록부터 수집기·감지기까지 한 번에. 같은 지갑 거스름 + 금액 있는 Script 출력은 사건, 0원 OP_RETURN은 아니다
  test('값 있는 Script 출력과 같은 지갑 거스름이 섞인 출금은 사건이 되고, 0원 OP_RETURN은 무시된다', () {
    final own = testWalletItem.walletBase.getAddress(0);
    final prev = TransactionMock.createMockTransaction(toAddress: own, amount: 100000);
    final pubkey = '02${'11' * 32}';
    final names = <String, String>{};
    final records = [
      for (final (name, amount, script) in [
        ('opReturnZero', 0, '066a04deadbeef'),
        ('p2pk', 90000, '2321${pubkey}ac'),
        ('bareMultisig', 90000, '255121${pubkey}51ae'),
        ('opReturnValued', 90000, '066a04deadbeef'),
      ])
        () {
          final tx = Transaction.withInputsAndOutputs(
            [TransactionInput.forPayment(prev.transactionHash, 0)],
            [
              TransactionOutput(Converter.intToLittleEndianBytes(amount, 8), ScriptPublicKey.parse(script)),
              TransactionOutput.forPayment(9000, own),
            ],
            AddressType.p2wpkh,
          );
          names[tx.transactionHash] = name;
          final d = transactionRecordService.processTransactionDetails(tx, [prev], testWalletId);
          return TransactionRecord.fromTransactions(
            transactionHash: tx.transactionHash,
            timestamp: DateTime(2026),
            blockHeight: 0,
            inputAddressList: d.inputAddressList,
            outputAddressList: d.outputAddressList,
            transactionType: d.txType,
            amount: d.amount,
            fee: d.fee,
            vSize: tx.getVirtualByte(),
          );
        }(),
    ];
    final wallets =
        SafetyWalletsFake([safetyWallet(id: testWalletId)])
          ..records[testWalletId] = records
          ..addressOwners[own] = testWalletId;
    final node = SafetyNodeFake();
    final auth = SafetyAuthFake();
    final connectivity = SafetyConnectivityFake();
    addTearDown(() {
      wallets.dispose();
      node.dispose();
      auth.dispose();
      connectivity.dispose();
    });
    final inputs = SafetyInputsCollector(
      walletProvider: wallets,
      nodeProvider: node,
      authProvider: auth,
      connectivityProvider: connectivity,
      realmManager: realmManager,
    ).collect(
      state: SafetyState(baselines: {testWalletId: WalletBaseline(height: 99, at: DateTime(2026))}),
      now: DateTime(2026),
    );

    expect(IncidentDetector.detect(inputs).created.map((i) => names[i.txid]), [
      'p2pk',
      'bareMultisig',
      'opReturnValued',
    ]);
  });

  // M01 R2-B1(업그레이드): 1.1 이하는 주소 없는 출력을 ('', 0)으로 저장했고 그 금액을 수수료로 셌다. 재조회도 저장된 출력·수수료를
  // 고치지 않는다. 이런 최근 출금(P2PK + 같은 지갑 거스름)이 첫 기준점의 검토 목록에서 빠지면 안 된다
  for (final height in [0, 100]) {
    test('1.1이 저장한 (\'\', 0) P2PK 출금은 첫 기준점 검토에 남는다(저장 높이 $height)', () async {
      final own = testWalletItem.walletBase.getAddress(0);
      final prev = TransactionMock.createMockTransaction(toAddress: own, amount: 100000);
      final tx = Transaction.withInputsAndOutputs(
        [TransactionInput.forPayment(prev.transactionHash, 0)],
        [
          TransactionOutput.forPayment(9000, own),
          TransactionOutput(
            Converter.intToLittleEndianBytes(90000, 8),
            ScriptPublicKey.parse('2321${'02${'11' * 32}'}ac'),
          ),
        ],
        AddressType.p2wpkh,
      );
      final d = transactionRecordService.processTransactionDetails(tx, [prev], testWalletId);
      expect(d.outputAddressList.last.amount, 90000);
      TransactionRecord record(List<TransactionAddress> outputs, int fee, int blockHeight) =>
          TransactionRecord.fromTransactions(
            transactionHash: tx.transactionHash,
            timestamp: DateTime(2026, 11, 10, 10),
            blockHeight: blockHeight,
            inputAddressList: d.inputAddressList,
            outputAddressList: outputs,
            transactionType: d.txType,
            amount: d.amount,
            fee: fee,
            vSize: tx.getVirtualByte(),
          );
      final repository = TransactionRepository(realmManager);
      // v1.1.0 transaction_record_service.dart:116-118의 모양: ('', 0), 그 금액 90,000은 수수료로 셈
      await repository.addAllTransactions(testWalletId, [
        record([d.outputAddressList.first, TransactionAddress('', 0)], d.fee + 90000, height),
      ]);
      // 지금 파서로 다시 받아 확정으로 저장해도 출력·수수료는 그대로다
      await repository.addAllTransactions(testWalletId, [record(d.outputAddressList, d.fee, 100)]);
      final stored = repository.getTransactionRecordList(testWalletId).single;
      expect((stored.blockHeight, stored.outputAddressList.last.amount, stored.fee), (100, 0, 91000));

      final wallets =
          SafetyWalletsFake([safetyWallet(id: testWalletId)])
            ..records[testWalletId] = [stored]
            ..addressOwners[own] = testWalletId;
      final node = SafetyNodeFake();
      final auth = SafetyAuthFake();
      final connectivity = SafetyConnectivityFake();
      addTearDown(() {
        wallets.dispose();
        node.dispose();
        auth.dispose();
        connectivity.dispose();
      });
      final collector = SafetyInputsCollector(
        walletProvider: wallets,
        nodeProvider: node,
        authProvider: auth,
        connectivityProvider: connectivity,
        realmManager: realmManager,
      );
      final now = DateTime(2026, 11, 10, 10, 5);
      final delta = IncidentDetector.detect(collector.collect(state: SafetyState.initial(), now: now));
      expect(delta.baselines[testWalletId]!.pendingSentAtBaseline, {tx.transactionHash});
      final report = SafetyEngine.evaluate(collector.collect(state: delta.applyTo(SafetyState.initial()), now: now));
      expect(report.reviewItems.where((c) => c.id == SafetyCheckId.pendingOutgoingAtBaseline).map((c) => c.subjects), [
        [tx.transactionHash],
      ]);
    });
  }

  group('이전 거래 일부 누락', () {
    late Transaction prevA;
    late Transaction prevB;
    late Transaction spendTx;

    setUp(() {
      final testAddress = testWalletItem.walletBase.getAddress(0);
      final externalAddress = testExternalWalletItem.walletBase.getAddress(0);
      prevA = TransactionMock.createMockTransaction(toAddress: testAddress, amount: 60000);
      prevB = TransactionMock.createMockTransaction(
        toAddress: testAddress,
        amount: 40000,
        inputTransactionHash: prevA.transactionHash,
      );
      spendTx = Transaction.withInputsAndOutputs(
        [TransactionInput.forPayment(prevA.transactionHash, 0), TransactionInput.forPayment(prevB.transactionHash, 0)],
        [TransactionOutput.forPayment(99000, externalAddress)],
        AddressType.p2wpkh,
      );
    });

    test('모든 이전 거래가 있으면 입력과 수수료를 그대로 기록한다', () {
      final details = transactionRecordService.processTransactionDetails(spendTx, [prevA, prevB], testWalletId);

      expect(details.inputAddressList, hasLength(2));
      expect(details.fee, 1000);
      expect(details.amount, -100000);
    });

    test('이전 거래가 하나라도 빠지면 입력 없이 수수료 0으로 기록해 거래 상세의 멤풀 보정 대상이 된다', () {
      final details = transactionRecordService.processTransactionDetails(spendTx, [prevA], testWalletId);

      expect(details.inputAddressList, isEmpty);
      expect(details.fee, 0, reason: '출력 합계만 뺀 음수 수수료를 저장하지 않는다');
      expect(
        details.txType,
        TransactionType.received,
        reason: '입력을 모르면 보낸 거래인지 알 수 없음. 거래 상세에서 멤풀 보정 전까지 빨리 받기·보내기를 막는다',
      );
    });
  });
}
