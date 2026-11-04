import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/model/error/app_error.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/providers/node_provider/isolate/isolate_controller.dart';
import 'package:coconut_wallet/providers/node_provider/isolate/isolate_enum.dart';
import 'package:coconut_wallet/providers/node_provider/network_service.dart';
import 'package:coconut_wallet/providers/node_provider/resync/wallet_resync_service.dart';
import 'package:coconut_wallet/providers/node_provider/state/isolate_state_manager.dart';
import 'package:coconut_wallet/providers/node_provider/subscription/subscription_service.dart';
import 'package:coconut_wallet/providers/node_provider/transaction/transaction_record_service.dart';
import 'package:coconut_wallet/repository/realm/realm_manager.dart';
import 'package:coconut_wallet/services/electrum_service.dart';
import 'package:coconut_wallet/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../mock/wallet_mock.dart';

class _Subscriptions extends Fake implements SubscriptionService {
  final Set<int> failing;
  final List<int> subscribed = [];
  _Subscriptions(this.failing);

  @override
  Future<Result<bool>> subscribeWallet(
    WalletItemBase walletItem, {
    void Function(int completed, int total)? onProgress,
    int? minReceiveUsedIndex,
    int? minChangeUsedIndex,
  }) async {
    subscribed.add(walletItem.id);
    return failing.contains(walletItem.id)
        ? Result.failure(ErrorCodes.withMessage(ErrorCodes.nodeUnknown, 'wallet ${walletItem.id}'))
        : Result.success(true);
  }
}

class _State extends Fake implements IsolateStateManager {
  @override
  void initWalletUpdateStatus(int walletId) {}
  @override
  void setNodeSyncStateToSyncing() {}
}

class _Network extends Fake implements NetworkService {}

class _BroadcastNetwork extends Fake implements NetworkService {
  Duration? replyTimeout;
  Duration? checkTimeout;

  @override
  Future<Result<String>> broadcast(
    Transaction signedTx, {
    Duration replyTimeout = Duration.zero,
    Duration checkTimeout = Duration.zero,
  }) async {
    this.replyTimeout = replyTimeout;
    this.checkTimeout = checkTimeout;
    return Result.success(signedTx.transactionHash);
  }
}

class _Electrum extends Fake implements ElectrumService {}

class _Records extends Fake implements TransactionRecordService {}

class _Resync extends Fake implements WalletResyncService {}

class _Realm extends Fake implements RealmManager {}

void main() {
  test('subscribeWallets keeps subscribing the other wallets after one fails and reports the first failure', () async {
    final subscriptions = _Subscriptions({1, 3});
    final controller = IsolateController(
      subscriptions,
      _Network(),
      _State(),
      _Electrum(),
      _Records(),
      _Resync(),
      _Realm(),
    );
    final port = ReceivePort();
    addTearDown(port.close);
    final wallets = [
      for (final id in [1, 2, 3]) WalletMock.createSingleSigWalletItem(id: id),
    ];

    await controller.executeNetworkCommand(IsolateControllerCommand.subscribeWallets, port.sendPort, [wallets]);
    final result = await port.first as Result<bool>;

    expect(subscriptions.subscribed, [1, 2, 3]);
    expect(result.isFailure, isTrue);
    expect(result.error.message, contains('wallet 1'));
  });

  test('broadcast forwards the reply and check limits that the main side waits for', () async {
    final network = _BroadcastNetwork();
    final controller = IsolateController(
      _Subscriptions({}),
      network,
      _State(),
      _Electrum(),
      _Records(),
      _Resync(),
      _Realm(),
    );
    final port = ReceivePort();
    addTearDown(port.close);
    final fixture = jsonDecode(File('test/fixtures/signing/coldcard_raw.json').readAsStringSync()) as Map;
    final tx = Transaction.parse(fixture['returnedPayload'] as String);

    await controller.executeNetworkCommand(IsolateControllerCommand.broadcast, port.sendPort, [
      tx,
      const Duration(seconds: 8),
      const Duration(seconds: 4),
    ]);

    expect((await port.first as Result<String>).value, tx.transactionHash);
    expect((network.replyTimeout, network.checkTimeout), (const Duration(seconds: 8), const Duration(seconds: 4)));
  });
}
