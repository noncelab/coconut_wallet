import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';

/// Who signs a wallet's side of a payjoin.
enum PayjoinSigner {
  /// The app, with the wallet's own key, without asking the user again.
  hotWallet,

  /// Coconut Vault, over QR. Each signature is a round trip the user makes,
  /// and the counterparty waits for it.
  coconutVault,
}

/// How [wallet] signs its side of a payjoin, or null if it cannot take part.
///
/// Payjoin here is limited to single-signature wallets. A hot wallet must
/// sign without asking for a passphrase, since the counterparty's proposal
/// arrives while the session runs. A watch-only wallet signs with Coconut
/// Vault, which accepts payjoin PSBTs for single-signature P2WPKH wallets.
PayjoinSigner? payjoinSignerOf(WalletItemBase wallet) {
  if (wallet.walletType != WalletType.singleSignature) return null;
  final metadata = wallet.hotWalletMetadata;
  if (metadata != null) return metadata.enterPassphraseWhenSigning ? null : PayjoinSigner.hotWallet;
  if (wallet.walletImportSource == WalletImportSource.coconutVault &&
      wallet.walletBase.addressType == AddressType.p2wpkh) {
    return PayjoinSigner.coconutVault;
  }
  return null;
}
