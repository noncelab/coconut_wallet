import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/node/subscribe_stream_dto.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/model/wallet/watch_only_wallet.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:coconut_wallet/services/model/response/block_timestamp.dart';
import 'package:coconut_wallet/services/model/response/electrum_response_types.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import '../../../../mock/script_sync_service_mock.dart';
import '../../../../mock/script_status_mock.dart';
import '../../../../mock/transaction_mock.dart';
import '../../../../mock/wallet_mock.dart';
import '../../../../services/shared_prefs_service_test.mocks.dart';

part 'constants.dart';
part 'data.dart';
part 'verifier.dart';
part 'setup.dart';

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

        final scriptSyncService = ScriptSyncServiceMock.createMockScriptSyncService();
        scriptSyncService.subscribeWallet = ScriptSyncServiceMock.subscribeWallet;

        // Given - 1단계: 초기 상태 설정
        await _ScriptSyncTestSetup.setupRbfCpfpInitialEnvironment(testData);

        // 초기 상태 검증
        _ScriptSyncTestVerifier.verifyRbfCpfpInitialState(testData);

        // When & Then
        await scriptSyncService.syncScriptStatus(testData.dtoA);
        await scriptSyncService.syncScriptStatus(testData.dtoB);
        await _ScriptSyncTestVerifier.verifyInitialTransactionProcessed(testData);

        // Given - 2단계: CPFP 수행
        await _ScriptSyncTestSetup.setupCpfpEnvironment(testData);

        // When & Then
        for (var dto in testData.cpfpTxDtos!) {
          await scriptSyncService.syncScriptStatus(dto);
        }
        await _ScriptSyncTestVerifier.verifyCpfpTransactionProcessed(testData);

        // Given - 3단계: A에서 RBF 수행
        await _ScriptSyncTestSetup.setupRbfEnvironment(testData);

        // When & Then
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
