import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/core/exceptions/transaction_creation/transaction_creation_exception.dart';
import 'package:coconut_wallet/core/transaction/transaction_builder.dart';
import 'package:coconut_wallet/core/transaction/utxo_selector.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/wallet/taproot_wallet_list_item.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../mock/wallet_mock.dart';

void main() {
  NetworkType.setNetworkType(NetworkType.regtest);

  late TaprootWalletListItem taprootWallet;

  // BIP-86 taproot testnet/regtest paths
  const changeDerivationPath = "m/86'/1'/0'/1/0";

  // recipient1~3: bcrt1q (P2WPKH) addresses — cross-type send from taproot wallet
  const String recipient1 = 'bcrt1q6c8cqxwld4zazqntqnw88p0krqp48hk7ngzl9e';
  const String recipient2 = 'bcrt1qwpkzfxqnenazz5vd5afnhsxhjqpa6zf4vp7kz3';
  const String recipient3 = 'bcrt1qk0sy5067et9mcvh7s4xa4ym2lunslhn9f2rnht';

  /// utxo_selector에서 amount 순으로 정렬됨
  late List<UtxoState> tAvailableUtxos = [
    UtxoState(
      transactionHash: 'd77dc64d3eb3454e9c65e5e36989af0eef349d824593dfe2a086fb9dadf7dfc4',
      index: 0,
      amount: 100000,
      blockHeight: 100,
      to: 'taproot-address-0',
      derivationPath: "m/86'/1'/0'/0/0",
      timestamp: DateTime.now(),
    ),
    UtxoState(
      transactionHash: '577a101d9bddd1ddee0d72a0853a8ca2d8b13d92c63f9a84277152ba791e426a',
      index: 1,
      amount: 200000,
      blockHeight: 101,
      to: 'taproot-address-1',
      derivationPath: "m/86'/1'/0'/0/1",
      timestamp: DateTime.now(),
    ),
  ];

  int sumOfBalance = tAvailableUtxos.map((u) => u.amount).reduce((a, b) => a + b);

  Map<String, int> singleRecipient = {recipient1: 50000};
  Map<String, int> singleRecipientEdgeBalance = {recipient1: 199999};
  Map<String, int> singleRecipientSameBalance = {recipient1: sumOfBalance};
  Map<String, int> batchRecipients = {recipient2: 30000, recipient3: 40000};
  int sumOfBatchRecipients = batchRecipients.values.reduce((a, b) => a + b);
  Map<String, int> batchRecipientsSameBalance = {recipient2: 150000, recipient3: 150000};
  Map<String, int> batchRecipientsOverBalance = {recipient2: 150000, recipient3: 150000, recipient1: 1000};

  setUpAll(() {
    taprootWallet = WalletMock.createTaprootWalletItem();
  });

  // ─────────────────────────────────────────────────────────────
  // Group 1: SingleTx – Auto UTXO – keyPath
  // ─────────────────────────────────────────────────────────────
  group('탭루트지갑 - SingleTx - Auto UTXO Selection - keyPath', () {
    test('Single / Auto Utxo / 수수료 발신자 부담', () {
      final result =
          TransactionBuilder(
            availableUtxos: tAvailableUtxos,
            recipients: singleRecipient,
            feeRate: 1.0,
            changeDerivationPath: changeDerivationPath,
            walletListItemBase: taprootWallet,
            isFeeSubtractedFromAmount: false,
            isUtxoFixed: false,
          ).build();

      expect(result.isSuccess, isTrue);
      expect(result.estimatedFee, 143);
      expect(result.transaction, isNotNull);
      expect(result.selectedUtxos, isNotNull);
      expect(result.selectedUtxos!.length, 1);
      expect(result.unintendedDustFee, 0);
    });

    test('Single / Auto Utxo / 수수료 발신자 부담 / 보내는 금액 = 잔액', () {
      final result =
          TransactionBuilder(
            availableUtxos: tAvailableUtxos,
            recipients: singleRecipientSameBalance,
            feeRate: 1.0,
            changeDerivationPath: changeDerivationPath,
            walletListItemBase: taprootWallet,
            isFeeSubtractedFromAmount: false,
            isUtxoFixed: false,
          ).build();

      expect(result.isFailure, isTrue);
      expect(result.transaction, isNull);
      expect(result.exception, isA<InsufficientBalanceException>());
      expect(result.estimatedFee, 201);
      expect(result.selectedUtxos, isNull);
    });

    test('Single / Auto Utxo / 수수료 수신자 부담', () {
      final result =
          TransactionBuilder(
            availableUtxos: tAvailableUtxos,
            recipients: singleRecipient,
            feeRate: 1.0,
            changeDerivationPath: changeDerivationPath,
            walletListItemBase: taprootWallet,
            isFeeSubtractedFromAmount: true,
            isUtxoFixed: false,
          ).build();

      expect(result.isSuccess, isTrue);
      expect(result.estimatedFee, 143);
      expect(result.transaction, isNotNull);
      expect(result.selectedUtxos, isNotNull);
      expect(result.transaction!.outputs.first.amount, lessThan(singleRecipient.values.first));
      expect(
        result.estimatedFee + result.transaction!.outputs.first.amount,
        lessThanOrEqualTo(singleRecipient.values.first),
      );
      expect(result.unintendedDustFee, 0);
    });

    test('Single / Auto Utxo / 수수료 수신자 부담 / 보내는 금액 = 잔액', () {
      final result =
          TransactionBuilder(
            availableUtxos: tAvailableUtxos,
            recipients: singleRecipientSameBalance,
            feeRate: 1.0,
            changeDerivationPath: changeDerivationPath,
            walletListItemBase: taprootWallet,
            isFeeSubtractedFromAmount: true,
            isUtxoFixed: false,
          ).build();

      expect(result.isSuccess, isTrue);
      print(result.estimatedFee);
      expect(result.estimatedFee, 157);
      expect(result.transaction, isNotNull);
      expect(result.transaction!.outputs.first.amount, lessThan(singleRecipientSameBalance.values.first));
      expect(
        result.estimatedFee + result.transaction!.outputs.first.amount,
        lessThanOrEqualTo(singleRecipientSameBalance.values.first),
      );
    });

    test('Single / Auto Utxo / 수수료 수신자 부담 / 보내는 금액 - 예상 수수료 <= dustLimit', () {
      final result =
          TransactionBuilder(
            availableUtxos: tAvailableUtxos,
            recipients: {recipient1: 200},
            feeRate: 10.0,
            changeDerivationPath: changeDerivationPath,
            walletListItemBase: taprootWallet,
            isFeeSubtractedFromAmount: true,
            isUtxoFixed: false,
          ).build();

      expect(result.isFailure, isTrue);
      expect(result.transaction, isNull);
      expect(result.exception, isA<SendAmountTooLowException>());
      print(result.estimatedFee);
      expect(result.estimatedFee, 1435);
    });
  });

  // ─────────────────────────────────────────────────────────────
  // Group 2: SingleTx – Auto UTXO – scriptPath
  // ─────────────────────────────────────────────────────────────
  group('탭루트지갑 - SingleTx - Auto UTXO Selection - scriptPath', () {
    test('Single / Auto Utxo / 수수료 발신자 부담', () {
      final result =
          TransactionBuilder(
            availableUtxos: tAvailableUtxos,
            recipients: singleRecipient,
            feeRate: 1.0,
            changeDerivationPath: changeDerivationPath,
            walletListItemBase: taprootWallet,
            isFeeSubtractedFromAmount: false,
            isUtxoFixed: false,
            scriptPathPolicy: taprootWallet.defaultPolicy!,
          ).build();

      expect(result.isSuccess, isTrue);
      expect(result.estimatedFee, 162);
      expect(result.transaction, isNotNull);
      expect(result.selectedUtxos, isNotNull);
      expect(result.selectedUtxos!.length, 1);
      expect(result.unintendedDustFee, 0);
    });

    test('Single / Auto Utxo / 수수료 발신자 부담 / 보내는 금액 = 잔액', () {
      final result =
          TransactionBuilder(
            availableUtxos: tAvailableUtxos,
            recipients: singleRecipientSameBalance,
            feeRate: 1.0,
            changeDerivationPath: changeDerivationPath,
            walletListItemBase: taprootWallet,
            isFeeSubtractedFromAmount: false,
            isUtxoFixed: false,
            scriptPathPolicy: taprootWallet.defaultPolicy!,
          ).build();

      expect(result.isFailure, isTrue);
      expect(result.transaction, isNull);
      expect(result.exception, isA<InsufficientBalanceException>());
    });

    test('Single / Auto Utxo / 수수료 수신자 부담', () {
      final result =
          TransactionBuilder(
            availableUtxos: tAvailableUtxos,
            recipients: singleRecipient,
            feeRate: 1.0,
            changeDerivationPath: changeDerivationPath,
            walletListItemBase: taprootWallet,
            isFeeSubtractedFromAmount: true,
            isUtxoFixed: false,
            scriptPathPolicy: taprootWallet.defaultPolicy!,
          ).build();

      expect(result.isSuccess, isTrue);
      expect(result.estimatedFee, 162);
      expect(result.transaction, isNotNull);
      expect(result.transaction!.outputs.first.amount, lessThan(singleRecipient.values.first));
      expect(
        result.estimatedFee + result.transaction!.outputs.first.amount,
        lessThanOrEqualTo(singleRecipient.values.first),
      );
      expect(result.unintendedDustFee, 0);
    });
  });

  // ─────────────────────────────────────────────────────────────
  // Group 3: taprootSpendType 미지정 → defaultSpendType 사용
  // ─────────────────────────────────────────────────────────────
  group('탭루트지갑 - taprootSpendType 미지정', () {
    test('Single / Auto Utxo / 수수료 발신자 부담 → defaultSpendType(keyPath) 수수료 동일', () {
      final resultDefault =
          TransactionBuilder(
            availableUtxos: tAvailableUtxos,
            recipients: singleRecipient,
            feeRate: 1.0,
            changeDerivationPath: changeDerivationPath,
            walletListItemBase: taprootWallet,
            isFeeSubtractedFromAmount: false,
            isUtxoFixed: false,
          ).build();

      final resultKeyPath =
          TransactionBuilder(
            availableUtxos: tAvailableUtxos,
            recipients: singleRecipient,
            feeRate: 1.0,
            changeDerivationPath: changeDerivationPath,
            walletListItemBase: taprootWallet,
            isFeeSubtractedFromAmount: false,
            isUtxoFixed: false,
          ).build();

      expect(resultDefault.isSuccess, isTrue);
      expect(resultDefault.estimatedFee, equals(resultKeyPath.estimatedFee));
      expect(resultDefault.selectedUtxos!.length, equals(resultKeyPath.selectedUtxos!.length));
    });

    test('Single / Auto Utxo / 수수료 수신자 부담 → defaultSpendType(keyPath) 수수료 동일', () {
      final resultDefault =
          TransactionBuilder(
            availableUtxos: tAvailableUtxos,
            recipients: singleRecipient,
            feeRate: 1.0,
            changeDerivationPath: changeDerivationPath,
            walletListItemBase: taprootWallet,
            isFeeSubtractedFromAmount: true,
            isUtxoFixed: false,
          ).build();

      final resultKeyPath =
          TransactionBuilder(
            availableUtxos: tAvailableUtxos,
            recipients: singleRecipient,
            feeRate: 1.0,
            changeDerivationPath: changeDerivationPath,
            walletListItemBase: taprootWallet,
            isFeeSubtractedFromAmount: true,
            isUtxoFixed: false,
          ).build();

      expect(resultDefault.isSuccess, isTrue);
      expect(resultDefault.estimatedFee, equals(resultKeyPath.estimatedFee));
      expect(resultDefault.transaction!.outputs.first.amount, equals(resultKeyPath.transaction!.outputs.first.amount));
    });

    test('Single / Auto Utxo / 잔액 부족 → InsufficientBalanceException', () {
      final result =
          TransactionBuilder(
            availableUtxos: tAvailableUtxos,
            recipients: singleRecipientSameBalance,
            feeRate: 1.0,
            changeDerivationPath: changeDerivationPath,
            walletListItemBase: taprootWallet,
            isFeeSubtractedFromAmount: false,
            isUtxoFixed: false,
          ).build();

      expect(result.isFailure, isTrue);
      expect(result.exception, isA<InsufficientBalanceException>());
    });

    test('Single / Manual Utxo / 수수료 발신자 부담 → defaultSpendType(keyPath) 수수료 동일', () {
      final resultDefault =
          TransactionBuilder(
            availableUtxos: [tAvailableUtxos[0]],
            recipients: singleRecipient,
            feeRate: 1.0,
            changeDerivationPath: changeDerivationPath,
            walletListItemBase: taprootWallet,
            isFeeSubtractedFromAmount: false,
            isUtxoFixed: true,
          ).build();

      final resultKeyPath =
          TransactionBuilder(
            availableUtxos: [tAvailableUtxos[0]],
            recipients: singleRecipient,
            feeRate: 1.0,
            changeDerivationPath: changeDerivationPath,
            walletListItemBase: taprootWallet,
            isFeeSubtractedFromAmount: false,
            isUtxoFixed: true,
          ).build();

      expect(resultDefault.isSuccess, isTrue);
      expect(resultDefault.estimatedFee, equals(resultKeyPath.estimatedFee));
    });

    test('Batch / Auto Utxo / 수수료 발신자 부담 → defaultSpendType(keyPath) 수수료 동일', () {
      final resultDefault =
          TransactionBuilder(
            availableUtxos: tAvailableUtxos,
            recipients: batchRecipients,
            feeRate: 1.0,
            changeDerivationPath: changeDerivationPath,
            walletListItemBase: taprootWallet,
            isFeeSubtractedFromAmount: false,
            isUtxoFixed: false,
          ).build();

      final resultKeyPath =
          TransactionBuilder(
            availableUtxos: tAvailableUtxos,
            recipients: batchRecipients,
            feeRate: 1.0,
            changeDerivationPath: changeDerivationPath,
            walletListItemBase: taprootWallet,
            isFeeSubtractedFromAmount: false,
            isUtxoFixed: false,
          ).build();

      expect(resultDefault.isSuccess, isTrue);
      expect(resultDefault.estimatedFee, equals(resultKeyPath.estimatedFee));
      expect(resultDefault.transaction!.inputs.length, equals(resultKeyPath.transaction!.inputs.length));
      expect(resultDefault.transaction!.outputs.length, equals(resultKeyPath.transaction!.outputs.length));
    });
  });

  // ─────────────────────────────────────────────────────────────
  // Group 4: SingleTx – Manual UTXO
  // ─────────────────────────────────────────────────────────────
  group('탭루트지갑 - SingleTx - Manual UTXO Selection', () {
    test('Single / Manual Utxo / 수수료 발신자 부담 / input 1개', () {
      final result =
          TransactionBuilder(
            availableUtxos: [tAvailableUtxos[0]],
            recipients: singleRecipient,
            feeRate: 1.0,
            changeDerivationPath: changeDerivationPath,
            walletListItemBase: taprootWallet,
            isFeeSubtractedFromAmount: false,
            isUtxoFixed: true,
          ).build();

      expect(result.isSuccess, isTrue);
      expect(result.transaction!.inputs.length, 1);
      expect(result.transaction!.outputs.length, 2);
      expect(result.estimatedFee, 143); // TODO: update with exact keyPath base fee after running
      expect(result.unintendedDustFee, 0);
    });

    test('Single / Manual Utxo / 수수료 발신자 부담 / input 2개', () {
      final result =
          TransactionBuilder(
            availableUtxos: tAvailableUtxos,
            recipients: singleRecipient,
            feeRate: 1.0,
            changeDerivationPath: changeDerivationPath,
            walletListItemBase: taprootWallet,
            isFeeSubtractedFromAmount: false,
            isUtxoFixed: true,
          ).build();

      expect(result.isSuccess, isTrue);
      expect(result.transaction!.inputs.length, 2);
      expect(result.transaction!.outputs.length, 2);
      expect(result.estimatedFee, 200);
      expect(result.selectedUtxos, isNotNull);
      expect(result.unintendedDustFee, 0);
    });

    test('Single / Manual Utxo / 수수료 발신자 부담 / 보내는 금액 = 잔액', () {
      final result =
          TransactionBuilder(
            availableUtxos: tAvailableUtxos,
            recipients: singleRecipientSameBalance,
            feeRate: 1.0,
            changeDerivationPath: changeDerivationPath,
            walletListItemBase: taprootWallet,
            isFeeSubtractedFromAmount: false,
            isUtxoFixed: true,
          ).build();

      expect(result.isFailure, isTrue);
      expect(result.transaction, isNull);
      expect(result.exception, isA<InsufficientBalanceException>());
      expect(result.estimatedFee, 200);
      expect(result.selectedUtxos, isNotNull);
    });

    test('Single / Manual Utxo / 수수료 수신자 부담', () {
      final result =
          TransactionBuilder(
            availableUtxos: tAvailableUtxos,
            recipients: singleRecipient,
            feeRate: 1.0,
            changeDerivationPath: changeDerivationPath,
            walletListItemBase: taprootWallet,
            isFeeSubtractedFromAmount: true,
            isUtxoFixed: true,
          ).build();

      expect(result.isSuccess, isTrue);
      print(result.estimatedFee);
      expect(result.estimatedFee, 200);
      expect(result.transaction, isNotNull);
      expect(result.selectedUtxos, isNotNull);
      expect(result.transaction!.outputs.first.amount, lessThan(singleRecipient.values.first));
      expect(
        result.estimatedFee + result.transaction!.outputs.first.amount,
        lessThanOrEqualTo(singleRecipient.values.first),
      );
      expect(result.unintendedDustFee, 0);
    });

    test('Single / Manual Utxo / 수수료 수신자 부담 / 보내는 금액 = 잔액', () {
      final result =
          TransactionBuilder(
            availableUtxos: tAvailableUtxos,
            recipients: singleRecipientSameBalance,
            feeRate: 1.0,
            changeDerivationPath: changeDerivationPath,
            walletListItemBase: taprootWallet,
            isFeeSubtractedFromAmount: true,
            isUtxoFixed: true,
          ).build();

      expect(result.isSuccess, isTrue);
      print(result.estimatedFee);
      expect(result.estimatedFee, 157);
      expect(result.transaction, isNotNull);
      expect(result.transaction!.outputs.first.amount, lessThan(singleRecipientSameBalance.values.first));
      expect(
        result.estimatedFee + result.transaction!.outputs.first.amount,
        lessThanOrEqualTo(singleRecipientSameBalance.values.first),
      );
    });

    test('Single / Manual Utxo / 수수료 수신자 부담 / 보내는 금액 - 예상 수수료 <= dustLimit', () {
      // Non-sweep: 2 UTXOs selected, initialFee ≈ 194 > recipient(200) → sendAmount ≤ dustThreshold
      final result =
          TransactionBuilder(
            availableUtxos: tAvailableUtxos,
            recipients: {recipient1: 200},
            feeRate: 1.0,
            changeDerivationPath: changeDerivationPath,
            walletListItemBase: taprootWallet,
            isFeeSubtractedFromAmount: true,
            isUtxoFixed: true,
          ).build();

      expect(result.isFailure, isTrue);
      expect(result.transaction, isNull);
      expect(result.exception, isA<SendAmountTooLowException>());
      print(result.estimatedFee);
      expect(result.estimatedFee, 195);
      expect(result.selectedUtxos, isNotNull);
    });
  });

  // ─────────────────────────────────────────────────────────────
  // Group 5: BatchTx – Auto UTXO
  // ─────────────────────────────────────────────────────────────
  group('탭루트지갑 - BatchTx - Auto UTXO Selection', () {
    test('Batch / Auto Utxo / 수수료 발신자 부담 / keyPath', () {
      final result =
          TransactionBuilder(
            availableUtxos: tAvailableUtxos,
            recipients: batchRecipients,
            feeRate: 1.0,
            changeDerivationPath: changeDerivationPath,
            walletListItemBase: taprootWallet,
            isFeeSubtractedFromAmount: false,
            isUtxoFixed: false,
          ).build();

      expect(result.isSuccess, isTrue);
      print(result.estimatedFee);
      expect(result.estimatedFee, 174);
      expect(result.transaction!.inputs.length, 1);
      expect(result.transaction!.outputs.length, 3);
      expect(result.unintendedDustFee, 0);
    });

    test('Batch / Auto Utxo / 수수료 발신자 부담 / scriptPath', () {
      final result =
          TransactionBuilder(
            availableUtxos: tAvailableUtxos,
            recipients: batchRecipients,
            feeRate: 1.0,
            changeDerivationPath: changeDerivationPath,
            walletListItemBase: taprootWallet,
            isFeeSubtractedFromAmount: false,
            isUtxoFixed: false,
            scriptPathPolicy: taprootWallet.defaultPolicy!,
          ).build();

      expect(result.isSuccess, isTrue);
      print(result.estimatedFee);
      expect(result.estimatedFee, 193);
      expect(result.transaction!.inputs.length, 1);
      expect(result.transaction!.outputs.length, 3);
      expect(result.unintendedDustFee, 0);
    });

    test('Batch / Auto Utxo / 수수료 발신자 부담 / 수수료율 높음', () {
      final result =
          TransactionBuilder(
            availableUtxos: tAvailableUtxos,
            recipients: batchRecipients,
            feeRate: 1800.0,
            changeDerivationPath: changeDerivationPath,
            walletListItemBase: taprootWallet,
            isFeeSubtractedFromAmount: false,
            isUtxoFixed: false,
          ).build();

      expect(result.isSuccess, isFalse);
      expect(result.exception, isA<InsufficientBalanceException>());
      print(result.estimatedFee);
      expect(result.estimatedFee, 417600);
      expect(result.transaction, isNull);
    });

    test('Batch / Auto Utxo / 수수료 발신자 부담 / 보내는 금액 합 = 잔액', () {
      final result =
          TransactionBuilder(
            availableUtxos: tAvailableUtxos,
            recipients: batchRecipientsSameBalance,
            feeRate: 1.0,
            changeDerivationPath: changeDerivationPath,
            walletListItemBase: taprootWallet,
            isFeeSubtractedFromAmount: false,
            isUtxoFixed: false,
          ).build();

      expect(result.isFailure, isTrue);
      expect(result.exception, isA<InsufficientBalanceException>());
    });

    test('Batch / Auto Utxo / 수수료 수신자 부담 / keyPath', () {
      final result =
          TransactionBuilder(
            availableUtxos: tAvailableUtxos,
            recipients: batchRecipients,
            feeRate: 1.0,
            changeDerivationPath: changeDerivationPath,
            walletListItemBase: taprootWallet,
            isFeeSubtractedFromAmount: true,
            isUtxoFixed: false,
          ).build();

      expect(result.isSuccess, isTrue);
      print(result.estimatedFee);
      expect(result.estimatedFee, 174);
      expect(result.transaction, isNotNull);
      expect(result.transaction!.inputs.length, 1);
      expect(result.transaction!.outputs.length, 3);
      expect(result.selectedUtxos, isNotNull);
      final totalOutputAmount = result.transaction!.outputs.fold(0, (s, o) => s + o.amount);
      final totalBalance = tAvailableUtxos.fold(0, (s, u) => s + u.amount);
      expect(totalOutputAmount + result.estimatedFee, lessThanOrEqualTo(totalBalance));
      expect(result.unintendedDustFee, 0);
    });

    test('Batch / Auto Utxo / 수수료 수신자 부담 / 보내는 금액 합 > 잔액', () {
      final result =
          TransactionBuilder(
            availableUtxos: tAvailableUtxos,
            recipients: batchRecipientsOverBalance,
            feeRate: 1.0,
            changeDerivationPath: changeDerivationPath,
            walletListItemBase: taprootWallet,
            isFeeSubtractedFromAmount: true,
            isUtxoFixed: false,
          ).build();

      expect(result.isSuccess, isFalse);
      expect(result.transaction, isNull);
      expect(result.exception, isA<InsufficientBalanceException>());
    });
  });

  // ─────────────────────────────────────────────────────────────
  // Group 6: BatchTx – Manual UTXO
  // ─────────────────────────────────────────────────────────────
  group('탭루트지갑 - BatchTx - Manual UTXO Selection', () {
    test('Batch / Manual Utxo / 수수료 발신자 부담', () {
      final result =
          TransactionBuilder(
            availableUtxos: tAvailableUtxos,
            recipients: batchRecipients,
            feeRate: 1.0,
            changeDerivationPath: changeDerivationPath,
            walletListItemBase: taprootWallet,
            isFeeSubtractedFromAmount: false,
            isUtxoFixed: true,
          ).build();

      expect(result.isSuccess, isTrue);
      print(result.estimatedFee);
      expect(result.estimatedFee, 231);
      expect(result.transaction, isNotNull);
      expect(result.transaction!.inputs.length, 2);
      expect(result.transaction!.outputs.length, 3);
      expect(result.transaction!.outputs[1].amount, equals(batchRecipients.values.last));
      expect(
        result.transaction!.outputs.last.amount,
        equals(sumOfBalance - sumOfBatchRecipients - result.estimatedFee),
      );
      expect(result.unintendedDustFee, 0);
    });

    test('Batch / Manual Utxo / 수수료 수신자 부담', () {
      final result =
          TransactionBuilder(
            availableUtxos: tAvailableUtxos,
            recipients: batchRecipients,
            feeRate: 1.0,
            changeDerivationPath: changeDerivationPath,
            walletListItemBase: taprootWallet,
            isFeeSubtractedFromAmount: true,
            isUtxoFixed: true,
          ).build();

      expect(result.isSuccess, isTrue);
      print(result.estimatedFee);
      expect(result.estimatedFee, 231);
      expect(result.transaction, isNotNull);
      expect(result.transaction!.inputs.length, 2);
      expect(result.transaction!.outputs.length, 3);
      expect(result.transaction!.outputs[1].amount, lessThan(batchRecipients.values.last));
      expect(
        result.transaction!.outputs[1].amount + result.estimatedFee,
        lessThanOrEqualTo(batchRecipients.values.last),
      );
      expect(result.transaction!.outputs.last.amount, greaterThanOrEqualTo(sumOfBalance - sumOfBatchRecipients));
      expect(result.unintendedDustFee, 0);
    });

    test('Batch / Manual Utxo / 수수료 수신자 부담 / 마지막 보내는 금액 dustLimit 이하', () {
      // keyPath fee (2 inputs, 3 outputs) ≈ 229 vB → fee at 200 sat/vB ≈ 45800
      // lastSendAmount = 40000 - 45800 < 0 ≤ dustThreshold → SendAmountTooLowException
      final result =
          TransactionBuilder(
            availableUtxos: tAvailableUtxos,
            recipients: batchRecipients,
            feeRate: 200.0,
            changeDerivationPath: changeDerivationPath,
            walletListItemBase: taprootWallet,
            isFeeSubtractedFromAmount: true,
            isUtxoFixed: true,
          ).build();

      expect(result.isSuccess, isFalse);
      print(result.estimatedFee);
      expect(result.estimatedFee, 45800);
      expect(result.transaction, isNull);
      expect(result.selectedUtxos, isNotNull);
      expect(result.exception, isA<SendAmountTooLowException>());
    });
  });

  // ─────────────────────────────────────────────────────────────
  // Group 7: copyWith
  // ─────────────────────────────────────────────────────────────
  group('탭루트지갑 - copyWith', () {
    test('keyPath → scriptPath: scriptPath fee 추정으로 UTXO 2개 선택', () {
      // UTXOs sorted desc: [200000, 100000]. With recipient=199850:
      // keyPath fee est (1 input) ≈ 136 → 200000 ≥ 199850+136=199986 → 1 UTXO
      // scriptPath fee est (1 input) ≈ 155 → 200000 < 199850+155=200005 → 2 UTXOs
      final builder = TransactionBuilder(
        availableUtxos: tAvailableUtxos,
        recipients: {recipient1: 199850},
        feeRate: 1.0,
        changeDerivationPath: changeDerivationPath,
        walletListItemBase: taprootWallet,
        isFeeSubtractedFromAmount: false,
        isUtxoFixed: false,
      );

      final keyPathResult = builder.build();
      final scriptPathResult =
          builder.copyWith(taprootPolicy: (taprootWallet.walletBase as TaprootWallet).policyList[0]).build();

      expect(keyPathResult.isSuccess, isTrue);
      expect(scriptPathResult.isSuccess, isTrue);
      expect(keyPathResult.selectedUtxos!.length, 1);
      expect(scriptPathResult.selectedUtxos!.length, 2);
    });

    test('isFeeSubtractedFromAmount 변경: change output amount 비교', () {
      final builder = TransactionBuilder(
        availableUtxos: tAvailableUtxos,
        recipients: singleRecipient,
        feeRate: 1.0,
        changeDerivationPath: changeDerivationPath,
        walletListItemBase: taprootWallet,
        isFeeSubtractedFromAmount: false,
        isUtxoFixed: false,
      );

      final result1 = builder.build();
      final result2 = builder.copyWith(isFeeSubtractedFromAmount: true).build();

      expect(result1.transaction!.outputs.last.amount, lessThan(result2.transaction!.outputs.last.amount));
    });
  });

  // ─────────────────────────────────────────────────────────────
  // Group 8: UtxoSelector와 TransactionBuilder 결과 비교
  // ─────────────────────────────────────────────────────────────
  group('탭루트지갑 - UtxoSelector와 TransactionBuilder 결과 비교', () {
    test('KeyPath 서명, UtxoSelector의 estimatedFee가 크거나 같아야 함', () {
      final paymentMap = {recipient1: 4000};
      const feeRate = 1.0;
      final utxoSelectorResult = UtxoSelector.selectOptimalUtxos(
        tAvailableUtxos,
        paymentMap,
        feeRate,
        WalletType.taproot,
        taprootSpendType: TaprootSpendType.keyPath,
      );

      final builder = TransactionBuilder(
        availableUtxos: tAvailableUtxos,
        recipients: paymentMap,
        feeRate: feeRate,
        changeDerivationPath: changeDerivationPath,
        walletListItemBase: taprootWallet,
        isFeeSubtractedFromAmount: false,
        isUtxoFixed: false,
      );

      final keyPathResult = builder.build();
      // final scriptPathResult =
      //     builder.copyWith(taprootPolicy: (taprootWallet.walletBase as TaprootWallet).policyList[0]).build();

      expect(keyPathResult.isSuccess, isTrue);
      expect(keyPathResult.selectedUtxos!.length, 1);
      print('utxoSelectorResult.estimatedFee: ${utxoSelectorResult.estimatedFee}');
      print('keyPathResult.estimatedFee: ${keyPathResult.estimatedFee}');
      expect(utxoSelectorResult.estimatedFee, greaterThanOrEqualTo(keyPathResult.estimatedFee));
    });

    test('ScriptPath 서명, UtxoSelector의 estimatedFee가 크거나 같아야 함', () {
      final paymentMap = {recipient1: 4000};
      const feeRate = 1.0;
      final utxoSelectorResult = UtxoSelector.selectOptimalUtxos(
        tAvailableUtxos,
        paymentMap,
        feeRate,
        WalletType.taproot,
        taprootConfig: taprootWallet.scriptPathConfigFor(taprootWallet.defaultPolicy!),
        taprootSpendType: TaprootSpendType.scriptPath,
      );

      final builder = TransactionBuilder(
        availableUtxos: tAvailableUtxos,
        recipients: paymentMap,
        feeRate: feeRate,
        changeDerivationPath: changeDerivationPath,
        walletListItemBase: taprootWallet,
        isFeeSubtractedFromAmount: false,
        isUtxoFixed: false,
        scriptPathPolicy: taprootWallet.defaultPolicy!,
      );

      final scriptPathResult = builder.build();
      // final scriptPathResult =
      //     builder.copyWith(taprootPolicy: (taprootWallet.walletBase as TaprootWallet).policyList[0]).build();

      expect(scriptPathResult.isSuccess, isTrue);
      expect(scriptPathResult.selectedUtxos!.length, 1);
      print('utxoSelectorResult.estimatedFee: ${utxoSelectorResult.estimatedFee}');
      print('scriptPathResult.estimatedFee: ${scriptPathResult.estimatedFee}');
      expect(utxoSelectorResult.estimatedFee, greaterThanOrEqualTo(scriptPathResult.estimatedFee));
    });
  });
}
