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
    final descriptor =
        randomDescriptor
            ? SingleSignatureVault.random().descriptor
            : "wpkh([D45AA182/84'/1'/0']vpub5YtEovN9MqeUZxWqdpUKngsiaLCPFY34KpWGQVk9Tjq8G5SYcRFj9s5aCKeAQYGunG7LrFkA5obtH8kPJiv92JtWHfRvnir6PDvhd4p93Pp/<0;1>/*)#rcn2hj6y";

    return SinglesigWalletListItem(
      id: id,
      name: name + id.toString(),
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
        "wsh(sortedmulti(2,[A3B2EB70/48'/1'/0'/2']Vpub5nPDj2f67vDX5FsPMTG9NJZEFWoZVCvdomuuXEtNdtbvMEW6R8Y4AfuvD1v8HEMJ5KV97Y2FkBcpiU1nTmVUEvx4oAUcyrMNayimtFvjGQs/<0;1>/*,[B697ED0C/48'/1'/0'/2']Vpub5m3o8CxnPauiate1UZLcQi45f6q5HnmtZ3tvP2cv5Vtm51LJt5Um51pjkeTYNjd1PZBJ18R5eaYQ8dZdhq2Fit39qNggpkVJyvHj8HzUUe4/<0;1>/*,[F75F5AB5/48'/1'/0'/2']Vpub5nMwPdpQ4ozaJdZQeD2A6A5ci9DwQN6pWKFF3GGuBAK2tewmCB7HMcYsb9iukL2KMNjAgb72HWicwo55kzmnNvyih767HwSUxcv9PPdY8qj/<0;1>/*))#qlqyc9ar";

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
