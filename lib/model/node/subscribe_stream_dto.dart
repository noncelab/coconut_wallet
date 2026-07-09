import 'package:coconut_wallet/model/node/script_status.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';

class SubscribeScriptStreamDto {
  final WalletItemBase walletItem;
  final ScriptStatus scriptStatus;

  SubscribeScriptStreamDto({required this.walletItem, required this.scriptStatus});
}
