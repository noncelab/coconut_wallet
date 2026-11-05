import 'dart:async';

import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/providers/node_provider/transaction/mempool_api_service.dart';
import 'package:coconut_wallet/services/electrum_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mockito/mockito.dart';

import 'electrum_service_test.mocks.dart';

void main() {
  const txid = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

  test('typed absence diagnostics contain no transaction identifiers', () {
    final failures = [TransactionNotFound(txid), MempoolHttpNotFound(txid)];
    expect(failures.map((error) => error.toString()), everyElement(isNot(contains(txid))));
  });

  test('HTTP 404 has a dedicated exception and other statuses do not', () async {
    for (final status in [404, 429, 500]) {
      final api = MempoolApi(client: MockClient((_) async => http.Response('unavailable', status)));
      try {
        await expectLater(
          api.fetchTxHex(txid),
          throwsA(status == 404 ? isA<MempoolHttpNotFound>() : isNot(isA<MempoolHttpNotFound>())),
        );
      } finally {
        api.close();
      }
    }
  });

  for (final failure in ['rpc', 'rpc internal error', 'timeout', 'transport', 'disconnect', 'invalid response']) {
    for (final fallback in ['404', '500', 'timeout', 'success']) {
      test('$failure + HTTP $fallback classifies absence only for RPC error + 404', () async {
        final socket = MockSocketManager();
        when(
          socket.connectionStatus,
        ).thenReturn(failure == 'disconnect' ? SocketConnectionStatus.terminated : SocketConnectionStatus.connected);
        when(socket.send(any)).thenAnswer((_) async {
          if (failure == 'transport') throw StateError('broken pipe');
        });
        when(socket.setCompleter(any, any)).thenAnswer((invocation) {
          final completer = invocation.positionalArguments[1] as Completer<Map>;
          if (failure == 'timeout') return;
          completer.complete(
            failure.startsWith('rpc')
                ? {
                  'error': {'code': failure == 'rpc' ? -5 : -32603, 'message': 'server response'},
                }
                : {'result': 42},
          );
        });
        var fallbackCalls = 0;
        final client = _ClosingClient((request) async {
          fallbackCalls++;
          expect(request.url.path, endsWith('/api/tx/$txid/hex'));
          if (fallback == 'timeout') throw TimeoutException('HTTP timeout');
          return http.Response(
            fallback == 'success' ? ' raw hex ' : 'unavailable',
            fallback == 'success' ? 200 : int.parse(fallback),
          );
        });
        final service = ElectrumService(socketManager: socket, mempoolApiFactory: () => MempoolApi(client: client));
        final result = service.getTransaction(txid, timeout: const Duration(milliseconds: 1));
        if (fallback == 'success') {
          expect(await result, 'raw hex');
        } else {
          await expectLater(
            result,
            throwsA(
              failure.startsWith('rpc') && fallback == '404'
                  ? isA<TransactionNotFound>()
                  : isNot(isA<TransactionNotFound>()),
            ),
          );
        }
        expect(fallbackCalls, 1);
        expect(client.closed, isTrue);
      });
    }
  }

  test('a successful Electrum response does not create an HTTP client', () async {
    final socket = MockSocketManager();
    when(socket.connectionStatus).thenReturn(SocketConnectionStatus.connected);
    when(socket.send(any)).thenAnswer((_) async {});
    when(socket.setCompleter(any, any)).thenAnswer((invocation) {
      (invocation.positionalArguments[1] as Completer<Map>).complete({'result': 'raw hex'});
    });
    final service = ElectrumService(
      socketManager: socket,
      mempoolApiFactory: () => throw StateError('HTTP must not be used'),
    );
    expect(await service.getTransaction(txid), 'raw hex');
  });
}

class _ClosingClient extends MockClient {
  bool closed = false;
  _ClosingClient(super.handler);

  @override
  void close() {
    closed = true;
    super.close();
  }
}
