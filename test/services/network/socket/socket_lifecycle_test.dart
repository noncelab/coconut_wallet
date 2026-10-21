import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/services/electrum_service.dart';
import 'package:coconut_wallet/services/network/socket/socket_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'socket_manager_test.mocks.dart';

void main() {
  const abort = SocketException('Software caused connection abort');
  const eventTimeout = Duration(seconds: 1);

  test('real TCP Electrum ping completes once before peer EOF reports loss', () async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final service = ElectrumService();
    final connectionLost = Completer<void>();
    final peerClosed = Completer<void>();
    final peers = <Socket>[];
    final methods = <String>[];
    var lossCount = 0;
    final connections = server.listen((socket) {
      peers.add(socket);
      socket.done.ignore();
      socket
          .cast<List<int>>()
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
            (line) {
              final request = jsonDecode(line) as Map<String, dynamic>;
              methods.add(request['method'] as String);
              socket.writeln(jsonEncode({'id': request['id'], 'result': null}));
              socket.close().ignore();
            },
            onError: peerClosed.completeError,
            onDone: peerClosed.complete,
          );
    }, onError: peerClosed.completeError);

    try {
      expect(await service.connect('127.0.0.1', server.port, ssl: false), isTrue);
      service.setOnConnectionLostCallback(() {
        lossCount++;
        if (!connectionLost.isCompleted) connectionLost.complete();
      });
      expect(await service.ping().timeout(eventTimeout), 'pong');
      await connectionLost.future.timeout(eventTimeout);
      expect(service.connectionStatus, SocketConnectionStatus.terminated);
      expect(lossCount, 1);
      expect(methods, ['server.ping']);
      await service.close();
      await peerClosed.future.timeout(eventTimeout);
      expect(lossCount, 1);
    } finally {
      await service.close();
      for (final socket in peers) {
        socket.destroy();
      }
      await connections.cancel();
      await server.close();
    }
  });

  for (final ssl in [false, true]) {
    group(ssl ? 'TLS socket lifecycle' : 'TCP socket lifecycle', () {
      late MockSocketFactory factory;
      late Socket socket;
      late SocketManager manager;
      late StreamController<Uint8List> reads;
      late Completer<void> sinkDone;
      late Completer<void> connectionLost;
      var lossCount = 0;

      setUp(() {
        factory = MockSocketFactory();
        socket = ssl ? MockSecureSocket() : MockSocket();
        reads = StreamController<Uint8List>(sync: true);
        sinkDone = Completer<void>();
        connectionLost = Completer<void>();
        lossCount = 0;
        when(socket.done).thenAnswer((_) => sinkDone.future);
        when(socket.close()).thenAnswer((_) => sinkDone.future);
        when(
          socket.listen(
            any,
            onError: anyNamed('onError'),
            onDone: anyNamed('onDone'),
            cancelOnError: anyNamed('cancelOnError'),
          ),
        ).thenAnswer((call) {
          return reads.stream.listen(
            call.positionalArguments[0] as void Function(Uint8List),
            onError: call.namedArguments[#onError],
            onDone: call.namedArguments[#onDone] as void Function(),
            cancelOnError: call.namedArguments[#cancelOnError] as bool,
          );
        });
        if (ssl) {
          when(factory.createSecureSocket(any, any)).thenAnswer((_) async => socket as SecureSocket);
        } else {
          when(factory.createSocket(any, any, timeout: anyNamed('timeout'))).thenAnswer((_) async => socket);
        }
        manager = SocketManager(factory: factory);
        manager.onConnectionLost = () {
          lossCount++;
          if (!connectionLost.isCompleted) connectionLost.complete();
        };
      });

      tearDown(() async {
        if (!sinkDone.isCompleted) sinkDone.complete();
        when(socket.close()).thenAnswer((_) async => socket);
        await manager.disconnect();
        // A failed or cancelled connect never subscribes to this controller.
        if (reads.hasListener) await reads.close();
      });

      Future<void> connect() async {
        expect(await manager.connect('localhost', 1, ssl: ssl), isTrue);
      }

      test('independent done failure after send notifies loss once', () async {
        await connect();
        await manager.send('probe');

        final lost = connectionLost.future.timeout(eventTimeout);
        sinkDone.completeError(abort, StackTrace.current);
        await lost;

        expect(manager.connectionStatus, SocketConnectionStatus.terminated);
        expect(lossCount, 1);
        reads.addError(abort, StackTrace.current);
        manager.markConnectionLost();
        expect(lossCount, 1);
        verify(socket.writeln('probe')).called(1);
        await expectLater(manager.send('after loss'), throwsA(isA<SocketException>()));
        verifyNever(socket.writeln('after loss'));
      });

      test('read error followed by done error notifies loss once', () async {
        await connect();
        await manager.send('probe');
        reads.addError(abort, StackTrace.current);
        await connectionLost.future.timeout(eventTimeout);

        final completed = expectLater(sinkDone.future, throwsA(same(abort)));
        sinkDone.completeError(abort, StackTrace.current);
        await completed;

        expect(manager.connectionStatus, SocketConnectionStatus.terminated);
        expect(lossCount, 1);
      });

      test('successful write completion leaves reads connected until EOF', () async {
        await connect();
        sinkDone.complete();
        await sinkDone.future;

        expect(manager.connectionStatus, SocketConnectionStatus.connected);
        expect(lossCount, 0);
        final response = Completer<dynamic>();
        manager.setCompleter(1, response);
        reads.add(Uint8List.fromList(utf8.encode('{"id":1,"result":"still reading"}\n')));
        expect((await response.future.timeout(eventTimeout))['result'], 'still reading');

        await reads.close();
        expect(manager.connectionStatus, SocketConnectionStatus.terminated);
        expect(lossCount, 1);
      });

      for (final closeFails in [false, true]) {
        test('explicit disconnect is silent when close ${closeFails ? 'fails' : 'succeeds'}', () async {
          await connect();
          final disconnected = manager.disconnect();
          final completed = closeFails ? expectLater(disconnected, throwsA(same(abort))) : disconnected;
          final statusDuringDisconnect = manager.connectionStatus;

          if (closeFails) {
            sinkDone.completeError(abort, StackTrace.current);
          } else {
            sinkDone.complete();
          }
          await completed;
          reads.addError(abort, StackTrace.current);

          expect(statusDuringDisconnect, SocketConnectionStatus.terminated);
          await expectLater(manager.send('after disconnect'), throwsA(isA<SocketException>()));
          expect(lossCount, 0);
          expect(manager.connectionStatus, SocketConnectionStatus.terminated);
          verify(socket.destroy()).called(1);
          await manager.disconnect();
          verify(socket.close()).called(1);
        });
      }

      test('disconnect during connect discards the late socket', () async {
        final connectingSocket = Completer<Socket>();
        if (ssl) {
          when(
            factory.createSecureSocket(any, any),
          ).thenAnswer((_) async => (await connectingSocket.future) as SecureSocket);
        } else {
          when(factory.createSocket(any, any, timeout: anyNamed('timeout'))).thenAnswer((_) => connectingSocket.future);
        }
        final connected = manager.connect('localhost', 1, ssl: ssl);
        await manager.disconnect();
        connectingSocket.complete(socket);

        expect(await connected, isFalse);
        expect(manager.connectionStatus, SocketConnectionStatus.terminated);
        expect(lossCount, 0);
        verify(socket.destroy()).called(1);
        final completed = expectLater(sinkDone.future, throwsA(same(abort)));
        sinkDone.completeError(abort, StackTrace.current);
        await completed;
        expect(lossCount, 0);
      });

      for (final staleReadError in [false, true]) {
        test('old done and read ${staleReadError ? 'error' : 'EOF'} do not terminate a replacement', () async {
          await connect();
          when(socket.writeln('failed write')).thenThrow(abort);
          await expectLater(manager.send('failed write'), throwsA(same(abort)));
          expect(manager.connectionStatus, SocketConnectionStatus.reconnecting);

          final replacement = MockSocket();
          final replacementReads = StreamController<Uint8List>(sync: true);
          final connectingReplacement = Completer<Socket>();
          when(replacement.done).thenAnswer((_) async => replacement);
          when(replacement.close()).thenAnswer((_) async => replacement);
          when(
            replacement.listen(
              any,
              onError: anyNamed('onError'),
              onDone: anyNamed('onDone'),
              cancelOnError: anyNamed('cancelOnError'),
            ),
          ).thenAnswer((call) {
            return replacementReads.stream.listen(
              call.positionalArguments[0] as void Function(Uint8List),
              onError: call.namedArguments[#onError],
              onDone: call.namedArguments[#onDone] as void Function(),
              cancelOnError: call.namedArguments[#cancelOnError] as bool,
            );
          });
          when(
            factory.createSocket(any, any, timeout: anyNamed('timeout')),
          ).thenAnswer((_) => connectingReplacement.future);
          final reconnected = manager.connect('localhost', 2, ssl: false);

          final oldResponse = Completer<dynamic>();
          manager.setCompleter(1, oldResponse);
          reads.add(Uint8List.fromList(utf8.encode('{"id":1,"result":"stale"}\n')));
          expect(manager.connectionStatus, SocketConnectionStatus.connecting);
          connectingReplacement.complete(replacement);
          expect(await reconnected, isTrue);
          replacementReads.add(Uint8List.fromList(utf8.encode('{"id":1,"result":"current"}\n')));
          expect((await oldResponse.future.timeout(eventTimeout))['result'], 'current');

          final completed = expectLater(sinkDone.future, throwsA(same(abort)));
          sinkDone.completeError(abort, StackTrace.current);
          await completed;
          if (staleReadError) {
            reads.addError(abort, StackTrace.current);
          } else {
            await reads.close();
          }

          expect(manager.connectionStatus, SocketConnectionStatus.connected);
          expect(lossCount, 0);
          await manager.send('new request');
          verify(replacement.writeln('new request')).called(1);
          verifyNever(replacement.writeln('failed write'));
          await replacementReads.close();
          expect(lossCount, 1);
        });
      }
    });
  }
}
