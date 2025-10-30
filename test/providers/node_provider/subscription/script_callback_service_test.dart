import 'package:coconut_wallet/model/node/script_status.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/providers/node_provider/subscription/script_callback_service.dart';
import 'package:coconut_wallet/providers/node_provider/subscription/script_callback_util.dart';
import 'package:flutter_test/flutter_test.dart';

// test/mock/wallet_mock.dart 에서 필요한 함수 임포트
import '../../../mock/script_status_mock.dart';
import '../../../mock/wallet_mock.dart';

void main() {
  late ScriptCallbackService scriptCallbackManager;
  late WalletListItemBase testWalletItem;
  late ScriptStatus testScriptStatus1;
  late ScriptStatus testScriptStatus2;

  // 각 테스트 실행 전에 호출되어 필요한 객체들을 초기화합니다.
  setUp(() {
    scriptCallbackManager = ScriptCallbackService();
    testWalletItem = WalletMock.createSingleSigWalletItem(id: 1);
    testScriptStatus1 = ScriptStatusMock.createMockScriptStatus(testWalletItem, 1);
    testScriptStatus2 = ScriptStatusMock.createMockScriptStatus(testWalletItem, 2);
  });

  group('ScriptCallbackManager 클래스', () {
    group('트랜잭션 처리 상태 관리:', () {
      const txHash1 = 'tx_hash_1';
      const txHash2 = 'tx_hash_2';
      late String txHashKey1;

      setUp(() {
        txHashKey1 = getTxHashKey(testWalletItem.id, txHash1);
      });

      test('등록되지 않은 트랜잭션은 처리 가능해야 함', () {
        // When & Then
        expect(scriptCallbackManager.isTransactionProcessable(txHashKey: txHashKey1, isConfirmed: false), isTrue);
      });

      test('최근 등록된 트랜잭션은 처리 불가능해야 함', () {
        // Given
        scriptCallbackManager.registerTransactionProcessing(testWalletItem.id, txHash1, false);

        // When & Then
        expect(
          scriptCallbackManager.isTransactionProcessable(txHashKey: txHashKey1, isConfirmed: false),
          isFalse,
          reason: '방금 등록된 트랜잭션은 처리 불가능해야 합니다.',
        );
      });

      test('트랜잭션이 컨펌 상태로 변경되면 처리 가능해야 함', () {
        // Given
        scriptCallbackManager.registerTransactionProcessing(testWalletItem.id, txHash1, false);

        // When & Then
        // 같은 트랜잭션 키에 대해 확정 상태로 처리 가능 여부를 확인하면 true를 반환해야 합니다.
        expect(
          scriptCallbackManager.isTransactionProcessable(txHashKey: txHashKey1, isConfirmed: true),
          isTrue,
          reason: '확정 상태로 변경되었으므로 처리 가능해야 합니다.',
        );
        // 내부 상태가 confirmed로 변경되었는지 확인 (다음 isProcessable 호출 시 false가 되어야 함)
        expect(
          scriptCallbackManager.isTransactionProcessable(txHashKey: txHashKey1, isConfirmed: true),
          isFalse,
          reason: '상태 변경 후 다시 호출하면 처리 불가능해야 합니다.',
        );
      });

      test('트랜잭션 완료 시 완료 상태로 표시되고 종속성이 제거되어야 함', () async {
        // Given
        final scriptKey1 = getScriptKey(testWalletItem.id, testScriptStatus1.derivationPath);
        bool callback1Called = false;
        Future<void> callback1() async {
          callback1Called = true;
        }

        // 콜백과 종속성 등록
        scriptCallbackManager.registerFetchUtxosCallback(scriptKey1, callback1);
        scriptCallbackManager.registerTransactionProcessing(testWalletItem.id, txHash1, false);
        scriptCallbackManager.registerTransactionProcessing(testWalletItem.id, txHash2, false);
        await scriptCallbackManager.registerTransactionDependency(testWalletItem, testScriptStatus1, [
          txHash1,
          txHash2,
        ]);

        // When
        await scriptCallbackManager.registerTransactionCompletion(testWalletItem.id, {txHash1});

        // Then
        expect(callback1Called, isFalse, reason: 'txHash2가 완료되지 않았으므로 콜백은 아직 호출되지 않아야 합니다.');
        expect(
          scriptCallbackManager.areAllTransactionsCompleted(testWalletItem.id, [txHash1, txHash2]),
          isFalse,
          reason: 'txHash1은 완료되었으나 txHash2가 완료되지 않았으므로 false를 반환해야 합니다.',
        );

        // txHash2 완료 처리
        await scriptCallbackManager.registerTransactionCompletion(testWalletItem.id, {txHash2});

        // 비동기 콜백 완료 대기
        await Future.delayed(Duration.zero);
        expect(callback1Called, isTrue, reason: '모든 종속 트랜잭션이 완료되었으므로 콜백이 호출되어야 합니다.');

        // 두 트랜잭션 모두 완료 상태여야 함
        expect(
          scriptCallbackManager.areAllTransactionsCompleted(testWalletItem.id, [txHash1, txHash2]),
          isTrue,
          reason: 'txHash1과 txHash2 모두 완료 처리되었습니다.',
        );
      });

      test('areAllTransactionsCompleted가 정확한 완료 상태를 반환해야 함', () async {
        // Given
        scriptCallbackManager.registerTransactionProcessing(testWalletItem.id, txHash1, false);
        scriptCallbackManager.registerTransactionProcessing(testWalletItem.id, txHash2, true); // confirmed 상태

        // When & Then
        expect(
          scriptCallbackManager.areAllTransactionsCompleted(testWalletItem.id, [txHash1]),
          isFalse,
          reason: 'txHash1은 아직 완료되지 않았습니다.',
        );
        expect(
          scriptCallbackManager.areAllTransactionsCompleted(testWalletItem.id, [txHash1, txHash2]),
          isFalse,
          reason: '두 트랜잭션 모두 아직 완료되지 않았습니다.',
        );

        // When
        await scriptCallbackManager.registerTransactionCompletion(testWalletItem.id, {txHash1});

        // Then
        expect(
          scriptCallbackManager.areAllTransactionsCompleted(testWalletItem.id, [txHash1]),
          isTrue,
          reason: 'txHash1이 완료되었습니다.',
        );
        expect(
          scriptCallbackManager.areAllTransactionsCompleted(testWalletItem.id, [txHash1, txHash2]),
          isFalse,
          reason: 'txHash2는 아직 완료되지 않았습니다.',
        ); // txHash2는 아직

        // When
        await scriptCallbackManager.registerTransactionCompletion(testWalletItem.id, {txHash2});

        // Then
        expect(
          scriptCallbackManager.areAllTransactionsCompleted(testWalletItem.id, [txHash2]),
          isTrue,
          reason: 'txHash2가 완료되었습니다.',
        );
        expect(
          scriptCallbackManager.areAllTransactionsCompleted(testWalletItem.id, [txHash1, txHash2]),
          isTrue,
          reason: '두 트랜잭션 모두 완료되었습니다.',
        ); // 모두 완료
        expect(
          scriptCallbackManager.areAllTransactionsCompleted(testWalletItem.id, [txHash1, txHash2, 'unknown_tx']),
          isFalse,
          reason: '목록에 존재하지 않는 트랜잭션 해시가 포함되면 false를 반환해야 합니다.',
        );
      });
    });

    group('콜백 및 종속성 관리:', () {
      const txHash1 = 'tx_hash_1';
      const txHash2 = 'tx_hash_2';
      late String scriptKey1;
      late String scriptKey2;

      setUp(() {
        scriptKey1 = getScriptKey(testWalletItem.id, testScriptStatus1.derivationPath);
        scriptKey2 = getScriptKey(testWalletItem.id, testScriptStatus2.derivationPath);
      });

      test('fetchUtxos 콜백을 등록하고 호출할 수 있어야 함', () async {
        // Given
        bool callbackCalled = false;
        Future<void> testCallback() async {
          callbackCalled = true;
        }

        scriptCallbackManager.registerFetchUtxosCallback(scriptKey1, testCallback);

        // When
        await scriptCallbackManager.callFetchUtxosCallback(scriptKey1);

        // Then
        expect(callbackCalled, isTrue, reason: '등록된 콜백은 호출 시 실행되어야 합니다.');
      });

      test('여러 콜백을 등록하면 등록된 콜백 횟수만큼 호출되어야 함', () async {
        // Given
        int callCount = 0;
        Future<void> callback() async {
          callCount++;
        }

        // When
        scriptCallbackManager.registerFetchUtxosCallback(scriptKey1, callback);
        scriptCallbackManager.registerFetchUtxosCallback(scriptKey1, callback);
        scriptCallbackManager.registerFetchUtxosCallback(scriptKey1, callback);

        // Then
        await scriptCallbackManager.callFetchUtxosCallback(scriptKey1);
        expect(callCount, 1, reason: '콜백이 1번 실행되어야 합니다.');
        await scriptCallbackManager.callFetchUtxosCallback(scriptKey1);
        expect(callCount, 2, reason: '콜백이 2번 실행되어야 합니다.');
        await scriptCallbackManager.callFetchUtxosCallback(scriptKey1);
        expect(callCount, 3, reason: '콜백이 3번 실행되어야 합니다.');
        await scriptCallbackManager.callFetchUtxosCallback(scriptKey1);
        expect(callCount, 3, reason: '등록된 횟수만큼만 호출되어야 합니다.');
      });

      test('모든 종속 트랜잭션이 이미 완료된 경우 콜백을 즉시 호출해야 함', () async {
        // Given
        scriptCallbackManager.registerTransactionProcessing(testWalletItem.id, txHash1, false);
        await scriptCallbackManager.registerTransactionCompletion(testWalletItem.id, {txHash1});
        scriptCallbackManager.registerTransactionProcessing(testWalletItem.id, txHash2, false);
        await scriptCallbackManager.registerTransactionCompletion(testWalletItem.id, {txHash2});

        bool callbackCalled = false;
        Future<void> testCallback() async {
          callbackCalled = true;
        }

        scriptCallbackManager.registerFetchUtxosCallback(scriptKey1, testCallback);

        // When
        // 이미 모든 트랜잭션이 완료된 상태에서 종속성 등록 시도
        await scriptCallbackManager.registerTransactionDependency(testWalletItem, testScriptStatus1, [
          txHash1,
          txHash2,
        ]);

        // Then
        expect(callbackCalled, isTrue, reason: '종속성 등록 시점에 모든 트랜잭션이 이미 완료 상태이므로 콜백이 즉시 호출되어야 합니다.');
      });

      test('여러 스크립트에 대한 종속성을 올바르게 처리해야 함', () async {
        // Given
        scriptCallbackManager.registerTransactionProcessing(testWalletItem.id, txHash1, false);
        scriptCallbackManager.registerTransactionProcessing(testWalletItem.id, txHash2, false);
        bool callback1Called = false;
        bool callback2Called = false;
        Future<void> callback1() async {
          callback1Called = true;
        }

        Future<void> callback2() async {
          callback2Called = true;
        }

        scriptCallbackManager.registerFetchUtxosCallback(scriptKey1, callback1);
        scriptCallbackManager.registerFetchUtxosCallback(scriptKey2, callback2);

        // 각 스크립트에 대한 종속성 등록
        // script1 -> txHash1
        // script2 -> txHash1, txHash2
        await scriptCallbackManager.registerTransactionDependency(testWalletItem, testScriptStatus1, [txHash1]);
        await scriptCallbackManager.registerTransactionDependency(testWalletItem, testScriptStatus2, [
          txHash1,
          txHash2,
        ]);

        // When
        // txHash1 완료 처리
        await scriptCallbackManager.registerTransactionCompletion(testWalletItem.id, {txHash1});

        // Then
        await Future.delayed(Duration.zero);
        expect(callback1Called, isTrue, reason: "Callback1은 txHash1 완료 후 호출되어야 합니다.");
        expect(callback2Called, isFalse, reason: "Callback2는 아직 호출되면 안 됩니다.");

        // txHash2 완료 처리
        await scriptCallbackManager.registerTransactionCompletion(testWalletItem.id, {txHash2});

        // script2의 모든 종속성이 해결되었으므로 callback2 호출됨
        await Future.delayed(Duration.zero);
        expect(callback2Called, isTrue, reason: "Callback2는 txHash2 완료 후 호출되어야 합니다.");
      });
    });
  });
}
