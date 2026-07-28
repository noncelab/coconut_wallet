import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/wallet/singlesig_wallet_item.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';

class TrezorWalletMismatch {
  const TrezorWalletMismatch._();

  static String? findMatchingWalletName(WalletProvider walletProvider, String xpub) {
    for (final wallet in walletProvider.walletItemList) {
      if (wallet.walletImportSource != WalletImportSource.trezor) continue;
      if (wallet is! SinglesigWalletItem) continue;
      if (wallet.extendedPublicKey == xpub) return wallet.name;
    }
    return null;
  }

  static bool isMismatch({
    required WalletProvider walletProvider,
    required String xpub,
    required String targetWalletName,
  }) {
    final matchedWalletName = findMatchingWalletName(walletProvider, xpub);
    return matchedWalletName == null || matchedWalletName != targetWalletName;
  }
}
