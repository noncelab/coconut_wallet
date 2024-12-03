import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/model/data/multisig_signer.dart';
import 'package:coconut_wallet/model/data/multisig_wallet_list_item.dart';
import 'package:coconut_wallet/model/data/wallet_list_item_factory.dart';

class MultisigWalletListItemFactory implements WalletListItemFactory {
  static const String signersField = 'signers';
  static const String requiredSignatureCountField = 'requiredSignatureCount';

  // 새로 생성 시
  @override
  Future<MultisigWalletListItem> create({
    required String name,
    required int colorIndex,
    required int iconIndex,
    required descriptor,
    Map<String, dynamic>? secrets,
  }) async {
    List<MultisigSigner> signers = secrets?[signersField];
    int requiredSignatureCount = secrets?[requiredSignatureCountField];

    final nextId = WalletListItemFactory.loadNextId();

    for (var signer in signers) {
      signer.name = signer.name?.replaceAll('\n', ' ');
    }

    final newVault = MultisigWalletListItem(
        id: nextId,
        name: name.replaceAll('\n', ' '),
        colorIndex: colorIndex,
        iconIndex: iconIndex,
        descriptor: descriptor,
        signers: signers,
        requiredSignatureCount: requiredSignatureCount);
    await WalletListItemFactory.saveNextId(nextId + 1);

    return newVault;
  }

  // SecureStorage에서 복원 시
  @override
  MultisigWalletListItem createFromJson(Map<String, dynamic> json) {
    final result = MultisigWalletListItem.fromJson(json);

    for (var signer in result.signers) {
      signer.name = signer.name?.replaceAll('\n', ' ');
    }

    result.name = result.name.replaceAll('\n', ' ');
    result.walletBase = MultisignatureWallet.fromDescriptor(result.descriptor);
    return result;
  }
}
