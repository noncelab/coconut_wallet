import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/model/ark/ark_payment.dart';
import 'package:coconut_wallet/utils/payment_request_parser.dart';
import 'package:flutter_test/flutter_test.dart';

const _bitcoin = 'bcrt1q7kcrvjzszlxme7fgs2euvv6lkgf99jdu8zjnus';
const _ark =
    'tark1pqma5v23zqqp5z47f6anpx0lp5vu757p3cnxzqx887t8zl3wacuvdgyeyee2puh3zqypf2680f7z8zau5ukptjaa7suxu0vadk0ncdyw4qdeazs9u29fddycffu4m9';
const _invoice =
    'lnbcrt300u1p4dtlwusp5nptqcasatxvy082yctgkamwtewxfdnuh3eemk48utk2cp6zz9umspp50rc6tq4889yrpqt5tlmssthes5qxrfzh3qh93fqm8h00j3sav27sdqqxqy9gcqcqzgq9qyysgqcjnlnm5mwfsf09uvnjraxzwj04c2l9gtduntevk95pec3vvkglv9wqu57rnw3mz8t37add2fsrs44llju7ncaty67ay3d2x9kayxxcsqertrwr';

void main() {
  final regtest = NetworkType.regtest;
  setUpAll(() => NetworkType.setNetworkType(NetworkType.regtest));

  PaymentRequest parse(String input) => PaymentRequest.parse(input, regtest);

  group('BOLT11 amounts', () {
    test('read the human-readable part', () {
      expect(PaymentRequest.bolt11AmountSats(_invoice), 30000); // 300 µBTC
      expect(PaymentRequest.bolt11AmountSats('lnbcrt10u1pqqqqqq'), 1000);
      expect(PaymentRequest.bolt11AmountSats('lnbcrt1m1pqqqqqq'), 100000);
      expect(PaymentRequest.bolt11AmountSats('lnbcrt2500n1pqqqqqq'), 250);
      expect(PaymentRequest.bolt11AmountSats('lnbcrt1500p1pqqqqqq'), 1); // 150 msat, rounded up
      expect(PaymentRequest.bolt11AmountSats('lnbc2500u1pqqqqqq'), 250000);
    });

    test('amountless and malformed amounts are null', () {
      expect(PaymentRequest.bolt11AmountSats('lnbcrt1pqqqqqq'), isNull);
      expect(PaymentRequest.bolt11AmountSats('lnbcrt1501p1pqqqqqq'), isNull); // not a whole msat
      expect(PaymentRequest.bolt11AmountSats('lnbcrt0100u1pqqqqqq'), isNull); // leading zero
    });
  });

  test('a Lightning invoice, with or without the lightning: scheme', () {
    for (final input in [_invoice, 'lightning:$_invoice', 'LIGHTNING:${_invoice.toUpperCase()}']) {
      final request = parse(input);
      expect(request.kind, PaymentRequestKind.lightningInvoice);
      expect(request.lightningInvoice, _invoice);
      expect(request.amountSats, 30000);
      expect(request.arkOptions.single.rail, ArkPaymentRail.lightningInvoice);
    }
  });

  test('an invoice for another network is unsupported', () {
    final request = parse('lnbc300u1pqqqqqq');
    expect(request.kind, PaymentRequestKind.unsupported);
    expect(request.problem, PaymentRequestProblem.invoiceNetwork);
  });

  test('an Ark address', () {
    final request = parse(' $_ark ');
    expect(request.kind, PaymentRequestKind.arkAddress);
    expect(request.arkAddress, _ark);
    expect(request.amountSats, isNull);
    expect(request.arkOptions.single.rail, ArkPaymentRail.ark);
    expect(parse('ark1${_ark.substring(5)}').kind, PaymentRequestKind.unsupported); // a mainnet address
  });

  test('a Lightning address', () {
    final request = parse('Satoshi@Example.com');
    expect(request.kind, PaymentRequestKind.lightningAddress);
    expect(request.lightningAddress, 'satoshi@example.com');
    expect(request.arkOptions.single.rail, ArkPaymentRail.lightningAddress);
  });

  test('a Bitcoin address', () {
    final request = parse(_bitcoin);
    expect(request.kind, PaymentRequestKind.bitcoinAddress);
    expect(request.hasArkOrLightning, isFalse);
    expect(request.arkOptions.single.rail, ArkPaymentRail.onchain);
  });

  group('BIP321', () {
    test('offers Ark first, then Lightning, then on-chain', () {
      final request = parse('bitcoin:$_bitcoin?amount=0.0003&ark=$_ark&lightning=$_invoice');

      expect(request.kind, PaymentRequestKind.bip321);
      expect(request.bitcoinAddress, _bitcoin);
      expect(request.amountSats, 30000);
      expect(request.arkOptions.map((option) => option.rail), [
        ArkPaymentRail.ark,
        ArkPaymentRail.lightningInvoice,
        ArkPaymentRail.onchain,
      ]);
    });

    test('works without an on-chain address and with encoded values', () {
      final request = parse('BITCOIN:?ark=${Uri.encodeQueryComponent(_ark)}&label=Coffee%20shop');

      expect(request.kind, PaymentRequestKind.bip321);
      expect(request.bitcoinAddress, isNull);
      expect(request.arkAddress, _ark);
      expect(request.amountSats, isNull);
    });

    test('reads an on-chain address given as a parameter, as bark writes it', () {
      // `bark bip321 --all` output: no path, the address under its network's key.
      final request = parse('bitcoin:?amount=0.00008&lightning=$_invoice&tb=$_bitcoin&ark=$_ark');

      expect(request.bitcoinAddress, _bitcoin);
      expect(request.amountSats, 8000);
      expect(request.arkOptions.map((option) => option.rail), [
        ArkPaymentRail.ark,
        ArkPaymentRail.lightningInvoice,
        ArkPaymentRail.onchain,
      ]);
    });

    test('takes the amount from the invoice when the URI has none', () {
      expect(parse('bitcoin:$_bitcoin?lightning=$_invoice').amountSats, 30000);
    });

    test('a plain on-chain URI has no Ark or Lightning', () {
      final request = parse('bitcoin:$_bitcoin?amount=0.001');
      expect(request.hasArkOrLightning, isFalse);
      expect(request.amountSats, 100000);
    });

    test('unknown required parameters and bad addresses are unsupported', () {
      final required = parse('bitcoin:$_bitcoin?req-somethingnew=1');
      expect(required.kind, PaymentRequestKind.unsupported);
      expect(required.problem, PaymentRequestProblem.requiredParameter);
      expect(required.problemDetail, 'req-somethingnew');
      expect(parse('bitcoin:bc1qnotregtest?ark=$_ark').kind, PaymentRequestKind.unsupported);
      expect(parse('bitcoin:?label=nothing').kind, PaymentRequestKind.unsupported);
    });
  });

  test('BOLT12 offers and LNURL are recognized but unsupported', () {
    expect(parse('lno1qgsyxjtl6luzd9t3pr62xr7eemp6awnejusgf6gw45q75vcfqqqqqqq').kind, PaymentRequestKind.unsupported);
    expect(
      parse(
        'lnurl1dp68gurn8ghj7um9wfmxjcm99e3k7mf0v9cxj0m385ekvcenxc6r2c35xvukxefcv5mkvv34x5ekzd3ev56nyd3hxqurzepexejxxepnxscrvwfnv9nxzcn9xq6xyefhvgcxxcmyxymnserxfq5fns',
      ).kind,
      PaymentRequestKind.unsupported,
    );
  });

  test('anything else is unknown', () {
    expect(parse('hello').kind, PaymentRequestKind.unknown);
    expect(parse('').kind, PaymentRequestKind.unknown);
  });
}
