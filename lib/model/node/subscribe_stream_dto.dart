import 'package:coconut_wallet/model/node/script_status.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';

class SubscribeScriptStreamDto {
  final WalletItemBase walletItem;
  final ScriptStatus scriptStatus;

  /// [updateUsedIndex] false면 usedIndex를 갱신하지 않음.
  /// 예: gap window 밖에서 발견된 개별 주소인 경우
  final bool updateUsedIndex;

  /// 인덱스 저장 후 실패한 구독 확장을 같은 주소의 새 상태에서 재시도한다.
  final bool retrySubscription;

  SubscribeScriptStreamDto({
    required this.walletItem,
    required this.scriptStatus,
    this.updateUsedIndex = true,
    this.retrySubscription = false,
  });
}
