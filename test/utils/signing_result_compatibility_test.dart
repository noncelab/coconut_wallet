import 'dart:convert';
import 'dart:io';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/utils/transaction_intent_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() {
    NetworkType.setNetworkType(NetworkType.regtest);
  });

  tearDownAll(() {
    NetworkType.setNetworkType(NetworkType.testnet);
  });

  const fixtureExpectations = {
    'trezor_usb': (source: 'trezor_usb', resultType: 'psbt'),
    'bitbox02_usb': (source: 'bitbox02_usb', resultType: 'psbt'),
    'coldcard_raw': (source: 'airgap_raw_coldCard', resultType: 'raw_transaction'),
  };

  for (final fixtureEntry in fixtureExpectations.entries) {
    final fixtureName = fixtureEntry.key;
    final expectedMetadata = fixtureEntry.value;
    group('$fixtureName signing result compatibility', () {
      late Map<String, dynamic> fixture;
      late Psbt unsignedPsbt;
      Psbt? signedPsbt;
      late Transaction returnedTransaction;

      setUpAll(() {
        final fixtureJson = File('test/fixtures/signing/$fixtureName.json').readAsStringSync();
        fixture = jsonDecode(fixtureJson) as Map<String, dynamic>;
        unsignedPsbt = Psbt.parse(fixture['unsignedPsbt'] as String);
        final returnedPayload = fixture['returnedPayload'] as String;
        if (expectedMetadata.resultType == 'psbt') {
          signedPsbt = Psbt.parse(returnedPayload);
          returnedTransaction = signedPsbt!.unsignedTransaction!;
        } else {
          returnedTransaction = Transaction.parse(returnedPayload);
        }
      });

      test('fixture metadata identifies the expected regtest signing result', () {
        expect(fixture['schemaVersion'], 1);
        expect(fixture['source'], expectedMetadata.source);
        expect(fixture['network'], 'regtest');
        expect(fixture['resultType'], expectedMetadata.resultType);
      });

      test('captured unsigned and returned payloads are parseable', () {
        expect(unsignedPsbt.unsignedTransaction, isNotNull);
        expect(returnedTransaction.inputs, isNotEmpty);
      });

      test('returned payload preserves the original transaction intent', () {
        _expectSameTransactionIntent(unsignedPsbt.unsignedTransaction!, returnedTransaction);
      });

      if (expectedMetadata.resultType == 'psbt') {
        test('returned PSBT can be finalized without changing transaction intent', () {
          final finalizedTransaction = signedPsbt!.getSignedTransaction(AddressType.p2wpkh);

          _expectSameTransactionIntent(unsignedPsbt.unsignedTransaction!, finalizedTransaction);
        });
      }
    });
  }

  group('TransactionIntentValidator rejects modified intent', () {
    const firstHash = '1111111111111111111111111111111111111111111111111111111111111111';
    const secondHash = '2222222222222222222222222222222222222222222222222222222222222222';
    const firstAddress = 'bcrt1qh22yl57ys0vaaln9nfp4zczj2fshjnl6gnsh66';
    const secondAddress = 'bcrt1qve37yvsmqksx93j6gqsnz862qpzfa0xya0yvve';

    Transaction transaction({
      int version = 2,
      int lockTime = 0,
      List<TransactionInput>? inputs,
      List<TransactionOutput>? outputs,
    }) {
      return Transaction.withInputsAndOutputs(
        inputs ?? [TransactionInput.forPayment(firstHash, 0, sequence: 0xfffffffd)],
        outputs ?? [TransactionOutput.forPayment(10000, firstAddress)],
        AddressType.p2wpkh,
        version: version,
        lockTime: lockTime,
      );
    }

    void expectMismatch(Transaction expected, Transaction actual, TransactionIntentMismatch mismatch) {
      final result = TransactionIntentValidator.validate(expected, actual);
      expect(result.isValid, isFalse);
      expect(result.mismatch, mismatch);
    }

    test('accepts identical transaction intent', () {
      expect(TransactionIntentValidator.matches(transaction(), transaction()), isTrue);
    });

    test('rejects a changed version', () {
      expectMismatch(transaction(), transaction(version: 1), TransactionIntentMismatch.version);
    });

    test('rejects a changed locktime', () {
      expectMismatch(transaction(), transaction(lockTime: 1), TransactionIntentMismatch.lockTime);
    });

    test('rejects a changed input count', () {
      expectMismatch(transaction(), transaction(inputs: []), TransactionIntentMismatch.inputCount);
    });

    test('rejects a changed input transaction hash', () {
      expectMismatch(
        transaction(),
        transaction(inputs: [TransactionInput.forPayment(secondHash, 0, sequence: 0xfffffffd)]),
        TransactionIntentMismatch.inputTransactionHash,
      );
    });

    test('rejects a changed input index', () {
      expectMismatch(
        transaction(),
        transaction(inputs: [TransactionInput.forPayment(firstHash, 1, sequence: 0xfffffffd)]),
        TransactionIntentMismatch.inputIndex,
      );
    });

    test('rejects a changed input sequence', () {
      expectMismatch(
        transaction(),
        transaction(inputs: [TransactionInput.forPayment(firstHash, 0, sequence: 0xfffffffc)]),
        TransactionIntentMismatch.inputSequence,
      );
    });

    test('rejects a changed output count', () {
      expectMismatch(transaction(), transaction(outputs: []), TransactionIntentMismatch.outputCount);
    });

    test('rejects a changed output amount', () {
      expectMismatch(
        transaction(),
        transaction(outputs: [TransactionOutput.forPayment(10001, firstAddress)]),
        TransactionIntentMismatch.outputAmount,
      );
    });

    test('rejects a changed output scriptPubKey', () {
      expectMismatch(
        transaction(),
        transaction(outputs: [TransactionOutput.forPayment(10000, secondAddress)]),
        TransactionIntentMismatch.outputScriptPubKey,
      );
    });

    test('rejects changed input order', () {
      final firstInput = TransactionInput.forPayment(firstHash, 0, sequence: 0xfffffffd);
      final secondInput = TransactionInput.forPayment(secondHash, 1, sequence: 0xfffffffc);
      expectMismatch(
        transaction(inputs: [firstInput, secondInput]),
        transaction(inputs: [secondInput, firstInput]),
        TransactionIntentMismatch.inputTransactionHash,
      );
    });

    test('rejects changed output order', () {
      final firstOutput = TransactionOutput.forPayment(10000, firstAddress);
      final secondOutput = TransactionOutput.forPayment(20000, secondAddress);
      expectMismatch(
        transaction(outputs: [firstOutput, secondOutput]),
        transaction(outputs: [secondOutput, firstOutput]),
        TransactionIntentMismatch.outputAmount,
      );
    });

    test('reports the mismatched field path', () {
      final result = TransactionIntentValidator.validate(
        transaction(),
        transaction(outputs: [TransactionOutput.forPayment(10001, firstAddress)]),
      );

      expect(result.fieldPath, 'outputs[0].amount');
      expect(TransactionIntentMismatchException(result).toString(), 'Transaction intent mismatch: outputs[0].amount');
    });
  });
}

void _expectSameTransactionIntent(Transaction expected, Transaction actual) {
  final result = TransactionIntentValidator.validate(expected, actual);
  expect(result.isValid, isTrue, reason: '${result.mismatch?.name}[${result.itemIndex}]');
}
