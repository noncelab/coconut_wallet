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

Future<void> expectEqualSplitAmountsNearNiceAmounts(
  UtxoSplitBuilder builder,
  Map<int, int> expectedNiceAmountByCount, {
  int tolerance = 10000,
}) async {
  for (final entry in expectedNiceAmountByCount.entries) {
    final result = await builder.buildEqualSplit(splitCount: entry.key);

    expectSuccessfulTransaction(result, expectedOutputCount: entry.key);
    expect(result.splitAmountMap.keys, everyElement(inInclusiveRange(entry.value - tolerance, entry.value)));
  }
}
