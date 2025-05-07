import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/model/node/subscribe_stream_dto.dart';
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

void main() {
  group('ScriptEventHandler 테스트', () {
    setUp(() {
      ScriptSyncServiceMock.init();
    });
    test('handleScriptStatusChanged 정상 동작 테스트', () async {
      // Given - 상수 및 환경 설정
      const walletId = 1;
      const index = 0;
      const height = 812345;
      const txAmount = 1000000;
      NetworkType.setNetworkType(NetworkType.regtest);

      final walletItem = WalletMock.createSingleSigWalletItem(id: walletId);
      final otherWalletItem =
          WalletMock.createSingleSigWalletItem(id: walletId + 1, randomDescriptor: true);
      final sharedPrefsRepository = SharedPrefsRepository()
        ..setSharedPreferencesForTest(MockSharedPreferences());
      when(sharedPrefsRepository.getInt('nextId')).thenReturn(walletItem.id);
      when(sharedPrefsRepository.setInt('nextId', walletItem.id + 1)).thenAnswer((_) async => true);

      // Given - 테스트에 필요한 의존성 클래스 생성
      final scriptStatus = ScriptStatusMock.createMockScriptStatus(walletItem, index);
      final dto = SubscribeScriptStreamDto(
        walletItem: walletItem,
        scriptStatus: scriptStatus,
      );
      final transactionRepository = ScriptSyncServiceMock.transactionRepository;
      final addressRepository = ScriptSyncServiceMock.addressRepository;
      final walletRepository = ScriptSyncServiceMock.walletRepository;
      final scriptSyncService = ScriptSyncServiceMock.createMockScriptSyncService();
      scriptSyncService.subscribeWallet = ScriptSyncServiceMock.subscribeWallet;
      final utxoRepository = ScriptSyncServiceMock.utxoRepository;
      final previousMockTx = TransactionMock.createMockTransaction(
        toAddress: otherWalletItem.walletBase.getAddress(index),
        amount: txAmount + 1000,
      );
      final mockTx = TransactionMock.createMockTransaction(
        inputTransactionHash: previousMockTx.transactionHash,
        toAddress: walletItem.walletBase.getAddress(index),
        amount: txAmount,
      );

      // Given - 로컬 DB 초기화
      await walletRepository.addSinglesigWallet(WatchOnlyWallet(walletItem.name,
          walletItem.colorIndex, walletItem.iconIndex, walletItem.descriptor, null, null));
      await addressRepository.ensureAddressesInit(walletItemBase: walletItem);

      // Given - ElectrumService만 모킹
      final electrumService = ScriptSyncServiceMock.electrumService;
      when(electrumService.getHistory(any, any)).thenAnswer(
        (_) async => [GetHistoryRes(height: height, txHash: mockTx.transactionHash)],
      );
      when(electrumService.getTransaction(mockTx.transactionHash))
          .thenAnswer((_) async => mockTx.serialize());
      when(electrumService.getBalance(any, any))
          .thenAnswer((_) async => GetBalanceRes(confirmed: txAmount, unconfirmed: 0));
      when(electrumService.fetchBlocksByHeight({height}))
          .thenAnswer((_) async => {height: BlockTimestamp(height, DateTime.now())});
      when(electrumService.getUnspentList(any, any)).thenAnswer((_) async {
        return [
          ListUnspentRes(
            height: height,
            txHash: mockTx.transactionHash,
            txPos: 0,
            value: txAmount,
          ),
        ];
      });
      when(electrumService.getPreviousTransactions(
        any,
        existingTxList: anyNamed('existingTxList'),
      )).thenAnswer((_) async => [
            previousMockTx,
          ]);

      /// Given - 이벤트 실행 전 검증
      final beforeWallet = walletRepository.getWalletBase(walletId);
      expect(beforeWallet.usedReceiveIndex, -1,
          reason: '사용한 지갑이 없는 경우 usedReceiveIndex 값은 -1이어야 합니다.');
      expect(beforeWallet.usedChangeIndex, -1,
          reason: '사용한 지갑이 없는 경우 usedChangeIndex 값은 -1이어야 합니다.');

      final beforeAddressList = addressRepository.getWalletAddressList(walletItem, 0, 1, false);
      expect(beforeAddressList.length, 1, reason: '지갑 추가 시 초기 1개의 주소가 생성되어야 한다.');
      expect(beforeAddressList[0].isUsed, false, reason: '주소가 생성되었지만 사용되지 않은 상태여야 한다.');

      final beforeTxList = transactionRepository.getTransactionRecordList(walletId);
      expect(beforeTxList.length, 0);

      final beforeBalance = walletRepository.getWalletBalance(walletId);
      expect(beforeBalance.total, 0);

      final beforeUtxoList = utxoRepository.getUtxoStateList(walletId);
      expect(beforeUtxoList.length, 0);

      /// When - 이벤트 실행
      await scriptSyncService.syncScriptStatus(dto);

      /// Then - 이벤트 실행 후 검증
      // 검증 - 1. Callback
      final isCompleted = ScriptSyncServiceMock.scriptCallbackService.areAllTransactionsCompleted(
        walletId,
        [mockTx.transactionHash],
      );
      expect(isCompleted, true, reason: '트랜잭션 처리가 완료되어야 한다.');

      // 검증 - 2. Address
      final addressList = addressRepository.getWalletAddressList(walletItem, 0, 1, false);
      expect(addressList.length, 1, reason: '주소 정보가 정확해야 한다.');
      expect(addressList[0].isUsed, true, reason: '주소가 사용되어야 한다.');

      // 검증 - 3. Balance
      final balance = walletRepository.getWalletBalance(walletItem.id);
      expect(balance.total, txAmount, reason: '지갑 잔액이 증가해야 한다.');

      // 검증 - 4. Transaction
      final txList = transactionRepository.getTransactionRecordList(walletId);
      expect(txList.length, 1, reason: '트랜잭션 정보가 정확해야 한다.');
      expect(txList[0].transactionHash, mockTx.transactionHash, reason: '트랜잭션 정보가 정확해야 한다.');

      // 검증 - 5. Utxo
      final utxoList = utxoRepository.getUtxoStateList(walletId);
      expect(utxoList.length, 1, reason: 'UTXO 정보가 정확해야 한다.');
      expect(utxoList[0].transactionHash, mockTx.transactionHash, reason: 'UTXO 정보가 정확해야 한다.');

      // 검증 - 6. 주소 사용 인덱스 갱신
      final oldUsedIndex =
          scriptStatus.isChange ? walletItem.changeUsedIndex : walletItem.receiveUsedIndex;
      expect(
        scriptStatus.isChange
            ? walletItem.changeUsedIndex == oldUsedIndex
            : walletItem.receiveUsedIndex == oldUsedIndex,
        true,
      );

      // 검증 - 7. 구독중인 스크립트 목록 갱신
      expect(ScriptSyncServiceMock.callSubscribeWalletCount, 1,
          reason: '지갑 인덱스가 갱신되어 다시 지갑 구독을 해야한다.');
    });

    test('handleScriptStatusChanged 중복 실행 테스트', () async {
      // Given - 상수 및 환경 설정
      const walletId = 1;
      const index = 0;
      const height = 812345;
      const txAmount = 1000000;
      NetworkType.setNetworkType(NetworkType.regtest);

      final walletItem = WalletMock.createSingleSigWalletItem(id: walletId);
      final otherWalletItem =
          WalletMock.createSingleSigWalletItem(id: walletId + 1, randomDescriptor: true);
      final sharedPrefsRepository = SharedPrefsRepository()
        ..setSharedPreferencesForTest(MockSharedPreferences());
      when(sharedPrefsRepository.getInt('nextId')).thenReturn(walletItem.id);
      when(sharedPrefsRepository.setInt('nextId', walletItem.id + 1)).thenAnswer((_) async => true);

      // Given - 테스트에 필요한 의존성 클래스 생성
      final scriptStatus = ScriptStatusMock.createMockScriptStatus(walletItem, index);
      final dto = SubscribeScriptStreamDto(
        walletItem: walletItem,
        scriptStatus: scriptStatus,
      );
      final transactionRepository = ScriptSyncServiceMock.transactionRepository;
      final addressRepository = ScriptSyncServiceMock.addressRepository;
      final walletRepository = ScriptSyncServiceMock.walletRepository;
      final scriptSyncService = ScriptSyncServiceMock.createMockScriptSyncService();
      scriptSyncService.subscribeWallet = ScriptSyncServiceMock.subscribeWallet;
      final utxoRepository = ScriptSyncServiceMock.utxoRepository;
      final previousMockTx = TransactionMock.createMockTransaction(
        toAddress: otherWalletItem.walletBase.getAddress(index),
        amount: txAmount + 1000,
      );
      final mockTx = TransactionMock.createMockTransaction(
        inputTransactionHash: previousMockTx.transactionHash,
        toAddress: walletItem.walletBase.getAddress(index),
        amount: txAmount,
      );

      // Given - 로컬 DB 초기화
      await walletRepository.addSinglesigWallet(WatchOnlyWallet(walletItem.name,
          walletItem.colorIndex, walletItem.iconIndex, walletItem.descriptor, null, null));
      await addressRepository.ensureAddressesInit(walletItemBase: walletItem);

      // Given - ElectrumService만 모킹
      final electrumService = ScriptSyncServiceMock.electrumService;
      when(electrumService.getHistory(any, any)).thenAnswer(
        (_) async => [GetHistoryRes(height: height, txHash: mockTx.transactionHash)],
      );
      when(electrumService.getTransaction(mockTx.transactionHash))
          .thenAnswer((_) async => mockTx.serialize());
      when(electrumService.getBalance(any, any))
          .thenAnswer((_) async => GetBalanceRes(confirmed: txAmount, unconfirmed: 0));
      when(electrumService.fetchBlocksByHeight({height}))
          .thenAnswer((_) async => {height: BlockTimestamp(height, DateTime.now())});
      when(electrumService.getUnspentList(any, any)).thenAnswer((_) async {
        return [
          ListUnspentRes(
            height: height,
            txHash: mockTx.transactionHash,
            txPos: 0,
            value: txAmount,
          ),
        ];
      });
      when(electrumService.getPreviousTransactions(
        any,
        existingTxList: anyNamed('existingTxList'),
      )).thenAnswer((_) async => [
            previousMockTx,
          ]);

      /// When - 이벤트 실행
      await Future.wait([
        scriptSyncService.syncScriptStatus(dto),
        scriptSyncService.syncScriptStatus(dto),
      ]);

      /// Then - 이벤트 실행 후 검증
      // 검증 - 1. Callback
      final isCompleted = ScriptSyncServiceMock.scriptCallbackService.areAllTransactionsCompleted(
        walletId,
        [mockTx.transactionHash],
      );
      expect(isCompleted, true, reason: '트랜잭션 처리가 완료되어야 한다.');

      // 검증 - 2. Address
      final addressList = addressRepository.getWalletAddressList(walletItem, 0, 1, false);
      expect(addressList.length, 1, reason: '주소 정보가 정확해야 한다.');
      expect(addressList[0].isUsed, true, reason: '주소가 사용되어야 한다.');

      // 검증 - 3. Balance
      final balance = walletRepository.getWalletBalance(walletItem.id);
      expect(balance.total, txAmount, reason: '지갑 잔액이 증가해야 한다.');

      // 검증 - 4. Transaction
      final txList = transactionRepository.getTransactionRecordList(walletId);
      expect(txList.length, 1, reason: '트랜잭션 정보가 정확해야 한다.');
      expect(txList[0].transactionHash, mockTx.transactionHash, reason: '트랜잭션 정보가 정확해야 한다.');

      // 검증 - 5. Utxo
      final utxoList = utxoRepository.getUtxoStateList(walletId);
      expect(utxoList.length, 1, reason: 'UTXO 정보가 정확해야 한다.');
      expect(utxoList[0].transactionHash, mockTx.transactionHash, reason: 'UTXO 정보가 정확해야 한다.');

      // 검증 - 6. 주소 사용 인덱스 갱신
      final oldUsedIndex =
          scriptStatus.isChange ? walletItem.changeUsedIndex : walletItem.receiveUsedIndex;
      expect(
        scriptStatus.isChange
            ? walletItem.changeUsedIndex == oldUsedIndex
            : walletItem.receiveUsedIndex == oldUsedIndex,
        true,
      );

      // 검증 - 7. 구독중인 스크립트 목록 갱신
      expect(ScriptSyncServiceMock.callSubscribeWalletCount, 1,
          reason: '지갑 인덱스가 갱신되어 다시 지갑 구독을 해야한다.');
    });
  });
}
