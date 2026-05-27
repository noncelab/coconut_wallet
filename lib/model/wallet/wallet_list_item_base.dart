import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/node/script_status.dart';
import 'package:coconut_wallet/model/taproot_script_path_config.dart';
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

  TaprootScriptPathConfig? get taprootConfig {
    if (walletType != WalletType.taproot) return null;

    final taprootWalletBase = walletBase as TaprootWalletBase;
    final policyList = taprootWalletBase.policyList;
    if (policyList.isEmpty || policyList.length > 1 || policyList.first is! InheritancePolicy) {
      throw StateError('Unexpected taproot policy: $policyList');
    }
    return TaprootScriptPathConfig(
      // InheritancePolicy = 단일 수혜자 서명 → script-path leaf의 요구 서명 수는 1
      requiredSignature: 1,
      leafCount: policyList.length,
      // tapscript 원시 바이트 길이 (transaction.dart estimateVirtualByte 와 동일 계산)
      tapScriptSize: Codec.decodeHex(policyList.last.toScript(0).rawSerialize()).length,
    );
  }
}
