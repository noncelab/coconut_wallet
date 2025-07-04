import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/node/subscribe_stream_dto.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/model/wallet/watch_only_wallet.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:coconut_wallet/services/model/response/block_timestamp.dart';
import 'package:coconut_wallet/services/model/response/electrum_response_types.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import '../../../mock/script_sync_service_mock.dart';
import '../../../mock/script_status_mock.dart';
import '../../../mock/transaction_mock.dart';
import '../../../mock/wallet_mock.dart';
import '../../../services/shared_prefs_service_test.mocks.dart';

/// 테스트 상수 정의
class _TestConstants {
  static const int walletId = 1;
  static const int addressIndex = 0;
  static const int blockHeight = 812345;
  static const int transactionAmount = 1000000;
  static const int previousTxAmount = 2000000;
  static const int cpfpFeeAmount = 5000;
  static const int rbfFeeAmount = 10000;
}

/// 테스트 데이터 클래스
class _ScriptSyncTestData {
  final WalletListItemBase walletA;
  final WalletListItemBase walletB;
  final SharedPrefsRepository sharedPrefsRepository;

  // previousWallet에서 A로 전송한 트랜잭션
  final SubscribeScriptStreamDto previousDto;

  // A에서 B로 전송한 트랜잭션 지갑 A의 스트림
  final SubscribeScriptStreamDto dtoA;

  // A에서 B로 전송한 트랜잭션 지갑 B의 스트림
  final SubscribeScriptStreamDto dtoB;

  // A에서 B로 전송한 트랜잭션
  final Transaction mockTx;

  // previousWallet에서 A로 전송한 트랜잭션
  final Transaction previousMockTx;

  // B에서 Self로 전송한 CPFP 트랜잭션
  final Transaction? cpfpTx;

  // A에서 B로 전송한 RBF 트랜잭션
  final Transaction? rbfTx;

  // B에서 Self로 전송한 CPFP 트랜잭션
  final SubscribeScriptStreamDto? cpfpTxDto;

  // 지갑A의 RBF 트랜잭션 스트림
  final SubscribeScriptStreamDto? rbfTxDtoA;

  // 지갑B의 RBF 트랜잭션 스트림
  final SubscribeScriptStreamDto? rbfTxDtoB;

  _ScriptSyncTestData({
    required this.walletA,
    required this.walletB,
    required this.sharedPrefsRepository,
    required this.dtoA,
    required this.dtoB,
    required this.previousDto,
    required this.mockTx,
    required this.previousMockTx,
    this.cpfpTx,
    this.rbfTx,
    this.cpfpTxDto,
    this.rbfTxDtoA,
    this.rbfTxDtoB,
  });

  factory _ScriptSyncTestData.createPreviousTestData(_ScriptSyncTestData defaultData,
      {required Transaction cpfpTx,
      required Transaction rbfTx,
      required SubscribeScriptStreamDto cpfpTxDto,
      required SubscribeScriptStreamDto rbfTxDtoA,
      required SubscribeScriptStreamDto rbfTxDtoB}) {
    return _ScriptSyncTestData(
      walletA: defaultData.walletA,
      walletB: defaultData.walletB,
      sharedPrefsRepository: defaultData.sharedPrefsRepository,
      dtoA: defaultData.dtoA,
      dtoB: defaultData.dtoB,
      previousDto: defaultData.previousDto,
      mockTx: defaultData.mockTx,
      previousMockTx: defaultData.previousMockTx,
      cpfpTx: cpfpTx,
      rbfTx: rbfTx,
      cpfpTxDto: cpfpTxDto,
      rbfTxDtoA: rbfTxDtoA,
      rbfTxDtoB: rbfTxDtoB,
    );
  }
}

