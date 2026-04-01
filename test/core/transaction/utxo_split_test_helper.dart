import 'package:coconut_wallet/constants/bitcoin_network_rules.dart';
import 'package:coconut_wallet/core/transaction/utxo_split_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void expectSuccessfulTransaction(UtxoSplitResult result, {int? expectedOutputCount}) {
  expect(result.isSuccess, isTrue);
  expect(result.transaction, isNotNull);
  expect(result.transaction!.inputs.length, 1);

  final splitMapOutputCount = result.splitAmountMap.values.fold<int>(0, (sum, c) => sum + c);
  expect(result.transaction!.outputs.length, splitMapOutputCount);
  if (expectedOutputCount != null) {
    expect(result.transaction!.outputs.length, expectedOutputCount);
  }

  for (final output in result.transaction!.outputs) {
    expect(output.amount, greaterThan(dustLimit));
  }
}
