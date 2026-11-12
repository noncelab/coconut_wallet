import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/utils/payment_request_parser.dart';
import 'package:coconut_wallet/utils/send_recipients.dart';
import 'package:flutter_test/flutter_test.dart';

const _bitcoin = 'bcrt1q7kcrvjzszlxme7fgs2euvv6lkgf99jdu8zjnus';
const _otherBitcoin = 'bcrt1qve37yvsmqksx93j6gqsnz862qpzfa0xya0yvve';
const _ark =
    'tark1pqma5v23zqqp5z47f6anpx0lp5vu757p3cnxzqx887t8zl3wacuvdgyeyee2puh3zqypf2680f7z8zau5ukptjaa7suxu0vadk0ncdyw4qdeazs9u29fddycffu4m9';
const _invoice =
    'lnbcrt300u1p4dtlwusp5nptqcasatxvy082yctgkamwtewxfdnuh3eemk48utk2cp6zz9umspp50rc6tq4889yrpqt5tlmssthes5qxrfzh3qh93fqm8h00j3sav27sdqqxqy9gcqcqzgq9qyysgqcjnlnm5mwfsf09uvnjraxzwj04c2l9gtduntevk95pec3vvkglv9wqu57rnw3mz8t37add2fsrs44llju7ncaty67ay3d2x9kayxxcsqertrwr';

