part of 'script_sync_service_test.dart';

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
        confirmed: 0,
        unconfirmed: _TestConstants.transactionAmount,
      ),
    );

    when(electrumService.fetchBlocksByHeight({_TestConstants.blockHeight})).thenAnswer((_) async =>
        {_TestConstants.blockHeight: BlockTimestamp(_TestConstants.blockHeight, DateTime.now())});

    when(electrumService.getUnspentList(any, any)).thenAnswer((_) async {
      return [
        ListUnspentRes(
          height: 0,
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
  static Future<void> setupRbfCpfpInitialEnvironment(_ScriptSyncTestData testData) async {
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
    when(electrumService.fetchBlocksByHeight({
      _TestConstants.blockHeight - 1,
      _TestConstants.blockHeight,
      _TestConstants.blockHeight + 1
    })).thenAnswer((_) async => {
          _TestConstants.blockHeight - 1:
              BlockTimestamp(_TestConstants.blockHeight - 1, DateTime.now()),
          _TestConstants.blockHeight: BlockTimestamp(_TestConstants.blockHeight, DateTime.now()),
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
      height: 0,
      txHash: testData.mockTx.transactionHash,
    );

    when(electrumService.getBalance(any, addressB)).thenAnswer(
      (_) async => GetBalanceRes(confirmed: _TestConstants.transactionAmount, unconfirmed: 0),
    );
    when(electrumService.getHistory(any, addressA)).thenAnswer((_) async => [txHistoryRes]);
    when(electrumService.getHistory(any, addressB)).thenAnswer((_) async => [txHistoryRes]);

    when(electrumService.getUnspentList(any, addressB)).thenAnswer((_) async => [
          ListUnspentRes(
            height: 0,
            txHash: testData.mockTx.transactionHash,
            txPos: 0,
            value: _TestConstants.transactionAmount,
          ),
        ]);
  }

  static Future<void> setupCpfpEnvironment(_ScriptSyncTestData testData) async {
    final electrumService = ScriptSyncServiceMock.electrumService;

    final addressB = testData.walletB.walletBase.getAddress(_TestConstants.addressIndex);
    final changeAddressB =
        testData.walletB.walletBase.getAddress(_TestConstants.addressIndex, isChange: true);

    final txHistoryRes = GetTxHistoryRes(
      height: 0,
      txHash: testData.mockTx.transactionHash,
    );

    final cpfpTxHistoryRes = GetTxHistoryRes(
      height: 0,
      txHash: testData.cpfpTx!.transactionHash,
    );
    final cpfpUnspentRes = ListUnspentRes(
      height: 0,
      txHash: testData.cpfpTx!.transactionHash,
      txPos: 0,
      value: _TestConstants.transactionAmount - _TestConstants.cpfpFeeAmount,
    );

    when(electrumService.getHistory(any, addressB))
        .thenAnswer((_) async => [txHistoryRes, cpfpTxHistoryRes]);
    when(electrumService.getHistory(any, changeAddressB))
        .thenAnswer((_) async => [cpfpTxHistoryRes]);

    when(electrumService.getTransaction(testData.cpfpTx!.transactionHash))
        .thenAnswer((_) async => testData.cpfpTx!.serialize());

    when(electrumService.getBalance(any, addressB)).thenAnswer(
      (_) async => GetBalanceRes(confirmed: 0, unconfirmed: 0),
    );

    when(electrumService.getBalance(any, changeAddressB)).thenAnswer(
      (_) async => GetBalanceRes(
        confirmed: 0,
        unconfirmed: _TestConstants.transactionAmount - _TestConstants.cpfpFeeAmount,
      ),
    );

    when(electrumService.getUnspentList(any, addressB)).thenAnswer((_) async => []);
    when(electrumService.getUnspentList(any, changeAddressB))
        .thenAnswer((_) async => [cpfpUnspentRes]);

    when(electrumService.getPreviousTransactions(
      any,
      existingTxList: anyNamed('existingTxList'),
    )).thenAnswer((_) async => []);
  }
}
