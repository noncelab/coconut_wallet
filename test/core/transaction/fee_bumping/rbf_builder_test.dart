import 'package:coconut_wallet/core/transaction/fee_bumping/rbf_builder.dart' as Builder;
import 'package:coconut_wallet/core/transaction/transaction_builder.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/wallet/singlesig_wallet_list_item.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/model/wallet/transaction_address.dart';
import 'package:coconut_wallet/enums/network_enums.dart' as NetworkEnums;
import 'package:coconut_wallet/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../mock/transaction_mock.dart';
import '../../../mock/wallet_mock.dart';

void main() {
  group('RbfBuilder RBF 테스트', () {
    // 기본 트랜잭션 생성
    late SinglesigWalletListItem wallet;
    late TransactionBuildResult baseTransaction;
    late List<UtxoState> availableUtxos;
    late Map<String, int> singleRecipient;
    late TransactionRecord pendingTransaction;

    setUp(() {
      wallet = WalletMock.createSingleSigWalletItem();
      availableUtxos = [
        UtxoState(
          transactionHash: 'd77dc64d3eb3454e9c65e5e36989af0eef349d824593dfe2a086fb9dadf7dfc4',
          index: 0,
          amount: 100000, // 0.001 BTC
          blockHeight: 100,
          to: 'bcrt1qh22yl57ys0vaaln9nfp4zczj2fshjnl6gnsh66',
          derivationPath: "m/84'/1'/0'/0/0",
          timestamp: DateTime.now(),
        ),
        UtxoState(
          transactionHash: '577a101d9bddd1ddee0d72a0853a8ca2d8b13d92c63f9a84277152ba791e426a',
          index: 1,
          amount: 200000, // 0.002 BTC
          blockHeight: 101,
          to: 'bcrt1qh22yl57ys0vaaln9nfp4zczj2fshjnl6gnsh66',
          derivationPath: "m/84'/1'/0'/0/1",
          timestamp: DateTime.now(),
        ),
      ];
      singleRecipient = {'bcrt1qh22yl57ys0vaaln9nfp4zczj2fshjnl6gnsh66': 50000};
    });

    test('기본 트랜잭션 생성', () {
      baseTransaction = TransactionBuilder(
        availableUtxos: availableUtxos,
        recipients: singleRecipient,
        feeRate: 1.0,
        changeDerivationPath: "m/84'/1'/0'/0/0",
        walletListItemBase: wallet,
        isFeeSubtractedFromAmount: false,
        isUtxoFixed: false,
      ).build();

      expect(baseTransaction.isSuccess, isTrue);
      expect(baseTransaction.estimatedFee, 141);
      expect(baseTransaction.transaction, isNotNull);
      expect(baseTransaction.selectedUtxos, isNotNull);
      expect(baseTransaction.selectedUtxos!.length, 1);
    });

    test('RBF 트랜잭션 구조 테스트', () {
      // Pending 트랜잭션 생성 (RBF 대상)
      pendingTransaction = TransactionRecord(
        'test_pending_hash',
        DateTime.now(),
        0, // pending 상태
        NetworkEnums.TransactionType.sent,
        'Test transaction for RBF',
        50000,
        141,
        [
          TransactionAddress('bcrt1qh22yl57ys0vaaln9nfp4zczj2fshjnl6gnsh66', 100000),
        ],
        [
          TransactionAddress('bcrt1qh22yl57ys0vaaln9nfp4zczj2fshjnl6gnsh66', 50000),
          TransactionAddress('bcrt1qh22yl57ys0vaaln9nfp4zczj2fshjnl6gnsh66', 49859), // change
        ],
        141.0,
        DateTime.now(),
      );

      // RBF 트랜잭션 구조 검증
      expect(pendingTransaction.transactionHash, equals('test_pending_hash'));
      expect(pendingTransaction.transactionType, equals(NetworkEnums.TransactionType.sent));
      expect(pendingTransaction.amount, equals(50000));
      expect(pendingTransaction.fee, equals(141));
      expect(pendingTransaction.inputAddressList.length, equals(1));
      expect(pendingTransaction.outputAddressList.length, equals(2));

      // RBF 대상이 될 수 있는 조건 검증
      expect(pendingTransaction.blockHeight, equals(0)); // pending 상태
      expect(pendingTransaction.feeRate, greaterThan(0));

      // RBF는 기존 트랜잭션의 입력 UTXO를 재사용
      final pendingUtxoSum =
          pendingTransaction.inputAddressList.fold<int>(0, (sum, input) => sum + input.amount);
      final pendingAmount = pendingTransaction.amount;
      final pendingFee = pendingTransaction.fee;

      expect(pendingUtxoSum, equals(100000)); // 입력 UTXO 합계
      expect(pendingAmount, equals(50000)); // 전송 금액
      expect(pendingFee, equals(141)); // 기존 수수료
    });

    test('RBF PaymentType 판단 테스트', () {
      // 단일 결제 트랜잭션 (1개 입력, 2개 출력: recipient + change)
      final singlePaymentTx = TransactionRecord(
        'single_payment_hash',
        DateTime.now(),
        0,
        NetworkEnums.TransactionType.sent,
        'Single payment transaction',
        50000,
        141,
        [
          TransactionAddress('input_address', 100000),
        ],
        [
          TransactionAddress('recipient_address', 50000),
          TransactionAddress('change_address', 49859),
        ],
        141.0,
        DateTime.now(),
      );

      // 스윕 트랜잭션 (1개 입력, 1개 출력)
      final sweepTx = TransactionRecord(
        'sweep_hash',
        DateTime.now(),
        0,
        NetworkEnums.TransactionType.sent,
        'Sweep transaction',
        99859,
        141,
        [
          TransactionAddress('input_address', 100000),
        ],
        [
          TransactionAddress('recipient_address', 99859),
        ],
        141.0,
        DateTime.now(),
      );

      // 배치 트랜잭션 (1개 입력, 3개 이상 출력)
      final batchTx = TransactionRecord(
        'batch_hash',
        DateTime.now(),
        0,
        NetworkEnums.TransactionType.sent,
        'Batch transaction',
        80000,
        141,
        [
          TransactionAddress('input_address', 100000),
        ],
        [
          TransactionAddress('recipient1_address', 30000),
          TransactionAddress('recipient2_address', 30000),
          TransactionAddress('change_address', 19859),
        ],
        141.0,
        DateTime.now(),
      );

      // 트랜잭션 구조 검증
      expect(singlePaymentTx.outputAddressList.length, equals(2));
      expect(sweepTx.outputAddressList.length, equals(1));
      expect(batchTx.outputAddressList.length, equals(3));
    });

    test('RBF 수수료율 및 amount 검증 테스트', () {
      // Pending 트랜잭션 생성
      final pendingTx = TransactionRecord(
        'test_pending_hash',
        DateTime.now(),
        0,
        NetworkEnums.TransactionType.sent,
        'Test transaction for RBF',
        50000,
        141,
        [
          TransactionAddress('bcrt1qh22yl57ys0vaaln9nfp4zczj2fshjnl6gnsh66', 100000),
        ],
        [
          TransactionAddress('bcrt1qh22yl57ys0vaaln9nfp4zczj2fshjnl6gnsh66', 50000),
          TransactionAddress('bcrt1qh22yl57ys0vaaln9nfp4zczj2fshjnl6gnsh66', 49859),
        ],
        141.0,
        DateTime.now(),
      );

      // RBF amount 계산 검증
      final pendingUtxoSum =
          pendingTx.inputAddressList.fold<int>(0, (sum, input) => sum + input.amount);
      final pendingAmount = pendingTx.amount;
      final pendingFee = pendingTx.fee;

      expect(pendingUtxoSum, equals(100000)); // 입력 UTXO 합계
      expect(pendingAmount, equals(50000)); // 전송 금액
      expect(pendingFee, equals(141)); // 기존 수수료

      // RBF는 기존 트랜잭션의 입력을 재사용하므로 동일한 amount 사용 가능
      expect(pendingUtxoSum, greaterThan(pendingAmount + pendingFee));

      // 다양한 수수료율로 RBF 가능 여부 검증
      final feeRates = [2.0, 5.0, 10.0];

      for (final feeRate in feeRates) {
        // RBF 수수료율은 pending 트랜잭션보다 높아야 함
        expect(feeRate, greaterThan(1.0));

        // 수수료율 범위 검증
        expect(feeRate, greaterThan(0));

        // RBF 트랜잭션 수수료 계산
        final estimatedRbfFee = pendingTx.vSize * feeRate;
        expect(estimatedRbfFee, greaterThan(pendingTx.fee));

        // RBF는 기존 입력을 재사용하므로 더 높은 수수료만 지불하면 됨
        final additionalFee = estimatedRbfFee - pendingTx.fee;
        expect(additionalFee, greaterThan(0));
      }

      // RbfTransactionResult 구조 검증
      expect(Builder.RbfTransactionResult, isNotNull);
      expect(Builder.PaymentType.singlePayment, isNotNull);
      expect(Builder.PaymentType.sweep, isNotNull);
      expect(Builder.PaymentType.batchPayment, isNotNull);
    });

    test('_handleInsufficientInputs - Change가 있는 경우', () async {
      final mockPendingTx = TransactionMock.createConfirmedTransactionRecord(
        transactionHash: baseTransaction.transaction!.transactionHash,
      );

      print('mockPendingTx:::::::::::: ${mockPendingTx.transactionHash}');
      print('baseTransaction:::::::::::: ${baseTransaction.transaction!.transactionHash}');

      // RbfBuilder 생성 (Change가 있는 경우)
      final rbfBuilder = Builder.RbfBuilder(
        (walletId, address, {isChange}) => address == 'change_address', // Change 감지
        (walletId) => TransactionAddress('change_address', 49859),
        (txHash) => Result.success(
            '02000000000101fc063a9b75aad4a651c8cb661c9eff341cf252941a2a9fa8d5bfed2bd0b1f8610100000000ffffffff021027000000000000160014f48bcaba1a880feba362d9f31d05c4efe15a3dd4f0b6f50500000000160014ed4e4e55eb338cf3b2aa99e98264d24f873feda10247304402201f174bfa44dc725a9bf39f1c1696c5acf282bfc57737460b95b9e8ecffcab4a80220509afe7a0ea2f02fe59847ba665d3bc1af82e7e3e48324335d8d4ff715e92be4012102a28fa6fc8dd88a78bf4ddd52325c3be4e3006edf132b7d766139f6eb4df1d77b00000000'),
        (walletId, address) => "m/84'/1'/0'/0/0", // _getDerivationPath
        (walletId, status) =>
            availableUtxos.where((utxo) => utxo.status == status).toList(), // _getUtxosByStatus
        (walletId, utxoId) =>
            availableUtxos.firstWhere((utxo) => utxo.transactionHash == utxoId), // _getUtxoState
        mockPendingTx,
        wallet.id,
        1.0, // feeRate
        wallet,
      );

      // RBF 빌드 실행
      final result = await rbfBuilder.build();

      // RbfBuilder 객체를 통한 검증
      expect(rbfBuilder.insufficientUtxos, isFalse); // UTXO 부족하지 않음
      expect(result, isNotNull); // RBF 결과가 생성됨
      expect(result!.transaction, isNotNull); // 트랜잭션이 생성됨
      expect(result.type, equals(Builder.TransactionType.single)); // 단일 결제 타입
    });
    test('_handleInsufficientInputs - 내 Output이 있는 경우', () {});
    test('_handleInsufficientInputs - Change도 없고 내 Output도 없는 경우', () {});

    test('_handleInsufficientInputsWithChange - Change로 충당 가능한 경우', () {});
    test('_handleInsufficientInputsWithChange - Change로는 부족한 경우', () {});

    test('_handleSufficientChange - 배치 트랜잭션', () {});
    test('_handleSufficientChange - Change = 새 수수료 (스윕)', () {});
    test('_handleSufficientChange - Change > 새 수수료 (더스트 처리)', () {});
    test('_handleSufficientChange - 일반적인 경우 (싱글)', () {});

    test('_handleInsufficientChange - 내 Output이 있는 경우', () {});
    test('_handleInsufficientChange - 내 Output이 없는 경우', () {});

    test('_handleSufficientInputs - 더스트 처리 필요', () {});
    test('_handleSufficientInputs - 스윕 트랜잭션 (Change 없음)', () {});
    test('_handleSufficientInputs - 일반적인 경우 (싱글)', () {});
    test('_handleSufficientInputs - 일반적인 경우 (배치)', () {});

    test('_handleTransactionWithSelfOutputs - 배치 트랜잭션', () {});
    test('_handleTransactionWithSelfOutputs - 단일/스윕 트랜잭션', () {});

    test('_handleBatchTransactionWithSelfOutputs - Self Output 조정 성공', () {});
    test('_handleBatchTransactionWithSelfOutputs - Self Output 조정 후 UTXO 추가 필요', () {});
    test('_handleBatchTransactionWithSelfOutputs - Self Output 조정 실패', () {});

    test('_handleSingleOrSweepWithSelfOutputs - 조정 후 금액이 0 (스윕)', () {});
    test('_handleSingleOrSweepWithSelfOutputs - 조정 후 금액이 양수이고 더스트 이상 (싱글)', () {});
    test('_handleSingleOrSweepWithSelfOutputs - 조정 후 금액이 부족 (UTXO 추가)', () {});
  });
}
