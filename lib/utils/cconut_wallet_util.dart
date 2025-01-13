import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/model/app/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';

WalletFeature getWalletFeatureByWalletType(WalletListItemBase walletItem) {
  if (walletItem.walletType == WalletType.singleSignature) {
    return walletItem.walletBase as SingleSignatureWallet;
  } else {
    return walletItem.walletBase as MultisignatureWallet;
  }
}
