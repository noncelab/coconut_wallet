import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/node/script_status.dart';
import 'package:coconut_wallet/model/wallet/multisig_config.dart';

abstract class WalletListItemBase {
  static const String walletTypeField = 'walletType';

  final int id;
  String name;
  int colorIndex;
  int iconIndex;
  final String descriptor;
  WalletType walletType;
  WalletImportSource walletImportSource;
  int receiveUsedIndex;
  int changeUsedIndex;
  // bool isFavorite = false;

  late WalletBase walletBase;

  Map<String, UnaddressedScriptStatus> subscribedScriptMap = {}; // { ScriptPubKey: ScriptStatus }

  WalletListItemBase({
    required this.id,
    required this.name,
    required this.colorIndex,
    required this.iconIndex,
    required this.descriptor,
    required this.walletType,
    required this.walletImportSource,
    this.receiveUsedIndex = -1,
    this.changeUsedIndex = -1,
    // this.isFavorite = false,
  });

  @override
  String toString() =>
      'Wallet($id) / type=$walletType / source=${walletImportSource.name}/ name=$name';

  MultisigConfig? get multisigConfig {
    if (walletType == WalletType.multiSignature) {
      final multisigWalletBase = walletBase as MultisignatureWallet;
      return MultisigConfig(
          requiredSignature: multisigWalletBase.requiredSignature,
          totalSigner: multisigWalletBase.totalSigner);
    }

    return null;
  }
}
