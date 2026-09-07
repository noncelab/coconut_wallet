import 'package:coconut_wallet/model/node/script_status.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';

class SubscribeScriptStreamDto {
  final WalletItemBase walletItem;
  final ScriptStatus scriptStatus;

  /// [updateUsedIndex] false면 usedIndex를 갱신하지 않음.
  /// 예: gap window 밖에서 발견된 개별 주소인 경우
  final bool updateUsedIndex;

  SubscribeScriptStreamDto({required this.walletItem, required this.scriptStatus, this.updateUsedIndex = true});
}
