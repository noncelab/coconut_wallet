import 'dart:typed_data';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/repository/realm/payjoin_session_repository.dart';
import 'package:coconut_wallet/services/payjoin/payjoin_wallet_adapter.dart';
import 'package:convert/convert.dart';
import 'package:flutter_test/flutter_test.dart';

class _Wallets extends Fake implements WalletProvider {
  _Wallets(this.addresses);

  final Set<String> addresses;

  @override
  bool containsAddress(int walletId, String address, {bool? isChange}) => addresses.contains(address);
}

void main() {
  const ours = 'bcrt1qk5cdgrs5s5atu2ttnmkm9mpplwmyztvtt8zm4d';
  const theirs = 'bcrt1quc5vu9lyf8kd68r6nlhg0dvht7pl4jz2dy0d9j';

  setUp(() => NetworkType.setNetworkType(NetworkType.regtest));
  tearDown(() => NetworkType.setNetworkType(NetworkType.testnet));

  Uint8List scriptOf(String address) =>
      Uint8List.fromList(hex.decode(TransactionOutput.forPayment(1000, address).scriptPubKey.rawSerialize()));

  test('recognises our output from the bare script payjoin passes', () {
    final adapter = WalletPayjoinReceiver(
      walletId: 1,
      sessionId: 's',
      wallets: _Wallets({ours}),
      node: _Node(),
      sessions: _Sessions(),
    );
    expect(adapter.isOwnedScript(scriptOf(ours)), isTrue);
    expect(adapter.isOwnedScript(scriptOf(theirs)), isFalse);
  });
}

class _Node extends Fake implements NodeProvider {}

class _Sessions extends Fake implements PayjoinSessionRepository {}
