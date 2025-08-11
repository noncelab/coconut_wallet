import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/core/exceptions/transaction_creation/transaction_creation_exception.dart';
import 'package:coconut_wallet/core/transaction/transaction_builder.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/wallet/multisig_wallet_list_item.dart';
import 'package:coconut_wallet/model/wallet/singlesig_wallet_list_item.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../mock/wallet_mock.dart';

void main() {
  SinglesigWalletListItem wallet = WalletMock.createSingleSigWalletItem();

  /// utxo_selector에서 amount순으로 정렬됨
  late List<UtxoState> availableUtxos = [
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
  int sumOfBalance = availableUtxos.map((utxo) => utxo.amount).reduce((a, b) => a + b);
  Map<String, int> singleRecipient = {'bcrt1qh22yl57ys0vaaln9nfp4zczj2fshjnl6gnsh66': 50000};
  Map<String, int> singleRecipientEdgeBalance = {
    'bcrt1qh22yl57ys0vaaln9nfp4zczj2fshjnl6gnsh66': 199999
  };
  // 다중서명지갑 주소
  Map<String, int> mSingleRecipient = {
    'bcrt1qjz3kf2lx94rt63tancphstvf9pdvv0j5jecp7nn9sx3rzgwzts0q8t5qsd': 50000
  };
  Map<String, int> mSingleRecipientEdgeBalance = {
    'bcrt1qjz3kf2lx94rt63tancphstvf9pdvv0j5jecp7nn9sx3rzgwzts0q8t5qsd': 199999
  };

  Map<String, int> singleRecipientSameBalance = {
    'bcrt1qh22yl57ys0vaaln9nfp4zczj2fshjnl6gnsh66': sumOfBalance,
  };
  Map<String, int> singleRecipientNearBalance = {
    'bcrt1qh22yl57ys0vaaln9nfp4zczj2fshjnl6gnsh66': sumOfBalance - 148,
  };
  const dustThreshold = 294;
  Map<String, int> singleRecipientEdgeBalance2 = {
    'bcrt1qh22yl57ys0vaaln9nfp4zczj2fshjnl6gnsh66': sumOfBalance - dustThreshold,
  };
  Map<String, int> batchRecipients = {
    'bcrt1qve37yvsmqksx93j6gqsnz862qpzfa0xya0yvve': 30000,
    'bcrt1qktkhznpjp6gg7waacvcgxrv3hd6aj8nj90rw8q': 40000,
  };
  int sumOfBatchRecipients = batchRecipients.values.reduce((a, b) => a + b);

  Map<String, int> batchRecipientsSameBalance = {
    'bcrt1qve37yvsmqksx93j6gqsnz862qpzfa0xya0yvve': 150000,
    'bcrt1qktkhznpjp6gg7waacvcgxrv3hd6aj8nj90rw8q': 150000,
  };
  Map<String, int> batchRecipientsOverBalance = {
    'bcrt1qve37yvsmqksx93j6gqsnz862qpzfa0xya0yvve': 150000,
    'bcrt1qktkhznpjp6gg7waacvcgxrv3hd6aj8nj90rw8q': 150000,
    'bcrt1qh22yl57ys0vaaln9nfp4zczj2fshjnl6gnsh66': 1000,
  };
  Map<String, int> batchRecipientsEdgeBalance = {
    'bcrt1qve37yvsmqksx93j6gqsnz862qpzfa0xya0yvve': 150000,
    'bcrt1qktkhznpjp6gg7waacvcgxrv3hd6aj8nj90rw8q': 150000 - dustThreshold,
  };

  NetworkType.setNetworkType(NetworkType.regtest);
  group('싱글시그지갑 - SingleTx - Auto UTXO Selection', () {
    test('Single / Auto Utxo / 수수료 발신자 부담 / availableUtxos가 비어있을 때', () {
      final TransactionBuildResult result = TransactionBuilder(
        availableUtxos: [],
        recipients: singleRecipient,
        feeRate: 1.0,
        changeDerivationPath: "m/84'/1'/0'/0/0",
        walletListItemBase: wallet,
        isFeeSubtractedFromAmount: false,
        isUtxoFixed: false,
      ).build();

      expect(result.isFailure, isTrue);
      expect(result.estimatedFee, isNotNull);
      expect(result.transaction, isNull);
      expect(result.selectedUtxos, isEmpty);
    });

    test('Single / Auto Utxo / 수수료 발신자 부담', () {
      final TransactionBuildResult result = TransactionBuilder(
        availableUtxos: availableUtxos,
        recipients: singleRecipient,
        feeRate: 1.0,
        changeDerivationPath: "m/84'/1'/0'/0/0",
        walletListItemBase: wallet,
        isFeeSubtractedFromAmount: false,
        isUtxoFixed: false,
      ).build();

      expect(result.isSuccess, isTrue);
      expect(result.estimatedFee, 141);
      expect(result.transaction, isNotNull);
      expect(result.selectedUtxos, isNotNull);
      expect(result.selectedUtxos!.length, 1);
    });

    test('Single / Auto Utxo / 수수료 발신자 부담 / 받는 주소가 다중서명지갑 주소', () {
      final TransactionBuildResult result = TransactionBuilder(
        availableUtxos: availableUtxos,
        recipients: mSingleRecipient,
        feeRate: 1.0,
        changeDerivationPath: "m/84'/1'/0'/0/0",
        walletListItemBase: wallet,
        isFeeSubtractedFromAmount: false,
        isUtxoFixed: false,
      ).build();

      expect(result.isSuccess, isTrue);
      expect(result.estimatedFee, 153);
      expect(result.transaction, isNotNull);
      expect(result.selectedUtxos, isNotNull);
      expect(result.selectedUtxos!.length, 1);
    });

    test('Single / Auto Utxo / 수수료 발신자 부담 / 수수료를 고려하여 utxo 선택 후 트랜잭션 생성', () {
      final TransactionBuildResult result = TransactionBuilder(
        availableUtxos: availableUtxos,
        recipients: singleRecipientEdgeBalance,
        feeRate: 1.0,
        changeDerivationPath: "m/84'/1'/0'/0/0",
        walletListItemBase: wallet,
        isFeeSubtractedFromAmount: false,
        isUtxoFixed: false,
      ).build();

      expect(result.isSuccess, isTrue);
      expect(result.estimatedFee, 141 + 68);
      expect(result.transaction, isNotNull);
      expect(result.selectedUtxos, isNotNull);
      expect(result.selectedUtxos!.length, 2);
    });

    test('Single / Auto Utxo / 수수료 발신자 부담 / 수수료를 고려하여 utxo 선택 후 트랜잭션 생성 / 받는 주소가 다중서명지갑 주소', () {
      final TransactionBuildResult result = TransactionBuilder(
        availableUtxos: availableUtxos,
        recipients: mSingleRecipientEdgeBalance,
        feeRate: 1.0,
        changeDerivationPath: "m/84'/1'/0'/0/0",
        walletListItemBase: wallet,
        isFeeSubtractedFromAmount: false,
        isUtxoFixed: false,
      ).build();

      expect(result.isSuccess, isTrue);
      expect(result.estimatedFee, 153 + 68);
      expect(result.transaction, isNotNull);
      expect(result.selectedUtxos, isNotNull);
      expect(result.selectedUtxos!.length, 2);
    });

    test('Single / Auto Utxo / 수수료 발신자 부담 / 보내는 금액 = 잔액', () {
      final TransactionBuildResult result = TransactionBuilder(
        availableUtxos: availableUtxos,
        recipients: singleRecipientSameBalance,
        feeRate: 1.0,
        changeDerivationPath: "m/84'/1'/0'/0/0",
        walletListItemBase: wallet,
        isFeeSubtractedFromAmount: false,
        isUtxoFixed: false,
      ).build();

      expect(result.isFailure, isTrue);
      expect(result.transaction, isNull);
      expect(result.exception, isA<InsufficientBalanceException>());
      expect(result.estimatedFee, isNotNull);
      expect(result.selectedUtxos, isNull);
    });

    test('Single / Auto Utxo / 수수료 발신자 부담 / 보내는 금액 + 예상 수수료 > 잔액', () {
      final TransactionBuildResult result = TransactionBuilder(
        availableUtxos: availableUtxos,
        recipients: singleRecipientNearBalance,
        feeRate: 1.0,
        changeDerivationPath: "m/84'/1'/0'/0/0",
        walletListItemBase: wallet,
        isFeeSubtractedFromAmount: false,
        isUtxoFixed: false,
      ).build();

      expect(result.isFailure, isTrue);
      expect(result.transaction, isNull);
      expect(result.exception, isA<InsufficientBalanceException>());
      expect(result.estimatedFee, isNotNull);
      expect(result.selectedUtxos, isNull);
    });

    test('Single / Auto Utxo / 수수료 수신자 부담', () {
      final result = TransactionBuilder(
        availableUtxos: availableUtxos,
        recipients: singleRecipient,
        feeRate: 1.0,
        changeDerivationPath: "m/84'/1'/0'/0/0",
        walletListItemBase: wallet,
        isFeeSubtractedFromAmount: true,
        isUtxoFixed: false,
      ).build();

      expect(result.isSuccess, isTrue);
      expect(result.estimatedFee, isNotNull);
      expect(result.transaction, isNotNull);
      final estimatedFeeOfTx = result.transaction!.estimateFee(1.0, wallet.walletType.addressType);
      expect(result.estimatedFee, equals(estimatedFeeOfTx));

      /// 사용하는 금액 = 예상 수수료 + 보내는 금액
      expect(singleRecipient.values.first,
          same(estimatedFeeOfTx + result.transaction!.outputs[0].amount));
      expect(result.selectedUtxos, isNotNull);
      expect(result.transaction!.outputs.first.amount, lessThan(singleRecipient.values.first));

      /// 예상 수수료 + amount <= maxUsedAmount
      expect(result.estimatedFee + result.transaction!.outputs.first.amount,
          lessThanOrEqualTo(singleRecipient.values.first));
    });

    test('Single / Auto Utxo / 수수료 수신자 부담 / 보내는 금액 = 잔액', () {
      final result = TransactionBuilder(
        availableUtxos: availableUtxos,
        recipients: singleRecipientSameBalance,
        feeRate: 1.0,
        changeDerivationPath: "m/84'/1'/0'/0/0",
        walletListItemBase: wallet,
        isFeeSubtractedFromAmount: true,
        isUtxoFixed: false,
      ).build();

      expect(result.isSuccess, isTrue);
      expect(result.estimatedFee, isNotNull);
      expect(result.transaction, isNotNull);
      final estimatedFeeOfTx = result.transaction!.estimateFee(1.0, wallet.walletType.addressType);
      expect(result.estimatedFee, equals(estimatedFeeOfTx));

      /// 사용하는 금액 = 예상 수수료 + 보내는 금액
      expect(singleRecipientSameBalance.values.first,
          same(estimatedFeeOfTx + result.transaction!.outputs[0].amount));
      expect(result.selectedUtxos, isNotNull);
    });

    test('Single / Auto Utxo / 수수료 수신자 부담 / 보내는 금액 - 예상 수수료 <= dustLimit', () {
      final result = TransactionBuilder(
        availableUtxos: availableUtxos,
        recipients: singleRecipientSameBalance,
        feeRate: 1800.0,
        changeDerivationPath: "m/84'/1'/0'/0/0",
        walletListItemBase: wallet,
        isFeeSubtractedFromAmount: true,
        isUtxoFixed: false,
      ).build();

      expect(result.isFailure, isTrue);
      expect(result.transaction, isNull);
      expect(result.exception, isA<SendAmountTooLowException>());
      expect(result.estimatedFee, isNotNull);
      expect(result.selectedUtxos, isNull);
    });

    /// recipient: 299706
    /// 1) initialFee: 216 / sendAmount: 299706-216 = 299490 / realFee: 209 / dustThreshold: 294 < 301
    /// 2) initialFee: 209 / sendAmount: 299706-209 = 299497 / realFee: 209 / dustThreshold: 294 >= 294
    /// 3) initialFee: 178 / sendAmount: 299706-178 = 299528 / realFee: 178 / dustThreshold: 294 > 263
    test('Single / Auto Utxo / 수수료 수신자 부담 / Sweep Edge Case', () {
      final result = TransactionBuilder(
        availableUtxos: availableUtxos,
        recipients: singleRecipientEdgeBalance2,
        feeRate: 1.0,
        changeDerivationPath: "m/84'/1'/0'/0/0",
        walletListItemBase: wallet,
        isFeeSubtractedFromAmount: true,
        isUtxoFixed: false,
      ).build();

      expect(result.isSuccess, isTrue);
      expect(result.estimatedFee, isNotNull);
      expect(result.transaction, isNotNull);
      expect(result.selectedUtxos, isNotNull);
      expect(
          result.transaction!.outputs.first.getAddress(), singleRecipientEdgeBalance2.keys.first);

      // tx의 outputs의 amount 합 + 수수료 = singleRecipientEdgeBalance2의 합
      final totalOutputAmount = result.transaction!.outputs
          .fold(0, (previousValue, element) => previousValue + element.amount);
      // expect(totalOutputAmount + estimatedFeeOfTx, sumOfBalance);

      final estimatedFeeOfTx = result.transaction!.estimateFee(1.0, AddressType.p2wpkh);
      expect(estimatedFeeOfTx, lessThan(result.estimatedFee));

      final sendAmount = singleRecipientEdgeBalance2.values.first;
      expect(sendAmount + (result.estimatedFee - estimatedFeeOfTx), equals(sumOfBalance));
      expect(totalOutputAmount + result.estimatedFee, equals(sumOfBalance));
    });
  });

  group('싱글시그지갑 - SingleTx - Manual UTXO Selection', () {
    test('Single / Manual Utxo / 수수료 발신자 부담 / input 1개', () {
      final result = TransactionBuilder(
        availableUtxos: [availableUtxos[0]],
        recipients: singleRecipient,
        feeRate: 1.0,
        changeDerivationPath: "m/84'/1'/0'/0/0",
        walletListItemBase: wallet,
        isFeeSubtractedFromAmount: false,
        isUtxoFixed: true,
      ).build();

      expect(result.isSuccess, isTrue);
      expect(result.transaction!.inputs.length, 1);
      expect(result.transaction!.outputs.length, 2);
      expect(result.estimatedFee, 141);
    });

    test('Single / Manual Utxo / 수수료 발신자 부담 / input 2개', () {
      final result = TransactionBuilder(
        availableUtxos: availableUtxos,
        recipients: singleRecipient,
        feeRate: 1.0,
        changeDerivationPath: "m/84'/1'/0'/0/0",
        walletListItemBase: wallet,
        isFeeSubtractedFromAmount: false,
        isUtxoFixed: true,
      ).build();

      expect(result.isSuccess, isTrue);
      expect(result.transaction!.inputs.length, 2);
      expect(result.transaction!.outputs.length, 2);
      expect(result.estimatedFee, 141 + 68);
      expect(result.selectedUtxos, isNotNull);
    });

    test('Single / Manual Utxo / 수수료 발신자 부담 / 보내는 금액 = 잔액', () {
      final result = TransactionBuilder(
        availableUtxos: availableUtxos,
        recipients: singleRecipientSameBalance,
        feeRate: 1.0,
        changeDerivationPath: "m/84'/1'/0'/0/0",
        walletListItemBase: wallet,
        isFeeSubtractedFromAmount: false,
        isUtxoFixed: true,
      ).build();

      expect(result.isFailure, isTrue);
      expect(result.transaction, isNull);
      expect(result.exception, isA<InsufficientBalanceException>());
      expect(result.estimatedFee, 141 + 68);
      expect(result.selectedUtxos, isNotNull);
    });

    test('Single / Manual Utxo / 수수료 수신자 부담', () {
      final result = TransactionBuilder(
        availableUtxos: availableUtxos,
        recipients: singleRecipient,
        feeRate: 1.0,
        changeDerivationPath: "m/84'/1'/0'/0/0",
        walletListItemBase: wallet,
        isFeeSubtractedFromAmount: true,
        isUtxoFixed: true,
      ).build();

      expect(result.isSuccess, isTrue);
      expect(result.estimatedFee, isNotNull);
      expect(result.transaction, isNotNull);
      expect(result.selectedUtxos, isNotNull);
      final estimatedFeeOfTx = result.transaction!.estimateFee(1.0, wallet.walletType.addressType);
      expect(result.estimatedFee, equals(estimatedFeeOfTx));

      /// 예상 수수료 + amount = maxUsedAmount
      expect(result.estimatedFee + result.transaction!.outputs.first.amount,
          equals(singleRecipient.values.first));
    });

    test('Single / Manual Utxo / 수수료 수신자 부담 / 보내는 금액 = 잔액', () {
      final result = TransactionBuilder(
        availableUtxos: availableUtxos,
        recipients: singleRecipientSameBalance,
        feeRate: 1.0,
        changeDerivationPath: "m/84'/1'/0'/0/0",
        walletListItemBase: wallet,
        isFeeSubtractedFromAmount: true,
        isUtxoFixed: true,
      ).build();

      expect(result.isSuccess, isTrue);
      expect(result.estimatedFee, isPositive);
      expect(result.transaction, isNotNull);
      expect(result.selectedUtxos, isNotNull);
      expect(result.transaction!.outputs.first.amount,
          lessThan(singleRecipientSameBalance.values.first));

      /// 예상 수수료 + amount = maxUsedAmount
      expect(result.estimatedFee + result.transaction!.outputs.first.amount,
          equals(singleRecipientSameBalance.values.first));
    });

    test('Single / Manual Utxo / 수수료 수신자 부담 / 잔액 - 보내는 금액 <= dustLimit', () {
      final result = TransactionBuilder(
        availableUtxos: availableUtxos,
        recipients: singleRecipientNearBalance,
        feeRate: 1.0,
        changeDerivationPath: "m/84'/1'/0'/0/0",
        walletListItemBase: wallet,
        isFeeSubtractedFromAmount: true,
        isUtxoFixed: true,
      ).build();

      expect(result.isSuccess, isTrue);
      expect(result.estimatedFee, isPositive);
      expect(result.transaction, isNotNull);
      expect(result.selectedUtxos, isNotNull);
      expect(result.estimatedFee + result.transaction!.outputs.first.amount, equals(sumOfBalance));
    });

    test('Single / Manual Utxo / 수수료 수신자 부담 / 보내는 금액 - 예상 수수료 <= dustLimit', () {
      final result = TransactionBuilder(
        availableUtxos: availableUtxos,
        recipients: singleRecipientSameBalance,
        feeRate: 1800.0,
        changeDerivationPath: "m/84'/1'/0'/0/0",
        walletListItemBase: wallet,
        isFeeSubtractedFromAmount: true,
        isUtxoFixed: true,
      ).build();

      expect(result.isFailure, isTrue);
      expect(result.transaction, isNull);
      expect(result.exception, isA<InsufficientBalanceException>());
      expect(result.estimatedFee, isNotNull);
      expect(result.selectedUtxos, isNotNull);
    });
  });

  group('싱글시그지갑 - BatchTx - Auto UTXO Selection', () {
    test('Batch / Auto Utxo / 수수료 발신자 부담', () {
      final result = TransactionBuilder(
        availableUtxos: availableUtxos,
        recipients: batchRecipients,
        feeRate: 1.0,
        changeDerivationPath: "m/84'/1'/0'/0/0",
        walletListItemBase: wallet,
        isFeeSubtractedFromAmount: false,
        isUtxoFixed: false,
      ).build();

      expect(result.isSuccess, isTrue);
      expect(result.estimatedFee, isPositive);
      expect(result.transaction!.inputs.length, 1);
      expect(result.transaction!.outputs.length, 3);
    });

    test('Batch / Auto Utxo / 수수료 발신자 부담 / 수수료율 높음', () {
      final result = TransactionBuilder(
        availableUtxos: availableUtxos,
        recipients: batchRecipients,
        feeRate: 1800.0,
        changeDerivationPath: "m/84'/1'/0'/0/0",
        walletListItemBase: wallet,
        isFeeSubtractedFromAmount: false,
        isUtxoFixed: false,
      ).build();

      expect(result.isSuccess, isFalse);
      expect(result.exception, isA<InsufficientBalanceException>());
      expect(result.estimatedFee, isPositive);
      expect(result.transaction, isNull);
      expect(result.selectedUtxos, isNull);
    });

    test('Batch / Auto Utxo / 수수료 발신자 부담 / 보내는 금액 합 = 잔액', () {
      final result = TransactionBuilder(
        availableUtxos: availableUtxos,
        recipients: batchRecipientsSameBalance,
        feeRate: 1.0,
        changeDerivationPath: "m/84'/1'/0'/0/0",
        walletListItemBase: wallet,
        isFeeSubtractedFromAmount: false,
        isUtxoFixed: false,
      ).build();

      expect(result.isFailure, isTrue);
      expect(result.exception, isA<InsufficientBalanceException>());
      expect(result.estimatedFee, isPositive);
      expect(result.transaction, isNull);
      expect(result.selectedUtxos, isNull);
    });

    test('Batch / Auto Utxo / 수수료 수신자 부담', () {
      final result = TransactionBuilder(
        availableUtxos: availableUtxos,
        recipients: batchRecipients,
        feeRate: 1.0,
        changeDerivationPath: "m/84'/1'/0'/0/0",
        walletListItemBase: wallet,
        isFeeSubtractedFromAmount: true,
        isUtxoFixed: false,
      ).build();

      expect(result.isSuccess, isTrue);
      expect(result.estimatedFee, isPositive);
      expect(result.transaction, isNotNull);
      expect(result.transaction!.inputs.length, 1);
      expect(result.transaction!.outputs.length, 3);
      expect(result.selectedUtxos, isNotNull);
      final totalOutputAmount = result.transaction!.outputs
          .fold(0, (previousValue, element) => previousValue + element.amount);
      final totalBalance =
          availableUtxos.fold(0, (previousValue, element) => previousValue + element.amount);
      expect(totalOutputAmount + result.estimatedFee, lessThanOrEqualTo(totalBalance));
    });

    test('Batch / Auto Utxo / 수수료 수신자 부담 / 보내는 금액 합 = 잔액', () {
      final result = TransactionBuilder(
        availableUtxos: availableUtxos,
        recipients: batchRecipientsSameBalance,
        feeRate: 1.0,
        changeDerivationPath: "m/84'/1'/0'/0/0",
        walletListItemBase: wallet,
        isFeeSubtractedFromAmount: true,
        isUtxoFixed: false,
      ).build();

      expect(result.isSuccess, isTrue);
      expect(result.estimatedFee, isPositive);
      expect(result.transaction, isNotNull);
      expect(result.transaction!.inputs.length, 2);
      expect(result.transaction!.outputs.length, 2);

      expect(result.selectedUtxos, isNotNull);
      final totalOutputAmount = result.transaction!.outputs
          .fold(0, (previousValue, element) => previousValue + element.amount);
      final totalBalance =
          availableUtxos.fold(0, (previousValue, element) => previousValue + element.amount);
      expect(totalOutputAmount + result.estimatedFee, equals(totalBalance));

      expect(result.transaction!.outputs[1].amount,
          lessThan(batchRecipientsSameBalance.entries.last.value));
      expect(result.transaction!.outputs[1].amount + result.estimatedFee,
          lessThanOrEqualTo(batchRecipientsSameBalance.entries.last.value));
    });

    test('Batch / Auto Utxo / 수수료 수신자 부담 / 보내는 금액 합 > 잔액', () {
      final result = TransactionBuilder(
        availableUtxos: availableUtxos,
        recipients: batchRecipientsOverBalance,
        feeRate: 1.0,
        changeDerivationPath: "m/84'/1'/0'/0/0",
        walletListItemBase: wallet,
        isFeeSubtractedFromAmount: true,
        isUtxoFixed: false,
      ).build();

      expect(result.isSuccess, isFalse);
      expect(result.estimatedFee, isPositive);
      expect(result.transaction, isNull);
      expect(result.selectedUtxos, isNull);
      expect(result.exception, isA<InsufficientBalanceException>());
    });

    /// 1) initialFee: 250 / lastSendAmount: 149706-250 = 149456 / realFee: 240 / dustThreshold: 294 < 304
    /// 2) initialFee: 240 / lastSendAmount: 149706-240 = 149466 / realFee: 240 / dustThreshold: 294 >= 294
    test('Batch / Auto Utxo / 수수료 수신자 부담 / Sweep Edge Case', () {
      final result = TransactionBuilder(
        availableUtxos: availableUtxos,
        recipients: batchRecipientsEdgeBalance,
        feeRate: 1.0,
        changeDerivationPath: "m/84'/1'/0'/0/0",
        walletListItemBase: wallet,
        isFeeSubtractedFromAmount: true,
        isUtxoFixed: false,
      ).build();

      expect(result.isSuccess, isTrue);
      expect(result.estimatedFee, isPositive);
      expect(result.transaction, isNotNull);
      expect(result.transaction!.inputs.length, 2);
      expect(result.transaction!.outputs.length, 2);
      expect(result.selectedUtxos, isNotNull);
      final totalOutputAmount = result.transaction!.outputs
          .fold(0, (previousValue, element) => previousValue + element.amount);
      final estimatedFee = result.transaction!.estimateFee(1.0, AddressType.p2wpkh);
      expect(estimatedFee, lessThan(result.estimatedFee));
      final totalBalance =
          availableUtxos.fold(0, (previousValue, element) => previousValue + element.amount);
      final totalSendAmount = batchRecipientsEdgeBalance.values
          .fold(0, (previousValue, element) => previousValue + element);
      expect(totalSendAmount + (result.estimatedFee - estimatedFee), equals(totalBalance));
      expect(totalOutputAmount + result.estimatedFee, equals(totalBalance));
    });
  });

  group('싱글시그지갑 - BatchTx - Manual UTXO Selection', () {
    test('Batch / Manual Utxo / 수수료 발신자 부담', () {
      final result = TransactionBuilder(
        availableUtxos: availableUtxos,
        recipients: batchRecipients,
        feeRate: 1.0,
        changeDerivationPath: "m/84'/1'/0'/0/0",
        walletListItemBase: wallet,
        isFeeSubtractedFromAmount: false,
        isUtxoFixed: true,
      ).build();

      expect(result.isSuccess, isTrue);
      expect(result.estimatedFee, isPositive);
      expect(result.transaction, isNotNull);
      expect(result.transaction!.inputs.length, 2);
      expect(result.transaction!.outputs.length, 3);
      expect(result.transaction!.outputs[1].amount, equals(batchRecipients.values.last));
      expect(result.transaction!.outputs.last.amount,
          equals(sumOfBalance - sumOfBatchRecipients - result.estimatedFee));
    });

    test('Batch / Manual Utxo / 수수료 수신자 부담', () {
      final result = TransactionBuilder(
        availableUtxos: availableUtxos,
        recipients: batchRecipients,
        feeRate: 1.0,
        changeDerivationPath: "m/84'/1'/0'/0/0",
        walletListItemBase: wallet,
        isFeeSubtractedFromAmount: true,
        isUtxoFixed: true,
      ).build();

      expect(result.isSuccess, isTrue);
      expect(result.estimatedFee, isPositive);
      expect(result.transaction, isNotNull);
      expect(result.transaction!.inputs.length, 2);
      expect(result.transaction!.outputs.length, 3);
      expect(result.transaction!.outputs[1].amount, lessThan(batchRecipients.values.last));
      expect(result.transaction!.outputs[1].amount + result.estimatedFee,
          equals(batchRecipients.values.last));
      expect(result.transaction!.outputs.last.amount, equals(sumOfBalance - sumOfBatchRecipients));
    });

    test('Batch / Manual Utxo / 수수료 수신자 부담 / 마지막 보내는 금액 dustLimit 이하', () {
      final result = TransactionBuilder(
        availableUtxos: availableUtxos,
        recipients: batchRecipients,
        feeRate: 160.0,
        changeDerivationPath: "m/84'/1'/0'/0/0",
        walletListItemBase: wallet,
        isFeeSubtractedFromAmount: true,
        isUtxoFixed: true,
      ).build();

      expect(result.isSuccess, isFalse);
      expect(result.estimatedFee, isPositive);
      expect(result.transaction, isNull);
      expect(result.selectedUtxos, isNotNull);
      expect(result.exception, isA<SendAmountTooLowException>());
    });

    test('Batch / Manual Utxo / 수수료 수신자 부담 / 잔액 - 보내는 금액 <= dustLimit', () {
      final result = TransactionBuilder(
        availableUtxos: availableUtxos,
        recipients: batchRecipientsEdgeBalance,
        feeRate: 1.0,
        changeDerivationPath: "m/84'/1'/0'/0/0",
        walletListItemBase: wallet,
        isFeeSubtractedFromAmount: true,
        isUtxoFixed: true,
      ).build();

      expect(result.isSuccess, isTrue);
      expect(result.estimatedFee, isPositive);
      expect(result.transaction, isNotNull);
      expect(result.selectedUtxos, isNotNull);
      final sumOfOutputs = result.transaction!.outputs
          .fold(0, (previousValue, element) => previousValue + element.amount);
      expect(result.estimatedFee + sumOfOutputs, equals(sumOfBalance));
    });
  });

  group('싱글시그지갑 - copyWith', () {
    test('should return a new instance with updated values', () {
      final builder = TransactionBuilder(
        availableUtxos: availableUtxos,
        recipients: singleRecipient,
        feeRate: 1.0,
        changeDerivationPath: "m/84'/1'/0'/0/0",
        walletListItemBase: wallet,
        isFeeSubtractedFromAmount: false,
        isUtxoFixed: false,
      );

      var result1 = builder.build();
      var result2 = builder.copyWith(isFeeSubtractedFromAmount: true).build();

      expect(result1.transaction!.outputs.last.amount,
          lessThan(result2.transaction!.outputs.last.amount));
    });
  });

  MultisigWalletListItem multisigWallet = WalletMock.createMultiSigWalletItem();

  /// utxo_selector에서 amount순으로 정렬됨
  late List<UtxoState> mAvailableUtxos = [
    UtxoState(
      transactionHash: 'd77dc64d3eb3454e9c65e5e36989af0eef349d824593dfe2a086fb9dadf7dfc4',
      index: 0,
      amount: 100000, // 0.001 BTC
      blockHeight: 100,
      to: 'bcrt1qj8xc32grq9jghxhwu2yeuj8qumw8zsexfjh8r40p6ud37gxsk49snlc26f',
      derivationPath: "m/84'/1'/0'/0/0",
      timestamp: DateTime.now(),
    ),
    UtxoState(
      transactionHash: '577a101d9bddd1ddee0d72a0853a8ca2d8b13d92c63f9a84277152ba791e426a',
      index: 1,
      amount: 200000, // 0.002 BTC
      blockHeight: 101,
      to: 'bcrt1qdgawn8wyfxvp9a4f0g7wcx5nf0z24d8j59aqv77455p84hk2km7qem666g',
      derivationPath: "m/84'/1'/0'/0/1",
      timestamp: DateTime.now(),
    ),
  ];

  group('멀티시그지갑 - SingleTx - Auto UTXO Selection', () {
    test('Single / Auto Utxo / 수수료 발신자 부담 / availableUtxos가 비어있을 때', () {
      final TransactionBuildResult result = TransactionBuilder(
        availableUtxos: [],
        recipients: singleRecipient,
        feeRate: 1.0,
        changeDerivationPath: "m/84'/1'/0'/0/0",
        walletListItemBase: multisigWallet,
        isFeeSubtractedFromAmount: false,
        isUtxoFixed: false,
      ).build();

      expect(result.isFailure, isTrue);
      expect(result.estimatedFee, isNotNull);
      expect(result.transaction, isNull);
      expect(result.selectedUtxos, isEmpty);
    });

    test('Single / Auto Utxo / 수수료 발신자 부담', () {
      final TransactionBuildResult result = TransactionBuilder(
        availableUtxos: mAvailableUtxos,
        recipients: singleRecipient,
        feeRate: 1.0,
        changeDerivationPath: "m/84'/1'/0'/0/0",
        walletListItemBase: multisigWallet,
        isFeeSubtractedFromAmount: false,
        isUtxoFixed: false,
      ).build();

      expect(result.isSuccess, isTrue);
      expect(result.estimatedFee, 189);
      expect(result.transaction, isNotNull);
      expect(result.selectedUtxos, isNotNull);
      expect(result.selectedUtxos!.length, 1);
    });

    test('Single / Auto Utxo / 수수료 발신자 부담 / 받는 주소가 다중서명지갑 주소', () {
      final TransactionBuildResult result = TransactionBuilder(
        availableUtxos: mAvailableUtxos,
        recipients: mSingleRecipient,
        feeRate: 1.0,
        changeDerivationPath: "m/84'/1'/0'/0/0",
        walletListItemBase: multisigWallet,
        isFeeSubtractedFromAmount: false,
        isUtxoFixed: false,
      ).build();

      expect(result.isSuccess, isTrue);
      expect(result.estimatedFee, greaterThan(189));
      expect(result.transaction, isNotNull);
      expect(result.selectedUtxos, isNotNull);
      expect(result.selectedUtxos!.length, 1);
    });

    test('Single / Auto Utxo / 수수료 발신자 부담 / 수수료를 고려하여 utxo 선택 후 트랜잭션 생성', () {
      final TransactionBuildResult result = TransactionBuilder(
        availableUtxos: mAvailableUtxos,
        recipients: singleRecipientEdgeBalance,
        feeRate: 1.0,
        changeDerivationPath: "m/84'/1'/0'/0/0",
        walletListItemBase: multisigWallet,
        isFeeSubtractedFromAmount: false,
        isUtxoFixed: false,
      ).build();

      expect(result.isSuccess, isTrue);
      expect(result.estimatedFee, greaterThan(189));
      expect(result.transaction, isNotNull);
      expect(result.selectedUtxos, isNotNull);
      expect(result.selectedUtxos!.length, 2);
    });

    test('Single / Auto Utxo / 수수료 발신자 부담 / 수수료를 고려하여 utxo 선택 후 트랜잭션 생성 / 받는 주소가 다중서명지갑 주소', () {
      final TransactionBuildResult result = TransactionBuilder(
        availableUtxos: mAvailableUtxos,
        recipients: mSingleRecipientEdgeBalance,
        feeRate: 1.0,
        changeDerivationPath: "m/84'/1'/0'/0/0",
        walletListItemBase: multisigWallet,
        isFeeSubtractedFromAmount: false,
        isUtxoFixed: false,
      ).build();

      expect(result.isSuccess, isTrue);
      expect(result.estimatedFee, greaterThan(189));
      expect(result.transaction, isNotNull);
      expect(result.selectedUtxos, isNotNull);
      expect(result.selectedUtxos!.length, 2);
    });

    test('Single / Auto Utxo / 수수료 발신자 부담 / 보내는 금액 = 잔액', () {
      final TransactionBuildResult result = TransactionBuilder(
        availableUtxos: mAvailableUtxos,
        recipients: singleRecipientSameBalance,
        feeRate: 1.0,
        changeDerivationPath: "m/84'/1'/0'/0/0",
        walletListItemBase: multisigWallet,
        isFeeSubtractedFromAmount: false,
        isUtxoFixed: false,
      ).build();

      expect(result.isFailure, isTrue);
      expect(result.transaction, isNull);
      expect(result.exception, isA<InsufficientBalanceException>());
      expect(result.estimatedFee, greaterThan(189));
      expect(result.selectedUtxos, isNull);
    });

    test('Single / Auto Utxo / 수수료 발신자 부담 / 보내는 금액 + 예상 수수료 > 잔액', () {
      final TransactionBuildResult result = TransactionBuilder(
        availableUtxos: mAvailableUtxos,
        recipients: singleRecipientNearBalance,
        feeRate: 1.0,
        changeDerivationPath: "m/84'/1'/0'/0/0",
        walletListItemBase: multisigWallet,
        isFeeSubtractedFromAmount: false,
        isUtxoFixed: false,
      ).build();

      expect(result.isFailure, isTrue);
      expect(result.transaction, isNull);
      expect(result.exception, isA<InsufficientBalanceException>());
      expect(result.estimatedFee, greaterThan(189));
      expect(result.selectedUtxos, isNull);
    });

    test('Single / Auto Utxo / 수수료 수신자 부담', () {
      final result = TransactionBuilder(
        availableUtxos: mAvailableUtxos,
        recipients: singleRecipient,
        feeRate: 1.0,
        changeDerivationPath: "m/84'/1'/0'/0/0",
        walletListItemBase: multisigWallet,
        isFeeSubtractedFromAmount: true,
        isUtxoFixed: false,
      ).build();

      expect(result.isSuccess, isTrue);
      expect(result.estimatedFee, isNotNull);
      expect(result.transaction, isNotNull);
      expect(result.selectedUtxos, isNotNull);
      expect(result.transaction!.outputs.first.amount, lessThan(singleRecipient.values.first));

      /// 예상 수수료 + amount <= maxUsedAmount
      expect(result.estimatedFee + result.transaction!.outputs.first.amount,
          lessThanOrEqualTo(singleRecipient.values.first));
    });

    test('Single / Auto Utxo / 수수료 수신자 부담 / 보내는 금액 = 잔액', () {
      final result = TransactionBuilder(
        availableUtxos: mAvailableUtxos,
        recipients: singleRecipientSameBalance,
        feeRate: 1.0,
        changeDerivationPath: "m/84'/1'/0'/0/0",
        walletListItemBase: multisigWallet,
        isFeeSubtractedFromAmount: true,
        isUtxoFixed: false,
      ).build();

      expect(result.isSuccess, isTrue);
      expect(result.estimatedFee, greaterThan(189));
      expect(result.transaction, isNotNull);
      expect(result.transaction!.outputs.first.amount,
          lessThan(singleRecipientSameBalance.values.first));

      /// 예상 수수료 + amount <= maxUsedAmount
      expect(result.estimatedFee + result.transaction!.outputs.first.amount,
          lessThanOrEqualTo(singleRecipientSameBalance.values.first));
    });

    test('Single / Auto Utxo / 수수료 수신자 부담 / 보내는 금액 - 예상 수수료 <= dustLimit', () {
      final result = TransactionBuilder(
        availableUtxos: mAvailableUtxos,
        recipients: singleRecipientSameBalance,
        feeRate: 1800.0,
        changeDerivationPath: "m/84'/1'/0'/0/0",
        walletListItemBase: multisigWallet,
        isFeeSubtractedFromAmount: true,
        isUtxoFixed: false,
      ).build();

      expect(result.isFailure, isTrue);
      expect(result.transaction, isNull);
      expect(result.exception, isA<SendAmountTooLowException>());
      expect(result.estimatedFee, isNotNull);
      expect(result.selectedUtxos, isNull);
    });
  });

  group('멀티시그지갑 - SingleTx - Manual UTXO Selection', () {
    test('Single / Manual Utxo / 수수료 발신자 부담 / input 1개', () {
      final result = TransactionBuilder(
        availableUtxos: [mAvailableUtxos[0]],
        recipients: singleRecipient,
        feeRate: 1.0,
        changeDerivationPath: "m/84'/1'/0'/0/0",
        walletListItemBase: multisigWallet,
        isFeeSubtractedFromAmount: false,
        isUtxoFixed: true,
      ).build();

      expect(result.isSuccess, isTrue);
      expect(result.transaction!.inputs.length, 1);
      expect(result.transaction!.outputs.length, 2);
      expect(result.estimatedFee, 189);
    });

    test('Single / Manual Utxo / 수수료 발신자 부담 / input 2개', () {
      final result = TransactionBuilder(
        availableUtxos: mAvailableUtxos,
        recipients: singleRecipient,
        feeRate: 1.0,
        changeDerivationPath: "m/84'/1'/0'/0/0",
        walletListItemBase: multisigWallet,
        isFeeSubtractedFromAmount: false,
        isUtxoFixed: true,
      ).build();

      expect(result.isSuccess, isTrue);
      expect(result.transaction!.inputs.length, 2);
      expect(result.transaction!.outputs.length, 2);
      expect(result.estimatedFee, greaterThan(189));
      expect(result.selectedUtxos, isNotNull);
    });

    test('Single / Manual Utxo / 수수료 발신자 부담 / 보내는 금액 = 잔액', () {
      final result = TransactionBuilder(
        availableUtxos: mAvailableUtxos,
        recipients: singleRecipientSameBalance,
        feeRate: 1.0,
        changeDerivationPath: "m/84'/1'/0'/0/0",
        walletListItemBase: multisigWallet,
        isFeeSubtractedFromAmount: false,
        isUtxoFixed: true,
      ).build();

      expect(result.isFailure, isTrue);
      expect(result.transaction, isNull);
      expect(result.exception, isA<InsufficientBalanceException>());
      expect(result.estimatedFee, greaterThan(189));
      expect(result.selectedUtxos, isNotNull);
    });

    test('Single / Auto Utxo / 수수료 수신자 부담', () {
      final result = TransactionBuilder(
        availableUtxos: mAvailableUtxos,
        recipients: singleRecipient,
        feeRate: 1.0,
        changeDerivationPath: "m/84'/1'/0'/0/0",
        walletListItemBase: multisigWallet,
        isFeeSubtractedFromAmount: true,
        isUtxoFixed: true,
      ).build();

      expect(result.isSuccess, isTrue);
      expect(result.estimatedFee, isNotNull);
      expect(result.transaction, isNotNull);
      expect(result.selectedUtxos, isNotNull);
      expect(result.transaction!.outputs.first.amount, lessThan(singleRecipient.values.first));

      /// 예상 수수료 + amount <= maxUsedAmount
      expect(result.estimatedFee + result.transaction!.outputs.first.amount,
          lessThanOrEqualTo(singleRecipient.values.first));
    });

    test('Single / Auto Utxo / 수수료 수신자 부담 / 보내는 금액 = 잔액', () {
      final result = TransactionBuilder(
        availableUtxos: mAvailableUtxos,
        recipients: singleRecipientSameBalance,
        feeRate: 1.0,
        changeDerivationPath: "m/84'/1'/0'/0/0",
        walletListItemBase: multisigWallet,
        isFeeSubtractedFromAmount: true,
        isUtxoFixed: true,
      ).build();

      expect(result.isSuccess, isTrue);
      expect(result.estimatedFee, isPositive);
      expect(result.transaction, isNotNull);
      expect(result.selectedUtxos, isNotNull);
      expect(result.transaction!.outputs.first.amount,
          lessThan(singleRecipientSameBalance.values.first));

      /// 예상 수수료 + amount <= maxUsedAmount
      expect(result.estimatedFee + result.transaction!.outputs.first.amount,
          lessThanOrEqualTo(singleRecipientSameBalance.values.first));
    });

    test('Single / Auto Utxo / 수수료 수신자 부담 / 보내는 금액 - 예상 수수료 <= dustLimit', () {
      final result = TransactionBuilder(
        availableUtxos: mAvailableUtxos,
        recipients: singleRecipientSameBalance,
        feeRate: 1800.0,
        changeDerivationPath: "m/84'/1'/0'/0/0",
        walletListItemBase: multisigWallet,
        isFeeSubtractedFromAmount: true,
        isUtxoFixed: true,
      ).build();

      expect(result.isFailure, isTrue);
      expect(result.transaction, isNull);
      expect(result.exception, isA<InsufficientBalanceException>());
      expect(result.estimatedFee, isNotNull);
      expect(result.selectedUtxos, isNotNull);
    });
  });

  group('멀티시그지갑 - BatchTx - Auto UTXO Selection', () {
    test('Batch / Auto Utxo / 수수료 발신자 부담', () {
      final result = TransactionBuilder(
        availableUtxos: mAvailableUtxos,
        recipients: batchRecipients,
        feeRate: 1.0,
        changeDerivationPath: "m/84'/1'/0'/0/0",
        walletListItemBase: multisigWallet,
        isFeeSubtractedFromAmount: false,
        isUtxoFixed: false,
      ).build();

      expect(result.isSuccess, isTrue);
      expect(result.estimatedFee, isPositive);
      expect(result.transaction!.inputs.length, 1);
      expect(result.transaction!.outputs.length, 3);
    });

    test('Batch / Auto Utxo / 수수료 발신자 부담 / 수수료율 높음', () {
      final result = TransactionBuilder(
        availableUtxos: availableUtxos,
        recipients: batchRecipients,
        feeRate: 1800.0,
        changeDerivationPath: "m/84'/1'/0'/0/0",
        walletListItemBase: multisigWallet,
        isFeeSubtractedFromAmount: false,
        isUtxoFixed: false,
      ).build();

      expect(result.isSuccess, isFalse);
      expect(result.exception, isA<InsufficientBalanceException>());
      expect(result.estimatedFee, isPositive);
      expect(result.transaction, isNull);
      expect(result.selectedUtxos, isNull);
    });

    test('Batch / Auto Utxo / 수수료 발신자 부담 / 보내는 금액 합 = 잔액', () {
      final result = TransactionBuilder(
        availableUtxos: mAvailableUtxos,
        recipients: batchRecipientsSameBalance,
        feeRate: 1.0,
        changeDerivationPath: "m/84'/1'/0'/0/0",
        walletListItemBase: multisigWallet,
        isFeeSubtractedFromAmount: false,
        isUtxoFixed: false,
      ).build();

      expect(result.isFailure, isTrue);
      expect(result.exception, isA<InsufficientBalanceException>());
      expect(result.estimatedFee, isPositive);
      expect(result.transaction, isNull);
      expect(result.selectedUtxos, isNull);
    });

    test('Batch / Auto Utxo / 수수료 수신자 부담', () {
      final result = TransactionBuilder(
        availableUtxos: availableUtxos,
        recipients: batchRecipients,
        feeRate: 1.0,
        changeDerivationPath: "m/84'/1'/0'/0/0",
        walletListItemBase: multisigWallet,
        isFeeSubtractedFromAmount: true,
        isUtxoFixed: false,
      ).build();

      expect(result.isSuccess, isTrue);
      expect(result.estimatedFee, isPositive);
      expect(result.transaction, isNotNull);
      expect(result.transaction!.inputs.length, 1);
      expect(result.transaction!.outputs.length, 3);
      expect(result.selectedUtxos, isNotNull);
      final totalOutputAmount = result.transaction!.outputs
          .fold(0, (previousValue, element) => previousValue + element.amount);
      final totalBalance =
          availableUtxos.fold(0, (previousValue, element) => previousValue + element.amount);
      expect(totalOutputAmount + result.estimatedFee, lessThanOrEqualTo(totalBalance));
    });

    test('Batch / Auto Utxo / 수수료 수신자 부담 / 보내는 금액 합 = 잔액', () {
      final result = TransactionBuilder(
        availableUtxos: mAvailableUtxos,
        recipients: batchRecipientsSameBalance,
        feeRate: 1.0,
        changeDerivationPath: "m/84'/1'/0'/0/0",
        walletListItemBase: multisigWallet,
        isFeeSubtractedFromAmount: true,
        isUtxoFixed: false,
      ).build();

      expect(result.isSuccess, isTrue);
      expect(result.estimatedFee, isPositive);
      expect(result.transaction, isNotNull);
      expect(result.transaction!.inputs.length, 2);
      expect(result.transaction!.outputs.length, 2);

      expect(result.selectedUtxos, isNotNull);
      final totalOutputAmount = result.transaction!.outputs
          .fold(0, (previousValue, element) => previousValue + element.amount);
      final totalBalance =
          availableUtxos.fold(0, (previousValue, element) => previousValue + element.amount);
      expect(totalOutputAmount + result.estimatedFee, lessThanOrEqualTo(totalBalance));

      expect(result.transaction!.outputs[1].amount,
          lessThan(batchRecipientsSameBalance.entries.last.value));
      expect(result.transaction!.outputs[1].amount + result.estimatedFee,
          lessThanOrEqualTo(batchRecipientsSameBalance.entries.last.value));
    });

    test('Batch / Auto Utxo / 수수료 수신자 부담 / 보내는 금액 합 > 잔액', () {
      final result = TransactionBuilder(
        availableUtxos: mAvailableUtxos,
        recipients: batchRecipientsOverBalance,
        feeRate: 1.0,
        changeDerivationPath: "m/84'/1'/0'/0/0",
        walletListItemBase: multisigWallet,
        isFeeSubtractedFromAmount: true,
        isUtxoFixed: false,
      ).build();

      expect(result.isSuccess, isFalse);
      expect(result.estimatedFee, isPositive);
      expect(result.transaction, isNull);
      expect(result.selectedUtxos, isNull);
      expect(result.exception, isA<InsufficientBalanceException>());
    });
  });

  group('멀티시그지갑 - BatchTx - Manual UTXO Selection', () {
    test('Batch / Manual Utxo / 수수료 발신자 부담', () {
      final result = TransactionBuilder(
        availableUtxos: mAvailableUtxos,
        recipients: batchRecipients,
        feeRate: 1.0,
        changeDerivationPath: "m/84'/1'/0'/0/0",
        walletListItemBase: multisigWallet,
        isFeeSubtractedFromAmount: false,
        isUtxoFixed: true,
      ).build();

      expect(result.isSuccess, isTrue);
      expect(result.estimatedFee, isPositive);
      expect(result.transaction, isNotNull);
      expect(result.transaction!.inputs.length, 2);
      expect(result.transaction!.outputs.length, 3);
      expect(result.transaction!.outputs[1].amount, equals(batchRecipients.values.last));
      expect(result.transaction!.outputs.last.amount,
          equals(sumOfBalance - sumOfBatchRecipients - result.estimatedFee));
    });

    test('Batch / Manual Utxo / 수수료 수신자 부담', () {
      final result = TransactionBuilder(
        availableUtxos: mAvailableUtxos,
        recipients: batchRecipients,
        feeRate: 1.0,
        changeDerivationPath: "m/84'/1'/0'/0/0",
        walletListItemBase: multisigWallet,
        isFeeSubtractedFromAmount: true,
        isUtxoFixed: true,
      ).build();

      expect(result.isSuccess, isTrue);
      expect(result.estimatedFee, isPositive);
      expect(result.transaction, isNotNull);
      expect(result.transaction!.inputs.length, 2);
      expect(result.transaction!.outputs.length, 3);
      expect(result.transaction!.outputs[1].amount, lessThan(batchRecipients.values.last));
      expect(result.transaction!.outputs[1].amount + result.estimatedFee,
          lessThanOrEqualTo(batchRecipients.values.last));
      expect(result.transaction!.outputs.last.amount,
          greaterThanOrEqualTo(sumOfBalance - sumOfBatchRecipients));
    });

    test('Batch / Manual Utxo / 수수료 수신자 부담 / 마지막 보내는 금액 dustLimit 이하', () {
      final result = TransactionBuilder(
        availableUtxos: mAvailableUtxos,
        recipients: batchRecipients,
        feeRate: 160.0,
        changeDerivationPath: "m/84'/1'/0'/0/0",
        walletListItemBase: multisigWallet,
        isFeeSubtractedFromAmount: true,
        isUtxoFixed: true,
      ).build();

      expect(result.isSuccess, isFalse);
      expect(result.estimatedFee, isPositive);
      expect(result.transaction, isNull);
      expect(result.selectedUtxos, isNotNull);
      expect(result.exception, isA<SendAmountTooLowException>());
    });
  });

  group('멀티시그지갑 - copyWith', () {
    test('should return a new instance with updated values', () {
      final builder = TransactionBuilder(
        availableUtxos: mAvailableUtxos,
        recipients: singleRecipient,
        feeRate: 1.0,
        changeDerivationPath: "m/84'/1'/0'/0/0",
        walletListItemBase: multisigWallet,
        isFeeSubtractedFromAmount: false,
        isUtxoFixed: false,
      );

      var result1 = builder.build();
      var result2 = builder.copyWith(isFeeSubtractedFromAmount: true).build();

      expect(result1.transaction!.outputs.last.amount,
          lessThan(result2.transaction!.outputs.last.amount));
    });
  });
}
