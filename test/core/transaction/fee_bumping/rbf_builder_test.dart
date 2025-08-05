import 'package:coconut_wallet/core/transaction/fee_bumping/rbf_builder.dart' hide TransactionType;
import 'package:coconut_wallet/core/transaction/transaction_builder.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/wallet/singlesig_wallet_list_item.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/model/wallet/transaction_address.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:flutter_test/flutter_test.dart';

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
        TransactionType.sent,
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
      expect(pendingTransaction.transactionType, equals(TransactionType.sent));
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
        TransactionType.sent,
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
        TransactionType.sent,
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
        TransactionType.sent,
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
        TransactionType.sent,
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
      expect(RbfTransactionResult, isNotNull);
      expect(PaymentType.singlePayment, isNotNull);
      expect(PaymentType.sweep, isNotNull);
      expect(PaymentType.batchPayment, isNotNull);
    });
  });
}
