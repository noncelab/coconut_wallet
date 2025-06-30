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
}

/// 테스트 데이터 클래스
class _ScriptSyncTestData {
  final WalletListItemBase walletItem;
  final WalletListItemBase otherWalletItem;
  final SharedPrefsRepository sharedPrefsRepository;
  final SubscribeScriptStreamDto dto;
  final Transaction mockTx;
  final Transaction previousMockTx;

  _ScriptSyncTestData({
    required this.walletItem,
    required this.otherWalletItem,
    required this.sharedPrefsRepository,
    required this.dto,
    required this.mockTx,
    required this.previousMockTx,
  });
}

/// 테스트 데이터 빌더
class _ScriptSyncTestDataBuilder {
  static _ScriptSyncTestData createDefaultTestData() {
    final walletItem = WalletMock.createSingleSigWalletItem(id: _TestConstants.walletId);
    final otherWalletItem = WalletMock.createSingleSigWalletItem(
      id: _TestConstants.walletId + 1,
      randomDescriptor: true,
    );

    final sharedPrefsRepository = SharedPrefsRepository()
      ..setSharedPreferencesForTest(MockSharedPreferences());

    final scriptStatus = ScriptStatusMock.createMockScriptStatus(
      walletItem,
      _TestConstants.addressIndex,
    );

    final dto = SubscribeScriptStreamDto(
      walletItem: walletItem,
      scriptStatus: scriptStatus,
    );

    final previousMockTx = TransactionMock.createMockTransaction(
      toAddress: otherWalletItem.walletBase.getAddress(_TestConstants.addressIndex),
      amount: _TestConstants.previousTxAmount,
    );

    final mockTx = TransactionMock.createMockTransaction(
      inputTransactionHash: previousMockTx.transactionHash,
      toAddress: walletItem.walletBase.getAddress(_TestConstants.addressIndex),
      amount: _TestConstants.transactionAmount,
    );

    return _ScriptSyncTestData(
      walletItem: walletItem,
      otherWalletItem: otherWalletItem,
      sharedPrefsRepository: sharedPrefsRepository,
      dto: dto,
      mockTx: mockTx,
      previousMockTx: previousMockTx,
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
    await verifyAddressUpdate(testData.walletItem);
    verifyBalanceUpdate(_TestConstants.walletId, _TestConstants.transactionAmount);
    verifyTransactionRecord(_TestConstants.walletId, testData.mockTx.transactionHash);
    verifyUtxoRecord(_TestConstants.walletId, testData.mockTx.transactionHash);
    verifyWalletSubscription();
  }
}

/// 테스트 셋업 헬퍼 클래스
class _ScriptSyncTestSetup {
  static void setupNetworkAndSharedPrefs(_ScriptSyncTestData testData) {
    NetworkType.setNetworkType(NetworkType.regtest);

    when(testData.sharedPrefsRepository.getInt('nextId')).thenReturn(testData.walletItem.id);
    when(testData.sharedPrefsRepository.setInt('nextId', testData.walletItem.id + 1))
        .thenAnswer((_) async => true);
  }

  static Future<void> setupLocalDatabase(_ScriptSyncTestData testData) async {
    await ScriptSyncServiceMock.walletRepository.addSinglesigWallet(
      WatchOnlyWallet(
        testData.walletItem.name,
        testData.walletItem.colorIndex,
        testData.walletItem.iconIndex,
        testData.walletItem.descriptor,
        null,
        null,
        WalletImportSource.coconutVault.name,
      ),
    );

    await ScriptSyncServiceMock.addressRepository
        .ensureAddressesInit(walletItemBase: testData.walletItem);
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
      _ScriptSyncTestVerifier.verifyInitialState(testData.walletItem, _TestConstants.walletId);
      await _ScriptSyncTestVerifier.verifyInitialAddress(testData.walletItem);

      // When
      await scriptSyncService.syncScriptStatus(testData.dto);

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
      _ScriptSyncTestVerifier.verifyInitialState(testData.walletItem, _TestConstants.walletId);
      await _ScriptSyncTestVerifier.verifyInitialAddress(testData.walletItem);

      // When - 동시에 두 번 실행
      await Future.wait([
        scriptSyncService.syncScriptStatus(testData.dto),
        scriptSyncService.syncScriptStatus(testData.dto),
      ]);

      // Then
      await _ScriptSyncTestVerifier.verifyAllPostConditions(testData);
    });
  });
}
