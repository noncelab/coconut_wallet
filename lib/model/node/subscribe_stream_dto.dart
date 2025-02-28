import 'package:coconut_wallet/model/node/script_status.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';

class SubscribeScriptStreamDto {
  final WalletListItemBase walletItem;
  final ScriptStatus scriptStatus;
  final WalletProvider walletProvider;

  SubscribeScriptStreamDto({
    required this.walletItem,
    required this.scriptStatus,
    required this.walletProvider,
  });
}
