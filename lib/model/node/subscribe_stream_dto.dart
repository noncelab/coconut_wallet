import 'package:coconut_wallet/model/node/script_status.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';

class SubscribeScriptStreamDto {
  final WalletListItemBase walletItem;
  final ScriptStatus scriptStatus;

  SubscribeScriptStreamDto({required this.walletItem, required this.scriptStatus});
}
