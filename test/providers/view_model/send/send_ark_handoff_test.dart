import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/providers/view_model/send/send_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

const _bitcoin = 'bcrt1q7kcrvjzszlxme7fgs2euvv6lkgf99jdu8zjnus';
const _ark =
    'tark1pqma5v23zqqp5z47f6anpx0lp5vu757p3cnxzqx887t8zl3wacuvdgyeyee2puh3zqypf2680f7z8zau5ukptjaa7suxu0vadk0ncdyw4qdeazs9u29fddycffu4m9';
const _invoice =
    'lnbcrt300u1p4dtlwusp5nptqcasatxvy082yctgkamwtewxfdnuh3eemk48utk2cp6zz9umspp50rc6tq4889yrpqt5tlmssthes5qxrfzh3qh93fqm8h00j3sav27sdqqxqy9gcqcqzgq9qyysgqcjnlnm5mwfsf09uvnjraxzwj04c2l9gtduntevk95pec3vvkglv9wqu57rnw3mz8t37add2fsrs44llju7ncaty67ay3d2x9kayxxcsqertrwr';

const SendArkWalletStatus _ready = (isUsable: true, isAdded: true, hasWallet: true, spendableSats: 100000);

SendArkHandoff? _handoff(String input, {SendArkWalletStatus ark = _ready, bool isBatchMode = false}) =>
    SendViewModel.arkHandoff(input, NetworkType.regtest, isBatchMode: isBatchMode, ark: ark);

void main() {
  setUp(() => NetworkType.setNetworkType(NetworkType.regtest));

  group('arkHandoff', () {
    test('a lightning invoice goes to the Ark wallet without a bitcoin choice', () {
      final handoff = _handoff(_invoice)!;

      expect(handoff.kind, SendArkHandoffKind.send);
      expect(handoff.offersBitcoin, isFalse);
      expect(handoff.input, _invoice);
      expect(handoff.arkAmountSats, 30000);
    });

    test('a lightning address and an Ark address go to the Ark wallet', () {
      expect(_handoff('alice@example.com')!.offersBitcoin, isFalse);
      expect(_handoff(_ark)!.offersBitcoin, isFalse);
    });

    test('a bitcoin URI with only lightning goes to the Ark wallet', () {
      expect(_handoff('bitcoin:?lightning=$_invoice')!.offersBitcoin, isFalse);
    });

    test('a bitcoin URI with an address and lightning offers a choice', () {
      final handoff = _handoff('bitcoin:$_bitcoin?amount=0.0003&lightning=$_invoice')!;

      expect(handoff.offersBitcoin, isTrue);
      expect(handoff.bitcoinAddress, _bitcoin);
      expect(handoff.showsAmounts, isFalse);
    });

    test('different amounts are shown under each choice', () {
      final handoff = _handoff('bitcoin:$_bitcoin?amount=0.0005&lightning=$_invoice')!;

      expect(handoff.showsAmounts, isTrue);
      expect(handoff.bitcoinAmountSats, 50000);
      expect(handoff.arkAmountSats, 30000);
    });

    test('a plain bitcoin address or URI stays on-chain', () {
      expect(_handoff(_bitcoin), isNull);
      expect(_handoff('bitcoin:$_bitcoin?amount=0.001'), isNull);
    });

    test('with several recipients nothing is offered', () {
      expect(_handoff(_invoice, isBatchMode: true), isNull);
    });

    test('an invoice above the Ark balance asks to top up and shows both amounts', () {
      final handoff = _handoff(_invoice, ark: (isUsable: true, isAdded: true, hasWallet: true, spendableSats: 20000))!;

      expect(handoff.kind, SendArkHandoffKind.lowBalance);
      expect(handoff.arkBalanceSats, 20000);
      expect(handoff.arkAmountSats, 30000);
    });

    test('without an amount the balance is left to the Ark send screen', () {
      final handoff =
          _handoff('alice@example.com', ark: (isUsable: true, isAdded: true, hasWallet: true, spendableSats: 0))!;

      expect(handoff.kind, SendArkHandoffKind.send);
    });

    test('without Ark added it points to the store, added without a wallet to creating one', () {
      final notAdded = _handoff(_invoice, ark: (isUsable: true, isAdded: false, hasWallet: false, spendableSats: 0))!;
      final noWallet = _handoff(_ark, ark: (isUsable: true, isAdded: true, hasWallet: false, spendableSats: 0))!;

      expect(notAdded.kind, SendArkHandoffKind.addArk);
      expect(notAdded.isInvoice, isTrue);
      expect(noWallet.kind, SendArkHandoffKind.createWallet);
      expect(noWallet.isInvoice, isFalse);
    });

    test('in a build without Ark no popup is shown', () {
      expect(_handoff(_invoice, ark: (isUsable: false, isAdded: false, hasWallet: false, spendableSats: 0)), isNull);
    });

    test('with a bitcoin address but no way to pay from Ark it stays on-chain', () {
      final uri = 'bitcoin:$_bitcoin?amount=0.0003&lightning=$_invoice';

      expect(_handoff(uri, ark: (isUsable: true, isAdded: true, hasWallet: true, spendableSats: 100)), isNull);
      expect(_handoff(uri, ark: (isUsable: true, isAdded: false, hasWallet: false, spendableSats: 0)), isNull);
      expect(_handoff(uri, ark: (isUsable: false, isAdded: false, hasWallet: false, spendableSats: 0)), isNull);
    });

    test('an invoice for another network is not offered', () {
      expect(_handoff(_invoice.replaceFirst('lnbcrt', 'lnbc')), isNull);
    });
  });

  group('isArkOnlyPayment', () {
    test('lightning and Ark payments are not on-chain addresses', () {
      expect(SendViewModel.isArkOnlyPayment(_invoice, NetworkType.regtest), isTrue);
      expect(SendViewModel.isArkOnlyPayment('alice@example.com', NetworkType.regtest), isTrue);
      expect(SendViewModel.isArkOnlyPayment(_ark, NetworkType.regtest), isTrue);
    });

    test('a bitcoin address, or a URI that also has one, is checked as on-chain', () {
      expect(SendViewModel.isArkOnlyPayment(_bitcoin, NetworkType.regtest), isFalse);
      expect(SendViewModel.isArkOnlyPayment('bitcoin:$_bitcoin?lightning=$_invoice', NetworkType.regtest), isFalse);
      expect(SendViewModel.isArkOnlyPayment('hello', NetworkType.regtest), isFalse);
    });
  });
}
