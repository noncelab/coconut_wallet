import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/providers/view_model/send/send_view_model.dart';
import 'package:coconut_wallet/services/payjoin/payjoin_sender.dart';
import 'package:coconut_wallet/utils/address_util.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // A BIP 77 URI as a receiver shares it: the pj parameter is percent-encoded
  // and carries the session's fragment parameters.
  const address = 'bcrt1q6rz28mcfaxtmd6v789l9rrlrusdprr9pz3cppk';
  const uri =
      'bitcoin:$address?amount=0.0001&pjos=0'
      '&pj=HTTPS://PAYJO.IN/TXJCGKTKXLUUZ%23EX1WKV8CEC-OH1QYPM5JXYNS754Y4R45QWE336QFX6ZR8DQGVQCULVZTV20TFVEYDMFQC-RK1Q0DJS3VVDXWQQTLQ8022QGXSX7ML9PHZ6EDSF6AKEWQG758JPS2EV';

  test('a payjoin URI keeps its pj parameter through BIP 21 parsing', () {
    expect(isPayjoinUri(uri), isTrue);
    final parsed = parseBip21Uri(uri);
    expect(parsed.address, address);
    expect(parsed.amount, 10000);
    expect(parsed.parameters?['pj'], isNotEmpty);
  });

  RecipientInfo recipient({String to = address, String? payjoinUri = uri}) =>
      RecipientInfo(address: to, amount: '10000')..payjoinUri = payjoinUri;

  String? forSend(List<RecipientInfo> recipients, {bool hot = true, bool passphrase = false}) =>
      payjoinUriForSend(recipients: recipients, isHotSingleSignatureWallet: hot, asksPassphraseWhenSigning: passphrase);

  test('the URI reaches the send for one recipient from a hot wallet', () {
    final info = SendInfoProvider()..setPayjoinUri(forSend([recipient()]));
    expect(info.payjoinUri, uri);
    info.clear();
    expect(info.payjoinUri, isNull);
  });

  test('editing the address after scanning drops the payjoin', () {
    expect(forSend([recipient(to: 'bcrt1qotheraddress')]), isNull);
  });

  test('no payjoin for batches, watch-only wallets or passphrase-at-signing wallets', () {
    expect(forSend([recipient(), recipient()]), isNull);
    expect(forSend([recipient()], hot: false), isNull);
    expect(forSend([recipient()], passphrase: true), isNull);
    expect(forSend([recipient(payjoinUri: null)]), isNull);
  });
}
