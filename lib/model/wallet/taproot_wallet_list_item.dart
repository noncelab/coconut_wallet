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
    super.receiveUsedIndex,
    super.changeUsedIndex,
  }) : super(walletType: WalletType.taproot, walletImportSource: WalletImportSource.coconutVault) {
    walletBase = TaprootWallet.fromDescriptor(descriptor);
  }

  final List<String> keyPathSeedInfos;
  final List<TaprootScriptPathSeedInfo> scriptPathSeedInfos;
  final DateTime? createdAtInVault;
}