/// 테스트 데이터 빌더
class _ScriptSyncTestDataBuilder {
  static _ScriptSyncTestData createDefaultTestData() {
    final walletA = WalletMock.createSingleSigWalletItem(id: _TestConstants.walletId);
    final walletB = WalletMock.createSingleSigWalletItem(
      id: _TestConstants.walletId + 1,
      randomDescriptor: true,
    );

    final sharedPrefsRepository = SharedPrefsRepository()
      ..setSharedPreferencesForTest(MockSharedPreferences());

    final previousScriptStatus = ScriptStatusMock.createMockScriptStatus(
      walletA,
      _TestConstants.addressIndex,
    );

    final previousDto = SubscribeScriptStreamDto(
      walletItem: walletA,
      scriptStatus: previousScriptStatus,
    );

    final scriptStatusA = ScriptStatusMock.createMockScriptStatus(
      walletA,
      _TestConstants.addressIndex,
    );

    final dtoA = SubscribeScriptStreamDto(
      walletItem: walletA,
      scriptStatus: scriptStatusA,
    );

    final scriptStatusB = ScriptStatusMock.createMockScriptStatus(
      walletB,
      _TestConstants.addressIndex,
    );

    final dtoB = SubscribeScriptStreamDto(
      walletItem: walletB,
      scriptStatus: scriptStatusB,
    );

    final previousMockTx = TransactionMock.createMockTransaction(
      toAddress: walletA.walletBase.getAddress(_TestConstants.addressIndex),
      amount: _TestConstants.previousTxAmount,
    );

    final mockTx = TransactionMock.createMockTransaction(
      inputTransactionHash: previousMockTx.transactionHash,
      toAddress: walletB.walletBase.getAddress(_TestConstants.addressIndex),
      amount: _TestConstants.transactionAmount,
    );

    return _ScriptSyncTestData(
      walletA: walletA,
      walletB: walletB,
      sharedPrefsRepository: sharedPrefsRepository,
      dtoA: dtoA,
      dtoB: dtoB,
      previousDto: previousDto,
      mockTx: mockTx,
      previousMockTx: previousMockTx,
    );
  }

  // RBF-CPFP 테스트 데이터 생성
  static _ScriptSyncTestData createRbfCpfpTestData(_ScriptSyncTestData defaultData) {
    // B가 수행하는 CPFP 트랜잭션 (initialTx를 부모로 함)
    final cpfpTx = TransactionMock.createMockTransaction(
      inputTransactionHash: defaultData.mockTx.transactionHash,
      toAddress: defaultData.walletB.walletBase.getAddress(_TestConstants.addressIndex),
      amount: _TestConstants.transactionAmount - _TestConstants.cpfpFeeAmount,
    );

    // A가 수행하는 RBF 트랜잭션 (initialTx를 대체)
    final rbfTx = TransactionMock.createMockTransaction(
      toAddress: defaultData.walletB.walletBase.getAddress(_TestConstants.addressIndex),
      amount: _TestConstants.transactionAmount - _TestConstants.rbfFeeAmount,
    );

    // Script Status DTO들 생성
    final cpfpTxScriptStatus = ScriptStatusMock.createMockScriptStatus(
      defaultData.walletB,
      _TestConstants.addressIndex,
    );
    final cpfpTxDto = SubscribeScriptStreamDto(
      walletItem: defaultData.walletB,
      scriptStatus: cpfpTxScriptStatus,
    );

    final rbfTxScriptStatusA = ScriptStatusMock.createMockScriptStatus(
      defaultData.walletA,
      _TestConstants.addressIndex,
    );
    final rbfTxScriptStatusB = ScriptStatusMock.createMockScriptStatus(
      defaultData.walletB,
      _TestConstants.addressIndex,
    );
    final rbfTxDtoA = SubscribeScriptStreamDto(
      walletItem: defaultData.walletA,
      scriptStatus: rbfTxScriptStatusA,
    );
    final rbfTxDtoB = SubscribeScriptStreamDto(
      walletItem: defaultData.walletB,
      scriptStatus: rbfTxScriptStatusB,
    );

    return _ScriptSyncTestData.createPreviousTestData(
      defaultData,
      cpfpTx: cpfpTx,
      rbfTx: rbfTx,
      cpfpTxDto: cpfpTxDto,
      rbfTxDtoA: rbfTxDtoA,
      rbfTxDtoB: rbfTxDtoB,
    );
  }
}

