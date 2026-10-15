import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/node/script_status.dart';
import 'package:coconut_wallet/model/wallet/multisig_config.dart';
import 'package:coconut_wallet/model/wallet/hot_wallet_metadata.dart';

abstract class WalletItemBase {
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
  late WalletBase walletBase;

  Map<String, UnaddressedScriptStatus> subscribedScriptMap = {}; // { ScriptPubKey: ScriptStatus }

  WalletItemBase({
    required this.id,
    required this.name,
    required this.colorIndex,
    required this.iconIndex,
    required this.descriptor,
    required this.walletType,
    required this.walletImportSource,
    this.receiveUsedIndex = -1,
    this.changeUsedIndex = -1,
  });

  HotWalletMetadata? get hotWalletMetadata => null;

  bool get hasLocalKey => hotWalletMetadata != null;

  WalletSigningMethod get signingMethod {
    if (hasLocalKey) return WalletSigningMethod.localSigner;
    if (walletImportSource == WalletImportSource.bitbox02) {
      return WalletSigningMethod.connectedHardware;
    }
    return WalletSigningMethod.externalQr;
  }

  @override
  String toString() => 'Wallet($id) / type=$walletType / source=${walletImportSource.name}/ name=$name';

  MultisigConfig? get multisigConfig {
    if (walletType == WalletType.multiSignature) {
      final multisigWalletBase = walletBase as MultisignatureWallet;
      return MultisigConfig(
        requiredSignature: multisigWalletBase.requiredSignature,
        totalSigner: multisigWalletBase.totalSigner,
      );
    }

    return null;
  }
}
