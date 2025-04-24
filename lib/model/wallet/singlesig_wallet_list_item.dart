import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_lib/coconut_lib.dart';

class SinglesigWalletListItem extends WalletListItemBase {
  SinglesigWalletListItem({
    required super.id,
    required super.name,
    required super.colorIndex,
    required super.iconIndex,
    required super.descriptor,
    super.receiveUsedIndex,
    super.changeUsedIndex,
    super.walletImportSource = WalletImportSource.coconutVault,
  }) : super(walletType: WalletType.singleSignature) {
    walletBase = SingleSignatureWallet.fromDescriptor(descriptor);
    name = name.replaceAll('\n', ' ');
  }
}
