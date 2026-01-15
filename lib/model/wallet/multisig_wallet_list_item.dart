import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/core/bip/129/multisig_normalizer.dart';
import 'package:coconut_wallet/core/bip/129/signer_bsms.dart';
import 'package:coconut_wallet/model/wallet/multisig_signer.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:json_annotation/json_annotation.dart';

class MultisigWalletListItem extends WalletListItemBase {
  MultisigWalletListItem({
    required super.id,
    required super.name,
    required super.colorIndex,
    required super.iconIndex,
    required super.descriptor,
    required this.signers,
    required this.requiredSignatureCount,
    super.receiveUsedIndex,
    super.changeUsedIndex,
  }) : super(walletType: WalletType.multiSignature, walletImportSource: WalletImportSource.coconutVault) {
    walletBase = MultisignatureWallet.fromDescriptor(descriptor);
    name = name.replaceAll('\n', ' ');
    signerBsmsList = _getSignerBsmsList(descriptor);
  }

  @JsonKey(name: "signers")
  late List<MultisigSigner> signers;

  @JsonKey(name: "requiredSignatureCount")
  late final int requiredSignatureCount;

  late final List<SignerBsms> signerBsmsList;

  List<SignerBsms> _getSignerBsmsList(String descriptor) {
    return MultisigNormalizer.fromCoordinatorResult("BSMS 1.0\n00\n$descriptor").signerBsms;
  }
}
