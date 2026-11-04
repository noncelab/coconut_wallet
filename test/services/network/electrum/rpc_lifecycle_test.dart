import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:coconut_wallet/providers/node_provider/transaction/mempool_api_service.dart';
import 'package:coconut_wallet/services/electrum_service.dart';
import 'package:coconut_wallet/services/network/socket/socket_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mockito/mockito.dart';

import '../socket/socket_manager_test.mocks.dart';

// Only native I/O is mocked: registrations, JSON dispatch and RPC timeout handling are real.
class _ObservedSocket extends SocketManager {
  _ObservedSocket(MockSocketFactory factory) : super(factory: factory);
  final sources = <int, Completer<dynamic>>{};
  @override
  void setCompleter(int id, Completer completer) {
    sources[id] = completer;
    super.setCompleter(id, completer);
  }
}

Future<void> _offline(
  Future<void> Function(_ObservedSocket socket, ElectrumService service, void Function(int) reply, List<String> logs)
  body,
) async {
  final logs = <String>[];
  await runZoned(() async {
    final stream = StreamController<Uint8List>();
    final native = MockSocket();
    final factory = MockSocketFactory();
    when(factory.createSocket(any, any, timeout: anyNamed('timeout'))).thenAnswer((_) async => native);
    when(native.close()).thenAnswer((_) async => null);
    when(native.writeln(any)).thenReturn(null);
    when(
      native.listen(
        any,
        onError: anyNamed('onError'),
        onDone: anyNamed('onDone'),
        cancelOnError: anyNamed('cancelOnError'),
      ),
    ).thenAnswer(
      (call) => stream.stream.listen(
        call.positionalArguments[0] as void Function(Uint8List),
        onDone: call.namedArguments[#onDone] as void Function()?,
      ),
    );
    final socket = _ObservedSocket(factory);
    await socket.connect('offline.invalid', 50001, ssl: false);
    final service = ElectrumService(
      socketManager: socket,
      mempoolApiFactory: () => MempoolApi(client: MockClient((_) async => http.Response('missing', 404))),
    );
    void reply(int id) => stream.add(Uint8List.fromList(utf8.encode(jsonEncode({'id': id, 'result': 'raw hex'}))));
    try {
      await body(socket, service, reply, logs);
    } finally {
      // Also settle observations on a deliberately failing pre-fix run.
      for (final source in socket.sources.values) {
        if (!source.isCompleted) source.completeError(const SocketException('test teardown'));
      }
      await service.close();
      await stream.close();
    }
  }, zoneSpecification: ZoneSpecification(print: (self, parent, zone, line) => logs.add(line)));
}

void main() {
  for (final count in [1, 20]) {
    test('$count RPC timeouts retain no registrations and ignore every late response silently', () async {
      await _offline((socket, service, reply, logs) async {
        for (var i = 0; i < count; i++) {
          await expectLater(
            service.getTransaction('11' * 32, timeout: const Duration(milliseconds: 1)),
            throwsA(isA<MempoolHttpNotFound>()),
          );
        }
        expect(socket.sources.length, count);
        logs.clear();
        for (final id in socket.sources.keys) {
          reply(id);
        }
        await Future<void>.delayed(Duration.zero);
        // A retained registration would complete its original source on the late response. This observes the
        // actual private registry without adding a production getter or duplicating the map in a fake transport.
        expect(socket.sources.values.where((source) => source.isCompleted), isEmpty);
        expect(logs, isEmpty);
      });
    });
  }

  test('a successful response removes its registration and duplicate responses are silent', () async {
    await _offline((socket, service, reply, logs) async {
      final result = service.getTransaction('11' * 32);
      await Future<void>.delayed(Duration.zero);
      reply(service.reqId);
      expect(await result, 'raw hex');
      logs.clear();
      reply(service.reqId);
      await Future<void>.delayed(Duration.zero);
      expect(logs, isEmpty);
    });
  });

  for (final explicitClose in [true, false]) {
    test('connection termination settles and clears pending RPCs (explicit=$explicitClose)', () async {
      await _offline((socket, service, reply, logs) async {
        final checks = [
          for (var i = 0; i < 3; i++)
            expectLater(
              service.getTransaction('11' * 32, timeout: const Duration(hours: 1)),
              throwsA(isA<MempoolHttpNotFound>()),
            ),
        ];
        await Future<void>.delayed(Duration.zero);
        expect(socket.sources.length, 3);
        if (explicitClose) {
          await service.close();
        } else {
          socket.markConnectionLost();
        }
        expect(
          socket.sources.values.every((source) => source.isCompleted),
          isTrue,
          reason: 'closing must settle pending calls without waiting for their response timeouts',
        );
        await Future.wait(checks);
        logs.clear();
        for (final id in socket.sources.keys) {
          reply(id);
        }
        await Future<void>.delayed(Duration.zero);
        expect(logs, isEmpty, reason: 'a disconnect also removes the completed registrations');
      });
    });
  }
}
