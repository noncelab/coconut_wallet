import 'dart:async';

import 'package:coconut_wallet/constants/address.dart';
import 'package:coconut_wallet/model/error/app_error.dart';
import 'package:coconut_wallet/model/node/resync_progress.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/providers/node_provider/state/isolate_state_manager.dart';
import 'package:coconut_wallet/providers/node_provider/subscription/script_callback_service.dart';
import 'package:coconut_wallet/providers/node_provider/subscription/subscription_service.dart';
import 'package:coconut_wallet/repository/realm/address_repository.dart';
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
  final AddressRepository _addressRepository;
  final SubscriptionService _subscriptionService;
  final IsolateStateManager _isolateStateManager;
  final ScriptCallbackService _scriptCallbackService;

  final Set<int> _resyncingWallets = {};
  final Map<int, Completer<Result<bool>>> _resyncCompleters = {};

  WalletResyncService(
    this._walletRepository,
    this._utxoRepository,
    this._addressRepository,
    this._subscriptionService,
    this._isolateStateManager,
    this._scriptCallbackService,
  );

  Future<Result<bool>> resyncWallet(WalletItemBase walletItem) async {
    final walletId = walletItem.id;

    if (_resyncingWallets.contains(walletId)) {
      Logger.log('WalletResyncService: ${walletItem.name} - 이미 재동기화 중, 기존 작업 대기');
      return await _resyncCompleters[walletId]?.future ?? Result.success(true);
    }

    _resyncingWallets.add(walletId);
    final completer = Completer<Result<bool>>();
    _resyncCompleters[walletId] = completer;

    try {
      final result = await _resyncWalletInternal(walletItem);
      completer.complete(result);
      return result;
    } finally {
      _resyncingWallets.remove(walletId);
      _resyncCompleters.remove(walletId);
    }
  }

  Future<Result<bool>> _resyncWalletInternal(WalletItemBase walletItem) async {
    final walletId = walletItem.id;

    try {
      final lockedUtxoIds = _utxoRepository.snapshotLockedUtxoIds(walletId);

      _isolateStateManager.setWalletResyncPhase(walletId, ResyncPhase.wiping);
      // 백그라운드에서 도는 이 지갑의 일반 subscribeWallet(재연결 시 자동 재구독 등)과 같은 지갑별 큐를 공유
      // 지우는 도중에 그쪽이 동시에 같은 지갑 데이터를 쓰지 않도록(데드락 방지) 도착 순서대로 직렬화한다.
      await _subscriptionService.runExclusive(walletId, () async {
        await _walletRepository.resetWalletForResync(walletId);

        // resetWalletForResync는 Realm DB(usedReceiveIndex 등)만 리셋한다.
        // subscribeWallet은 이 walletItem(메모리 객체)의 receiveUsedIndex/changeUsedIndex/subscribedScriptMap을 보고
        // 콜드 스캔 여부와 재구독 필요 여부를 판단하므로, 여기서도 같이 리셋해야 실제로 0부터 전체 재스캔이 일어난다
        walletItem.receiveUsedIndex = -1;
        walletItem.changeUsedIndex = -1;
        walletItem.subscribedScriptMap.clear();

        // 안 지우면 이미 처리된 걸로 기억된 확정 트랜잭션은 재스캔해도 DB에 다시 안 쓰인다.
        _scriptCallbackService.clearWalletState(walletId);

        await _addressRepository.ensureAddressesExist(
          walletItemBase: walletItem,
          cursor: 0,
          count: kSubscriptionGapLimit,
          isChange: false,
        );
        await _addressRepository.ensureAddressesExist(
          walletItemBase: walletItem,
          cursor: 0,
          count: kSubscriptionGapLimit,
          isChange: true,
        );
      });

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
