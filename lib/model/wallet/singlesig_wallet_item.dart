import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/model/wallet/local_signer_metadata.dart';

class SinglesigWalletItem extends WalletItemBase {
  SinglesigWalletItem({
    required super.id,
    required super.name,
    required super.colorIndex,
    required super.iconIndex,
    required super.descriptor,
    super.receiveUsedIndex,
    super.changeUsedIndex,
    super.walletImportSource = WalletImportSource.coconutVault,
    this.localSignerMetadata,
  }) : super(walletType: WalletType.singleSignature) {
    walletBase = SingleSignatureWallet.fromDescriptor(descriptor);
    name = name.replaceAll('\n', ' ');
  }

  @override
  final LocalSignerMetadata? localSignerMetadata;

  String get extendedPublicKey => (walletBase as SingleSignatureWallet).keyStore.extendedPublicKey.serialize();
}