void main() {
  setUpAll(() => NetworkType.setNetworkType(NetworkType.regtest));

  SendRecipientList check(
    List<SendRecipientRow> rows, {
    int onchain = 1000000,
    int ark = 100000,
    SendFunding funding = SendFunding.any,
  }) => SendRecipientList(
    rows,
    network: NetworkType.regtest,
    onchainAvailableSats: onchain,
    arkAvailableSats: ark,
    funding: funding,
  );

  test('one recipient can be anything payable', () {
    for (final input in [_bitcoin, _ark, _invoice, 'satoshi@example.com', 'bitcoin:?ark=$_ark&amount=0.0001']) {
      final list = check([SendRecipientRow(input, enteredAmountSats: 5000)]);
      expect(list.canContinue, isTrue, reason: input);
    }
    final offer = check([const SendRecipientRow('lno1qgsqvgnwgcg35z6ee2h3yczraddm72xrfua9uve2rlrm9deu7xyfzr')]);
    expect(offer.checks.single.problem, SendRecipientProblem.unsupported);
    expect(offer.checks.single.request!.problem, PaymentRequestProblem.bolt12);
  });

  test('an amount the destination carries is fixed', () {
    final invoice = check([const SendRecipientRow(_invoice, enteredAmountSats: 1)]).checks.single;
    expect(invoice.fixedAmountSats, 30000);
    expect(invoice.amountSats, 30000);
    expect(invoice.canUseOnchainMax, isFalse);
    expect(invoice.canUseArkMax, isFalse);

    final code = check([const SendRecipientRow('bitcoin:$_bitcoin?amount=0.0002')]).checks.single;
    expect(code.amountSats, 20000);
    expect(code.isValid, isTrue);
  });

  test('an amount is needed unless it is fixed or everything from a balance', () {
    final missing = check([const SendRecipientRow(_bitcoin)]);
    expect(missing.checks.single.problem, SendRecipientProblem.needsAmount);
    expect(missing.canContinue, isFalse);

    final max = check([const SendRecipientRow(_bitcoin, maxSource: SendMaxSource.onchain)]);
    expect(max.canContinue, isTrue);
    expect(max.maxLast, isTrue);
    expect(max.checks.single.amountSats, isNull);

    // On-chain funds can't pay an Ark address, so everything on-chain isn't honoured for one…
    final onchainMax = check([const SendRecipientRow(_ark, maxSource: SendMaxSource.onchain)]);
    expect(onchainMax.checks.single.canUseOnchainMax, isFalse);
    expect(onchainMax.maxLast, isFalse);
    expect(onchainMax.checks.single.problem, SendRecipientProblem.needsAmount);

    // …but everything in Ark is, as for a Bitcoin address.
    for (final input in [_ark, _bitcoin]) {
      final arkMax = check([SendRecipientRow(input, maxSource: SendMaxSource.ark)]);
      expect(arkMax.maxFromArk, isTrue, reason: input);
      expect(arkMax.canContinue, isTrue, reason: input);
    }
    expect(check([const SendRecipientRow(_invoice, maxSource: SendMaxSource.ark)]).maxFromArk, isFalse);
  });

  test('a move pays only from its source balance', () {
    final fromOnchain = check([const SendRecipientRow(_ark, enteredAmountSats: 1000)], funding: SendFunding.onchain);
    expect(fromOnchain.checks.single.problem, SendRecipientProblem.onchainOnly);
    final arkMax = check([
      const SendRecipientRow(_bitcoin, maxSource: SendMaxSource.ark),
    ], funding: SendFunding.onchain);
    expect(arkMax.maxFromArk, isFalse);

    final fromArk = check([const SendRecipientRow(_bitcoin, enteredAmountSats: 150000)], funding: SendFunding.ark);
    expect(fromArk.exceedsAvailable, isTrue, reason: 'only the Ark balance (100000) pays');
    expect(fromArk.checks.single.canUseOnchainMax, isFalse);
  });

  test('several recipients need on-chain addresses', () {
    final list = check([
      const SendRecipientRow(_bitcoin, enteredAmountSats: 10000),
      const SendRecipientRow(_ark, enteredAmountSats: 10000),
      const SendRecipientRow(_invoice),
      const SendRecipientRow('bitcoin:?ark=$_ark&amount=0.0001'),
      const SendRecipientRow('bitcoin:$_otherBitcoin?ark=$_ark&amount=0.0001'),
    ]);
    const onchainOnly = SendRecipientProblem.onchainOnly;
    expect(list.checks.map((check) => check.problem).toList(), [null, onchainOnly, onchainOnly, onchainOnly, null]);
    expect(list.checks.last.amountSats, 10000);
    expect(list.canContinue, isFalse);
  });

  test('duplicates are refused, empty rows block Next, and Max only on the last', () {
    final list = check([
      const SendRecipientRow(_bitcoin, enteredAmountSats: 10000),
      const SendRecipientRow(''),
      const SendRecipientRow('bitcoin:$_bitcoin?amount=0.0001'),
      const SendRecipientRow(_otherBitcoin, maxSource: SendMaxSource.onchain),
    ]);
    expect(list.checks[1].isEmpty, isTrue);
    expect(list.checks[2].problem, SendRecipientProblem.duplicate);
    expect(list.checks[3].canUseOnchainMax, isTrue);
    expect(list.checks[3].canUseArkMax, isFalse, reason: 'several recipients are paid on-chain');
    expect(list.recipients.length, 3);

    final withEmpty = check([const SendRecipientRow(_bitcoin, enteredAmountSats: 10000), const SendRecipientRow('')]);
    expect(withEmpty.recipients.length, 1);
    expect(withEmpty.canContinue, isFalse);

    final maxNotLast = check([
      const SendRecipientRow(_bitcoin, maxSource: SendMaxSource.onchain),
      const SendRecipientRow(_otherBitcoin, enteredAmountSats: 10000),
    ]);
    expect(maxNotLast.checks.first.problem, SendRecipientProblem.needsAmount);
    expect(maxNotLast.maxLast, isFalse);
  });

  test('more than either balance can pay is flagged', () {
    expect(check([const SendRecipientRow(_ark, enteredAmountSats: 150000)]).exceedsAvailable, isTrue);
    // A Bitcoin address can be paid from the larger of the two.
    expect(check([const SendRecipientRow(_bitcoin, enteredAmountSats: 150000)]).exceedsAvailable, isFalse);
    // Several recipients are on-chain only.
    final several = check(
      [
        const SendRecipientRow(_bitcoin, enteredAmountSats: 60000),
        const SendRecipientRow(_otherBitcoin, enteredAmountSats: 60000),
      ],
      onchain: 100000,
      ark: 500000,
    );
    expect(several.exceedsAvailable, isTrue);
  });
}
