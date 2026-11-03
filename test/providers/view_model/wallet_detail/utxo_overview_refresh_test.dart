import 'dart:async';

import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/enums/utxo_enums.dart';
import 'package:coconut_wallet/model/node/wallet_update_info.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/utxo/utxo_tag.dart';
import 'package:coconut_wallet/model/wallet/balance.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/price_provider.dart';
import 'package:coconut_wallet/providers/transaction_provider.dart';
import 'package:coconut_wallet/providers/utxo_tag_provider.dart';
import 'package:coconut_wallet/providers/view_model/wallet_detail/utxo_overview_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/utils/result.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../mock/wallet_mock.dart';

final _wallet = WalletMock.createSingleSigWalletItem(id: 1);

class _Wallets extends Fake with ChangeNotifier implements WalletProvider {
  int utxoReads = 0;
  @override
  WalletItemBase getWalletById(int id) => _wallet;
  @override
  Balance getWalletBalance(int id) => Balance(0, 0);
  @override
  List<UtxoState> getUtxoList(int walletId) {
    utxoReads++;
    return [];
  }
}

class _Transactions extends Fake with ChangeNotifier implements TransactionProvider {
  @override
  void initTxList(int id) {}
}

class _Tags extends Fake with ChangeNotifier implements UtxoTagProvider {
  @override
  List<UtxoTag> getUtxoTagList(int walletId) => [];
}

class _Connectivity extends Fake with ChangeNotifier implements ConnectivityProvider {}

class _Price extends Fake with ChangeNotifier implements PriceProvider {}

class _Preferences extends Fake with ChangeNotifier implements PreferenceProvider {
  @override
  UtxoOrder get utxoSortOrder => UtxoOrder.byAmountDesc;
}

class _Node extends Fake with ChangeNotifier implements NodeProvider {
  int reconnects = 0;
  @override
  Future<Result<bool>> reconnectIfNeeded() async {
    reconnects++;
    return Result.success(true);
  }

  @override
  Future<Result<bool>> syncDormantAddresses(WalletItemBase walletItem) async => Result.success(true);
}

void main() {
  test('a sync that failed and left the UTXO state waiting does not block a manual refresh', () async {
    final updates = StreamController<WalletUpdateInfo>();
    final wallets = _Wallets();
    final node = _Node();
    final viewModel = UtxoOverviewViewModel(
      _wallet.id,
      wallets,
      _Transactions(),
      _Tags(),
      _Connectivity(),
      _Price(),
      _Preferences(),
      node,
      updates.stream,
    );
    addTearDown(() async {
      viewModel.dispose();
      await updates.close();
    });
    // runQueued published a failed drain: the balance is waiting and the UTXO element never completed.
    updates.add(WalletUpdateInfo(_wallet.id, utxo: WalletSyncState.syncing));
    await pumpEventQueue();
    final readsBefore = wallets.utxoReads;

    await viewModel.refresh();

    expect(wallets.utxoReads, greaterThan(readsBefore), reason: 'the refresh re-reads the UTXO list');
    expect(node.reconnects, 1, reason: 'the refresh asks for a reconnect when the node failed');
  });
}
