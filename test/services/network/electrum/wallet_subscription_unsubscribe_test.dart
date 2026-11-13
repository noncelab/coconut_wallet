import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/model/node/subscribe_stream_dto.dart';
import 'package:coconut_wallet/providers/node_provider/state/state_manager_interface.dart';
import 'package:coconut_wallet/providers/node_provider/subscription/script_sync_service.dart';
import 'package:coconut_wallet/providers/node_provider/subscription/subscription_service.dart';
import 'package:coconut_wallet/repository/realm/address_repository.dart';
import 'package:coconut_wallet/repository/realm/subscription_repository.dart';
import 'package:coconut_wallet/services/electrum_service.dart';
import 'package:coconut_wallet/services/network/socket/socket_manager.dart';
import 'package:coconut_wallet/utils/electrum_utils.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import '../../../mock/wallet_mock.dart';
import '../socket/socket_manager_test.mocks.dart';

class _State extends Fake implements StateManagerInterface {}

class _Addresses extends Fake implements AddressRepository {}

class _Subscriptions extends Fake implements SubscriptionRepository {}

class _Sync extends Mock implements ScriptSyncService {
  final events = <SubscribeScriptStreamDto>[];
  @override
  Future<void> syncScriptStatus(SubscribeScriptStreamDto dto) async => events.add(dto);
}

class _Wire {
  final factory = MockSocketFactory();
  final socket = MockSocket();
  final incoming = StreamController<Uint8List>();
  final requests = <Map<String, dynamic>>[];
  late final manager = SocketManager(factory: factory);
  late final electrum = ElectrumService(socketManager: manager);
  bool rejectUnsubscribe = false;

  Future<void> open() async {
    when(factory.createSocket(any, any, timeout: anyNamed('timeout'))).thenAnswer((_) async => socket);
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
      final req = jsonDecode(call.positionalArguments.single as String) as Map<String, dynamic>;
      requests.add(req);
      final unsubscribe = req['method'] == 'blockchain.scripthash.unsubscribe';
      Timer.run(
        () => incoming.add(
          Uint8List.fromList(
            utf8.encode(
              jsonEncode({
                'id': req['id'],
                if (unsubscribe && rejectUnsubscribe)
                  'error': {'code': -32601, 'message': 'unsubscribe unavailable'}
                else
                  'result': unsubscribe ? true : null,
              }),
            ),
          ),
        ),
      );
    });
    expect(await electrum.connect('review.invalid', 50001, ssl: false), isTrue);
  }

  int get unsubscribeCount => requests.where((r) => r['method'] == 'blockchain.scripthash.unsubscribe').length;
  int get subscribeCount => requests.where((r) => r['method'] == 'blockchain.scripthash.subscribe').length;

  Future<void> notify(String address, String status) async {
    incoming.add(
      Uint8List.fromList(
        utf8.encode(
          jsonEncode({
            'method': 'blockchain.scripthash.subscribe',
            'params': [ElectrumUtil.addressToReversedScriptHash(AddressType.p2wpkh, address), status],
          }),
        ),
      ),
    );
    await pumpEventQueue();
  }

  Future<void> close() async {
    await electrum.close();
    await incoming.close();
  }
}

void main() {
  setUpAll(() => NetworkType.setNetworkType(NetworkType.regtest));

  test('real Electrum and SocketManager remove only the leaving wallet and unsubscribe the last one', () async {
    final wire = _Wire();
    addTearDown(wire.close);
    await wire.open();
    final address = WalletMock.createSingleSigWalletItem().walletBase.getAddress(0);
    final delivered = <int>[];
    Future<void> subscribe(int walletId) async {
      await wire.electrum.subscribeScriptForWallet(
        AddressType.p2wpkh,
        address,
        walletId: walletId,
        onUpdate: (_, __) => delivered.add(walletId),
      );
    }

    await subscribe(1);
    await subscribe(2);
    await subscribe(1);
    await wire.notify(address, 'first');
    expect(delivered, [1, 2], reason: 'resubscribe replaces, rather than duplicates, a callback');
    delivered.clear();
    expect(await wire.electrum.unsubscribeScriptForWallet(AddressType.p2wpkh, address, walletId: 1), isTrue);
    expect(wire.unsubscribeCount, 0);
    await wire.notify(address, 'second');
    expect(delivered, [2]);
    delivered.clear();
    expect(await wire.electrum.unsubscribeScriptForWallet(AddressType.p2wpkh, address, walletId: 2), isTrue);
    expect(wire.unsubscribeCount, 1);
    await wire.notify(address, 'third');
    expect(delivered, isEmpty);
    await subscribe(1);
    await wire.notify(address, 'fourth');
    expect(delivered, [1]);
    expect(await wire.electrum.unsubscribeScriptForWallet(AddressType.p2wpkh, address, walletId: 1), isTrue);
    expect(wire.unsubscribeCount, 2, reason: 'a single-wallet subscription is removed server-side');
  });

  test('fresh reconnect accepts both wallet callbacks once after one wallet previously left', () async {
    final address = WalletMock.createSingleSigWalletItem().walletBase.getAddress(0);
    final old = _Wire();
    await old.open();
    await old.electrum.subscribeScriptForWallet(AddressType.p2wpkh, address, walletId: 1, onUpdate: (_, __) {});
    await old.electrum.unsubscribeScriptForWallet(AddressType.p2wpkh, address, walletId: 1);
    await old.close();
    final fresh = _Wire();
    addTearDown(fresh.close);
    await fresh.open();
    final delivered = <int>[];
    for (final id in [1, 2]) {
      await fresh.electrum.subscribeScriptForWallet(
        AddressType.p2wpkh,
        address,
        walletId: id,
        onUpdate: (_, __) => delivered.add(id),
      );
    }
    await fresh.notify(address, 'after-reconnect');
    expect(delivered, [1, 2]);
  });

  test('failed last-listener unsubscribe retains a usable subscription or permits resubscribe', () async {
    final wire = _Wire();
    addTearDown(wire.close);
    await wire.open();
    final wallet = WalletMock.createSingleSigWalletItem();
    final address = wallet.walletBase.getAddress(0);
    final sync = _Sync();
    final service = SubscriptionService(wire.electrum, _State(), _Addresses(), _Subscriptions(), sync);
    await service.subscribeAddress(wallet, 0, address, false);
    wire.rejectUnsubscribe = true;
    await expectLater(service.unsubscribeAddress(wallet, address), throwsA(isA<Map>()));
    final beforeRetry = wire.subscribeCount;
    await service.subscribeAddress(wallet, 0, address, false);
    await wire.notify(address, 'new-funds');
    expect(
      sync.events.length,
      1,
      reason:
          'failed unsubscribe left ${wallet.subscribedScriptMap.length} local script entries; '
          'subscribe requests before/after retry: $beforeRetry/${wire.subscribeCount}',
    );
  });
}
