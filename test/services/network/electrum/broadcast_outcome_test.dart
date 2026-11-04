import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/model/error/app_error.dart';
import 'package:coconut_wallet/providers/node_provider/network_service.dart';
import 'package:coconut_wallet/providers/node_provider/transaction/mempool_api_service.dart';
import 'package:coconut_wallet/services/electrum_service.dart';
import 'package:coconut_wallet/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mockito/mockito.dart';

import 'electrum_service_test.mocks.dart';

/// A node can accept a payment whose reply never arrives. Reporting it as failed invites the user to pay again.
void main() {
  late Transaction sent;
  late Transaction other;

  setUpAll(() {
    Map<String, dynamic> fixture(String name) =>
        jsonDecode(File('test/fixtures/signing/$name.json').readAsStringSync()) as Map<String, dynamic>;
    sent = Transaction.parse(fixture('coldcard_raw')['returnedPayload'] as String);
    other = Psbt.parse(fixture('trezor_usb')['returnedPayload'] as String).unsignedTransaction!;
    expect(other.transactionHash, isNot(sent.transactionHash));
  });

  /// [broadcast]: reply | drop | reject. [lookup]: found | missing | other | drop (blockchain.transaction.get).
  Future<({Result<String> result, List<String> methods, int fallbackCalls, MockSocketManager socket})> send(
    String broadcast,
    String lookup, {
    bool connected = true,
  }) async {
    final socket = MockSocketManager();
    final methods = <String>[];
    final pending = <int, String>{};
    when(
      socket.connectionStatus,
    ).thenReturn(connected ? SocketConnectionStatus.connected : SocketConnectionStatus.terminated);
    when(socket.send(any)).thenAnswer((call) async {
      final request = jsonDecode(call.positionalArguments.single as String) as Map<String, dynamic>;
      methods.add(request['method'] as String);
      pending[request['id'] as int] = request['method'] as String;
    });
    when(socket.setCompleter(any, any)).thenAnswer((call) {
      final method = pending.remove(call.positionalArguments[0] as int)!;
      final completer = call.positionalArguments[1] as Completer<Map>;
      switch (method == 'blockchain.transaction.broadcast' ? broadcast : lookup) {
        case 'reply':
          completer.complete({'result': sent.transactionHash});
        case 'reject':
          completer.complete({
            'error': {'code': -26, 'message': 'rejected'},
          });
        case 'found':
          completer.complete({'result': sent.serialize()});
        case 'missing':
          completer.complete({
            'error': {'code': -5, 'message': 'No such mempool or blockchain transaction'},
          });
        case 'other':
          completer.complete({'result': other.serialize()});
        case 'method':
          completer.complete({
            'error': {'code': -32601, 'message': 'Method not found'},
          });
        case 'busy':
          completer.complete({
            'error': {'code': -32603, 'message': 'server busy, retry later'},
          });
      }
    });
    var fallbackCalls = 0;
    final electrum = ElectrumService(
      socketManager: socket,
      mempoolApiFactory:
          () => MempoolApi(
            client: MockClient((_) async {
              fallbackCalls++;
              return http.Response('not found', 404);
            }),
          ),
    );

    final result = await NetworkService(
      electrum,
    ).broadcast(sent, replyTimeout: const Duration(milliseconds: 20), checkTimeout: const Duration(milliseconds: 20));
    return (result: result, methods: methods, fallbackCalls: fallbackCalls, socket: socket);
  }

  test('a normal reply needs no lookup', () async {
    final r = await send('reply', 'missing');
    expect(r.result.value, sent.transactionHash);
    expect(r.methods, ['blockchain.transaction.broadcast']);
  });

  test('a lost reply for a payment the node accepted is a success, not a failure to resend', () async {
    final r = await send('drop', 'found');
    expect(r.result.value, sent.transactionHash);
    expect(r.methods, ['blockchain.transaction.broadcast', 'blockchain.transaction.get']);
  });

  test('a rejection for a payment the node already has (sent before) is a success', () async {
    expect((await send('reject', 'found')).result.value, sent.transactionHash);
  });

  test('an unanswered broadcast the node does not have keeps the old timeout error and message', () async {
    for (final lookup in ['missing', 'other', 'drop']) {
      final r = await send('drop', lookup);
      expect(r.result.isFailure, isTrue, reason: lookup);
      expect(r.result.error.code, ErrorCodes.nodeIsolateError.code, reason: lookup);
    }
  });

  test('a rejection the node does not have keeps the server message', () async {
    final r = await send('reject', 'missing');
    expect(r.result.error.code, ErrorCodes.broadcastError.code);
    expect(r.result.error.message, contains('rejected'));
  });

  test('a rejection the lookup could not answer is an unknown outcome, not a failure', () async {
    // e.g. the same transaction sent earlier is already in a block and its lookup timed out or the server was busy
    for (final lookup in ['drop', 'other', 'busy', 'method']) {
      expect((await send('reject', lookup)).result.error.code, ErrorCodes.nodeIsolateError.code, reason: lookup);
    }
  });

  test('no connection sends nothing and stays an unknown outcome', () async {
    final r = await send('reply', 'found', connected: false);
    expect(r.result.error.code, ErrorCodes.nodeIsolateError.code);
    expect(r.methods, isEmpty);
  });

  test('the reply wait is the RPC timeout itself, so nothing waits on past it', () async {
    final r = await send('drop', 'missing');
    // Both registrations are already gone when broadcast returns: the broadcast RPC used the reply limit,
    // not the default 60 s that an outer timeout could not shorten or extend.
    verify(r.socket.removeCompleter(1)).called(1);
    verify(r.socket.removeCompleter(2)).called(1);
  });

  test('the check asks only the Electrum server, never the mempool API fallback', () async {
    for (final (broadcast, lookup) in [
      ('drop', 'found'),
      ('drop', 'missing'),
      ('drop', 'drop'),
      ('reject', 'missing'),
    ]) {
      expect((await send(broadcast, lookup)).fallbackCalls, 0, reason: '$broadcast + $lookup');
    }
  });
}
