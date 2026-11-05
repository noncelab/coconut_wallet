import 'dart:async';
import 'dart:convert';

import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/providers/node_provider/transaction/mempool_api_service.dart';
import 'package:coconut_wallet/services/electrum_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mockito/mockito.dart';

import '../services/network/electrum/electrum_service_test.mocks.dart';

/// Exercises the real transaction/parent loader without opening a socket or making an HTTP request.
class ElectrumTransactionTransport {
  late final ElectrumService service;
  final requestedHashes = <String>[];

  ElectrumTransactionTransport(FutureOr<String> Function(String hash) rawTransaction) {
    final socket = MockSocketManager();
    final requests = <int, String>{};
    when(socket.connectionStatus).thenReturn(SocketConnectionStatus.connected);
    when(socket.send(any)).thenAnswer((call) async {
      final request = jsonDecode(call.positionalArguments.single as String) as Map<String, dynamic>;
      if (request['method'] != 'blockchain.transaction.get') throw StateError('Unexpected request: $request');
      final hash = (request['params'] as List).first as String;
      requests[request['id'] as int] = hash;
      requestedHashes.add(hash);
    });
    when(socket.setCompleter(any, any)).thenAnswer((call) {
      final hash = requests.remove(call.positionalArguments[0] as int)!;
      final completer = call.positionalArguments[1] as Completer<Map>;
      Future.sync(() => rawTransaction(hash)).then<void>(
        (raw) => completer.complete({'result': raw}),
        onError: (Object error, StackTrace stack) => completer.completeError(error, stack),
      );
    });
    service = ElectrumService(
      socketManager: socket,
      mempoolApiFactory: () => MempoolApi(client: MockClient((_) async => http.Response('offline fallback', 503))),
    );
  }
}
