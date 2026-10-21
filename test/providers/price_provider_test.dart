import 'dart:async';
import 'dart:io';

import 'package:coconut_wallet/app_guard.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/model/node/node_provider_state.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/providers/auth_provider.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/price_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/services/web_socket_service.dart';
import 'package:coconut_wallet/utils/result.dart';
import 'package:coconut_wallet/widgets/common/amount/fiat_price.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(OwnedSocket.reset);

  tearDown(AppGuard.enablePrivacyScreen);

  testWidgets('four currency tickers update the real provider once each', (tester) async {
    await withHarness(tester, (harness) async {
      expect(OwnedSocket.live, 4);
      expect(OwnedSocket.created, 4);

      harness.emit(FiatCode.KRW, 100000000);
      harness.emit(FiatCode.USD, 60000);
      harness.emit(FiatCode.JPY, 9000000);
      harness.emit(FiatCode.EUR, 55000);
      await tester.pump();

      expect(harness.prices.bitcoinPriceKrw, 100000000);
      expect(harness.prices.bitcoinPriceUsd, 60000);
      expect(harness.prices.bitcoinPriceJpy, 9000000);
      expect(harness.prices.bitcoinPriceEur, 55000);
      expect(harness.prices.getBitcoinPriceForFiat(FiatCode.KRW), 100000000);
      expect(harness.prices.getFiatPrice(100000000), '₩ 100,000,000');
      expect(harness.notes, hasLength(4));
      expect(OwnedSocket.live, 4);
      expect(OwnedSocket.created, 4);
    });
  });

  testWidgets('selected currency change reconnects once and keeps one live set', (tester) async {
    await withHarness(tester, (harness) async {
      harness.emit(FiatCode.KRW, 100000000);
      harness.emit(FiatCode.USD, 60000);
      await tester.pump();
      harness.notes.clear();

      harness.preference.select(FiatCode.USD);

      expect(OwnedSocket.live, 4);
      expect(OwnedSocket.created, 8);
      expect(harness.prices.getFiatPrice(100000000), r'$ 60,000');

      harness.emit(FiatCode.USD, 61000);
      await tester.pump();

      expect(harness.prices.bitcoinPriceUsd, 61000);
      expect(harness.prices.getFiatPrice(100000000), r'$ 61,000');
      expect(harness.notes, hasLength(1));
      expect(OwnedSocket.live, 4);
    });
  });

  testWidgets('a preference notification that keeps the currency does not open sockets', (tester) async {
    await withHarness(tester, (harness) async {
      harness.preference.pulse();
      await tester.pump();

      expect(OwnedSocket.created, 4);
      expect(OwnedSocket.live, 4);
    });
  });

  testWidgets('offline startup waits, then one online notification opens four sockets', (tester) async {
    await withHarness(tester, (harness) async {
      expect(OwnedSocket.created, 0);
      expect(harness.prices.bitcoinPriceKrw, isNull);
      expect(harness.prices.getFiatPrice(100000000), isEmpty);

      harness.connectivity.setOnline(true);
      await tester.pump();

      expect(OwnedSocket.created, 4);
      expect(OwnedSocket.live, 4);
      harness.emit(FiatCode.KRW, 100000000);
      await tester.pump();
      expect(harness.prices.getFiatPrice(100000000), '₩ 100,000,000');
    }, online: false);
  });

  testWidgets('repeated online notifications do not open another socket', (tester) async {
    await withHarness(tester, (harness) async {
      for (var i = 0; i < 5; i++) {
        harness.connectivity.pulse();
      }
      await tester.pump();

      expect(OwnedSocket.created, 4);
      expect(OwnedSocket.live, 4);
    });
  });

  testWidgets('rapid disconnect and reconnect leaves one subscription per currency', (tester) async {
    await withHarness(tester, (harness) async {
      for (var i = 0; i < 5; i++) {
        harness.connectivity.setOnline(false);
        harness.connectivity.setOnline(true);
      }
      await tester.pump();

      expect(OwnedSocket.live, 4);
      expect(OwnedSocket.created, 24);
      harness.notes.clear();
      harness.emit(FiatCode.KRW, 42000);
      await tester.pump();

      expect(harness.prices.bitcoinPriceKrw, 42000);
      expect(harness.notes, hasLength(1));
    });
  });

  testWidgets('repeated force init replaces sockets instead of stacking them', (tester) async {
    await withHarness(tester, (harness) async {
      harness.prices.initWebSocketService(force: true);
      harness.prices.initWebSocketService(force: true);
      await tester.pump();

      expect(OwnedSocket.live, 4);
      expect(OwnedSocket.created, 12);
      expect(OwnedSocket.disposedCount, 8);
      harness.notes.clear();
      harness.emit(FiatCode.EUR, 55000);
      await tester.pump();

      expect(harness.prices.bitcoinPriceEur, 55000);
      expect(harness.notes, hasLength(1));
    });
  });

  testWidgets('force init while offline does not connect until the network returns', (tester) async {
    await withHarness(tester, (harness) async {
      harness.prices.initWebSocketService(force: true);
      harness.prices.initWebSocketService(force: true);
      expect(OwnedSocket.created, 0);

      harness.connectivity.setOnline(true);
      await tester.pump();

      expect(OwnedSocket.created, 4);
      expect(OwnedSocket.live, 4);
    }, online: false);
  });

  testWidgets('a queued ticker from the replaced socket is not delivered', (tester) async {
    await withHarness(tester, (harness) async {
      harness.emit(FiatCode.KRW, 100000000);
      await tester.pump();
      harness.notes.clear();

      harness.emit(FiatCode.KRW, 1);
      harness.prices.initWebSocketService(force: true);
      harness.emit(FiatCode.KRW, 222);
      await tester.pump();

      expect(harness.prices.bitcoinPriceKrw, 222);
      expect(harness.notes.map((note) => note.krw).toList(), [222]);
      expect(OwnedSocket.live, 4);
    });
  });

  testWidgets('dispose drops a queued ticker and both upstream listeners', (tester) async {
    await withHarness(tester, (harness) async {
      harness.emit(FiatCode.KRW, 50);

      harness.disposePrices();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(harness.connectivity.hasListeners, isFalse);
      expect(harness.preference.hasListeners, isFalse);
      expect(OwnedSocket.live, 0);

      harness.connectivity.pulse();
      harness.preference.pulse();
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(OwnedSocket.created, 4);
    });
  });

  testWidgets('a replacement provider after dispose owns a new socket set', (tester) async {
    final first = Harness();
    Harness? second;
    try {
      first.emit(FiatCode.KRW, 100000000);
      await tester.pump();
      final firstConnectivity = first.connectivity;
      first.dispose();
      expect(OwnedSocket.live, 0);
      expect(firstConnectivity.hasListeners, isFalse);

      second = Harness();
      expect(OwnedSocket.live, 4);
      second.emit(FiatCode.KRW, 333);
      await tester.pump();

      expect(second.prices.bitcoinPriceKrw, 333);
      expect(second.notes, hasLength(1));
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      second?.dispose();
      first.dispose();
    }
  });

  testWidgets('FiatPrice shows synthetic updates and hides them while offline', (tester) async {
    await withHarness(tester, (harness) async {
      await tester.pumpWidget(harness.priceApp(const FiatPrice(satoshiAmount: 100000000)));
      expect(find.text('₩ 100,000,000'), findsNothing);

      harness.emit(FiatCode.KRW, 100000000);
      await tester.pump();
      expect(find.text('₩ 100,000,000'), findsOneWidget);

      harness.emit(FiatCode.KRW, 99000000);
      await tester.pump();
      expect(harness.prices.bitcoinPriceKrw, 99000000);
      expect(harness.prices.getFiatPrice(100000000), '₩ 99,000,000');
      expect(find.text('₩ 99,000,000'), findsOneWidget);
      expect(find.text('₩ 100,000,000'), findsNothing);

      harness.preference.select(FiatCode.USD);
      await tester.pump();
      harness.emit(FiatCode.USD, 60000);
      await tester.pump();
      expect(find.text(r'$ 60,000'), findsOneWidget);

      harness.connectivity.setOnline(false);
      await tester.pump();
      expect(find.text(r'$ 60,000'), findsNothing);
      expect(find.byType(Text), findsNothing);

      harness.connectivity.setOnline(true);
      harness.emit(FiatCode.USD, 61000);
      await tester.pump();
      expect(find.text(r'$ 61,000'), findsOneWidget);
      expect(OwnedSocket.live, 4);
    });
  });

  testWidgets('background pause closes price sockets and resume opens one set', (tester) async {
    final session = await pumpGuard(tester);
    try {
      expect(OwnedSocket.live, 4);
      expect(session.auth.checks, 0);

      await enterBackground(tester);
      expect(session.auth.checks, 0, reason: 'pause does not ask for biometrics');
      expect(OwnedSocket.live, 0);
      expect(OwnedSocket.disposedCount, 4);

      await enterForeground(tester);
      expect(session.auth.checks, 1, reason: 'resume reached the real AppGuard handler');
      expect(OwnedSocket.live, 4);
      expect(OwnedSocket.created, 8);

      session.harness.notes.clear();
      session.harness.emit(FiatCode.KRW, 100000000);
      await tester.pump();
      expect(session.harness.notes, hasLength(1));
      expect(session.harness.prices.bitcoinPriceKrw, 100000000);
    } finally {
      await releaseGuard(tester, session);
    }
  });

  testWidgets('inactive then resume does not stack sockets', (tester) async {
    final session = await pumpGuard(tester);
    try {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      expect(session.auth.checks, 1);
      expect(OwnedSocket.live, 4);
      expect(OwnedSocket.created, 8);
      session.harness.notes.clear();
      session.harness.emit(FiatCode.JPY, 9000000);
      await tester.pump();
      expect(session.harness.notes, hasLength(1));
    } finally {
      await releaseGuard(tester, session);
    }
  });

  testWidgets('a second background resume still has one live set', (tester) async {
    final session = await pumpGuard(tester);
    try {
      for (var i = 0; i < 2; i++) {
        await enterBackground(tester);
        expect(OwnedSocket.live, 0);
        await enterForeground(tester);
      }

      expect(session.auth.checks, 2);
      expect(OwnedSocket.live, 4);
      expect(OwnedSocket.created, 12);
      session.harness.notes.clear();
      session.harness.emit(FiatCode.EUR, 55000);
      await tester.pump();
      expect(session.harness.notes, hasLength(1));
      expect(tester.takeException(), isNull);
    } finally {
      await releaseGuard(tester, session);
    }
  });

  test('loopback sockets deliver four prices through the real provider', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    var accepted = 0;
    server.listen((request) {
      final path = request.uri.path;
      WebSocketTransformer.upgrade(request).then((socket) {
        accepted += 1;
        socket.add(_payloadForPath(path));
        socket.listen((_) {}, onError: (_) {}, onDone: () {});
      }, onError: (_) {});
    });

    final connectivity = ScriptedConnectivity(online: true);
    final preference = ScriptedPreference(FiatCode.KRW);
    final prices = PriceProvider(
      connectivity,
      preference,
      webSocketFactory: (fiat) {
        return WebSocketService(
          exchangeType: _exchangeFor(fiat),
          symbol: _symbolFor(fiat),
          openChannel: (uri) {
            final kind = _kindFor(uri);
            return WebSocketChannel.connect(Uri.parse('ws://127.0.0.1:${server.port}/$kind'));
          },
        );
      },
    );
    addTearDown(prices.dispose);
    addTearDown(connectivity.dispose);
    addTearDown(preference.dispose);

    await _waitUntil(
      () =>
          prices.bitcoinPriceKrw == 100000000 &&
          prices.bitcoinPriceUsd == 60000 &&
          prices.bitcoinPriceJpy == 9000000 &&
          prices.bitcoinPriceEur == 55000,
    );

    expect(accepted, 4);
    expect(prices.getFiatPrice(100000000), '₩ 100,000,000');
    expect(prices.getBitcoinPriceForFiat(FiatCode.USD), 60000);
    expect(prices.getBitcoinPriceForFiat(FiatCode.JPY), 9000000);
    expect(prices.getBitcoinPriceForFiat(FiatCode.EUR), 55000);
  });
}

