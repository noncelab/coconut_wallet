import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/node/script_status.dart';
import 'package:coconut_wallet/model/wallet/multisig_config.dart';
import 'package:coconut_wallet/model/wallet/hot_wallet_metadata.dart';

final Expando<String> _accountKeys = Expando('accountKey');

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

  /// 같은 계정(같은 지갑)을 가리는 키: 지갑 종류 + 첫 받기 주소. 지갑을 더할 때 같은 지갑을 찾는 기준
  /// (`WalletProvider._findSameWalletIndex`·`findSameSinglesigWallet`)과 같아서 핫월렛과 그 보기 전용 지갑은 같은 키다.
  /// 주소를 만드는 비용이 있어 지갑 정보([walletBase])마다 한 번만 만든다.
  String get accountKey => _accountKeys[walletBase] ??= _accountKeyOf();

  /// 첫 받기 주소를 만들 수 없는 지갑(앱이 만들지 않는 조합)은 다른 지갑과 묶지 않는다(Fable N7).
  String _accountKeyOf() {
    try {
      return '${walletType.name}:${walletBase.getAddress(0)}';
    } catch (_) {
      return 'wallet:$id';
    }
  }

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
