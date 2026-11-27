import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_payment_request.dart';
import 'package:flutter_test/flutter_test.dart';

const _bitcoin = 'bcrt1q7kcrvjzszlxme7fgs2euvv6lkgf99jdu8zjnus';
const _ark =
    'tark1pqma5v23zqqp5z47f6anpx0lp5vu757p3cnxzqx887t8zl3wacuvdgyeyee2puh3zqypf2680f7z8zau5ukptjaa7suxu0vadk0ncdyw4qdeazs9u29fddycffu4m9';
const _invoice =
    'lnbcrt300u1p4dtlwusp5nptqcasatxvy082yctgkamwtewxfdnuh3eemk48utk2cp6zz9umspp50rc6tq4889yrpqt5tlmssthes5qxrfzh3qh93fqm8h00j3sav27sdqqxqy9gcqcqzgq9qyysgqcjnlnm5mwfsf09uvnjraxzwj04c2l9gtduntevk95pec3vvkglv9wqu57rnw3mz8t37add2fsrs44llju7ncaty67ay3d2x9kayxxcsqertrwr';

void main() {
  final regtest = NetworkType.regtest;
  setUpAll(() => NetworkType.setNetworkType(NetworkType.regtest));
  setUp(() => ArkPaymentRequest.clock = () => DateTime.utc(2026, 10, 19, 12));
  tearDown(() => ArkPaymentRequest.clock = DateTime.now);

  ArkPaymentRequest parse(String input) => ArkPaymentRequest.parse(input, regtest);

  group('BOLT11 amounts', () {
    test('read the human-readable part', () {
      expect(ArkPaymentRequest.bolt11AmountSats(_invoice), 30000); // 300 µBTC
      expect(ArkPaymentRequest.bolt11AmountSats('lnbcrt10u1pqqqqqq'), 1000);
      expect(ArkPaymentRequest.bolt11AmountSats('lnbcrt1m1pqqqqqq'), 100000);
      expect(ArkPaymentRequest.bolt11AmountSats('lnbcrt2500n1pqqqqqq'), 250);
      expect(ArkPaymentRequest.bolt11AmountSats('lnbcrt1500p1pqqqqqq'), 1); // 150 msat, rounded up
      expect(ArkPaymentRequest.bolt11AmountSats('lnbc2500u1pqqqqqq'), 250000);
    });

    test('amountless and malformed amounts are null', () {
      expect(ArkPaymentRequest.bolt11AmountSats('lnbcrt1pqqqqqq'), isNull);
      expect(ArkPaymentRequest.bolt11AmountSats('lnbcrt1501p1pqqqqqq'), isNull); // not a whole msat
      expect(ArkPaymentRequest.bolt11AmountSats('lnbcrt0100u1pqqqqqq'), isNull); // leading zero
    });
  });

  test('a Lightning invoice, with or without the lightning: scheme', () {
    for (final input in [_invoice, 'lightning:$_invoice', 'LIGHTNING:${_invoice.toUpperCase()}']) {
      final request = parse(input);
      expect(request.kind, ArkPaymentRequestKind.lightningInvoice);
      expect(request.lightningInvoice, _invoice);
      expect(request.amountSats, 30000);
      expect(request.arkOptions.single.rail, ArkPaymentRail.lightningInvoice);
    }
  });

  test('an invoice for another network is unsupported', () {
    final request = parse('lnbc300u1pqqqqqq');
    expect(request.kind, ArkPaymentRequestKind.unsupported);
    expect(request.problem, ArkPaymentRequestProblem.invoiceNetwork);
  });

  test('an Ark address', () {
    final request = parse(' $_ark ');
    expect(request.kind, ArkPaymentRequestKind.arkAddress);
    expect(request.arkAddress, _ark);
    expect(request.amountSats, isNull);
    expect(request.arkOptions.single.rail, ArkPaymentRail.ark);
    expect(parse('ark1${_ark.substring(5)}').kind, ArkPaymentRequestKind.unsupported); // a mainnet address
  });

  test('a Lightning address', () {
    final request = parse('Satoshi@Example.com');
    expect(request.kind, ArkPaymentRequestKind.lightningAddress);
    expect(request.lightningAddress, 'satoshi@example.com');
    expect(request.arkOptions.single.rail, ArkPaymentRail.lightningAddress);
  });

  test('a Bitcoin address', () {
    final request = parse(_bitcoin);
    expect(request.kind, ArkPaymentRequestKind.bitcoinAddress);
    expect(request.hasArkOrLightning, isFalse);
    expect(request.arkOptions.single.rail, ArkPaymentRail.onchain);
  });

  group('BIP321', () {
    test('offers Ark first, then Lightning, then on-chain', () {
      final request = parse('bitcoin:$_bitcoin?amount=0.0003&ark=$_ark&lightning=$_invoice');

      expect(request.kind, ArkPaymentRequestKind.bip321);
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

      expect(request.kind, ArkPaymentRequestKind.bip321);
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
      expect(required.kind, ArkPaymentRequestKind.unsupported);
      expect(required.problem, ArkPaymentRequestProblem.requiredParameter);
      expect(required.problemDetail, 'req-somethingnew');
      expect(parse('bitcoin:bc1qnotregtest?ark=$_ark').kind, ArkPaymentRequestKind.unsupported);
      expect(parse('bitcoin:?label=nothing').kind, ArkPaymentRequestKind.unsupported);
    });
  });

  test('BOLT12 offers and LNURL are recognized but unsupported', () {
    expect(
      parse('lno1qgsyxjtl6luzd9t3pr62xr7eemp6awnejusgf6gw45q75vcfqqqqqqq').kind,
      ArkPaymentRequestKind.unsupported,
    );
    expect(
      parse(
        'lnurl1dp68gurn8ghj7um9wfmxjcm99e3k7mf0v9cxj0m385ekvcenxc6r2c35xvukxefcv5mkvv34x5ekzd3ev56nyd3hxqurzepexejxxepnxscrvwfnv9nxzcn9xq6xyefhvgcxxcmyxymnserxfq5fns',
      ).kind,
      ArkPaymentRequestKind.unsupported,
    );
  });

  test('anything else is unknown', () {
    expect(parse('hello').kind, ArkPaymentRequestKind.unknown);
    expect(parse('').kind, ArkPaymentRequestKind.unknown);
  });

  test('an on-chain address alone cannot be paid from the Ark wallet', () {
    final request = parse(_bitcoin);

    expect(request.isOnchainOnly, isTrue);
    expect(parse('bitcoin:$_bitcoin?ark=$_ark').isOnchainOnly, isFalse);
  });

  group('memo', () {
    test('comes from a BIP21 message, then its label', () {
      expect(parse('bitcoin:?ark=$_ark&message=Coffee%20beans&label=Shop').memo, 'Coffee beans');
      expect(parse('bitcoin:?ark=$_ark&label=Shop').memo, 'Shop');
    });

    test('comes from the invoice description when the URI has none', () {
      ArkPaymentRequest.clock = () => DateTime.utc(2017, 6, 1, 11);
      const described =
          'lnbc1pvjluezsp5zyg3zyg3zyg3zyg3zyg3zyg3zyg3zyg3zyg3zyg3zyg3zyg3zygspp5qqqsyqcyq5rqwzqfqqqsyqcyq5rqwzqfqqqsyqcyq5rqwzqfqypqdpl2pkx2ctnv5sxxmmwwd5kgetjypeh2ursdae8g6twvus8g6rfwvs8qun0dfjkxaq9qrsgq357wnc5r2ueh7ck6q93dj32dlqnls087fxdwk8qakdyafkq3yap9us6v52vjjsrvywa6rt52cm9r9zqt8r2t7mlcwspyetp5h2tztugp9lfyql';
      expect(ArkPaymentRequest.bolt11Description(described), 'Please consider supporting this project');
      expect(ArkPaymentRequest.parse(described, NetworkType.mainnet).memo, 'Please consider supporting this project');
    });

    test('is empty for an invoice without a description', () {
      expect(parse(_invoice).memo, isNull);
      expect(parse(_ark).memo, isNull);
    });
  });

  group('invoice expiry', () {
    test('reads the creation time plus its x field', () {
      expect(ArkPaymentRequest.bolt11ExpiresAt(_invoice), DateTime.utc(2026, 10, 21, 11, 24, 12));
    });

    test('a short or malformed invoice has no known expiry', () {
      expect(ArkPaymentRequest.bolt11ExpiresAt('lnbcrt10u1pqqqqqq'), isNull);
    });

    test('an expired invoice cannot be paid', () {
      ArkPaymentRequest.clock = () => DateTime.utc(2026, 10, 21, 11, 24, 12);

      final request = parse(_invoice);
      expect(request.isPayable, isFalse);
      expect(request.problem, ArkPaymentRequestProblem.invoiceExpired);
    });

    test('a bitcoin URI drops an expired invoice and keeps its address', () {
      ArkPaymentRequest.clock = () => DateTime.utc(2026, 10, 22);

      final withAddress = parse('bitcoin:$_bitcoin?lightning=$_invoice');
      expect(withAddress.lightningInvoice, isNull);
      expect(withAddress.bitcoinAddress, _bitcoin);
      expect(parse('bitcoin:?lightning=$_invoice').problem, ArkPaymentRequestProblem.invoiceExpired);
    });

    test('a valid invoice carries its expiry', () {
      expect(parse(_invoice).invoiceExpiresAt, DateTime.utc(2026, 10, 21, 11, 24, 12));
    });
  });
}