/// 검증 헬퍼 클래스
class _ScriptSyncTestVerifier {
  static void verifyInitialState(
    WalletListItemBase walletItem,
    int walletId,
  ) {
    final beforeWallet = ScriptSyncServiceMock.walletRepository.getWalletBase(walletId);
    expect(beforeWallet.usedReceiveIndex, -1,
        reason: '사용한 지갑이 없는 경우 usedReceiveIndex 값은 -1이어야 합니다.');
    expect(beforeWallet.usedChangeIndex, -1, reason: '사용한 지갑이 없는 경우 usedChangeIndex 값은 -1이어야 합니다.');

    final beforeTxList =
        ScriptSyncServiceMock.transactionRepository.getTransactionRecordList(walletId);
    expect(beforeTxList.length, 0);

    final beforeBalance = ScriptSyncServiceMock.walletRepository.getWalletBalance(walletId);
    expect(beforeBalance.total, 0);

    final beforeUtxoList = ScriptSyncServiceMock.utxoRepository.getUtxoStateList(walletId);
    expect(beforeUtxoList.length, 0);
  }

  static Future<void> verifyInitialAddress(WalletListItemBase walletItem) async {
    final beforeAddressList = await ScriptSyncServiceMock.addressRepository
        .getWalletAddressList(walletItem, -1, 1, false, false);

    expect(beforeAddressList.length, 1, reason: '지갑 추가 시 초기 1개의 주소가 생성되어야 한다.');
    expect(beforeAddressList[0].isUsed, false, reason: '주소가 생성되었지만 사용되지 않은 상태여야 한다.');
  }

  static void verifyTransactionProcessing(int walletId, String txHash) {
    final isCompleted =
        ScriptSyncServiceMock.scriptCallbackService.areAllTransactionsCompleted(walletId, [txHash]);
    expect(isCompleted, true, reason: '트랜잭션 처리가 완료되어야 한다.');
  }

  static Future<void> verifyAddressUpdate(WalletListItemBase walletItem) async {
    final addressList = await ScriptSyncServiceMock.addressRepository
        .getWalletAddressList(walletItem, -1, 1, false, false);

    expect(addressList.length, 1, reason: '주소 정보가 정확해야 한다.');
    expect(addressList[0].isUsed, true, reason: '주소가 사용되어야 한다.');
  }

  static void verifyBalanceUpdate(int walletId, int expectedAmount) {
    final balance = ScriptSyncServiceMock.walletRepository.getWalletBalance(walletId);
    expect(balance.total, expectedAmount, reason: '지갑 잔액이 증가해야 한다.');
  }

  static void verifyTransactionRecord(int walletId, String expectedTxHash) {
    final txList = ScriptSyncServiceMock.transactionRepository.getTransactionRecordList(walletId);
    expect(txList.length, 1, reason: '트랜잭션 정보가 정확해야 한다.');
    expect(txList[0].transactionHash, expectedTxHash, reason: '트랜잭션 정보가 정확해야 한다.');
  }

  static void verifyUtxoRecord(int walletId, String expectedTxHash) {
    final utxoList = ScriptSyncServiceMock.utxoRepository.getUtxoStateList(walletId);
    expect(utxoList.length, 1, reason: 'UTXO 정보가 정확해야 한다.');
    expect(utxoList[0].transactionHash, expectedTxHash, reason: 'UTXO 정보가 정확해야 한다.');
  }

  static void verifyWalletSubscription() {
    expect(ScriptSyncServiceMock.callSubscribeWalletCount, 1,
        reason: '지갑 인덱스가 갱신되어 다시 지갑 구독을 해야한다.');
  }

  static Future<void> verifyAllPostConditions(
    _ScriptSyncTestData testData,
  ) async {
    verifyTransactionProcessing(_TestConstants.walletId, testData.mockTx.transactionHash);
    await verifyAddressUpdate(testData.walletA);
    verifyBalanceUpdate(_TestConstants.walletId, _TestConstants.transactionAmount);
    verifyTransactionRecord(_TestConstants.walletId, testData.mockTx.transactionHash);
    verifyUtxoRecord(_TestConstants.walletId, testData.mockTx.transactionHash);
    verifyWalletSubscription();
  }

