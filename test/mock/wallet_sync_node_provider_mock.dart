import 'dart:async';

import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/model/node/node_provider_state.dart';
import 'package:coconut_wallet/model/node/wallet_update_info.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// 지갑별 업데이트 상태를 직접 바꿀 수 있는 노드
class WalletSyncNodeProviderMock extends Fake with ChangeNotifier implements NodeProvider {
  final _walletStates = StreamController<Map<int, WalletUpdateInfo>>.broadcast();
  Map<int, WalletUpdateInfo> _registered = {};

  void setSyncing(int walletId, bool syncing) {
    _registered = {
      ..._registered,
      walletId: WalletUpdateInfo(
        walletId,
        subscription: WalletSyncState.completed,
        balance: WalletSyncState.completed,
        transaction: WalletSyncState.completed,
        utxo: WalletSyncState.completed,
        isSyncQueued: syncing,
        balanceSnapshot: 0,
      ),
    };
    _walletStates.add(_registered);
  }

  @override
  NodeProviderState get state =>
      NodeProviderState(nodeSyncState: NodeSyncState.completed, registeredWallets: _registered);
  @override
  Stream<NodeSyncState> get syncStateStream => const Stream.empty();
  @override
  Stream<WalletUpdateInfo> getWalletStateStream(int walletId) =>
      _walletStates.stream.map((wallets) => wallets[walletId]).where((state) => state != null).cast<WalletUpdateInfo>();
}
