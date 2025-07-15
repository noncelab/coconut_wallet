import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/model/wallet/singlesig_wallet_list_item.dart';
import 'package:coconut_wallet/model/wallet/multisig_wallet_list_item.dart';
import 'package:coconut_wallet/model/wallet/multisig_signer.dart';

class WalletMock {
  static SinglesigWalletListItem createSingleSigWalletItem({
    int id = 1,
    String name = 'test_wallet',
    bool randomDescriptor = false,
  }) {
    final descriptor = randomDescriptor
        ? SingleSignatureVault.random().descriptor
        : "wpkh([D45AA182/84'/1'/0']vpub5YtEovN9MqeUZxWqdpUKngsiaLCPFY34KpWGQVk9Tjq8G5SYcRFj9s5aCKeAQYGunG7LrFkA5obtH8kPJiv92JtWHfRvnir6PDvhd4p93Pp/<0;1>/*)#rcn2hj6y";

    return SinglesigWalletListItem(
      id: id,
      name: name,
      colorIndex: 0,
      iconIndex: 0,
      descriptor: descriptor,
    );
  }

  static MultisigWalletListItem createMultiSigWalletItem({
    int id = 1,
    String name = 'test_multisig_wallet',
    int requiredSignatureCount = 2,
    int totalSigners = 3,
  }) {
    const descriptor =
        "wsh(sortedmulti(2,[D45AA182/48'/1'/0'/2']tpubDEBqRRczC3kBKcVwNpXZDca2JxnhGhG4nZX3bdzQP9bdXe5X5F8QmvwpnfGVJVgXJVh4n1N4YRLuqZwdPh1JpWd2xE1zftHQcxS4QaQ8Qzj/<0;1>/*,[D45AA182/48'/1'/0'/2']tpubDEBqRRczC3kBKcVwNpXZDca2JxnhGhG4nZX3bdzQP9bdXe5X5F8QmvwpnfGVJVgXJVh4n1N4YRLuqZwdPh1JpWd2xE1zftHQcxS4QaQ8Qzj/<0;1>/*,[D45AA182/48'/1'/0'/2']tpubDEBqRRczC3kBKcVwNpXZDca2JxnhGhG4nZX3bdzQP9bdXe5X5F8QmvwpnfGVJVgXJVh4n1N4YRLuqZwdPh1JpWd2xE1zftHQcxS4QaQ8Qzj/<0;1>/*))#vzh9c8jy";

    final signers = List.generate(
      totalSigners,
      (index) => MultisigSigner(
        name: 'Signer ${index + 1}',
        iconIndex: index,
        colorIndex: index,
        memo: 'Test signer ${index + 1}',
      ),
    );

    return MultisigWalletListItem(
      id: id,
      name: name,
      colorIndex: 0,
      iconIndex: 0,
      descriptor: descriptor,
      signers: signers,
      requiredSignatureCount: requiredSignatureCount,
    );
  }
}
