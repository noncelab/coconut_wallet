import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/wallet/hot_wallet_metadata.dart';
import 'package:coconut_wallet/model/wallet/singlesig_wallet_item.dart';
import 'package:coconut_wallet/services/payjoin/payjoin_signer.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../mock/wallet_mock.dart';

void main() {
  setUp(() => NetworkType.setNetworkType(NetworkType.regtest));
  tearDown(() => NetworkType.setNetworkType(NetworkType.testnet));

  const wpkh =
      "wpkh([D45AA182/84'/1'/0']vpub5YtEovN9MqeUZxWqdpUKngsiaLCPFY34KpWGQVk9Tjq8G5SYcRFj9s5aCKeAQYGunG7LrFkA5obtH8kPJiv92JtWHfRvnir6PDvhd4p93Pp/<0;1>/*)#rcn2hj6y";

  SinglesigWalletItem singleSig({
    WalletImportSource source = WalletImportSource.coconutVault,
    bool? passphraseAtSigning,
  }) => SinglesigWalletItem(
    id: 1,
    name: 'w',
    colorIndex: 0,
    iconIndex: 0,
    descriptor: wpkh,
    walletImportSource: source,
    hotWalletMetadata:
        passphraseAtSigning == null
            ? null
            : HotWalletMetadata(
              walletId: 1,
              secureStorageKey: 'k',
              masterFingerprint: 'D45AA182',
              derivationPath: "m/84'/1'/0'",
              accountIndex: 0,
              backupVerified: true,
              enterPassphraseWhenSigning: passphraseAtSigning,
              createdAt: DateTime(2026),
            ),
  );

  test('a hot wallet signs itself unless it asks for a passphrase', () {
    expect(payjoinSignerOf(singleSig(passphraseAtSigning: false)), PayjoinSigner.hotWallet);
    expect(payjoinSignerOf(singleSig(passphraseAtSigning: true)), isNull);
  });

  test('a watch-only wallet from Coconut Vault signs with the vault', () {
    expect(payjoinSignerOf(singleSig()), PayjoinSigner.coconutVault);
  });

  test('other signers and multisig wallets take no part', () {
    expect(payjoinSignerOf(singleSig(source: WalletImportSource.keystone)), isNull);
    expect(payjoinSignerOf(singleSig(source: WalletImportSource.extendedPublicKey)), isNull);
    expect(payjoinSignerOf(WalletMock.createMultiSigWalletItem()), isNull);
  });
}