Future<void> withHarness(WidgetTester tester, Future<void> Function(Harness harness) body, {bool online = true}) async {
  final harness = Harness(online: online);
  try {
    await body(harness);
  } finally {
    await tester.pumpWidget(const SizedBox.shrink());
    harness.dispose();
  }
}

/// Flutter only accepts resumed → inactive → hidden → paused, then the reverse.
Future<void> enterBackground(WidgetTester tester) async {
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  await tester.pump();
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
  await tester.pump();
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
  await tester.pump();
}

Future<void> enterForeground(WidgetTester tester) async {
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
  await tester.pump();
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  await tester.pump();
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  await tester.pump();
}

Future<GuardSession> pumpGuard(WidgetTester tester) async {
  final harness = Harness();
  final auth = _Auth();
  addTearDown(harness.dispose);
  AppGuard.disablePrivacyScreen();
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('screencapture_method'), (
    call,
  ) async {
    return null;
  });
  addTearDown(() {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('screencapture_method'), null);
  });
  // The listener records the binding state at construction. Start from resumed
  // so inactive is a legal transition. No listener exists yet, so this does
  // not notify AppGuard.
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);

  await tester.pumpWidget(
    MaterialApp(
      theme: buildCoconutThemeData(),
      home: MultiProvider(
        providers: [
          ChangeNotifierProvider<ConnectivityProvider>.value(value: harness.connectivity),
          ChangeNotifierProvider<PreferenceProvider>.value(value: harness.preference),
          ChangeNotifierProvider<PriceProvider>.value(value: harness.prices),
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ChangeNotifierProvider<NodeProvider>.value(value: _Nodes()),
          ChangeNotifierProvider<WalletProvider>.value(value: _Wallets()),
        ],
        child: const AppGuard(child: SizedBox.shrink()),
      ),
    ),
  );
  return GuardSession(harness, auth);
}

