part of 'script_sync_service_test.dart';

/// 검증 헬퍼 클래스
class _ScriptSyncTestVerifier {
  static void verifyInitialState(WalletListItemBase walletItem, int walletId) {
    final beforeWallet = ScriptSyncServiceMock.walletRepository.getWalletBase(walletId);
    expect(beforeWallet.usedReceiveIndex, -1, reason: '사용한 지갑이 없는 경우 usedReceiveIndex 값은 -1이어야 합니다.');
    expect(beforeWallet.usedChangeIndex, -1, reason: '사용한 지갑이 없는 경우 usedChangeIndex 값은 -1이어야 합니다.');

    final beforeTxList = ScriptSyncServiceMock.transactionRepository.getTransactionRecordList(walletId);
    expect(beforeTxList.length, 0);

    final beforeBalance = ScriptSyncServiceMock.walletRepository.getWalletBalance(walletId);
    expect(beforeBalance.total, 0);

    final beforeUtxoList = ScriptSyncServiceMock.utxoRepository.getUtxoStateList(walletId);
    expect(beforeUtxoList.length, 0);
  }

  static Future<void> verifyInitialAddress(WalletListItemBase walletItem) async {
    final beforeAddressList = await ScriptSyncServiceMock.addressRepository.getWalletAddressList(
      walletItem,
      -1,
      1,
      false,
      false,
    );

    expect(beforeAddressList.length, 1, reason: '지갑 추가 시 초기 1개의 주소가 생성되어야 한다.');
    expect(beforeAddressList[0].isUsed, false, reason: '주소가 생성되었지만 사용되지 않은 상태여야 한다.');
  }

  static void verifyTransactionProcessing(int walletId, String txHash) {
    final isCompleted = ScriptSyncServiceMock.scriptCallbackService.areAllTransactionsCompleted(walletId, [txHash]);
    expect(isCompleted, true, reason: '트랜잭션 처리가 완료되어야 한다.');
  }

  static Future<void> verifyAddressUpdate(WalletListItemBase walletItem) async {
    final addressList = await ScriptSyncServiceMock.addressRepository.getWalletAddressList(
      walletItem,
      -1,
      1,
      false,
      false,
    );

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
    expect(ScriptSyncServiceMock.callSubscribeWalletCount, 1, reason: '지갑 인덱스가 갱신되어 다시 지갑 구독을 해야한다.');
  }

  static Future<void> verifyAllPostConditions(_ScriptSyncTestData testData) async {
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
    final walletATxList = ScriptSyncServiceMock.transactionRepository.getTransactionRecordList(testData.walletA.id);
    final walletBTxList = ScriptSyncServiceMock.transactionRepository.getTransactionRecordList(testData.walletB.id);

    expect(walletATxList.length, 0, reason: '초기 상태에서 지갑 A에 트랜잭션이 없어야 합니다.');
    expect(walletBTxList.length, 0, reason: '초기 상태에서 지갑 B에 트랜잭션이 없어야 합니다.');
  }

  static Future<void> verifyInitialTransactionProcessed(_ScriptSyncTestData testData) async {
    // 지갑 B에 초기 트랜잭션(A -> B) 수신 확인
    final walletBTxList = ScriptSyncServiceMock.transactionRepository.getTransactionRecordList(testData.walletB.id);

    expect(walletBTxList.length, 1, reason: 'A -> B 전송 후 지갑 B에 1개의 트랜잭션이 있어야 합니다.');
    expect(walletBTxList[0].transactionHash, testData.mockTx.transactionHash, reason: '초기 트랜잭션 해시가 일치해야 합니다.');

    // 지갑 B 잔액 증가 확인
    final walletBBalance = ScriptSyncServiceMock.walletRepository.getWalletBalance(testData.walletB.id);
    expect(walletBBalance.total, _TestConstants.transactionAmount, reason: '지갑 B 잔액이 초기 전송 금액만큼 증가해야 합니다.');
  }

