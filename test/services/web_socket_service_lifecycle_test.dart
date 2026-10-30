import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;

import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/services/web_socket_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Adversarial lifecycle checks for [WebSocketService].
///
/// Handshake failures use the installed `web_socket_channel` 3.0.3
/// [IOWebSocketChannel]: a rejected socket future completes `ready` with
/// [WebSocketChannelException], then `addError`s that error and closes the
/// stream. Counting wrappers only record calls forwarded to that channel.
/// Loopback servers never leave 127.0.0.1.

void main() {
  test('exchange urls and the four fiat factories stay on the current hosts', () async {
    final direct = <ExchangeType, Uri>{};
    final sentByExchange = <ExchangeType, List<Object?>>{};
    final services = <WebSocketService>[];
    for (final exchange in ExchangeType.values) {
      final sent = <Object?>[];
      sentByExchange[exchange] = sent;
      services.add(
        WebSocketService(
          exchangeType: exchange,
          openChannel: (uri) {
            direct[exchange] = uri;
            return _QuietChannel(sent);
          },
        ),
      );
    }

    final factoryUris = <FiatCode, Uri>{};
    final factorySent = <FiatCode, List<Object?>>{};
    for (final fiat in FiatCode.values.where((fiat) => fiat.hasExchangeSource)) {
      final sent = <Object?>[];
      factorySent[fiat] = sent;
      services.add(
        WebSocketServiceFactory.create(
          fiat,
          openChannel: (uri) {
            factoryUris[fiat] = uri;
            return _QuietChannel(sent);
          },
        ),
      );
    }

    for (final service in services) {
      service.dispose();
    }
    await Future<void>.delayed(Duration.zero);

    expect(direct[ExchangeType.upbit], Uri.parse('wss://api.upbit.com/websocket/v1'));
    expect(direct[ExchangeType.binance], Uri.parse('wss://stream.binance.com:9443/ws/btcusdt@ticker'));
    expect(direct[ExchangeType.bitflyer], Uri.parse('wss://ws.lightstream.bitflyer.com/json-rpc'));
    expect(factoryUris[FiatCode.KRW], direct[ExchangeType.upbit]);
    expect(factoryUris[FiatCode.USD], direct[ExchangeType.binance]);
    expect(factoryUris[FiatCode.JPY], direct[ExchangeType.bitflyer]);
    expect(factoryUris[FiatCode.EUR], Uri.parse('wss://stream.binance.com:9443/ws/btceur@ticker'));

    expect(_texts(sentByExchange[ExchangeType.upbit]!), anyElement(contains('KRW-BTC')));
    expect(_texts(sentByExchange[ExchangeType.bitflyer]!), anyElement(contains('lightning_ticker_BTC_JPY')));
    expect(sentByExchange[ExchangeType.binance], isEmpty);
    expect(_texts(factorySent[FiatCode.KRW]!), anyElement(contains('KRW-BTC')));
    expect(_texts(factorySent[FiatCode.JPY]!), anyElement(contains('lightning_ticker_BTC_JPY')));
    expect(factorySent[FiatCode.USD], isEmpty);
    expect(factorySent[FiatCode.EUR], isEmpty);
    expect(_texts(sentByExchange[ExchangeType.upbit]!).where((line) => line == 'PING'), isEmpty);
  });

  test('the factory rejects currencies without an exchange websocket', () {
    for (final fiat in FiatCode.values.where((fiat) => !fiat.hasExchangeSource)) {
      expect(() => WebSocketServiceFactory.create(fiat), throwsArgumentError, reason: fiat.code);
    }
  });

  test('text, binary, and malformed frames recover once per exchange', () async {
    for (final exchange in ExchangeType.values) {
      final server = await _bind();
      addTearDown(() => server.close(force: true));
      final session = await _Session.start(server);
      final observed = _Observed();
      final prices = <int>[];
      await _guard(observed, () async {
        final service = _serviceFor(server, exchange);
        service.tickerStream.listen((ticker) {
          if (ticker != null) prices.add(ticker.tradePrice);
        });
        final socket = await session.nextSocket();
        await Future<void>.delayed(const Duration(milliseconds: 30));
        socket.add(_payload(exchange, 11));
        socket.add(utf8.encode(_payload(exchange, 22)));
        socket.add('not-json');
        socket.add(_payload(exchange, 33));
        await _waitUntil(() => prices.length >= 3);
        await Future<void>.delayed(const Duration(milliseconds: 400));
        final attemptsBeforeDispose = session.attempts;
        service.dispose();
        try {
          socket.add(_payload(exchange, 44));
        } catch (_) {}
        await Future<void>.delayed(const Duration(milliseconds: 250));
        expect(attemptsBeforeDispose, 1, reason: '$exchange');
      });

      expect(prices, [11, 22, 33], reason: '$exchange ${observed.errors} attempts=${session.attempts}');
      expect(session.attempts, 1, reason: '$exchange');
      expect(observed.errors, isEmpty, reason: '$exchange ${observed.logs}');
      if (exchange == ExchangeType.binance) {
        expect(session.messages, isNot(anyElement(contains('PING'))));
        expect(session.messages, isNot(anyElement(contains('KRW-BTC'))));
        expect(session.messages, isNot(anyElement(contains('lightning_ticker'))));
      } else if (exchange == ExchangeType.upbit) {
        expect(session.messages, anyElement(contains('KRW-BTC')));
      } else {
        expect(session.messages, anyElement(contains('lightning_ticker_BTC_JPY')));
      }
      await server.close(force: true);
    }
  });

  test('upbit and bitflyer subscribe and ping once; binance does neither', () async {
    for (final exchange in [ExchangeType.upbit, ExchangeType.bitflyer]) {
      final server = await _bind();
      addTearDown(() => server.close(force: true));
      final session = await _Session.start(server);
      final observed = _Observed();
      await _guard(observed, () async {
        final service = _serviceFor(server, exchange);
        await session.nextSocket();
        await _waitUntil(() => session.messages.contains('PING'), timeout: const Duration(seconds: 12));
        service.dispose();
        await Future<void>.delayed(const Duration(seconds: 2));
      });

      expect(session.attempts, 1, reason: '$exchange ${session.messages}');
      expect(session.messages.where((message) => message == 'PING'), hasLength(1), reason: '$exchange');
      expect(observed.errors, isEmpty, reason: '$exchange ${observed.logs}');
      if (exchange == ExchangeType.upbit) {
        expect(session.messages, anyElement(contains('KRW-BTC')));
      } else {
        expect(session.messages, anyElement(contains('"method":"subscribe"')));
        expect(session.messages, anyElement(contains('lightning_ticker_BTC_JPY')));
      }
      await server.close(force: true);
    }

    final server = await _bind();
    addTearDown(() => server.close(force: true));
    final session = await _Session.start(server);
    final observed = _Observed();
    await _guard(observed, () async {
      final service = _serviceFor(server, ExchangeType.binance);
      await session.nextSocket();
      await Future<void>.delayed(const Duration(seconds: 11));
      service.dispose();
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    expect(session.attempts, 1);
    expect(session.messages, isEmpty, reason: '${session.messages}');
    expect(observed.errors, isEmpty);
    await server.close(force: true);
  });

  testWidgets('retry cap stays one schedule and the ping timer does not survive it', (tester) async {
    for (var iteration = 0; iteration < 3; iteration++) {
      for (final exchange in ExchangeType.values) {
        final observed = _Observed();
        final probe = _CapProbe();
        late final WebSocketService service;
        _guardSync(observed, () {
          service = WebSocketService(
            exchangeType: exchange,
            openChannel: (_) {
              probe.connects += 1;
              return _CountingChannel(probe, _rejectedSocket());
            },
          );
        });
        await tester.pump();
        await tester.pump(const Duration(seconds: 6));
        final atSix = probe.connects;
        await tester.pump(const Duration(seconds: 2));
        final atEight = probe.connects;
        await tester.pump(const Duration(seconds: 4));
        final atTwelve = probe.connects;
        final pingsAtCap = probe.pings;
        await tester.pump(const Duration(seconds: 11));
        final pingsAfterHold = probe.pings;
        final connectsAfterHold = probe.connects;
        service.dispose();
        await tester.pump(const Duration(seconds: 15));

        final summary =
            'iter=$iteration $exchange connects=${probe.connects} pingsAtCap=$pingsAtCap '
            'pingsAfter=$pingsAfterHold errors=${observed.errors.map((error) => error.runtimeType).toList()} '
            'handshake=${observed.handshakeLogs.length}';
        expect(atSix, 3, reason: summary);
        expect(atEight, 3, reason: summary);
        expect(atTwelve, 4, reason: summary);
        expect(connectsAfterHold, 4, reason: summary);
        expect(probe.connects, 4, reason: summary);
        expect(pingsAtCap, 0, reason: summary);
        expect(pingsAfterHold, exchange == ExchangeType.binance ? 0 : 0, reason: summary);
        expect(probe.pings, 0, reason: summary);
        expect(observed.errors, isEmpty, reason: summary);
        _expectReadyObserved(observed, summary);
      }
    }
  });

  test('a delayed socket failure still schedules one reconnect', () async {
    final observed = _Observed();
    var connects = 0;
    await _guard(observed, () async {
      final service = WebSocketService(
        exchangeType: ExchangeType.binance,
        openChannel: (_) {
          connects += 1;
          return IOWebSocketChannel(
            Future<io.WebSocket>.delayed(const Duration(milliseconds: 40), () {
              throw const io.WebSocketException('Connection was not upgraded to websocket');
            }),
          );
        },
      );
      await Future<void>.delayed(const Duration(milliseconds: 200));
      final beforeRetry = connects;
      await Future<void>.delayed(const Duration(milliseconds: 2300));
      final afterFirstRetry = connects;
      service.dispose();
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(beforeRetry, 1);
      expect(afterFirstRetry, 2);
    });
    expect(connects, 2, reason: '${observed.errors} ${observed.handshakeLogs}');
    expect(observed.errors, isEmpty);
    _expectReadyObserved(observed, 'delayed');
  });

  test('dispose during a pending socket future has no later connect or uncaught error', () async {
    for (var iteration = 0; iteration < 8; iteration++) {
      final observed = _Observed();
      var connects = 0;
      final prices = <int>[];
      final exchange = ExchangeType.values[iteration % ExchangeType.values.length];
      await _guard(observed, () async {
        final pending = Completer<io.WebSocket>();
        final service = WebSocketService(
          exchangeType: exchange,
          openChannel: (_) {
            connects += 1;
            return IOWebSocketChannel(pending.future);
          },
        );
        service.tickerStream.listen((ticker) {
          if (ticker != null) prices.add(ticker.tradePrice);
        });
        service.dispose();
        final logsAtDispose = observed.logs.length;
        pending.completeError(const io.WebSocketException('Connection was not upgraded to websocket'));
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(observed.logs.length, logsAtDispose, reason: 'post-dispose logs ${observed.logs.skip(logsAtDispose)}');
      });
      expect(connects, 1, reason: 'iter=$iteration $exchange ${observed.errors}');
      expect(prices, isEmpty);
      expect(observed.errors, isEmpty, reason: 'iter=$iteration ${observed.logs}');
    }
  });

  test('repeated dispose during a stalled upgrade never opens a second socket', () async {
    for (var iteration = 0; iteration < 8; iteration++) {
      final server = await _bind();
      var attempts = 0;
      final release = Completer<void>();
      server.listen((request) {
        attempts += 1;
        release.future.whenComplete(() {
          request.response.statusCode = io.HttpStatus.badRequest;
          request.response.close();
        });
      });
      final observed = _Observed();
      await _guard(observed, () async {
        final service = WebSocketService(
          exchangeType: ExchangeType.values[iteration % ExchangeType.values.length],
          openChannel: (_) => WebSocketChannel.connect(Uri.parse('ws://127.0.0.1:${server.port}')),
        );
        await Future<void>.delayed(const Duration(milliseconds: 40));
        service.dispose();
        if (!release.isCompleted) release.complete();
        await Future<void>.delayed(const Duration(milliseconds: 350));
      });
      expect(attempts, lessThanOrEqualTo(1), reason: 'iter=$iteration attempts=$attempts errors=${observed.errors}');
      expect(observed.errors, isEmpty, reason: 'iter=$iteration ${observed.logs}');
      await server.close(force: true);
    }
  });

  test('a ready socket that arrives after dispose does not deliver a ticker', () async {
    for (var iteration = 0; iteration < 4; iteration++) {
      final server = await _bind();
      final serverClosed = Completer<void>();
      server.transform(io.WebSocketTransformer()).listen((socket) {
        socket.listen(
          (_) {},
          onError: (_) {},
          onDone: () {
            if (!serverClosed.isCompleted) serverClosed.complete();
          },
        );
      }, onError: (_) {});
      final pending = Completer<io.WebSocket>();
      final observed = _Observed();
      final prices = <int>[];
      var connects = 0;
      await _guard(observed, () async {
        final service = WebSocketService(
          exchangeType: ExchangeType.binance,
          openChannel: (_) {
            connects += 1;
            return IOWebSocketChannel(pending.future);
          },
        );
        service.tickerStream.listen((ticker) {
          if (ticker != null) prices.add(ticker.tradePrice);
        });
        service.dispose();
        final socket = await io.WebSocket.connect('ws://127.0.0.1:${server.port}');
        pending.complete(socket);
        await serverClosed.future.timeout(const Duration(seconds: 3));
        try {
          socket.add('{"c":"9"}');
        } catch (_) {}
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      expect(connects, 1, reason: 'iter=$iteration');
      expect(prices, isEmpty, reason: 'iter=$iteration ${observed.errors}');
      expect(observed.errors, isEmpty, reason: 'iter=$iteration ${observed.logs}');
      await server.close(force: true);
    }
  });

  test('installed sink.close futures stay inside the zone for live and peer-closed sockets', () async {
    final server = await _bind();
    addTearDown(() => server.close(force: true));
    final session = await _Session.start(server);
    final observed = _Observed();
    await _guard(observed, () async {
      final service = _serviceFor(server, ExchangeType.upbit);
      final socket = await session.nextSocket();
      await Future<void>.delayed(const Duration(milliseconds: 30));
      service.dispose();
      await _waitUntil(() => socket.closeCode != null || session.attempts == 1);
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    expect(session.attempts, 1, reason: '${observed.errors}');
    expect(observed.errors, isEmpty, reason: '${observed.logs}');

    final peer = await _bind();
    addTearDown(() => peer.close(force: true));
    final peerSession = await _Session.start(peer);
    final peerObserved = _Observed();
    await _guard(peerObserved, () async {
      final service = _serviceFor(peer, ExchangeType.binance);
      final socket = await peerSession.nextSocket();
      await socket.close();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      service.dispose();
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    expect(peerObserved.errors, isEmpty, reason: '${peerObserved.logs}');

    final direct = await _bind();
    addTearDown(() => direct.close(force: true));
    final directReady = Completer<io.WebSocket>();
    direct.transform(io.WebSocketTransformer()).listen((socket) {
      if (!directReady.isCompleted) directReady.complete(socket);
    }, onError: (_) {});
    final channel = IOWebSocketChannel.connect(Uri.parse('ws://127.0.0.1:${direct.port}'));
    await channel.ready.timeout(const Duration(seconds: 5));
    await channel.sink.close().timeout(const Duration(seconds: 3));
    await directReady.future.timeout(const Duration(seconds: 3));
    await direct.close(force: true);
    await server.close(force: true);
    await peer.close(force: true);
  });

  test('replacement sockets do not replay or overwrite the current ticker', () async {
    for (final exchange in ExchangeType.values) {
      for (var iteration = 0; iteration < 2; iteration++) {
        final server = await _bind();
        final session = await _Session.start(server);
        final observed = _Observed();
        final prices = <int>[];
        await _guard(observed, () async {
          final service = _serviceFor(server, exchange);
          service.tickerStream.listen((ticker) {
            if (ticker != null) prices.add(ticker.tradePrice);
          });
          final first = await session.nextSocket();
          await Future<void>.delayed(const Duration(milliseconds: 30));
          first.add(_payload(exchange, 111));
          await first.close();
          await _waitUntil(() => session.attempts >= 2, timeout: const Duration(seconds: 5));
          final second = session.sockets[1];
          await Future<void>.delayed(const Duration(milliseconds: 30));
          second.add(_payload(exchange, 222));
          await _waitUntil(() => prices.contains(222), timeout: const Duration(seconds: 5));
          await Future<void>.delayed(const Duration(milliseconds: 250));
          service.dispose();
          try {
            second.add(_payload(exchange, 333));
          } catch (_) {}
          await Future<void>.delayed(const Duration(milliseconds: 200));
        });
        expect(prices, [111, 222], reason: '$exchange#$iteration attempts=${session.attempts} ${observed.errors}');
        expect(session.attempts, 2, reason: '$exchange#$iteration');
        expect(observed.errors, isEmpty, reason: '$exchange#$iteration ${observed.logs}');
        await server.close(force: true);
      }
    }
  });
}

WebSocketChannel _rejectedSocket() {
  return IOWebSocketChannel(
    Future<io.WebSocket>.error(const io.WebSocketException('Connection was not upgraded to websocket')),
  );
}

class _CapProbe {
  int connects = 0;
  int pings = 0;
}

class _CountingChannel implements WebSocketChannel {
  _CountingChannel(_CapProbe probe, this._inner) : sink = _CountingSink(probe, _inner.sink);

  final WebSocketChannel _inner;

  @override
  final _CountingSink sink;

  @override
  Future<void> get ready => _inner.ready;

  @override
  Stream<dynamic> get stream => _inner.stream;

  @override
  String? get protocol => _inner.protocol;

  @override
  int? get closeCode => _inner.closeCode;

  @override
  String? get closeReason => _inner.closeReason;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError('${invocation.memberName} is unused');
}

class _CountingSink implements WebSocketSink {
  _CountingSink(this._probe, this._inner);

  final _CapProbe _probe;
  final WebSocketSink _inner;

  @override
  void add(Object? data) {
    if (data == 'PING') _probe.pings += 1;
    _inner.add(data);
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) => _inner.addError(error, stackTrace);

  @override
  Future<void> addStream(Stream<dynamic> stream) => _inner.addStream(stream);

  @override
  Future<void> close([int? closeCode, String? closeReason]) => _inner.close(closeCode, closeReason);

  @override
  Future<void> get done => _inner.done;
}

class _QuietChannel implements WebSocketChannel {
  _QuietChannel(this.sent) : sink = _QuietSink(sent);

  final List<Object?> sent;
  final _events = StreamController<dynamic>(sync: true);

  @override
  final _QuietSink sink;

  @override
  Future<void> get ready => Future<void>.value();

  @override
  Stream<dynamic> get stream => _events.stream;

  @override
  String? get protocol => null;

  @override
  int? get closeCode => null;

  @override
  String? get closeReason => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError('${invocation.memberName} is unused');
}

class _QuietSink implements WebSocketSink {
  _QuietSink(this.sent);

  final List<Object?> sent;
  var _closed = false;

  @override
  void add(Object? data) {
    if (_closed) throw StateError('Cannot add event after closing.');
    sent.add(data);
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future<void> addStream(Stream<dynamic> stream) async {}

  @override
  Future<void> close([int? closeCode, String? closeReason]) async {
    _closed = true;
  }

  @override
  Future<void> get done => Future<void>.value();
}

class _Session {
  _Session(this.attemptsBox, this.sockets, this.messages);

  final List<int> attemptsBox;
  final List<io.WebSocket> sockets;
  final List<String> messages;
  var _cursor = 0;

  int get attempts => attemptsBox.single;

  Future<io.WebSocket> nextSocket() async {
    final index = _cursor;
    _cursor += 1;
    await _waitUntil(() => sockets.length > index);
    return sockets[index];
  }

  static Future<_Session> start(io.HttpServer server) async {
    final attempts = [0];
    final sockets = <io.WebSocket>[];
    final messages = <String>[];
    server.transform(io.WebSocketTransformer()).listen((socket) {
      attempts[0] += 1;
      sockets.add(socket);
      socket.listen((data) {
        messages.add(data is String ? data : utf8.decode(data as List<int>));
      }, onError: (_) {});
    }, onError: (_) {});
    return _Session(attempts, sockets, messages);
  }
}

class _Observed {
  final logs = <String>[];
  final errors = <Object>[];

  List<String> get handshakeLogs => logs.where((line) => line.contains('handshake failed')).toList();
}

void _guardSync(_Observed observed, void Function() body) {
  runZonedGuarded(
    body,
    (error, _) => observed.errors.add(error),
    zoneSpecification: ZoneSpecification(print: (self, parent, zone, line) => observed.logs.add(line)),
  );
}

Future<void> _guard(_Observed observed, Future<void> Function() body) {
  final result = runZonedGuarded(
    body,
    (error, _) => observed.errors.add(error),
    zoneSpecification: ZoneSpecification(print: (self, parent, zone, line) => observed.logs.add(line)),
  );
  return result ?? Future<void>.value();
}

void _expectReadyObserved(_Observed observed, String summary) {
  expect(observed.errors.map((error) => error.runtimeType.toString()).toList(), isEmpty, reason: summary);
  expect(observed.handshakeLogs, isNotEmpty, reason: summary);
  expect(observed.handshakeLogs.every((line) => line.contains('WebSocketChannelException')), isTrue, reason: summary);
  expect(observed.handshakeLogs.any(_containsEndpoint), isFalse, reason: summary);
  expect(
    observed.handshakeLogs.any((line) => line.contains('was not upgraded') || line.contains('KRW-BTC')),
    isFalse,
    reason: summary,
  );
}

bool _containsEndpoint(String line) {
  return line.contains('127.0.0.1') ||
      line.contains('http://') ||
      line.contains('https://') ||
      line.contains('ws://') ||
      line.contains('wss://');
}

String _payload(ExchangeType exchange, int price) {
  switch (exchange) {
    case ExchangeType.upbit:
      return '{"trade_price":$price}';
    case ExchangeType.binance:
      return '{"c":"$price"}';
    case ExchangeType.bitflyer:
      return '{"method":"channelMessage","params":{"message":{"ltp":$price}}}';
  }
}

List<String> _texts(List<Object?> values) {
  return values.map((value) => value is String ? value : '$value').toList();
}

Future<io.HttpServer> _bind() {
  return io.HttpServer.bind(io.InternetAddress.loopbackIPv4, 0);
}

WebSocketService _serviceFor(io.HttpServer server, ExchangeType exchangeType) {
  final uri = Uri.parse('ws://127.0.0.1:${server.port}');
  return WebSocketService(exchangeType: exchangeType, openChannel: (_) => WebSocketChannel.connect(uri));
}

Future<void> _waitUntil(bool Function() ready, {Duration timeout = const Duration(seconds: 5)}) async {
  final started = DateTime.now();
  while (!ready()) {
    if (DateTime.now().difference(started) > timeout) {
      fail('timed out waiting for the socket event');
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}
