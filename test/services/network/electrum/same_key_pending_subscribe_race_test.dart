// 같은 키 지갑들의 구독이 응답을 기다리는 동안 겹쳐도 실시간 알림이 끊기지 않는지(#790 리뷰 1).
// 실제 ElectrumService·SocketManager에 가짜 소켓만 붙인다. 가짜 서버는 요청이 도착한 순서대로 구독·해제를 반영하고
// (응답은 늦게, 성공이나 실패로 보낼 수 있음), 구독이 남아 있는 스크립트에만 상태 알림을 보낸다(실제 Electrum처럼 연결별).
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/model/node/subscribe_stream_dto.dart';
import 'package:coconut_wallet/model/wallet/wallet_address.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
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

/// 지갑 삭제(unsubscribeWallet)가 읽는 활성 주소는 없다고 둔다(gap 창 주소만 해제)
class _Addresses extends Fake implements AddressRepository {
  @override
  List<WalletAddress> getActiveUsedAddresses(int walletId, bool isChange) => const [];
}

class _Subscriptions extends Fake implements SubscriptionRepository {}

class _Sync extends Mock implements ScriptSyncService {
  final events = <SubscribeScriptStreamDto>[];
  @override
  Future<void> syncScriptStatus(SubscribeScriptStreamDto dto) async => events.add(dto);
}

/// 잡아 둔 subscribe 하나. [fail]이면 서버가 구독하지 않고 오류로 답한다
class _Held {
  _Held({this.fail = false});
  final bool fail;
  final _gate = Completer<void>();
  void release() => _gate.complete();
}

class _Wire {
  final factory = MockSocketFactory();
  final socket = MockSocket();
  final incoming = StreamController<Uint8List>();
  final requests = <Map<String, dynamic>>[];
  late final manager = SocketManager(factory: factory);
  late final electrum = ElectrumService(socketManager: manager);

  /// 서버가 지금 구독 중인 스크립트 해시(도착 순서대로 반영)
  final serverSubscribed = <String>{};

  /// 정해 두면 다음 subscribe 하나의 응답을 [_Held.release]까지 미룬다
  _Held? holdNextSubscribe;

  void _send(Map<String, Object?> message) => incoming.add(Uint8List.fromList(utf8.encode(jsonEncode(message))));

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
      final method = req['method'];
      final params = req['params'] as List?;
      if (method == 'blockchain.scripthash.subscribe') {
        final hold = holdNextSubscribe;
        holdNextSubscribe = null;
        if (hold?.fail != true) serverSubscribed.add(params!.first as String);
        void reply() => _send({
          'id': req['id'],
          if (hold?.fail == true) 'error': {'code': -32000, 'message': 'held failure'} else 'result': null,
        });
        if (hold != null) {
          unawaited(hold._gate.future.then((_) => reply()));
        } else {
          Timer.run(reply);
        }
        return;
      }
      if (method == 'blockchain.scripthash.unsubscribe') serverSubscribed.remove(params!.first as String);
      Timer.run(() => _send({'id': req['id'], 'result': method == 'blockchain.scripthash.unsubscribe' ? true : null}));
    });
    expect(await electrum.connect('review.invalid', 50001, ssl: false), isTrue);
  }

  String hashOf(String address) => ElectrumUtil.addressToReversedScriptHash(AddressType.p2wpkh, address);

  int count(String method) => requests.where((r) => r['method'] == 'blockchain.scripthash.$method').length;

  /// 이 주소에 간 요청 순서
  List<String> requestsFor(String address) => [
    for (final r in requests)
      if ((r['params'] as List?)?.first == hashOf(address)) (r['method'] as String).split('.').last,
  ];

  /// 서버가 아직 구독 중일 때만 상태 알림을 보낸다
  Future<void> notify(String address, String status) async {
    final hash = hashOf(address);
    if (serverSubscribed.contains(hash)) {
      _send({
        'method': 'blockchain.scripthash.subscribe',
        'params': [hash, status],
      });
    }
    await pumpEventQueue();
  }

  Future<void> close() async {
    await electrum.close();
    await incoming.close();
  }
}