Future<void> releaseGuard(WidgetTester tester, GuardSession session) async {
  // Paused disables frames, so unmount only after a legal return to resumed.
  final state = tester.binding.lifecycleState;
  if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
    await enterForeground(tester);
  } else if (state == AppLifecycleState.inactive) {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
  }
  await tester.pumpWidget(const SizedBox.shrink());
  session.harness.dispose();
}

class GuardSession {
  GuardSession(this.harness, this.auth);

  final Harness harness;
  final _Auth auth;
}

class Harness {
  Harness({bool online = true, FiatCode fiat = FiatCode.KRW})
    : connectivity = ScriptedConnectivity(online: online),
      preference = ScriptedPreference(fiat) {
    prices = PriceProvider(connectivity, preference, webSocketFactory: book.create);
    prices.addListener(() {
      notes.add(
        PriceNote(prices.bitcoinPriceKrw, prices.bitcoinPriceUsd, prices.bitcoinPriceJpy, prices.bitcoinPriceEur),
      );
    });
  }

  final ScriptedConnectivity connectivity;
  final ScriptedPreference preference;
  final SocketBook book = SocketBook();
  late final PriceProvider prices;
  final notes = <PriceNote>[];
  var _pricesDisposed = false;
  var _disposed = false;

  void emit(FiatCode fiat, int price, {bool previous = false}) {
    final channel = previous ? book.previous(fiat) : book.latest(fiat);
    channel.add(_payload(fiat, price));
  }

