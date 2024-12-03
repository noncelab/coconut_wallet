import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/model/data/singlesig_wallet_list_item.dart';
import 'package:coconut_wallet/model/data/wallet_list_item_factory.dart';

class SinglesigWalletListItemFactory implements WalletListItemFactory {
  static const String descriptorField = 'descriptor';

  @override
  Future<SinglesigWalletListItem> create({
    required String name,
    required int colorIndex,
    required int iconIndex,
    required descriptor,
    Map<String, dynamic>? secrets,
  }) async {
    final nextId = WalletListItemFactory.loadNextId();
    final newWallet = SinglesigWalletListItem(
      id: nextId,
      name: name..replaceAll('\n', ' '),
      colorIndex: colorIndex,
      iconIndex: iconIndex,
      descriptor: descriptor,
    );
    await WalletListItemFactory.saveNextId(nextId + 1);

    return newWallet;
  }

  @override
  SinglesigWalletListItem createFromJson(Map<String, dynamic> json) {
    final result = SinglesigWalletListItem.fromJson(json);

    result.name = result.name.replaceAll('\n', ' ');
    result.walletBase = SingleSignatureWallet.fromDescriptor(result.descriptor);
    return result;
  }
}
