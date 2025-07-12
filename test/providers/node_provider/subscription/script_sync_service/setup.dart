part of 'script_sync_service_test.dart';

/// 테스트 셋업 헬퍼 클래스
class _ScriptSyncTestSetup {
  static void setupNetworkAndSharedPrefs(_ScriptSyncTestData testData) {
    int callCount = 0;
    when(testData.sharedPrefsRepository.getInt(SharedPrefKeys.kNextIdField)).thenAnswer((_) {
      callCount++;
      return testData.walletA.id + callCount - 1; // 첫 번째 호출에서 walletAId, 두 번째에서 walletBId
    });
    when(testData.sharedPrefsRepository
            .setInt(SharedPrefKeys.kNextIdField, testData.walletA.id + 1))
        .thenAnswer((_) async => true);
    when(testData.sharedPrefsRepository
            .setInt(SharedPrefKeys.kNextIdField, testData.walletB.id + 1))
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
    )).thenAnswer((invocation) async {
      final transaction = invocation.positionalArguments[0] as Transaction;
      final txHash = transaction.transactionHash;

      // 기본 테스트에서는 mockTx에 대해 previousMockTx 반환
      if (txHash == testData.mockTx.transactionHash) {
        return [testData.previousMockTx];
      }
      return [];
    });
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
    ScriptSyncServiceMock.utxoRepository.addAllUtxos(testData.walletA.id, [
      UtxoState(
        transactionHash: testData.previousMockTx.transactionHash,
        index: 0,
        amount: _TestConstants.previousTxAmount,
        derivationPath:
            '${testData.walletA.walletBase.derivationPath}/0/${_TestConstants.addressIndex}',
        blockHeight: _TestConstants.blockHeight - 1,
        timestamp: DateTime.now(),
        to: testData.walletA.walletBase.getAddress(_TestConstants.addressIndex),
      ),
    ]);
    final electrumService = ScriptSyncServiceMock.electrumService;

    when(electrumService.fetchBlocksByHeight(any)).thenAnswer((invocation) async {
      final blockHeights = invocation.positionalArguments[0] as Set<int>;
      final result = <int, BlockTimestamp>{};

      for (final height in blockHeights) {
        result[height] = BlockTimestamp(height, DateTime.now());
      }

      return result;
    });

    // 모든 트랜잭션에 대한 모킹 - transactionHash로 매칭
    when(electrumService.getPreviousTransactions(
      any,
      existingTxList: anyNamed('existingTxList'),
    )).thenAnswer((invocation) async {
      final transaction = invocation.positionalArguments[0] as Transaction;
      final txHash = transaction.transactionHash;

      // 트랜잭션 해시로 구분하여 적절한 응답 반환
      if (txHash == testData.mockTx.transactionHash) {
        return [testData.previousMockTx];
      } else if (testData.cpfpTx != null && txHash == testData.cpfpTx!.transactionHash) {
        return [testData.mockTx];
      } else if (testData.rbfTx != null && txHash == testData.rbfTx!.transactionHash) {
        return [testData.previousMockTx];
      }
      return [];
    });

    // 개별 트랜잭션 직렬화 모킹
    when(electrumService.getTransaction(testData.previousMockTx.transactionHash))
        .thenAnswer((_) async => testData.previousMockTx.serialize());

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
    when(electrumService.getUnspentList(any, any)).thenAnswer((_) async => []);

    // 초기 트랜잭션 추가
    final addressA = testData.walletA.walletBase.getAddress(_TestConstants.addressIndex);
    final addressB = testData.walletB.walletBase.getAddress(_TestConstants.addressIndex);

    final prevTxHistoryRes = GetTxHistoryRes(
      height: _TestConstants.blockHeight - 1,
      txHash: testData.previousMockTx.transactionHash,
    );
    final txHistoryRes = GetTxHistoryRes(
      height: 0,
      txHash: testData.mockTx.transactionHash,
    );

    when(electrumService.getBalance(any, addressB)).thenAnswer(
      (_) async => GetBalanceRes(confirmed: 0, unconfirmed: _TestConstants.transactionAmount),
    );
    when(electrumService.getHistory(any, addressA))
        .thenAnswer((_) async => [prevTxHistoryRes, txHistoryRes]);
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
  }

  static Future<void> setupRbfEnvironment(_ScriptSyncTestData testData) async {
    final electrumService = ScriptSyncServiceMock.electrumService;

    final addressA = testData.walletA.walletBase.getAddress(_TestConstants.addressIndex);
    final addressB = testData.walletB.walletBase.getAddress(_TestConstants.addressIndex);

    final rbfTxHistoryRes = GetTxHistoryRes(
      height: 0,
      txHash: testData.rbfTx!.transactionHash,
    );
    final txHistoryRes = GetTxHistoryRes(
      height: 0,
      txHash: testData.mockTx.transactionHash,
    );

    when(electrumService.getHistory(any, addressA))
        .thenAnswer((_) async => [txHistoryRes, rbfTxHistoryRes]);
    when(electrumService.getHistory(any, addressB)).thenAnswer((_) async => [rbfTxHistoryRes]);

    when(electrumService.getTransaction(testData.rbfTx!.transactionHash))
        .thenAnswer((_) async => testData.rbfTx!.serialize());

    when(electrumService.getBalance(any, addressA)).thenAnswer(
      (_) async => GetBalanceRes(confirmed: 0, unconfirmed: 0),
    );

    final rbfUnspentRes = ListUnspentRes(
      height: 0,
      txHash: testData.rbfTx!.transactionHash,
      txPos: 0,
      value: _TestConstants.transactionAmount - _TestConstants.rbfFeeAmount,
    );

    when(electrumService.getUnspentList(any, addressB)).thenAnswer((_) async => [rbfUnspentRes]);
  }
}