  static Future<void> verifyCpfpTransactionProcessed(_ScriptSyncTestData testData) async {
    // 지갑 B에  2개의 트랜잭션 (초기 + CPFP)
    final walletBTxList = ScriptSyncServiceMock.transactionRepository.getTransactionRecordList(testData.walletB.id);
    expect(walletBTxList.length, 2, reason: 'CPFP 후 지갑 B에 2개의 트랜잭션이 있어야 합니다.');

    expect(
      walletBTxList[0].transactionHash,
      anyOf(testData.mockTx.transactionHash, testData.cpfpTx!.transactionHash),
      reason: 'CPFP 후 트랜잭션 중 초기 트랜잭션 해시가 일치해야 합니다.',
    );
    expect(
      walletBTxList[1].transactionHash,
      anyOf(testData.mockTx.transactionHash, testData.cpfpTx!.transactionHash),
      reason: 'CPFP 트랜잭션 해시가 일치해야 합니다.',
    );

    final walletBUtxoList = ScriptSyncServiceMock.utxoRepository.getUtxoStateList(testData.walletB.id);
    expect(walletBUtxoList.length, 2, reason: 'CPFP 후 지갑 B에 2개의 UTXO가 있어야 합니다.');

    final walletAUtxoList = ScriptSyncServiceMock.utxoRepository.getUtxoStateList(testData.walletA.id);
    final outgoingUtxos = walletAUtxoList.where((utxo) => utxo.status == UtxoStatus.outgoing);
    expect(walletAUtxoList.length, 1, reason: 'CPFP 후 지갑 A에 1개의 Outgoing UTXO가 있어야 합니다.');
    expect(outgoingUtxos.length, 1, reason: 'A지갑에서는 사용한 UTXO가 Outgoing 상태여야 합니다.');
  }

  static Future<void> verifyRbfProcessedAndCpfpRemoved(_ScriptSyncTestData testData) async {
    // RBF 트랜잭션이 초기 트랜잭션을 대체했는지 확인
    final walletBTxList = ScriptSyncServiceMock.transactionRepository.getTransactionRecordList(testData.walletB.id);

    // 지갑 B에는 RBF 트랜잭션만 남아있어야 함 (초기 트랜잭션은 대체됨)
    final rbfTxExists = walletBTxList.any((tx) => tx.transactionHash == testData.rbfTx!.transactionHash);
    final initialTxExists = walletBTxList.any((tx) => tx.transactionHash == testData.mockTx.transactionHash);

    expect(rbfTxExists, true, reason: 'RBF 트랜잭션이 지갑 B에 존재해야 합니다.');
    expect(initialTxExists, false, reason: '초기 트랜잭션은 RBF로 인해 대체되어야 합니다.');

    final rbfTxRecord =
        ScriptSyncServiceMock.transactionRepository.getTransactionRecord(
          testData.walletA.id,
          testData.rbfTx!.transactionHash,
        )!;
    expect(rbfTxRecord.rbfHistoryList!.length, 2, reason: 'RBF 트랜잭션을 조회하면 RBF 트랜잭션 정보가 2개 존재해야 합니다.');

    // // B 지갑의 CPFP 트랜잭션이 제거되어야 함
    final cpfpTxExists = walletBTxList.any((tx) => tx.transactionHash == testData.cpfpTx!.transactionHash);
    expect(cpfpTxExists, false, reason: 'CPFP 트랜잭션은 부모 트랜잭션(초기 트랜잭션)이 RBF로 대체되면서 제거되어야 합니다.');

    // UTXO 상태도 확인
    final walletBUtxoList = ScriptSyncServiceMock.utxoRepository.getUtxoStateList(testData.walletB.id);
    final cpfpUtxoExists = walletBUtxoList.any((utxo) => utxo.transactionHash == testData.cpfpTx!.transactionHash);
    expect(cpfpUtxoExists, false, reason: 'CPFP 트랜잭션 관련 UTXO도 제거되어야 합니다. ${testData.cpfpTx!.transactionHash}');
  }
}
