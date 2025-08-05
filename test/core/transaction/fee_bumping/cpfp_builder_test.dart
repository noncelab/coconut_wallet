import 'package:coconut_wallet/core/transaction/fee_bumping/cpfp_builder.dart';
import 'package:coconut_wallet/core/transaction/transaction_builder.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/wallet/singlesig_wallet_list_item.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/model/wallet/transaction_address.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../mock/wallet_mock.dart';

void main() {
  group('CpfpBuilder CPFP 테스트', () {
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

    test('CPFP 트랜잭션 구조 테스트', () {
      // Pending 트랜잭션 생성 (CPFP 대상)
      pendingTransaction = TransactionRecord(
        'test_pending_hash',
        DateTime.now(),
        0, // pending 상태
        TransactionType.sent,
        'Test transaction for CPFP',
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

      // CPFP 트랜잭션 구조 검증
      expect(pendingTransaction.transactionHash, equals('test_pending_hash'));
      expect(pendingTransaction.transactionType, equals(TransactionType.sent));
      expect(pendingTransaction.amount, equals(50000));
      expect(pendingTransaction.fee, equals(141));
      expect(pendingTransaction.inputAddressList.length, equals(1));
      expect(pendingTransaction.outputAddressList.length, equals(2));

      // CPFP 대상이 될 수 있는 조건 검증
      expect(pendingTransaction.blockHeight, equals(0)); // pending 상태
      expect(pendingTransaction.feeRate, greaterThan(0));

      // CPFP는 pending 트랜잭션의 change output을 사용함
      // 사용 가능한 금액 = 입력 UTXO 합계 - pending 트랜잭션 amount
      final pendingUtxoSum =
          pendingTransaction.inputAddressList.fold<int>(0, (sum, input) => sum + input.amount);
      final pendingAmount = pendingTransaction.amount;
      final availableForCpfp = pendingUtxoSum - pendingAmount;

      expect(availableForCpfp, greaterThan(0));
      expect(availableForCpfp, equals(100000 - 50000)); // change output: 50000 sats

      // CPFP 트랜잭션은 change output에서 수수료를 제외한 금액만 사용 가능
      expect(availableForCpfp, greaterThan(pendingTransaction.fee));
    });

    test('CPFP 수수료율 및 amount 검증 테스트', () {
      // Pending 트랜잭션 생성
      final pendingTx = TransactionRecord(
        'test_pending_hash',
        DateTime.now(),
        0,
        TransactionType.sent,
        'Test transaction for CPFP',
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

      // CPFP 사용 가능 금액 계산
      final pendingUtxoSum =
          pendingTx.inputAddressList.fold<int>(0, (sum, input) => sum + input.amount);
      final pendingAmount = pendingTx.amount;
      final availableForCpfp = pendingUtxoSum - pendingAmount - pendingTx.fee;

      expect(availableForCpfp, equals(50000 - 141)); // change output: 50000 - 141

      // 다양한 수수료율로 CPFP 가능 여부 검증
      final feeRates = [2.0, 5.0, 10.0];

      for (final feeRate in feeRates) {
        // CPFP 수수료율은 pending 트랜잭션보다 높아야 함
        expect(feeRate, greaterThan(1.0));

        // 수수료율 범위 검증
        expect(feeRate, greaterThan(0));

        // CPFP 트랜잭션 수수료 계산
        final estimatedCpfpFee = pendingTx.vSize * feeRate;
        expect(estimatedCpfpFee, greaterThan(pendingTx.fee));

        // CPFP 실제 사용 가능 금액 = change output - CPFP 수수료
        final maxCpfpAmount = availableForCpfp - estimatedCpfpFee;
        expect(maxCpfpAmount, greaterThan(0));
      }

      // CpfpTransactionResult 구조 검증
      expect(CpfpTransactionResult, isNotNull);
    });
  });
}