  // RBF-CPFP 테스트용 검증 메소드들
  static void verifyRbfCpfpInitialState(_ScriptSyncTestData testData) {
    // 지갑 A 초기 상태 검증
    final walletABefore = ScriptSyncServiceMock.walletRepository.getWalletBase(testData.walletA.id);
    expect(walletABefore.usedReceiveIndex, -1, reason: '지갑 A 초기 상태에서 usedReceiveIndex는 -1이어야 합니다.');

    // 지갑 B 초기 상태 검증
    final walletBBefore = ScriptSyncServiceMock.walletRepository.getWalletBase(testData.walletB.id);
    expect(walletBBefore.usedReceiveIndex, -1, reason: '지갑 B 초기 상태에서 usedReceiveIndex는 -1이어야 합니다.');

    // 초기 트랜잭션 없음 검증
    final walletATxList =
        ScriptSyncServiceMock.transactionRepository.getTransactionRecordList(testData.walletA.id);
    final walletBTxList =
        ScriptSyncServiceMock.transactionRepository.getTransactionRecordList(testData.walletB.id);

    expect(walletATxList.length, 0, reason: '초기 상태에서 지갑 A에 트랜잭션이 없어야 합니다.');
    expect(walletBTxList.length, 0, reason: '초기 상태에서 지갑 B에 트랜잭션이 없어야 합니다.');
  }

  static Future<void> verifyInitialTransactionProcessed(_ScriptSyncTestData testData) async {
    // 지갑 B에 초기 트랜잭션(A -> B) 수신 확인
    final walletBTxList =
        ScriptSyncServiceMock.transactionRepository.getTransactionRecordList(testData.walletB.id);

    expect(walletBTxList.length, 1, reason: 'A -> B 전송 후 지갑 B에 1개의 트랜잭션이 있어야 합니다.');
    expect(walletBTxList[0].transactionHash, testData.mockTx.transactionHash,
        reason: '초기 트랜잭션 해시가 일치해야 합니다.');

    // 지갑 B 잔액 증가 확인
    final walletBBalance =
        ScriptSyncServiceMock.walletRepository.getWalletBalance(testData.walletB.id);
    expect(walletBBalance.total, _TestConstants.transactionAmount,
        reason: '지갑 B 잔액이 초기 전송 금액만큼 증가해야 합니다.');
  }

  static Future<void> verifyCpfpTransactionProcessed(_ScriptSyncTestData testData) async {
    // 지갑 A에 CPFP 트랜잭션(B -> A) 수신 확인
    final walletATxList =
        ScriptSyncServiceMock.transactionRepository.getTransactionRecordList(testData.walletA.id);

    expect(walletATxList.length, 1, reason: 'CPFP 후 지갑 A에 1개의 트랜잭션이 있어야 합니다.');
    expect(walletATxList[0].transactionHash, testData.cpfpTx!.transactionHash,
        reason: 'CPFP 트랜잭션 해시가 일치해야 합니다.');

    // 지갑 B에는 여전히 2개의 트랜잭션 (초기 + CPFP 지출)
    final walletBTxList =
        ScriptSyncServiceMock.transactionRepository.getTransactionRecordList(testData.walletB.id);
    expect(walletBTxList.length, 2, reason: 'CPFP 후 지갑 B에 2개의 트랜잭션이 있어야 합니다.');
  }

