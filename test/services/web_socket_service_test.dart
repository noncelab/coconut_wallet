import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;

import 'package:coconut_wallet/services/web_socket_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

void main() {
  testWidgets('handshake failure observes ready and schedules one reconnect', (tester) async {
    final observed = _Observed();
    var connects = 0;
    var atSixSeconds = 0;
    var atEightSeconds = 0;
    var atEighteenSeconds = 0;
    late final WebSocketService service;
    _guardSync(observed, () {
      service = WebSocketService(
        exchangeType: ExchangeType.binance,
        openChannel: (_) {
          connects += 1;
          return _rejectedHandshake();
        },
      );
    });
    await tester.pump();
    await tester.pump(const Duration(seconds: 6));
    atSixSeconds = connects;
    await tester.pump(const Duration(seconds: 2));
    atEightSeconds = connects;
    await tester.pump(const Duration(seconds: 10));
    atEighteenSeconds = connects;
    service.dispose();
    await tester.pump();

    final summary = _summary(connects: [atSixSeconds, atEightSeconds, atEighteenSeconds], observed: observed);
    // One failure schedules one retry: connects at 0s, 2s, and 6s, then the capped retry at 12s.
    expect(atSixSeconds, 3, reason: summary);
    expect(atEightSeconds, 3, reason: summary);
    expect(atEighteenSeconds, 4, reason: summary);
    _expectReadyObserved(observed, summary);
  });

  testWidgets('a late failure from the replaced channel does not reconnect', (tester) async {
    final observed = _Observed();
    var connects = 0;
    _SplitHandshake? replaced;
    late final WebSocketService service;
    _guardSync(observed, () {
      service = WebSocketService(
        exchangeType: ExchangeType.binance,
        openChannel: (_) {
          connects += 1;
          if (replaced == null) {
            replaced = _SplitHandshake();
            return replaced!;
          }
          return _QuietChannel();
        },
      );
    });
    await tester.pump();
    replaced!.emitConnectionError();
    await tester.pump(const Duration(seconds: 2));
    final summary = _summary(connects: [connects], observed: observed);
    expect(connects, 2, reason: summary);

    replaced!.emitConnectionError();
    replaced!.emitDone();
    await tester.pump(const Duration(seconds: 10));
    service.dispose();
    await tester.pump();

    expect(connects, 2, reason: _summary(connects: [connects], observed: observed));
    _expectReadyObserved(observed, summary);
  });

  testWidgets('dispose during backoff does not open another socket', (tester) async {
    final observed = _Observed();
    var connects = 0;
    late final WebSocketService service;
    _guardSync(observed, () {
      service = WebSocketService(
        exchangeType: ExchangeType.binance,
        openChannel: (_) {
          connects += 1;
          return _rejectedHandshake();
        },
      );
    });
    await tester.pump();
    service.dispose();
    await tester.pump(const Duration(seconds: 20));

    final summary = _summary(connects: [connects], observed: observed);
    expect(connects, 1, reason: summary);
    _expectReadyObserved(observed, summary);
  });

  testWidgets('upbit subscribe-before-ready still observes the handshake error', (tester) async {
    final observed = _Observed();
    var connects = 0;
    late final WebSocketService service;
    _guardSync(observed, () {
      service = WebSocketService(
        exchangeType: ExchangeType.upbit,
        openChannel: (_) {
          connects += 1;
          return _rejectedHandshake();
        },
      );
    });
    await tester.pump();
    service.dispose();
    await tester.pump(const Duration(seconds: 30));

    final summary = _summary(connects: [connects], observed: observed);
    expect(connects, 1, reason: summary);
    _expectReadyObserved(observed, summary);
  });

  test('real connect reports a refused handshake without an uncaught ready error', () async {
    final server = await io.HttpServer.bind(io.InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    var attempts = 0;
    final fourth = Completer<void>();
    server.listen((request) {
      attempts += 1;
      if (attempts == 4 && !fourth.isCompleted) fourth.complete();
      request.response.statusCode = io.HttpStatus.badRequest;
      request.response.close();
    });
    final uri = Uri.parse('ws://127.0.0.1:${server.port}');
    final observed = _Observed();
    await _guard(observed, () async {
      final service = WebSocketService(
        exchangeType: ExchangeType.binance,
        openChannel: (_) => WebSocketChannel.connect(uri),
      );
      await fourth.future.timeout(const Duration(seconds: 20));
      await Future<void>.delayed(const Duration(seconds: 3));
      service.dispose();
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });

    final summary = _summary(connects: [attempts], observed: observed);
    expect(attempts, 4, reason: summary);
    _expectReadyObserved(observed, summary);
  });

  test('real connect delivers a ticker and dispose does not reconnect', () async {
    final server = await io.HttpServer.bind(io.InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    var attempts = 0;
    server.transform(io.WebSocketTransformer()).listen((socket) async {
      attempts += 1;
      await Future<void>.delayed(const Duration(milliseconds: 50));
      socket.add('{"c":"42000"}');
    }, onError: (_) {});
    final observed = _Observed();
    final prices = <int>[];
    await _guard(observed, () async {
      final service = _serviceFor(server, ExchangeType.binance);
      service.tickerStream.listen((ticker) {
        if (ticker != null) prices.add(ticker.tradePrice);
      });
      await _waitUntil(() => prices.isNotEmpty);
      service.dispose();
      await Future<void>.delayed(const Duration(seconds: 3));
    });

    expect(prices, [42000]);
    expect(attempts, 1, reason: _summary(connects: [attempts], observed: observed));
    expect(observed.errors.map((error) => error.runtimeType.toString()).toList(), isEmpty);
    expect(observed.logs.any(_containsEndpoint), isFalse);
  });

  test('a clean close keeps the existing retry cap', () async {
    final server = await io.HttpServer.bind(io.InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    var attempts = 0;
    server.transform(io.WebSocketTransformer()).listen((socket) {
      attempts += 1;
      socket.add('{"c":"42000"}');
      socket.close();
    }, onError: (_) {});
    final observed = _Observed();
    final prices = <int>[];
    var midway = 0;
    await _guard(observed, () async {
      final service = _serviceFor(server, ExchangeType.binance);
      service.tickerStream.listen((ticker) {
        if (ticker != null) prices.add(ticker.tradePrice);
      });
      await Future<void>.delayed(const Duration(seconds: 8));
      midway = attempts;
      await Future<void>.delayed(const Duration(seconds: 8));
      service.dispose();
      await Future<void>.delayed(const Duration(seconds: 3));
    });

    final summary = _summary(connects: [midway, attempts], observed: observed);
    expect(midway, 3, reason: summary);
    expect(attempts, 4, reason: summary);
    expect(prices, [42000, 42000, 42000, 42000], reason: summary);
    expect(observed.errors, isEmpty, reason: summary);
    expect(observed.handshakeLogs, isEmpty, reason: summary);
  });

  test('upbit sends the subscribe and stops ping on dispose', () async {
    final server = await io.HttpServer.bind(io.InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    var attempts = 0;
    final messages = <String>[];
    server.transform(io.WebSocketTransformer()).listen((socket) {
      attempts += 1;
      socket.listen((data) {
        messages.add(data is String ? data : utf8.decode(data as List<int>));
      }, onError: (_) {});
    }, onError: (_) {});
    final observed = _Observed();
    await _guard(observed, () async {
      final service = _serviceFor(server, ExchangeType.upbit);
      await _waitUntil(() => messages.any((message) => message.contains('KRW-BTC')));
      await _waitUntil(() => messages.contains('PING'), timeout: const Duration(seconds: 12));
      service.dispose();
      await Future<void>.delayed(const Duration(seconds: 3));
    });

    expect(messages.any((message) => message.contains('KRW-BTC')), isTrue);
    expect(messages.where((message) => message == 'PING'), hasLength(1));
    expect(attempts, 1, reason: _summary(connects: [attempts], observed: observed));
    expect(observed.errors, isEmpty);
    expect(observed.logs.any(_containsEndpoint), isFalse);
  });
}

WebSocketChannel _rejectedHandshake() {
  return IOWebSocketChannel(
    Future<io.WebSocket>.error(const io.WebSocketException('Connection was not upgraded to websocket')),
  );
}

class _SplitHandshake implements WebSocketChannel {
  final _ready = Completer<void>();
  final _events = StreamController<dynamic>(sync: true);
  final _sink = _IdleSink();

  @override
  Future<void> get ready => _ready.future;

  @override
  Stream<dynamic> get stream => _events.stream;

  @override
  WebSocketSink get sink => _sink;

  @override
  String? get protocol => null;

  @override
  int? get closeCode => null;

  @override
  String? get closeReason => null;

  void emitConnectionError() {
    final error = WebSocketChannelException('Connection was not upgraded to websocket');
    if (!_ready.isCompleted) _ready.completeError(error);
    if (!_events.isClosed) _events.addError(error);
  }

  void emitDone() {
    if (!_events.isClosed) _events.close();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError('${invocation.memberName} is unused');
}

class _QuietChannel implements WebSocketChannel {
  final _events = StreamController<dynamic>();
  final _sink = _IdleSink();

  @override
  Future<void> get ready => Future<void>.value();

  @override
  Stream<dynamic> get stream => _events.stream;

  @override
  WebSocketSink get sink => _sink;

  @override
  String? get protocol => null;

  @override
  int? get closeCode => null;

  @override
  String? get closeReason => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError('${invocation.memberName} is unused');
}

class _IdleSink implements WebSocketSink {
  @override
  void add(Object? data) {}

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future<void> addStream(Stream<dynamic> stream) async {}

  @override
  Future<void> close([int? closeCode, String? closeReason]) async {}

  @override
  Future<void> get done => Future<void>.value();
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

String _summary({required List<int> connects, required _Observed observed}) {
  return 'connects=$connects uncaught=${observed.errors.map((error) => error.runtimeType).toList()} '
      'handshakeLogs=${observed.handshakeLogs.length}';
}

bool _containsEndpoint(String line) {
  return line.contains('127.0.0.1') ||
      line.contains('http://') ||
      line.contains('https://') ||
      line.contains('ws://') ||
      line.contains('wss://');
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
