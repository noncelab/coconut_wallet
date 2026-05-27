import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/wallet/taproot_script_path_seed_info.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';

class TaprootWalletListItem extends WalletListItemBase {
  TaprootWalletListItem({
    required super.id,
    required super.name,
    required super.colorIndex,
    required super.iconIndex,
    required super.descriptor,
    required this.keyPathSeedInfos,
    required this.scriptPathSeedInfos,
    this.createdAtInVault,
    this.userSelectedSpendType,
    super.receiveUsedIndex,
    super.changeUsedIndex,
  }) : super(walletType: WalletType.taproot, walletImportSource: WalletImportSource.coconutVault) {
    walletBase = TaprootWallet.fromDescriptor(descriptor);
  }

  final List<String> keyPathSeedInfos;
  final List<TaprootScriptPathSeedInfo> scriptPathSeedInfos;
  final DateTime? createdAtInVault;

  /// 둘 다 가능한 wallet 에서 사용자가 사전 선택한 spend 경로. realm 영구 저장값.
  /// null = 미선택. 단일 spend 경로 wallet 에서는 무시된다.
  final TaprootSpendType? userSelectedSpendType;

  bool get canSpendViaKeyPath => keyPathSeedInfos.isNotEmpty;
  bool get canSpendViaScriptPath => scriptPathSeedInfos.isNotEmpty;
  bool get canSpendBothPaths => canSpendViaKeyPath && canSpendViaScriptPath;

  /// 보유 시드 역량으로 결정되는 기본 spend 경로.
  /// - 한쪽만 가능: 그쪽 경로
  /// - 둘 다 가능: 사용자 사전 선택값(없으면 keyPath)
  TaprootSpendType get defaultSpendType {
    if (canSpendViaScriptPath && !canSpendViaKeyPath) return TaprootSpendType.scriptPath;
    if (canSpendViaKeyPath && !canSpendViaScriptPath) return TaprootSpendType.keyPath;
    return userSelectedSpendType ?? TaprootSpendType.keyPath;
  }

  Policy? get defaultPolicy {
    final walletBase = this.walletBase as TaprootWallet;
    if (walletBase.policyList.isEmpty) return null;

    return walletBase.policyList.first;
  }
}
