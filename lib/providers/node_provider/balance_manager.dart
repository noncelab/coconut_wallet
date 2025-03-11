import 'package:coconut_wallet/model/node/script_status.dart';
import 'package:coconut_wallet/model/wallet/balance.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/providers/node_provider/state_manager.dart';
import 'package:coconut_wallet/repository/realm/address_repository.dart';
import 'package:coconut_wallet/repository/realm/wallet_repository.dart';
import 'package:coconut_wallet/services/electrum_service.dart';
import 'package:coconut_wallet/enums/network_enums.dart';

/// NodeProvider의 잔액 관련 기능을 담당하는 매니저 클래스
class BalanceManager {
  final ElectrumService _electrumService;
  final NodeStateManager _stateManager;
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

    _walletRepository.accumulateWalletBalance(walletItem.id, balanceDiff);

    if (!inBatchProcess) {
      // 동기화 완료 state 업데이트
      _stateManager.addWalletCompletedState(
          walletItem.id, UpdateElement.balance);
    }
  }
}