  static Future<void> verifyRbfProcessedAndCpfpRemoved(_ScriptSyncTestData testData) async {
    // RBF 트랜잭션이 초기 트랜잭션을 대체했는지 확인
    final walletBTxList =
        ScriptSyncServiceMock.transactionRepository.getTransactionRecordList(testData.walletB.id);

    // 지갑 B에는 RBF 트랜잭션만 남아있어야 함 (초기 트랜잭션은 대체됨)
    final rbfTxExists =
        walletBTxList.any((tx) => tx.transactionHash == testData.rbfTx!.transactionHash);
    final initialTxExists =
        walletBTxList.any((tx) => tx.transactionHash == testData.mockTx.transactionHash);

    expect(rbfTxExists, true, reason: 'RBF 트랜잭션이 지갑 B에 존재해야 합니다.');
    expect(initialTxExists, false, reason: '초기 트랜잭션은 RBF로 인해 대체되어야 합니다.');

    // 핵심 버그 검증: CPFP 트랜잭션이 제거되어야 함
    final walletATxList =
        ScriptSyncServiceMock.transactionRepository.getTransactionRecordList(testData.walletA.id);

    final cpfpTxExists =
        walletATxList.any((tx) => tx.transactionHash == testData.cpfpTx!.transactionHash);
    expect(cpfpTxExists, false,
        reason: 'CPFP 트랜잭션은 부모 트랜잭션(초기 트랜잭션)이 RBF로 대체되면서 제거되어야 합니다. 이것이 수정되어야 할 버그입니다.');

    // UTXO 상태도 확인
    final walletAUtxoList =
        ScriptSyncServiceMock.utxoRepository.getUtxoStateList(testData.walletA.id);
    final cpfpUtxoExists =
        walletAUtxoList.any((utxo) => utxo.transactionHash == testData.cpfpTx!.transactionHash);
    expect(cpfpUtxoExists, false, reason: 'CPFP 트랜잭션 관련 UTXO도 제거되어야 합니다.');
  }
}

/// 테스트 셋업 헬퍼 클래스
class _ScriptSyncTestSetup {
  static void setupNetworkAndSharedPrefs(_ScriptSyncTestData testData) {
    int callCount = 0;
    when(testData.sharedPrefsRepository.getInt('nextId')).thenAnswer((_) {
      callCount++;
      return testData.walletA.id + callCount - 1; // 첫 번째 호출에서 walletAId, 두 번째에서 walletBId
    });
    when(testData.sharedPrefsRepository.setInt('nextId', testData.walletA.id + 1))
        .thenAnswer((_) async => true);
    when(testData.sharedPrefsRepository.setInt('nextId', testData.walletB.id + 1))
        .thenAnswer((_) async => true);
  }

  static Future<void> setupLocalDatabase(_ScriptSyncTestData testData) async {
    await ScriptSyncServiceMock.walletRepository.addSinglesigWallet(
      WatchOnlyWallet(
        testData.walletA.name,
        testData.walletA.colorIndex,
        testData.walletA.iconIndex,
        testData.walletA.descriptor,
        null,
        null,
        WalletImportSource.coconutVault.name,
      ),
    );
    await ScriptSyncServiceMock.walletRepository.addSinglesigWallet(
      WatchOnlyWallet(
        testData.walletB.name,
        testData.walletB.colorIndex,
        testData.walletB.iconIndex,
        testData.walletB.descriptor,
        null,
        null,
        WalletImportSource.coconutVault.name,
      ),
    );

    await ScriptSyncServiceMock.addressRepository
        .ensureAddressesInit(walletItemBase: testData.walletA);
    await ScriptSyncServiceMock.addressRepository
        .ensureAddressesInit(walletItemBase: testData.walletB);
  }

