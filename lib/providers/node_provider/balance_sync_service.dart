import 'package:coconut_wallet/model/node/script_status.dart';
import 'package:coconut_wallet/model/node/update_address_balance_dto.dart';
import 'package:coconut_wallet/model/wallet/balance.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/repository/realm/address_repository.dart';
import 'package:coconut_wallet/repository/realm/wallet_repository.dart';
import 'package:coconut_wallet/services/electrum_service.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/providers/node_provider/state/state_manager_interface.dart';

/// NodeProvider의 잔액 관련 기능을 담당하는 매니저 클래스
class BalanceSyncService {
  final ElectrumService _electrumService;
  final StateManagerInterface _stateManager;
  final AddressRepository _addressRepository;
  final WalletRepository _walletRepository;

  BalanceSyncService(this._electrumService, this._stateManager, this._addressRepository, this._walletRepository);

  /// 스크립트의 잔액을 조회하고 업데이트합니다.
  Future<void> fetchScriptBalance(WalletItemBase walletItem, ScriptStatus scriptStatus) async {
    // 동기화 시작 state 업데이트
    _stateManager.addWalletSyncState(walletItem.id, UpdateElement.balance);

    await syncAddressBalance(
      walletItem,
      address: scriptStatus.address,
      index: scriptStatus.index,
      isChange: scriptStatus.isChange,
    );

    _stateManager.addWalletCompletedState(walletItem.id, UpdateElement.balance);
  }

  /// 주소의 잔액을 Electrum에서 조회해 지갑 총 잔액에 반영합니다.
  /// [fetchScriptBalance]가 내부적으로
  /// 사용하는 것 외에도 다른 주소 이벤트가 발견한 co-spent 주소의 잔액을 재조회할 때도 사용합니다.
  Future<void> syncAddressBalance(
    WalletItemBase walletItem, {
    required String address,
    required int index,
    required bool isChange,
  }) async {
    final balanceResponse = await _electrumService.getBalance(walletItem.walletBase.addressType, address);

    // GetBalanceRes에서 Balance 객체로 변환
    final addressBalance = Balance(balanceResponse.confirmed, balanceResponse.unconfirmed);

    final balanceDiff = _addressRepository.updateAddressBalance(
      walletId: walletItem.id,
      index: index,
      isChange: isChange,
      balance: addressBalance,
    );

    await _walletRepository.accumulateWalletBalance(walletItem.id, balanceDiff);
  }

  /// 여러 스크립트의 잔액을 일괄적으로 조회하고 업데이트합니다.
  /// [onBatchProgress]는 재동기화 화면 진행률 표시 등 선택적 용도로만 사용한다(기본 null).
  /// 배치(기본 50개)가 하나 끝날 때마다 그 배치에 포함된 스크립트 개수로 호출된다.
  Future<void> fetchScriptBalanceBatch(
    WalletItemBase walletItem,
    List<ScriptStatus> scriptStatuses, {
    void Function(int batchCount)? onBatchProgress,
  }) async {
    if (scriptStatuses.isEmpty) {
      Logger.error('fetchScriptBalanceBatch: scriptStatus is empty');
      return;
    }

    // 동기화 시작 state 업데이트
    _stateManager.addWalletSyncState(walletItem.id, UpdateElement.balance);

    try {
      List<UpdateAddressBalanceDto> balanceUpdates = [];

      const batchSize = 50; // 배치 사이즈 임의 설정
      final isOnionHost = scriptStatuses.isNotEmpty && scriptStatuses.first.address.contains('.onion');

      for (int i = 0; i < scriptStatuses.length; i += batchSize) {
        final endIndex = (i + batchSize < scriptStatuses.length) ? i + batchSize : scriptStatuses.length;
        final batch = scriptStatuses.sublist(i, endIndex);

        Logger.log(
          'BalanceSyncService: Processing batch ${(i ~/ batchSize) + 1}/${(scriptStatuses.length / batchSize).ceil()}',
        );

        // 배치 내에서 병렬 처리
        final batchFutures = batch.map((script) async {
          try {
            final balanceResponse = await _electrumService.getBalance(
              walletItem.walletBase.addressType,
              script.address,
            );

            return UpdateAddressBalanceDto(
              scriptStatus: script,
              confirmed: balanceResponse.confirmed,
              unconfirmed: balanceResponse.unconfirmed,
            );
          } catch (e) {
            Logger.error('BalanceSyncService: Error fetching balance for ${script.address}: $e');
            // 조회 실패를 잔액 0으로 간주하면 기존에 저장된 잔액을 잘못 덮어쓸 수 있으므로,
            // 이번 배치에서는 제외하고 기존 저장값을 그대로 유지한다.
            return null;
          }
        });

        final batchResults = await Future.wait(batchFutures);
        balanceUpdates.addAll(batchResults.whereType<UpdateAddressBalanceDto>());
        onBatchProgress?.call(batch.length);

        // .onion 주소인 경우 배치 간 짧은 대기
        if (isOnionHost && i + batchSize < scriptStatuses.length) {
          await Future.delayed(const Duration(milliseconds: 200));
        }
      }

      // 기존 방식
      // for (var script in scriptStatuses) {
      //   final balanceResponse =
      //       await _electrumService.getBalance(walletItem.walletBase.addressType, script.address);

      //   balanceUpdates.add(UpdateAddressBalanceDto(
      //     scriptStatus: script,
      //     confirmed: balanceResponse.confirmed,
      //     unconfirmed: balanceResponse.unconfirmed,
      //   ));
      // }

      final totalBalanceDiff = await _addressRepository.updateAddressBalanceBatch(walletItem.id, balanceUpdates);

      // 지갑 잔액에 변화량 반영
      await _walletRepository.accumulateWalletBalance(walletItem.id, totalBalanceDiff);

      // 동기화 완료 state 업데이트
      _stateManager.addWalletCompletedState(walletItem.id, UpdateElement.balance);

      Logger.log('BalanceSyncService: Completed processing ${scriptStatuses.length} scripts');
    } catch (e, stack) {
      Logger.error('fetchScriptBalanceBatch error: $e');
      Logger.error(stack);
      // 동기화 실패 state 업데이트 (오류 시 동기화 완료 상태로 변경)
      _stateManager.addWalletCompletedState(walletItem.id, UpdateElement.balance);
      rethrow;
    }
  }
}
