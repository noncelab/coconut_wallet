import 'package:coconut_lib/coconut_lib.dart';

enum TransactionIntentMismatch {
  missingTransaction,
  version,
  lockTime,
  inputCount,
  inputTransactionHash,
  inputIndex,
  inputSequence,
  outputCount,
  outputAmount,
  outputScriptPubKey,
}

class TransactionIntentValidationResult {
  final TransactionIntentMismatch? mismatch;
  final int? itemIndex;

  const TransactionIntentValidationResult.match() : mismatch = null, itemIndex = null;

  const TransactionIntentValidationResult.mismatch(this.mismatch, {this.itemIndex});

  bool get isValid => mismatch == null;

  String get fieldPath {
    final index = itemIndex ?? '?';
    return switch (mismatch) {
      TransactionIntentMismatch.missingTransaction => 'transaction',
      TransactionIntentMismatch.version => 'version',
      TransactionIntentMismatch.lockTime => 'lockTime',
      TransactionIntentMismatch.inputCount => 'inputs.length',
      TransactionIntentMismatch.inputTransactionHash => 'inputs[$index].txid',
      TransactionIntentMismatch.inputIndex => 'inputs[$index].vout',
      TransactionIntentMismatch.inputSequence => 'inputs[$index].sequence',
      TransactionIntentMismatch.outputCount => 'outputs.length',
      TransactionIntentMismatch.outputAmount => 'outputs[$index].amount',
      TransactionIntentMismatch.outputScriptPubKey => 'outputs[$index].scriptPubKey',
      null => 'unknown',
    };
  }
}

class TransactionIntentMismatchException implements Exception {
  final TransactionIntentValidationResult result;

  const TransactionIntentMismatchException(this.result);

  @override
  String toString() => 'Transaction intent mismatch: ${result.fieldPath}';
}

class TransactionIntentValidator {
  const TransactionIntentValidator._();

  static TransactionIntentValidationResult validate(Transaction? expected, Transaction? actual) {
    if (expected == null || actual == null) {
      return const TransactionIntentValidationResult.mismatch(TransactionIntentMismatch.missingTransaction);
    }

    if (expected.version != actual.version) {
      return const TransactionIntentValidationResult.mismatch(TransactionIntentMismatch.version);
    }
    if (expected.lockTime != actual.lockTime) {
      return const TransactionIntentValidationResult.mismatch(TransactionIntentMismatch.lockTime);
    }
    if (expected.inputs.length != actual.inputs.length) {
      return const TransactionIntentValidationResult.mismatch(TransactionIntentMismatch.inputCount);
    }

    for (var index = 0; index < expected.inputs.length; index++) {
      final expectedInput = expected.inputs[index];
      final actualInput = actual.inputs[index];

      if (expectedInput.transactionHash != actualInput.transactionHash) {
        return TransactionIntentValidationResult.mismatch(
          TransactionIntentMismatch.inputTransactionHash,
          itemIndex: index,
        );
      }
      if (expectedInput.index != actualInput.index) {
        return TransactionIntentValidationResult.mismatch(TransactionIntentMismatch.inputIndex, itemIndex: index);
      }
      if (expectedInput.sequence != actualInput.sequence) {
        return TransactionIntentValidationResult.mismatch(TransactionIntentMismatch.inputSequence, itemIndex: index);
      }
    }

    if (expected.outputs.length != actual.outputs.length) {
      return const TransactionIntentValidationResult.mismatch(TransactionIntentMismatch.outputCount);
    }

    for (var index = 0; index < expected.outputs.length; index++) {
      final expectedOutput = expected.outputs[index];
      final actualOutput = actual.outputs[index];

      if (expectedOutput.amount != actualOutput.amount) {
        return TransactionIntentValidationResult.mismatch(TransactionIntentMismatch.outputAmount, itemIndex: index);
      }
      if (expectedOutput.scriptPubKey.serialize() != actualOutput.scriptPubKey.serialize()) {
        return TransactionIntentValidationResult.mismatch(
          TransactionIntentMismatch.outputScriptPubKey,
          itemIndex: index,
        );
      }
    }

    return const TransactionIntentValidationResult.match();
  }

  static bool matches(Transaction? expected, Transaction? actual) => validate(expected, actual).isValid;

  static void ensureMatches(Transaction? expected, Transaction? actual) {
    final result = validate(expected, actual);
    if (!result.isValid) {
      throw TransactionIntentMismatchException(result);
    }
  }
}