  static void setupMockElectrumService(_ScriptSyncTestData testData) {
    final electrumService = ScriptSyncServiceMock.electrumService;

    when(electrumService.getHistory(any, any)).thenAnswer(
      (_) async => [
        GetTxHistoryRes(
          height: _TestConstants.blockHeight,
          txHash: testData.mockTx.transactionHash,
        )
      ],
    );

    when(electrumService.getTransaction(testData.mockTx.transactionHash))
        .thenAnswer((_) async => testData.mockTx.serialize());

    when(electrumService.getBalance(any, any)).thenAnswer(
      (_) async => GetBalanceRes(
        confirmed: _TestConstants.transactionAmount,
        unconfirmed: 0,
      ),
    );

    when(electrumService.fetchBlocksByHeight({_TestConstants.blockHeight})).thenAnswer((_) async =>
        {_TestConstants.blockHeight: BlockTimestamp(_TestConstants.blockHeight, DateTime.now())});

    when(electrumService.getUnspentList(any, any)).thenAnswer((_) async {
      return [
        ListUnspentRes(
          height: _TestConstants.blockHeight,
          txHash: testData.mockTx.transactionHash,
          txPos: 0,
          value: _TestConstants.transactionAmount,
        ),
      ];
    });

    when(electrumService.getPreviousTransactions(
      any,
      existingTxList: anyNamed('existingTxList'),
    )).thenAnswer((_) async => [testData.previousMockTx]);
  }

  static Future<void> setupCompleteTestEnvironment(_ScriptSyncTestData testData) async {
    setupNetworkAndSharedPrefs(testData);
    await setupLocalDatabase(testData);
    setupMockElectrumService(testData);
  }

  // RBF-CPFP 테스트용 셋업
  static Future<void> setupRbfCpfpTestEnvironment1(_ScriptSyncTestData testData) async {
    setupNetworkAndSharedPrefs(testData);
    await setupLocalDatabase(testData);
    final electrumService = ScriptSyncServiceMock.electrumService;

    // 모든 트랜잭션에 대한 모킹
    when(electrumService.getTransaction(testData.mockTx.transactionHash))
        .thenAnswer((_) async => testData.mockTx.serialize());
    if (testData.cpfpTx != null) {
      when(electrumService.getTransaction(testData.cpfpTx!.transactionHash))
          .thenAnswer((_) async => testData.cpfpTx!.serialize());
    }
    if (testData.rbfTx != null) {
      when(electrumService.getTransaction(testData.rbfTx!.transactionHash))
          .thenAnswer((_) async => testData.rbfTx!.serialize());
    }

    // 기본 응답 설정
    when(electrumService.getHistory(any, any)).thenAnswer((_) async => []);
    when(electrumService.getBalance(any, any)).thenAnswer(
      (_) async => GetBalanceRes(confirmed: 0, unconfirmed: 0),
    );
    when(electrumService.fetchBlocksByHeight(any)).thenAnswer((_) async => {
          _TestConstants.blockHeight - 1:
              BlockTimestamp(_TestConstants.blockHeight - 1, DateTime.now())
        });
    when(electrumService.fetchBlocksByHeight(any)).thenAnswer((_) async =>
        {_TestConstants.blockHeight: BlockTimestamp(_TestConstants.blockHeight, DateTime.now())});
    when(electrumService.fetchBlocksByHeight(any)).thenAnswer((_) async => {
          _TestConstants.blockHeight + 1:
              BlockTimestamp(_TestConstants.blockHeight + 1, DateTime.now())
        });
    when(electrumService.getUnspentList(any, any)).thenAnswer((_) async => []);
    when(electrumService.getPreviousTransactions(
      any,
      existingTxList: anyNamed('existingTxList'),
    )).thenAnswer((_) async => []);

    final addressA = testData.walletA.walletBase.getAddress(_TestConstants.addressIndex);
    final addressB = testData.walletB.walletBase.getAddress(_TestConstants.addressIndex);
    final txHistoryRes = GetTxHistoryRes(
      height: _TestConstants.blockHeight,
      txHash: testData.mockTx.transactionHash,
    );

    when(electrumService.getBalance(any, addressB)).thenAnswer(
      (_) async => GetBalanceRes(confirmed: _TestConstants.transactionAmount, unconfirmed: 0),
    );
    when(electrumService.getHistory(any, addressA)).thenAnswer((_) async => [txHistoryRes]);
    when(electrumService.getHistory(any, addressB)).thenAnswer((_) async => [txHistoryRes]);

    when(electrumService.getUnspentList(any, addressB)).thenAnswer((_) async => [
          ListUnspentRes(
            height: _TestConstants.blockHeight,
            txHash: testData.mockTx.transactionHash,
            txPos: 0,
            value: _TestConstants.transactionAmount,
          ),
        ]);
  }
}

