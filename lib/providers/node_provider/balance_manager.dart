import 'package:coconut_wallet/model/node/script_status.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/providers/node_provider/state_manager.dart';
import 'package:coconut_wallet/repository/realm/address_repository.dart';
import 'package:coconut_wallet/repository/realm/wallet_repository.dart';
import 'package:coconut_wallet/services/network/node_client.dart';
import 'package:coconut_wallet/enums/network_enums.dart';

/// NodeProvider의 잔액 관련 기능을 담당하는 매니저 클래스
class BalanceManager {
  final NodeClient _nodeClient;
  final NodeStateManager _stateManager;
  final AddressRepository _addressRepository;
  final WalletRepository _walletRepository;

  BalanceManager(
    this._nodeClient,
    this._stateManager,
    this._addressRepository,
    this._walletRepository,
  );

  /// 스크립트의 잔액을 조회하고 업데이트합니다.
  Future<void> fetchScriptBalance(
    WalletListItemBase walletItem,
    ScriptStatus scriptStatus,
  ) async {
    // 동기화 시작 state 업데이트
    _stateManager.addWalletSyncState(walletItem.id, UpdateElement.balance);

    final addressBalance =
        await _nodeClient.getAddressBalance(scriptStatus.scriptPubKey);

    final balanceDiff = _addressRepository.updateAddressBalance(
      walletId: walletItem.id,
      index: scriptStatus.index,
      isChange: scriptStatus.isChange,
      balance: addressBalance,
    );

    _walletRepository.accumulateWalletBalance(walletItem.id, balanceDiff);

    // Balance 업데이트 완료 state 업데이트
    _stateManager.addWalletCompletedState(walletItem.id, UpdateElement.balance);
  }
}
