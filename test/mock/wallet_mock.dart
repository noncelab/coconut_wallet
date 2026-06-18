import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/model/wallet/singlesig_wallet_list_item.dart';
import 'package:coconut_wallet/model/wallet/multisig_wallet_list_item.dart';
import 'package:coconut_wallet/model/wallet/multisig_signer.dart';
import 'package:coconut_wallet/model/wallet/taproot_script_path_seed_info.dart';
import 'package:coconut_wallet/model/wallet/taproot_wallet_list_item.dart';

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

  static TaprootWalletListItem createTaprootWalletItem({
    int id = 1,
    String name = 'test_taproot_wallet',
    bool hasKeyPathSeedInfo = true,
    bool hasScriptPathSeedInfo = true,
  }) {
    const parentTaprootXpub =
        'tpubDDMbU29QrSafD2Ui4yGv31Xp3PPSMvudreoohYjR8xLTng7hbsjYwUTeRhiKULFqX16M5M8zZh9siw5i6RRyisc6LtWjr1FwBYTiZUGGYJN';
    const childTaprootXpub =
        'tpubDCp2emt17Ng6ujD8BC6ScL4vfwhN3nAJQ8kCqLjRQHxcFhWt6YK5Ws6UcKD6HgLCZuwU8DryKo7h2gpieLa7Q9YF1AqfL9XiF7349nHaLi8';
    const inheritanceMiniscript = 'and_v(v:pk([70C4E9DE/86\'/1\'/0\']$childTaprootXpub/<0;1>/*),older(500000000))';
    const descriptor = 'tr([9B1441E4/86\'/1\'/0\']$parentTaprootXpub/<0;1>/*,{$inheritanceMiniscript})#w0hf4lu5';

    return TaprootWalletListItem(
      id: id,
      name: name,
      colorIndex: 0,
      iconIndex: 0,
      descriptor: descriptor,
      keyPathSeedInfos: hasKeyPathSeedInfo ? [parentTaprootXpub] : [],
      scriptPathSeedInfos:
          hasScriptPathSeedInfo
              ? [
                TaprootScriptPathSeedInfo(miniscript: inheritanceMiniscript, extendedPublicKeys: [childTaprootXpub]),
              ]
              : [],
    );
  }
}