void main() {
  group('ScriptEventHandler 테스트', () {
    setUp(() {
      ScriptSyncServiceMock.init();
    });

    test('handleScriptStatusChanged 정상 동작 테스트', () async {
      // Given
      final testData = _ScriptSyncTestDataBuilder.createDefaultTestData();
      await _ScriptSyncTestSetup.setupCompleteTestEnvironment(testData);

      final scriptSyncService = ScriptSyncServiceMock.createMockScriptSyncService();
      scriptSyncService.subscribeWallet = ScriptSyncServiceMock.subscribeWallet;

      // 초기 상태 검증
      _ScriptSyncTestVerifier.verifyInitialState(testData.walletA, _TestConstants.walletId);
      await _ScriptSyncTestVerifier.verifyInitialAddress(testData.walletA);

      // When
      await scriptSyncService.syncScriptStatus(testData.dtoA);

      // Then
      await _ScriptSyncTestVerifier.verifyAllPostConditions(testData);
    });

    test('handleScriptStatusChanged 중복 실행 테스트', () async {
      // Given
      final testData = _ScriptSyncTestDataBuilder.createDefaultTestData();
      await _ScriptSyncTestSetup.setupCompleteTestEnvironment(testData);

      final scriptSyncService = ScriptSyncServiceMock.createMockScriptSyncService();
      scriptSyncService.subscribeWallet = ScriptSyncServiceMock.subscribeWallet;

      // 초기 상태 검증
      _ScriptSyncTestVerifier.verifyInitialState(testData.walletA, _TestConstants.walletId);
      await _ScriptSyncTestVerifier.verifyInitialAddress(testData.walletA);

      // When - 동시에 두 번 실행
      await Future.wait([
        scriptSyncService.syncScriptStatus(testData.dtoA),
        scriptSyncService.syncScriptStatus(testData.dtoA),
      ]);

      // Then
      await _ScriptSyncTestVerifier.verifyAllPostConditions(testData);
    });

    group('RBF-CPFP 테스트', () {
      setUp(() {
        // 완전히 새로운 초기화
        ScriptSyncServiceMock.init();
      });

      test('CPFP 후 조상 트랜잭션 RBF 수행 시 CPFP 트랜잭션이 제거되어야 함', () async {
        // Given
        final defaultData = _ScriptSyncTestDataBuilder.createDefaultTestData();
        final testData = _ScriptSyncTestDataBuilder.createRbfCpfpTestData(defaultData);
        await _ScriptSyncTestSetup.setupRbfCpfpTestEnvironment1(testData);

        final scriptSyncService = ScriptSyncServiceMock.createMockScriptSyncService();
        scriptSyncService.subscribeWallet = ScriptSyncServiceMock.subscribeWallet;

        // 초기 상태 검증
        _ScriptSyncTestVerifier.verifyRbfCpfpInitialState(testData);

        // When & Then - 1단계: A -> B 전송 트랜잭션 처리
        await scriptSyncService.syncScriptStatus(testData.dtoA);
        await scriptSyncService.syncScriptStatus(testData.dtoB);
        await _ScriptSyncTestVerifier.verifyInitialTransactionProcessed(testData);

        // When & Then - 2단계: B가 CPFP 수행
        await scriptSyncService.syncScriptStatus(testData.cpfpTxDto!);
        await _ScriptSyncTestVerifier.verifyCpfpTransactionProcessed(testData);

        // When & Then - 3단계: A가 RBF 수행 (핵심 버그 검증)
        await scriptSyncService.syncScriptStatus(testData.rbfTxDtoA!);
        await scriptSyncService.syncScriptStatus(testData.rbfTxDtoB!);
        await _ScriptSyncTestVerifier.verifyRbfProcessedAndCpfpRemoved(testData);
      });
    });

    tearDown(() {
      ScriptSyncServiceMock.realmManager?.reset();
      ScriptSyncServiceMock.realmManager?.dispose();
    });
  });
}
