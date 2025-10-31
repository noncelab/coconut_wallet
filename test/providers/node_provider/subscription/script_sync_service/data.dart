part of 'script_sync_service_test.dart';

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

  // B에서 Self로 전송한 CPFP 트랜잭션 스트림
  final List<SubscribeScriptStreamDto>? cpfpTxDtos;

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
    this.cpfpTxDtos,
    this.rbfTxDtoA,
    this.rbfTxDtoB,
  });

  factory _ScriptSyncTestData.createPreviousTestData(
    _ScriptSyncTestData defaultData, {
    required Transaction cpfpTx,
    required Transaction rbfTx,
    required List<SubscribeScriptStreamDto> cpfpTxDtos,
    required SubscribeScriptStreamDto rbfTxDtoA,
    required SubscribeScriptStreamDto rbfTxDtoB,
  }) {
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
      cpfpTxDtos: cpfpTxDtos,
      rbfTxDtoA: rbfTxDtoA,
      rbfTxDtoB: rbfTxDtoB,
    );
  }
}

/// 테스트 데이터 빌더
class _ScriptSyncTestDataBuilder {
  static _ScriptSyncTestData createDefaultTestData() {
    final walletA = WalletMock.createSingleSigWalletItem(id: _TestConstants.walletId);
    final walletB = WalletMock.createSingleSigWalletItem(id: _TestConstants.walletId + 1, randomDescriptor: true);

    final sharedPrefsRepository = SharedPrefsRepository()..setSharedPreferencesForTest(MockSharedPreferences());

    final previousScriptStatus = ScriptStatusMock.createMockScriptStatus(walletA, _TestConstants.addressIndex);

    final previousDto = SubscribeScriptStreamDto(walletItem: walletA, scriptStatus: previousScriptStatus);

    final scriptStatusA = ScriptStatusMock.createMockScriptStatus(walletA, _TestConstants.addressIndex);

    final dtoA = SubscribeScriptStreamDto(walletItem: walletA, scriptStatus: scriptStatusA);

    final scriptStatusB = ScriptStatusMock.createMockScriptStatus(walletB, _TestConstants.addressIndex);

    final dtoB = SubscribeScriptStreamDto(walletItem: walletB, scriptStatus: scriptStatusB);

    final previousMockTx = TransactionMock.createMockTransaction(
      toAddress: walletA.walletBase.getAddress(_TestConstants.addressIndex),
      amount: _TestConstants.previousTxAmount,
    );

    final mockTx = TransactionMock.createMockTransaction(
      inputTransactionHash: previousMockTx.transactionHash,
      toAddress: walletB.walletBase.getAddress(_TestConstants.addressIndex),
      amount: _TestConstants.transactionAmount,
      change: (
        amount: _TestConstants.changeAmount,
        address: walletA.walletBase.getAddress(_TestConstants.addressIndex, isChange: true),
      ),
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
      inputTransactionHash: defaultData.previousMockTx.transactionHash,
      toAddress: defaultData.walletB.walletBase.getAddress(_TestConstants.addressIndex),
      amount: _TestConstants.transactionAmount,
      change: (
        amount: _TestConstants.changeAmount - _TestConstants.rbfFeeAmount,
        address: defaultData.walletA.walletBase.getAddress(_TestConstants.addressIndex, isChange: true),
      ),
    );

    // Script Status DTO들 생성
    final cpfpTxScriptStatus = ScriptStatusMock.createMockScriptStatus(
      defaultData.walletB,
      _TestConstants.addressIndex,
    );
    final cpfpTxChangeScriptStatus = ScriptStatusMock.createMockScriptStatus(
      defaultData.walletB,
      _TestConstants.addressIndex,
      isChange: true,
    );
    final cpfpTxDto = SubscribeScriptStreamDto(walletItem: defaultData.walletB, scriptStatus: cpfpTxScriptStatus);
    final cpfpTxChangeDto = SubscribeScriptStreamDto(
      walletItem: defaultData.walletB,
      scriptStatus: cpfpTxChangeScriptStatus,
    );

    final rbfTxScriptStatusA = ScriptStatusMock.createMockScriptStatus(
      defaultData.walletA,
      _TestConstants.addressIndex,
    );
    final rbfTxScriptStatusB = ScriptStatusMock.createMockScriptStatus(
      defaultData.walletB,
      _TestConstants.addressIndex,
    );
    final rbfTxDtoA = SubscribeScriptStreamDto(walletItem: defaultData.walletA, scriptStatus: rbfTxScriptStatusA);
    final rbfTxDtoB = SubscribeScriptStreamDto(walletItem: defaultData.walletB, scriptStatus: rbfTxScriptStatusB);

    return _ScriptSyncTestData.createPreviousTestData(
      defaultData,
      cpfpTx: cpfpTx,
      rbfTx: rbfTx,
      cpfpTxDtos: [cpfpTxDto, cpfpTxChangeDto],
      rbfTxDtoA: rbfTxDtoA,
      rbfTxDtoB: rbfTxDtoB,
    );
  }
}
