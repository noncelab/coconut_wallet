import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_payment_link.dart';
import 'package:flutter_test/flutter_test.dart';

const _bitcoin = 'bcrt1q7kcrvjzszlxme7fgs2euvv6lkgf99jdu8zjnus';
const _ark =
    'tark1pqma5v23zqqp5z47f6anpx0lp5vu757p3cnxzqx887t8zl3wacuvdgyeyee2puh3zqypf2680f7z8zau5ukptjaa7suxu0vadk0ncdyw4qdeazs9u29fddycffu4m9';
const _invoice =
    'lnbcrt300u1p4dtlwusp5nptqcasatxvy082yctgkamwtewxfdnuh3eemk48utk2cp6zz9umspp50rc6tq4889yrpqt5tlmssthes5qxrfzh3qh93fqm8h00j3sav27sdqqxqy9gcqcqzgq9qyysgqcjnlnm5mwfsf09uvnjraxzwj04c2l9gtduntevk95pec3vvkglv9wqu57rnw3mz8t37add2fsrs44llju7ncaty67ay3d2x9kayxxcsqertrwr';

void main() {
  setUpAll(() => NetworkType.setNetworkType(NetworkType.regtest));

  bool opens(String uri, {bool hasArkWallet = true}) =>
      opensInArkWallet(uri, NetworkType.regtest, hasArkWallet: hasArkWallet);

  test('links with an Ark address open in the Ark wallet, with or without an on-chain address', () {
    expect(opens('bitcoin:?ark=$_ark'), isTrue);
    expect(opens('bitcoin:$_bitcoin?ark=$_ark&lightning=$_invoice'), isTrue);
  });

  test('a Lightning-only link opens in the Ark wallet', () {
    expect(opens('bitcoin:?lightning=$_invoice'), isTrue);
    expect(opens('lightning:$_invoice'), isTrue);
    expect(opens('lightning:$_invoice', hasArkWallet: false), isFalse);
  });

  test('links with an on-chain address and no Ark address stay with Coconut send', () {
    expect(opens('bitcoin:$_bitcoin'), isFalse);
    expect(opens('bitcoin:$_bitcoin?lightning=$_invoice'), isFalse);
  });

  test('without an Ark wallet nothing opens there', () {
    expect(opens('bitcoin:?ark=$_ark', hasArkWallet: false), isFalse);
  });
}
