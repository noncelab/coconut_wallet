import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';

extension TransactionExtension on Transaction {
  double estimateVirtualByteForWallet(WalletListItemBase wallet) {
    return estimateVirtualByte(
      wallet.walletType.addressType,
      requiredSignature: wallet.multisigConfig?.requiredSignature,
      totalSigner: wallet.multisigConfig?.totalSigner,
    );
  }
}