  Widget priceApp(Widget child) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ConnectivityProvider>.value(value: connectivity),
        ChangeNotifierProvider<PreferenceProvider>.value(value: preference),
        ChangeNotifierProvider<PriceProvider>.value(value: prices),
      ],
      child: MaterialApp(theme: buildCoconutThemeData(), home: Scaffold(body: child)),
    );
  }

  void disposePrices() {
    if (_pricesDisposed) return;
    _pricesDisposed = true;
    prices.dispose();
  }

  void dispose() {
    disposePrices();
    if (_disposed) return;
    _disposed = true;
    connectivity.dispose();
    preference.dispose();
  }
}

class PriceNote {
  const PriceNote(this.krw, this.usd, this.jpy, this.eur);

  final int? krw;
  final int? usd;
  final int? jpy;
  final int? eur;
}

class SocketBook {
  final _channels = <FiatCode, List<ScriptedChannel>>{};

  WebSocketService create(FiatCode fiat) {
    final channel = ScriptedChannel();
    _channels.putIfAbsent(fiat, () => []).add(channel);
    return OwnedSocket(exchangeType: _exchangeFor(fiat), symbol: _symbolFor(fiat), openChannel: (_) => channel);
  }

  ScriptedChannel latest(FiatCode fiat) => _channels[fiat]!.last;

  ScriptedChannel previous(FiatCode fiat) {
    final channels = _channels[fiat]!;
    return channels[channels.length - 2];
  }
}

class OwnedSocket extends WebSocketService {
  static int created = 0;
  static int disposedCount = 0;
  static int live = 0;

  static void reset() {
    created = 0;
    disposedCount = 0;
    live = 0;
  }

  OwnedSocket({required super.exchangeType, super.symbol, required super.openChannel}) {
    created += 1;
    live += 1;
  }

  var _closed = false;

  @override
  void dispose() {
    if (_closed) return;
    _closed = true;
    live -= 1;
    disposedCount += 1;
    super.dispose();
  }
}

class ScriptedConnectivity extends Fake with ChangeNotifier implements ConnectivityProvider {
  ScriptedConnectivity({required this.online});

