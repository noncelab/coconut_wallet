import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/providers/node_provider/transaction/transaction_record_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TransactionType typeOf(int selfIn, int selfOut, int ins, int outs, int net) => transactionTypeOf(
    selfInputCount: selfIn,
    selfOutputCount: selfOut,
    inputCount: ins,
    outputCount: outs,
    netAmount: net,
  );

  test('a payjoin the wallet received counts as received', () {
    // Sender's input + ours in; sender's change + our (larger) output out.
    expect(typeOf(1, 1, 2, 2, 40000), TransactionType.received);
  });

  test('a payjoin the wallet sent counts as sent', () {
    // Our input + the receiver's in; our change + the receiver's output out.
    expect(typeOf(1, 1, 2, 2, -40150), TransactionType.sent);
  });

  test('ordinary transactions keep their type', () {
    expect(typeOf(0, 1, 1, 2, 40000), TransactionType.received);
    expect(typeOf(1, 1, 1, 2, -40150), TransactionType.sent);
    expect(typeOf(2, 2, 2, 2, -300), TransactionType.self);
    expect(
      transactionTypeOf(selfInputCount: 1, selfOutputCount: 1, inputCount: 2, outputCount: 2),
      TransactionType.sent,
      reason: 'without a net amount the old rule applies',
    );
  });

  test('a payjoin spends inputs of both wallets', () {
    bool isOurs(String address) => address.startsWith('ours');
    expect(spendsCounterpartyInputs(['ours1', 'theirs1'], isOurs: isOurs), isTrue);
    expect(spendsCounterpartyInputs(['ours1', 'ours2'], isOurs: isOurs), isFalse);
    expect(spendsCounterpartyInputs(['theirs1'], isOurs: isOurs), isFalse);
    expect(spendsCounterpartyInputs([], isOurs: isOurs), isFalse);
  });
}