/// 같은 키의 지갑 A(1)·B(2), 같은 주소
class _Rig {
  _Rig(this.wire) : sync = _Sync() {
    service = SubscriptionService(wire.electrum, _State(), _Addresses(), _Subscriptions(), sync);
  }

  final _Wire wire;
  final _Sync sync;
  late final SubscriptionService service;
  final a = WalletMock.createSingleSigWalletItem(id: 1);
  final b = WalletMock.createSingleSigWalletItem(id: 2);
  late final address = a.walletBase.getAddress(0);

  static Future<_Rig> open() async {
    final wire = _Wire();
    addTearDown(wire.close);
    await wire.open();
    final rig = _Rig(wire);
    expect(rig.b.walletBase.getAddress(0), rig.address, reason: 'same key, same address');
    return rig;
  }

  Future<void> subscribe(WalletItemBase wallet) => service.subscribeAddress(wallet, 0, address, false);

  bool hasCallback(WalletItemBase wallet) =>
      wire.manager.hasWalletSubscriptionCallback(wire.hashOf(address), wallet.id);

  /// 새 상태 알림을 보내고, 받은 지갑·서버 구독·B의 콜백과 로컬 목록을 한 줄로 돌려준다(실패 메시지용)
  Future<String> notifyAndReport() async {
    sync.events.clear();
    await wire.notify(address, 'status-${wire.requests.length}');
    final delivered = [for (final event in sync.events) event.walletItem.id];
    return 'delivered=$delivered server=${wire.serverSubscribed.contains(wire.hashOf(address)) ? 1 : 0} '
        'bCallback=${hasCallback(b) ? 1 : 0} bLocal=${b.subscribedScriptMap.length} '
        'requests=${wire.requestsFor(address)}';
  }
}