  bool online;

  @override
  bool get isInternetOn => online;

  @override
  bool get isInternetOff => !online;

  @override
  Future<void> refreshConnectivity() async {}

  void setOnline(bool value) {
    online = value;
    notifyListeners();
  }

  void pulse() => notifyListeners();
}

class ScriptedPreference extends Fake with ChangeNotifier implements PreferenceProvider {
  ScriptedPreference(this.selectedFiat);

  @override
  FiatCode selectedFiat;

  void select(FiatCode fiat) {
    selectedFiat = fiat;
    notifyListeners();
  }

  void pulse() => notifyListeners();
}

class ScriptedChannel implements WebSocketChannel {
  ScriptedChannel() {
    sink = ScriptedSink(events);
  }

  final events = StreamController<dynamic>.broadcast(sync: true);
  late final ScriptedSink sink;

  @override
  Future<void> get ready => Future<void>.value();

  @override
  Stream<dynamic> get stream => events.stream;

  @override
  String? get protocol => null;

  @override
  int? get closeCode => null;

  @override
  String? get closeReason => null;

  void add(Object data) {
    if (!events.isClosed) events.add(data);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError('${invocation.memberName} is unused');
}

class ScriptedSink implements WebSocketSink {
  ScriptedSink(this._events);

  final StreamController<dynamic> _events;
  int closes = 0;

  @override
  void add(Object? data) {}

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future<void> addStream(Stream<dynamic> stream) async {}

  @override
  Future<void> close([int? closeCode, String? closeReason]) async {
    closes += 1;
    if (!_events.isClosed) await _events.close();
  }

  @override
  Future<void> get done => Future<void>.value();
}

class _Auth extends Fake with ChangeNotifier implements AuthProvider {
  int checks = 0;

  @override
  Future<void> checkDeviceBiometrics() async {
    checks += 1;
  }
}

class _Nodes extends Fake with ChangeNotifier implements NodeProvider {
  @override
  bool get isInitializing => false;

  @override
  bool get isInitialized => false;

  @override
  bool get hasConnectionError => false;

  @override
  NodeProviderState get state => NodeProviderState.initial();

  @override
  Future<void> initialize() async {}

  @override
  Future<void> closeConnection() async {}

  @override
  Future<Result<bool>> reconnect() async => Result.success(true);

  @override
  Future<Result<bool>> syncDormantAddresses(WalletItemBase wallet) async => Result.success(true);
}

class _Wallets extends Fake with ChangeNotifier implements WalletProvider {
  @override
  List<WalletItemBase> get walletItemList => const [];
}

ExchangeType _exchangeFor(FiatCode fiat) {
  switch (fiat) {
    case FiatCode.KRW:
      return ExchangeType.upbit;
    case FiatCode.USD:
    case FiatCode.EUR:
      return ExchangeType.binance;
    case FiatCode.JPY:
      return ExchangeType.bitflyer;
  }
}

String? _symbolFor(FiatCode fiat) {
  switch (fiat) {
    case FiatCode.USD:
      return 'btcusdt';
    case FiatCode.EUR:
      return 'btceur';
    case FiatCode.KRW:
    case FiatCode.JPY:
      return null;
  }
}

String _payload(FiatCode fiat, int price) {
  switch (fiat) {
    case FiatCode.KRW:
      return '{"trade_price":$price}';
    case FiatCode.USD:
    case FiatCode.EUR:
      return '{"c":"$price"}';
    case FiatCode.JPY:
      return '{"method":"channelMessage","params":{"message":{"ltp":$price}}}';
  }
}

String _kindFor(Uri uri) {
  final text = uri.toString();
  if (text.contains('upbit')) return 'krw';
  if (text.contains('bitflyer')) return 'jpy';
  if (text.contains('btceur')) return 'eur';
  return 'usd';
}

String _payloadForPath(String path) {
  switch (path) {
    case '/krw':
      return _payload(FiatCode.KRW, 100000000);
    case '/usd':
      return _payload(FiatCode.USD, 60000);
    case '/jpy':
      return _payload(FiatCode.JPY, 9000000);
    case '/eur':
      return _payload(FiatCode.EUR, 55000);
    default:
      return '{}';
  }
}

Future<void> _waitUntil(bool Function() ready) async {
  final started = DateTime.now();
  while (!ready()) {
    if (DateTime.now().difference(started) > const Duration(seconds: 5)) {
      fail('timed out waiting for loopback prices');
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}
