import 'package:coconut_wallet/model/error/app_error.dart';
import 'package:coconut_wallet/model/node/resync_progress.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/providers/node_provider/state/isolate_state_manager.dart';
import 'package:coconut_wallet/providers/node_provider/subscription/subscription_service.dart';
import 'package:coconut_wallet/repository/realm/utxo_repository.dart';
import 'package:coconut_wallet/repository/realm/wallet_repository.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/utils/result.dart';

/// 지갑 재동기화(온체인 데이터 초기화 후 처음부터 다시 fetch)를 담당하는 클래스
/// 트랜잭션 메모/UTXO 태그는 결정적 키를 사용하므로 별도 백업 없이 자동으로 보존되고,
/// UTXO 잠금 상태만 RealmUtxo.status 필드에 저장돼 있어 명시적으로 스냅샷/복원한다.
class WalletResyncService {
  final WalletRepository _walletRepository;
  final UtxoRepository _utxoRepository;
  final SubscriptionService _subscriptionService;
  final IsolateStateManager _isolateStateManager;

  WalletResyncService(
    this._walletRepository,
    this._utxoRepository,
    this._subscriptionService,
    this._isolateStateManager,
  );

  Future<Result<bool>> resyncWallet(WalletItemBase walletItem) async {
    final walletId = walletItem.id;

    try {
      final lockedUtxoIds = _utxoRepository.snapshotLockedUtxoIds(walletId);

      _isolateStateManager.setWalletResyncPhase(walletId, ResyncPhase.wiping);
      await _walletRepository.resetWalletForResync(walletId);

      // resetWalletForResync는 Realm DB(usedReceiveIndex 등)만 리셋한다. subscribeWallet은
      // 이 walletItem(메모리 객체)의 receiveUsedIndex/changeUsedIndex/subscribedScriptMap을 보고
      // 콜드 스캔 여부와 재구독 필요 여부를 판단하므로, 여기서도 같이 리셋해야 실제로 0부터
      // 전체 재스캔이 일어난다 (안 하면 예전 인덱스/구독 캐시를 그대로 신뢰해서 빈 꼬리 구간만
      // 스캔하고 끝나버려 잔액/거래/UTXO가 전부 0으로 보이는 버그가 생김).
      walletItem.receiveUsedIndex = -1;
      walletItem.changeUsedIndex = -1;
      walletItem.subscribedScriptMap.clear();

      _isolateStateManager.setWalletResyncPhase(walletId, ResyncPhase.scanning);
      final subscribeResult = await _subscriptionService.subscribeWallet(
        walletItem,
        onProgress: (completed, total) {
          _isolateStateManager.setWalletResyncFetchProgress(walletId, completed, total);
        },
      );

      if (subscribeResult.isFailure) {
        _isolateStateManager.setWalletResyncPhase(
          walletId,
          ResyncPhase.failed,
          errorMessage: subscribeResult.error.message,
        );
        return Result.failure(subscribeResult.error);
      }

      if (lockedUtxoIds.isNotEmpty) {
        _isolateStateManager.setWalletResyncPhase(walletId, ResyncPhase.restoringMetadata);
        await _utxoRepository.restoreLockedUtxos(walletId, lockedUtxoIds);
      }

      _isolateStateManager.setWalletResyncPhase(walletId, ResyncPhase.completed);
      return Result.success(true);
    } catch (e, stackTrace) {
      Logger.error('WalletResyncService: ${walletItem.name} - 재동기화 중 에러 발생: $e');
      Logger.error('Stack trace: $stackTrace');
      _isolateStateManager.setWalletResyncPhase(walletId, ResyncPhase.failed, errorMessage: e.toString());
      return Result.failure(ErrorCodes.withMessage(ErrorCodes.nodeUnknown, e.toString()));
    }
  }
}
