import 'dart:async';
import 'dart:isolate';

import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/model/node/isolate_state_message.dart';
import 'package:coconut_wallet/model/node/resync_progress.dart';
import 'package:coconut_wallet/model/node/wallet_fetch_progress.dart';
import 'package:coconut_wallet/model/node/wallet_update_info.dart';
import 'package:coconut_wallet/providers/node_provider/isolate/isolate_enum.dart';
import 'package:coconut_wallet/providers/node_provider/state/isolate_state_manager.dart';
import 'package:coconut_wallet/providers/node_provider/state/node_state_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late NodeStateManager state;
  late StreamController<NodeSyncState> nodeEvents;
  late StreamController<Map<int, WalletUpdateInfo>> walletEvents;
  late StreamController<Map<int, ResyncProgress>> resyncEvents;
  late StreamController<Map<int, WalletFetchProgress>> fetchEvents;

  setUp(() {
    nodeEvents = StreamController.broadcast();
    walletEvents = StreamController.broadcast();
    resyncEvents = StreamController.broadcast();
    fetchEvents = StreamController.broadcast();
    state = NodeStateManager(() {}, nodeEvents, walletEvents, resyncEvents, fetchEvents);
  });
  tearDown(() async {
    await Future.wait([nodeEvents.close(), walletEvents.close(), resyncEvents.close(), fetchEvents.close()]);
  });

  test('isolate messages retain the previous balance until every queued address is processed', () async {
    final port = ReceivePort();
    final delivered = Completer<void>();
    final states = <NodeSyncState>[];
    final stateSubscription = nodeEvents.stream.listen(states.add);
    final subscription = port.listen((message) {
      final data = message as List<dynamic>;
      expect(data.first, IsolateManagerCommand.updateState);
      final args = data[1] as List<dynamic>;
      state.handleIsolateStateMessage(IsolateStateMessage(args.first as IsolateStateMethod, args.sublist(1)));
      if (state.state.registeredWallets[1]?.balanceSnapshot == 99000) delivered.complete();
    });
    addTearDown(() async {
      await subscription.cancel();
      port.close();
      await stateSubscription.cancel();
    });
    final isolate = IsolateStateManager(port.sendPort);
    isolate.setWalletSyncQueueState(1, true, 100000);
    for (var i = 0; i < 50; i++) {
      isolate.initWalletUpdateStatus(1);
      isolate.addWalletSyncState(1, UpdateElement.balance);
      isolate.addWalletCompletedState(1, UpdateElement.balance);
      isolate.addWalletCompletedAllStates(1);
    }
    isolate.setWalletSyncQueueState(1, false, 99000);
    await delivered.future;
    await Future<void>.delayed(Duration.zero);
    expect(states, [NodeSyncState.syncing, NodeSyncState.completed]);
    expect(state.state.registeredWallets[1]!.balanceSnapshot, 99000);
    expect(state.state.registeredWallets[1]!.isSyncQueued, isFalse);
  });

  test('another wallet completing cannot clear a failed balance sync', () {
    state.setWalletSyncQueueState(1, true, 100000);
    state.setWalletSyncQueueState(2, true, 200000);
    state.addWalletCompletedAllStates(1);
    state.setWalletSyncQueueState(1, false, null);
    state.setWalletSyncQueueState(2, false, 199000);
    expect(state.state.registeredWallets[1]!.balanceSnapshot, 100000);
    expect(state.state.registeredWallets[2]!.balanceSnapshot, 199000);
    expect(state.state.nodeSyncState, NodeSyncState.failed);

    state.setWalletSyncQueueState(1, true, 150000);
    expect(state.state.registeredWallets[1]!.balanceSnapshot, 100000);
    state.setWalletSyncQueueState(1, false, 99000);
    expect(state.state.registeredWallets[1]!.balanceSnapshot, 99000);
    expect(state.state.nodeSyncState, NodeSyncState.completed);
  });
}
