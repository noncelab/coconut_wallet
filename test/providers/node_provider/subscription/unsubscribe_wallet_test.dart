// Unsubscribing one wallet must not silence another wallet on the same address, and a failed unsubscribe request must
// not leave a cached subscription without a live callback.
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:coconut_wallet/model/node/subscribe_stream_dto.dart';
import 'package:coconut_wallet/providers/node_provider/subscription/script_sync_service.dart';
import 'package:coconut_wallet/providers/node_provider/subscription/subscription_service.dart';
import 'package:coconut_wallet/repository/realm/subscription_repository.dart';
import 'package:coconut_wallet/services/electrum_service.dart';
import 'package:coconut_wallet/services/network/socket/socket_manager.dart';
import 'package:coconut_wallet/utils/electrum_utils.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import '../../../mock/script_sync_service_mock.dart';
import '../../../mock/wallet_mock.dart';
import '../../../services/network/socket/socket_manager_test.mocks.dart';

/// Records which wallet each live push reaches instead of syncing it.
class _InertSync extends ScriptSyncService {
  final List<int> pushes;
  _InertSync(this.pushes)
    : super(
        ScriptSyncServiceMock.stateManager,
        ScriptSyncServiceMock.balanceSyncService,
        ScriptSyncServiceMock.transactionSyncService,
        ScriptSyncServiceMock.utxoSyncService,
        ScriptSyncServiceMock.addressRepository,
        ScriptSyncServiceMock.scriptCallbackService,
        retryDelays: const [],
      );

  @override
  Future<void> syncScriptStatus(SubscribeScriptStreamDto dto) async => pushes.add(dto.walletItem.id);
}

void main() {
  setUp(ScriptSyncServiceMock.init);
  tearDown(() {
    ScriptSyncServiceMock.realmManager?.dispose();
    ScriptSyncServiceMock.realmManager = null;
  });

  test('unsubscribeWallet removes only this wallet\'s subscriptions', () async {
    const walletId = 907;
    final wallet = WalletMock.createSingleSigWalletItem(id: walletId);
    final electrum = ScriptSyncServiceMock.electrumService;
    when(electrum.unsubscribeScriptForWallet(any, any, walletId: anyNamed('walletId'))).thenAnswer((_) async => true);
    final subscriptions = SubscriptionService(
      electrum,
      ScriptSyncServiceMock.stateManager,
      ScriptSyncServiceMock.addressRepository,
      SubscriptionRepository(ScriptSyncServiceMock.realmManager!),
      ScriptSyncServiceMock.createMockScriptSyncService(),
    );

    await subscriptions.unsubscribeWallet(wallet);

    verify(electrum.unsubscribeScriptForWallet(any, any, walletId: walletId)).called(greaterThan(0));
    verifyNever(electrum.unsubscribeScript(any, any));
  });

  // Review round 1 (Codex probe), over the real ElectrumService and SocketManager with a fake socket.
  test('[codex-unsubscribe-error] retrying subscribe after an unsubscribe RPC error restores live pushes', () async {
    final incoming = StreamController<Uint8List>();
    final methods = <String>[];
    final socket = MockSecureSocket();
    final factory = MockSocketFactory();
    when(
      socket.listen(
        any,
        onError: anyNamed('onError'),
        onDone: anyNamed('onDone'),
        cancelOnError: anyNamed('cancelOnError'),
      ),
    ).thenAnswer((call) => incoming.stream.listen(call.positionalArguments[0] as void Function(Uint8List)));
    when(socket.close()).thenAnswer((_) async {});
    when(socket.writeln(any)).thenAnswer((call) {
      final request = jsonDecode(call.positionalArguments[0] as String) as Map<String, dynamic>;
      final method = request['method'] as String;
      methods.add(method);
      final response = <String, dynamic>{'jsonrpc': '2.0', 'id': request['id']};
      if (method == 'blockchain.scripthash.unsubscribe') {
        response['error'] = {'code': -32603, 'message': 'transient unsubscribe error'};
      } else {
        response['result'] = null;
      }
      Timer.run(() => incoming.add(utf8.encode(jsonEncode(response))));
    });
    when(factory.createSecureSocket(any, any)).thenAnswer((_) async => socket);
    final electrum = ElectrumService(socketManager: SocketManager(factory: factory, maxConnectionAttempts: 3));
    expect(await electrum.connect('localhost', 50002), isTrue);
    addTearDown(() async {
      await electrum.close();
      await incoming.close();
    });
    final pushes = <int>[];
    final service = SubscriptionService(
      electrum,
      ScriptSyncServiceMock.stateManager,
      ScriptSyncServiceMock.addressRepository,
      SubscriptionRepository(ScriptSyncServiceMock.realmManager!),
      _InertSync(pushes),
    );
    final wallet = WalletMock.createSingleSigWalletItem(id: 1);
    final address = wallet.walletBase.getAddress(0);
    await service.subscribeAddress(wallet, 0, address, false);
    final hash = ElectrumUtil.addressToReversedScriptHash(wallet.walletBase.addressType, address);
    Future<List<int>> push(String status) async {
      pushes.clear();
      incoming.add(
        utf8.encode(
          jsonEncode({
            'jsonrpc': '2.0',
            'method': 'blockchain.scripthash.subscribe',
            'params': [hash, status],
          }),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      return [...pushes];
    }

    expect(await push('before'), [1]);
    await expectLater(service.unsubscribeAddress(wallet, address), throwsA(isA<Map>()));
    await service.subscribeAddress(wallet, 0, address, false);
    final received = await push('after-retry');
    // ignore: avoid_print
    print('CODEX_UNSUBSCRIBE received=$received methods=$methods cached=${wallet.subscribedScriptMap.length}');
    expect(received, [
      1,
    ], reason: 'cached subscription metadata must agree with the actual socket listener after an error');
  });
}
