import 'dart:async';

import 'package:coconut_wallet/app.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/model/node/node_provider_state.dart';
import 'package:coconut_wallet/model/node/wallet_update_info.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/transaction_provider.dart';
import 'package:coconut_wallet/providers/view_model/wallet_detail/wallet_detail_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../mock/wallet_mock.dart';

class _Node extends Fake with ChangeNotifier implements NodeProvider {
  final syncEvents = StreamController<NodeSyncState>.broadcast();
  final walletEvents = StreamController<WalletUpdateInfo>.broadcast();
  Completer<void>? refreshing;
  int refreshCount = 0;
  final refreshedWalletIds = <int>[];

  @override
  NodeProviderState get state => const NodeProviderState(nodeSyncState: NodeSyncState.completed, registeredWallets: {});

  @override
  Stream<NodeSyncState> get syncStateStream => syncEvents.stream;

  @override
  Stream<WalletUpdateInfo> getWalletStateStream(int walletId) => walletEvents.stream;

  @override
  Future<bool> refreshWallet(WalletItemBase walletItem) async {
    refreshedWalletIds.add(walletItem.id);
    refreshCount++;
    await refreshing?.future;
    return true;
  }
}

class _Wallets extends Fake with ChangeNotifier implements WalletProvider {
  final WalletItemBase wallet = WalletMock.createSingleSigWalletItem(id: 1);

  @override
  WalletItemBase getWalletById(int id) => wallet;
}

class _Transactions extends Fake with ChangeNotifier implements TransactionProvider {
  int loadCount = 0;

  @override
  void initTxList(int id) => loadCount++;
}

class _Prefs extends Fake implements SharedPrefsRepository {}

void main() {
  CoconutWalletApp.kFaucetHost = 'http://localhost';

  test('지갑 상세를 당겨서 새로고침하면 서버 동기화가 끝난 뒤 거래 목록을 다시 읽는다', () async {
    final node = _Node();
    final transactions = _Transactions();
    final detail = WalletDetailViewModel(
      1,
      _Wallets(),
      transactions,
      node,
      initialUnit: BitcoinUnit.btc,
      sharedPrefs: _Prefs(),
    );
    addTearDown(() async {
      detail.dispose();
      await node.syncEvents.close();
      await node.walletEvents.close();
    });
    final loadedBeforeRefresh = transactions.loadCount;
    node.refreshing = Completer<void>();

    final refresh = detail.refresh();
    expect(node.refreshCount, 1);
    expect(node.refreshedWalletIds, [1], reason: '전체가 아니라 이 지갑만 새로고침한다');
    expect(detail.isRefreshing, isTrue);
    expect(transactions.loadCount, loadedBeforeRefresh);

    node.refreshing!.complete();
    await refresh;
    expect(transactions.loadCount, loadedBeforeRefresh + 1);
    expect(detail.isRefreshing, isFalse);
  });
}
