import 'package:coconut_wallet/model/node/script_status.dart';
import 'package:coconut_wallet/model/wallet/balance.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/repository/realm/address_repository.dart';
import 'package:coconut_wallet/repository/realm/wallet_repository.dart';
import 'package:coconut_wallet/services/electrum_service.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/model/node/address_balance_update_dto.dart';
import 'package:coconut_wallet/providers/node_provider/state_manager_interface.dart';

/// NodeProvider의 잔액 관련 기능을 담당하는 매니저 클래스
class BalanceManager {
  final ElectrumService _electrumService;
  final StateManagerInterface _stateManager;
  final AddressRepository _addressRepository;
  final WalletRepository _walletRepository;

  BalanceManager(
    this._electrumService,
    this._stateManager,
    this._addressRepository,
    this._walletRepository,
  );

  /// 스크립트의 잔액을 조회하고 업데이트합니다.
  Future<void> fetchScriptBalance(
    WalletListItemBase walletItem,
    ScriptStatus scriptStatus, {
    bool inBatchProcess = false,
  }) async {
    if (!inBatchProcess) {
      // 동기화 시작 state 업데이트
      _stateManager.addWalletSyncState(walletItem.id, UpdateElement.balance);
    }

    final balanceResponse = await _electrumService.getBalance(
        walletItem.walletBase.addressType, scriptStatus.address);

    // GetBalanceRes에서 Balance 객체로 변환
    final addressBalance =
        Balance(balanceResponse.confirmed, balanceResponse.unconfirmed);

    final balanceDiff = _addressRepository.updateAddressBalance(
      walletId: walletItem.id,
      index: scriptStatus.index,
      isChange: scriptStatus.isChange,
      balance: addressBalance,
    );

    await _walletRepository.accumulateWalletBalance(walletItem.id, balanceDiff);

    if (!inBatchProcess) {
      // 하나의 트랜잭션으로 여러 스크립트에 대한 이벤트가 발생할 경우에 오류 발생.
      // 이벤트 리스너 함수들이 모두 완료되지 않은 상태로 state가 업데이트됨.
      // 결과적으로 화면에서 잔액이 제대로 변경되지 않는 오류가 있음.
      // 임시로 지연을 통해 이벤트 리스너가 모두 실행되기 전에 동기화 완료 state가 업데이트되는 것을 방지함.
      // TODO: 이벤트 리스너에 대해서 동시성 제어 필요함
      Future.delayed(const Duration(milliseconds: 300), () {
        _stateManager.addWalletCompletedState(
            walletItem.id, UpdateElement.balance);
      });
    }
  }

  /// 여러 스크립트의 잔액을 일괄적으로 조회하고 업데이트합니다.
  Future<void> fetchScriptBalanceBatch(
    WalletListItemBase walletItem,
    List<ScriptStatus> scriptStatuses,
  ) async {
    if (scriptStatuses.isEmpty) {
      Logger.error('fetchScriptBalanceBatch: scriptStatuses is empty');
      return;
    }

    // 동기화 시작 state 업데이트
    _stateManager.addWalletSyncState(walletItem.id, UpdateElement.balance);

    try {
      List<AddressBalanceUpdateDto> balanceUpdates = [];

      for (var script in scriptStatuses) {
        final balanceResponse = await _electrumService.getBalance(
            walletItem.walletBase.addressType, script.address);

        balanceUpdates.add(AddressBalanceUpdateDto(
          scriptStatus: script,
          confirmed: balanceResponse.confirmed,
          unconfirmed: balanceResponse.unconfirmed,
        ));
      }

      final totalBalanceDiff =
          await _addressRepository.updateAddressBalanceBatch(
        walletItem.id,
        balanceUpdates,
      );

      // 지갑 잔액에 변화량 반영
      await _walletRepository.accumulateWalletBalance(
          walletItem.id, totalBalanceDiff);

      // 동기화 완료 state 업데이트
      _stateManager.addWalletCompletedState(
          walletItem.id, UpdateElement.balance);
    } catch (e, stack) {
      Logger.error('fetchScriptBalanceBatch error: $e');
      Logger.error(stack);
      // 동기화 실패 state 업데이트 (오류 시 동기화 완료 상태로 변경)
      _stateManager.addWalletCompletedState(
          walletItem.id, UpdateElement.balance);
      rethrow;
    }
  }
}