void main() {
  setUpAll(() => NetworkType.setNetworkType(NetworkType.regtest));

  final entries = <String, Future<void> Function(SubscriptionService, WalletItemBase, String)>{
    'empty-address unsubscribe': (service, wallet, address) => service.unsubscribeAddress(wallet, address),
    'wallet delete': (service, wallet, _) async {
      await service.unsubscribeWallet(wallet);
    },
  };

  for (final MapEntry(key: entry, value: leave) in entries.entries) {
    group(entry, () {
      /// A가 구독을 마친 뒤 B가 같은 주소를 구독한다(응답은 잡아 둠). [bReplyFirst]면 B의 응답을 먼저 끝낸 뒤 A가 떠나고
      /// (대조군), 아니면 A가 떠난 뒤 B의 응답이 온다(리뷰가 말한 겹침)
      Future<String> aLeavesWhileB({required bool bReplyFirst}) async {
        final rig = await _Rig.open();
        await rig.subscribe(rig.a);
        final held = _Held();
        rig.wire.holdNextSubscribe = held;
        final bSubscribed = rig.subscribe(rig.b);
        await pumpEventQueue();
        expect(rig.wire.count('subscribe'), 2, reason: "B's subscribe is on the wire and its reply is held");
        if (bReplyFirst) {
          held.release();
          await bSubscribed;
        }
        await leave(rig.service, rig.a, rig.address);
        if (!bReplyFirst) {
          held.release();
          await bSubscribed;
        }
        return rig.notifyAndReport();
      }

      test("race: A leaves while B's subscribe reply is still pending -> B keeps notifications", () async {
        final result = await aLeavesWhileB(bReplyFirst: false);
        expect(result, startsWith('delivered=[2] server=1 bCallback=1 bLocal=1'), reason: result);
      });

      test("control: B's subscribe reply arrives before A leaves -> B keeps notifications", () async {
        final result = await aLeavesWhileB(bReplyFirst: true);
        expect(result, startsWith('delivered=[2] server=1 bCallback=1 bLocal=1'), reason: result);
      });

      // 콜백을 먼저 등록해도, 마지막 구독자가 떠나면 서버 해제는 나간다
      test('the last subscriber leaving still unsubscribes on the server', () async {
        final rig = await _Rig.open();
        await rig.subscribe(rig.a);
        await rig.subscribe(rig.b);
        await leave(rig.service, rig.a, rig.address);
        expect(rig.wire.requestsFor(rig.address), ['subscribe', 'subscribe'], reason: 'B still listens');
        await leave(rig.service, rig.b, rig.address);
        final result = await rig.notifyAndReport();
        expect(result, startsWith('delivered=[] server=0 bCallback=0 bLocal=0'), reason: result);
        expect(rig.wire.requestsFor(rig.address), ['subscribe', 'subscribe', 'unsubscribe']);
      });
    });
  }

  // 같은 지갑의 앞선 구독이 실패해도, 그사이 성공한 같은 지갑의 새 구독(콜백)은 지우지 않는다
  test("a failed earlier subscribe never removes the same wallet's newer, successful subscription", () async {
    final rig = await _Rig.open();
    final first = _Held(fail: true);
    rig.wire.holdNextSubscribe = first;
    final earlier = rig.subscribe(rig.b);
    await pumpEventQueue();
    await rig.subscribe(rig.b); // 목록에 아직 없어 다시 요청하고, 이번에는 성공한다
    first.release();
    await expectLater(earlier, throwsA(isA<Map>()));
    final result = await rig.notifyAndReport();
    expect(result, startsWith('delivered=[2] server=1 bCallback=1 bLocal=1'), reason: result);
  });

  // 다른 지갑이 같은 주소를 듣고 있을 때 B의 구독이 실패하면 B만 되돌리고, A의 알림은 그대로이며 B는 다시 붙을 수 있다
  test("a failed subscribe while another wallet holds the address rolls back only the failing wallet", () async {
    final rig = await _Rig.open();
    await rig.subscribe(rig.a);
    final held = _Held(fail: true);
    rig.wire.holdNextSubscribe = held;
    final failing = rig.subscribe(rig.b);
    await pumpEventQueue();
    held.release();
    await expectLater(failing, throwsA(isA<Map>()));
    var result = await rig.notifyAndReport();
    expect(result, startsWith('delivered=[1] server=1 bCallback=0 bLocal=0'), reason: result);
    await rig.subscribe(rig.b);
    result = await rig.notifyAndReport();
    expect(result, startsWith('delivered=[1, 2] server=1 bCallback=1 bLocal=1'), reason: result);
  });

  // 응답 전에 온 알림(A의 서버 구독 덕분)이 B의 목록에 항목을 넣었더라도, B의 구독이 실패하면 그 항목을 남기지 않는다
  test('an early notification before a failed reply leaves no stale entry, so B can subscribe again', () async {
    final rig = await _Rig.open();
    await rig.subscribe(rig.a);
    final held = _Held(fail: true);
    rig.wire.holdNextSubscribe = held;
    final failing = rig.subscribe(rig.b);
    await pumpEventQueue();
    await rig.wire.notify(rig.address, 'early');
    expect(rig.b.subscribedScriptMap, hasLength(1), reason: 'the early notification reached B before its reply');
    held.release();
    await expectLater(failing, throwsA(isA<Map>()));
    expect(rig.b.subscribedScriptMap, isEmpty);
    await rig.subscribe(rig.b);
    final result = await rig.notifyAndReport();
    expect(result, startsWith('delivered=[1, 2] server=1 bCallback=1 bLocal=1'), reason: result);
  });

  // 지갑 삭제가 B의 구독 응답보다 먼저 끝나면, 늦게 온 성공 응답이 콜백도 목록 항목도 되살리지 않는다
  test('a late subscribe reply after the wallet was deleted revives neither the callback nor the entry', () async {
    final rig = await _Rig.open();
    final held = _Held();
    rig.wire.holdNextSubscribe = held;
    final pending = rig.subscribe(rig.b);
    await pumpEventQueue();
    await rig.service.unsubscribeWallet(rig.b);
    held.release();
    await pending;
    final result = await rig.notifyAndReport();
    expect(result, startsWith('delivered=[] server=0 bCallback=0 bLocal=0'), reason: result);
    expect(rig.wire.requestsFor(rig.address), ['subscribe', 'unsubscribe']);
  });

  // 재동기화처럼 목록만 비우고 다시 구독했다가 실패하면, 이전에 성공한 B의 콜백으로 돌아가 알림을 계속 받는다
  test("a failed re-subscribe keeps the wallet's previous successful callback (the list was cleared first)", () async {
    final rig = await _Rig.open();
    await rig.subscribe(rig.a);
    await rig.subscribe(rig.b);
    rig.b.subscribedScriptMap.clear(); // WalletResyncService가 subscribeWallet 전에 비운다
    final held = _Held(fail: true);
    rig.wire.holdNextSubscribe = held;
    final retry = rig.subscribe(rig.b);
    await pumpEventQueue();
    held.release();
    await expectLater(retry, throwsA(isA<Map>()));
    final result = await rig.notifyAndReport();
    expect(result, startsWith('delivered=[1, 2] server=1 bCallback=1 bLocal=1'), reason: result);
  });

  // Electrum 층에서 바로: 성공 → 같은 지갑 재구독 실패 → 알림은 이전 콜백이 받는다
  test('a failed same-wallet re-subscribe keeps the previous callback at the Electrum level', () async {
    final rig = await _Rig.open();
    final delivered = <String>[];
    await rig.wire.electrum.subscribeScriptForWallet(
      AddressType.p2wpkh,
      rig.address,
      walletId: 2,
      onUpdate: (_, status) => delivered.add('old:$status'),
    );
    final held = _Held(fail: true);
    rig.wire.holdNextSubscribe = held;
    final retry = rig.wire.electrum.subscribeScriptForWallet(
      AddressType.p2wpkh,
      rig.address,
      walletId: 2,
      onUpdate: (_, status) => delivered.add('new:$status'),
    );
    await pumpEventQueue();
    held.release();
    await expectLater(retry, throwsA(isA<Map>()));
    await rig.wire.notify(rig.address, 'still-subscribed');
    expect(delivered, ['old:still-subscribed']);
  });

  // 실패 전에 이 지갑을 해제했으면(다른 지갑은 남음) 실패해도 이전 콜백을 되살리지 않는다
  test('a failed re-subscribe after an explicit unsubscribe revives nothing', () async {
    final rig = await _Rig.open();
    await rig.subscribe(rig.a);
    await rig.subscribe(rig.b);
    rig.b.subscribedScriptMap.clear();
    final held = _Held(fail: true);
    rig.wire.holdNextSubscribe = held;
    final retry = rig.subscribe(rig.b);
    await pumpEventQueue();
    await rig.service.unsubscribeWallet(rig.b);
    held.release();
    await expectLater(retry, throwsA(isA<Map>()));
    final result = await rig.notifyAndReport();
    expect(result, startsWith('delivered=[1] server=1 bCallback=0 bLocal=0'), reason: result);
  });

  // 응답을 잡아 둔 사이 온 알림(새 상태) 뒤에 지난 스냅숏(null)을 담은 성공 응답이 와도, 목록과 이미 넘긴 이벤트는 새 상태다
  test('an early notification is not overwritten by an older snapshot in the reply', () async {
    final rig = await _Rig.open();
    final held = _Held();
    rig.wire.holdNextSubscribe = held;
    final pending = rig.subscribe(rig.b);
    await pumpEventQueue();
    await rig.wire.notify(rig.address, 'early-new-status');
    expect(rig.sync.events.single.scriptStatus.status, 'early-new-status');
    held.release();
    await pending;
    expect(
      'local=${rig.b.subscribedScriptMap.values.single.status} queued=${rig.sync.events.single.scriptStatus.status}',
      'local=early-new-status queued=early-new-status',
    );
  });

  // 큐로 넘긴 이벤트는 자기 상태를 지닌다: 뒤의 알림이 앞서 넘긴 이벤트를 바꾸지 않는다
  test('a queued event keeps its own status when a later notification arrives', () async {
    final rig = await _Rig.open();
    await rig.subscribe(rig.b);
    await rig.wire.notify(rig.address, 'first');
    await rig.wire.notify(rig.address, 'second');
    expect([for (final event in rig.sync.events) event.scriptStatus.status], ['first', 'second']);
  });
}
