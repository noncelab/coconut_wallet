import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/constants/shared_pref_keys.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/node/subscribe_stream_dto.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/wallet/balance.dart';
import 'package:coconut_wallet/model/wallet/watch_only_wallet.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:coconut_wallet/services/model/response/block_timestamp.dart';
import 'package:coconut_wallet/services/model/response/electrum_response_types.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import '../../../../mock/script_sync_service_mock.dart';
import '../../../../mock/script_status_mock.dart';
import '../../../../mock/wallet_mock.dart';
import '../../../../services/shared_prefs_service_test.mocks.dart';

/// 실제 사용자 리포트 기반 버그 재현 시나리오:
/// 지갑 내 두 주소(receive index0, change index0)의 UTXO를 함께 소비하는 전액 스윕 트랜잭션에서,
/// receive 주소 자신의 구독 이벤트가 네트워크 오류로 잔액 조회에 실패하더라도,
/// change 주소의 구독 이벤트가 같은 트랜잭션에서 co-spent 주소(receive)를 발견해 그 잔액을
/// 강제로 동기화함으로써 지갑 총 잔액이 정확히 반영되는지 검증한다.
void main() {
  const walletId = 900;
  const receiveAmount = 700000;
  const changeAmount = 300000;
  const blockHeight = 850000;

  group('Co-spent 주소 잔액 동기화 테스트', () {
    setUp(() {
      ScriptSyncServiceMock.init();
    });

    tearDown(() {
      ScriptSyncServiceMock.realmManager?.reset();
      ScriptSyncServiceMock.realmManager?.dispose();
    });

    test('한 주소의 잔액 조회가 실패해도 co-spent 주소 잔액 동기화로 지갑 총 잔액과 UTXO가 정확히 반영된다', () async {
      // Given: 지갑을 생성하고, receive(index0)/change(index0) 두 주소가 각각 UTXO를 보유한 상태를 구성한다.
      final wallet = WalletMock.createSingleSigWalletItem(id: walletId, name: 'sweep_wallet');

      final sharedPrefsRepository = SharedPrefsRepository()..setSharedPreferencesForTest(MockSharedPreferences());
      when(sharedPrefsRepository.getInt(SharedPrefKeys.kNextIdField)).thenAnswer((_) => wallet.id);
      when(sharedPrefsRepository.setInt(SharedPrefKeys.kNextIdField, wallet.id + 1)).thenAnswer((_) async => true);

      await ScriptSyncServiceMock.walletRepository.addSinglesigWallet(
        WatchOnlyWallet(
          wallet.name,
          wallet.colorIndex,
          wallet.iconIndex,
          wallet.descriptor,
          null,
          null,
          WalletImportSource.coconutVault.name,
        ),
      );
      await ScriptSyncServiceMock.addressRepository.ensureAddressesInit(walletItemBase: wallet);

      final addressReceive = wallet.walletBase.getAddress(0);
      final addressChange = wallet.walletBase.getAddress(0, isChange: true);
      final externalAddress = wallet.walletBase.getAddress(5);

      final receiveTxHash = List.filled(64, '1').join();
      final changeTxHash = List.filled(64, '2').join();

      // 기존 UTXO 2개 시딩 (receive, change 각각 1개씩)
      await ScriptSyncServiceMock.utxoRepository.addAllUtxos(wallet.id, [
        UtxoState(
          transactionHash: receiveTxHash,
          index: 0,
          amount: receiveAmount,
          derivationPath: '${wallet.walletBase.derivationPath}/0/0',
          blockHeight: blockHeight - 10,
          timestamp: DateTime.now(),
          to: addressReceive,
        ),
        UtxoState(
          transactionHash: changeTxHash,
          index: 0,
          amount: changeAmount,
          derivationPath: '${wallet.walletBase.derivationPath}/1/0',
          blockHeight: blockHeight - 10,
          timestamp: DateTime.now(),
          to: addressChange,
        ),
      ]);

      // 기존 주소별 잔액 및 지갑 총 잔액 시딩
      ScriptSyncServiceMock.addressRepository.updateAddressBalance(
        walletId: wallet.id,
        index: 0,
        isChange: false,
        balance: Balance(receiveAmount, 0),
      );
      ScriptSyncServiceMock.addressRepository.updateAddressBalance(
        walletId: wallet.id,
        index: 0,
        isChange: true,
        balance: Balance(changeAmount, 0),
      );
      ScriptSyncServiceMock.walletRepository.updateWalletBalance(wallet.id, Balance(receiveAmount + changeAmount, 0));

      // 두 UTXO를 모두 input으로 사용하는 sweep transaction
      final sweepTx = Transaction.withInputsAndOutputs(
        [TransactionInput.forPayment(receiveTxHash, 0), TransactionInput.forPayment(changeTxHash, 0)],
        [TransactionOutput.forPayment(receiveAmount + changeAmount - 1000, externalAddress)],
        AddressType.p2wpkh,
      );

      final scriptStatusReceive = ScriptStatusMock.createMockScriptStatus(wallet, 0);
      final scriptStatusChange = ScriptStatusMock.createMockScriptStatus(wallet, 0, isChange: true);
      final dtoReceive = SubscribeScriptStreamDto(walletItem: wallet, scriptStatus: scriptStatusReceive);
      final dtoChange = SubscribeScriptStreamDto(walletItem: wallet, scriptStatus: scriptStatusChange);

      final electrumService = ScriptSyncServiceMock.electrumService;

      when(
        electrumService.getHistory(any, addressReceive),
      ).thenAnswer((_) async => [GetTxHistoryRes(height: blockHeight, txHash: sweepTx.transactionHash)]);
      when(
        electrumService.getHistory(any, addressChange),
      ).thenAnswer((_) async => [GetTxHistoryRes(height: blockHeight, txHash: sweepTx.transactionHash)]);

      when(electrumService.getTransaction(sweepTx.transactionHash)).thenAnswer((_) async => sweepTx.serialize());

      when(
        electrumService.fetchBlocksByHeight({blockHeight}),
      ).thenAnswer((_) async => {blockHeight: BlockTimestamp(blockHeight, DateTime.now())});

      when(electrumService.getUnspentList(any, addressReceive)).thenAnswer((_) async => []);
      when(electrumService.getUnspentList(any, addressChange)).thenAnswer((_) async => []);

      when(
        electrumService.getPreviousTransactions(any, existingTxList: anyNamed('existingTxList')),
      ).thenAnswer((_) async => []);

      // receive 주소의 구독 이벤트에서는 잔액 조회가 실패(네트워크 타임아웃 등)하고,
      // 이후 change 주소 이벤트가 트리거하는 co-spent 잔액 동기화에서는 성공한다.
      var receiveBalanceCallCount = 0;
      when(electrumService.getBalance(any, addressReceive)).thenAnswer((_) async {
        receiveBalanceCallCount++;
        if (receiveBalanceCallCount == 1) {
          throw Exception('simulated electrum timeout');
        }
        return GetBalanceRes(confirmed: 0, unconfirmed: 0);
      });

      when(
        electrumService.getBalance(any, addressChange),
      ).thenAnswer((_) async => GetBalanceRes(confirmed: 0, unconfirmed: 0));

      final scriptSyncService = ScriptSyncServiceMock.createMockScriptSyncService();
      scriptSyncService.subscribeWallet = ScriptSyncServiceMock.subscribeWallet;
      scriptSyncService.unsubscribeAddress = ScriptSyncServiceMock.unsubscribeAddress;

      // When: receive 주소 이벤트가 먼저 처리되며 잔액 조회 실패로 트랜잭션 동기화까지 진행하지 못하고,
      // 이어서 change 주소 이벤트가 처리되며 스윕 트랜잭션을 감지해 UTXO를 삭제하고
      // co-spent 주소(receive)의 잔액을 강제로 동기화한다.
      await scriptSyncService.syncScriptStatus(dtoReceive);
      await scriptSyncService.syncScriptStatus(dtoChange);

      // Then
      final utxoList = ScriptSyncServiceMock.utxoRepository.getUtxoStateList(wallet.id);
      expect(utxoList.length, 0, reason: '스윕 트랜잭션으로 두 주소의 UTXO가 모두 삭제되어야 한다.');

      expect(receiveBalanceCallCount, 2, reason: 'receive 주소는 최초 실패 후 co-spent 동기화로 한 번 더 잔액 조회가 일어나야 한다.');

      final balance = ScriptSyncServiceMock.walletRepository.getWalletBalance(wallet.id);
      expect(balance.total, 0, reason: 'receive 주소의 최초 잔액 조회가 실패했더라도, co-spent 잔액 동기화를 통해 지갑 총 잔액이 0으로 정확히 반영되어야 한다.');

      expect(
        ScriptSyncServiceMock.unsubscribedAddresses,
        containsAll([addressReceive, addressChange]),
        reason: '스윕으로 잔액이 0이 된 두 주소는 모두 dormant 처리되어 구독 해제되어야 한다.',
      );
    });
  });
}
