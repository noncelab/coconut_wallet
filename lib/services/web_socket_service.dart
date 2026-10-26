import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:uuid/uuid.dart';

enum ExchangeType { upbit, binance, bitflyer }

class WebSocketService {
  final ExchangeType _exchangeType;
  final String? _symbol;
  final WebSocketChannel Function(Uri uri) _openChannel;
  final Uuid _uuid = const Uuid();
  WebSocketChannel? _channel;
  int _generation = 0;
  int? _reconnectScheduledFor;
  int _reconnectAttempts = 0;
  Timer? _pingTimer;
  bool _isDisposed = false;

  final StreamController<PriceResponse?> _tickerController = StreamController.broadcast();
  Stream<PriceResponse?> get tickerStream => _tickerController.stream;

  /// [openChannel]은 테스트가 연결 구현을 주입할 때만 사용한다.
  WebSocketService({
    required ExchangeType exchangeType,
    String? symbol,
    @visibleForTesting WebSocketChannel Function(Uri uri)? openChannel,
  }) : _exchangeType = exchangeType,
       _symbol = symbol,
       _openChannel = openChannel ?? WebSocketChannel.connect {
    _connect();
  }

  String get _url {
    switch (_exchangeType) {
      case ExchangeType.upbit:
        return 'wss://api.upbit.com/websocket/v1';
      case ExchangeType.binance:
        final symbol = _symbol?.toLowerCase() ?? 'btcusdt';
        return 'wss://stream.binance.com:9443/ws/$symbol@ticker';
      case ExchangeType.bitflyer:
        return 'wss://ws.lightstream.bitflyer.com/json-rpc';
    }
  }

  void _connect() {
    if (_isDisposed) return;

    // 이전 채널의 늦은 onError/onDone이 새 소켓을 끊지 않게 먼저 세대를 올린다.
    _generation++;
    final generation = _generation;
    _disposeChannel();

    try {
      _channel = _openChannel(Uri.parse(_url));
      // ready와 스트림은 같은 핸드셰이크 실패를 따로 전달한다.
      // ready는 관찰만 하고, 재연결은 실패한 채널마다 한 번만 예약한다.
      _observeReady(_channel!, generation);

      if (_exchangeType == ExchangeType.upbit) {
        final request = _buildUpbitRequest();
        _channel?.sink.add(jsonEncode(request));
      } else if (_exchangeType == ExchangeType.bitflyer) {
        final request = _buildBitflyerRequest();
        _channel?.sink.add(jsonEncode(request));
      }

      _channel?.stream.listen(
        _onData,
        onError: (Object error, StackTrace _) => _onError(generation, error),
        onDone: () => _onDone(generation),
      );

      // Binance는 ping이 필요하지 않으므로 Upbit와 Coincheck만 ping 전송
      if (_exchangeType == ExchangeType.upbit || _exchangeType == ExchangeType.bitflyer) {
        _pingTimer = Timer.periodic(const Duration(seconds: 10), (_) => _sendPing(generation));
      }
    } catch (e) {
      Logger.log('WebSocketService: 연결 실패 - 네트워크 연결 확인 필요: $e');
      // 연결 실패 시 재시도하지 않고 조용히 종료
      _disposeChannel();
    }
  }

  void _observeReady(WebSocketChannel channel, int generation) {
    unawaited(
      channel.ready.then<void>(
        (_) {},
        onError: (Object error, StackTrace _) {
          if (!_isCurrent(generation)) return;
          Logger.log('WebSocketService: handshake failed (${error.runtimeType})');
        },
      ),
    );
  }

  List<Map<String, dynamic>> _buildUpbitRequest() {
    return [
      {"ticket": _uuid.v4()},
      {
        "type": "ticker",
        "codes": ["KRW-BTC"],
      },
    ];
  }

  Map<String, dynamic> _buildBitflyerRequest() {
    return {
      "method": "subscribe",
      "params": {"channel": "lightning_ticker_BTC_JPY"},
    };
  }

  bool _isCurrent(int generation) => !_isDisposed && generation == _generation;

  void _scheduleReconnect(int generation) {
    if (!_isCurrent(generation) || _reconnectScheduledFor == generation) return;

    _reconnectScheduledFor = generation;
    if (_reconnectAttempts >= 3) {
      _pingTimer?.cancel();
      _pingTimer = null;
      Logger.log('WebSocketService: 재연결 중단 - 최대 시도 횟수 도달 또는 서비스 종료됨');
      return;
    }

    _reconnectAttempts++;
    Logger.log('WebSocketService: 재연결 시도... ($_reconnectAttempts/3)');

    // 지수 백오프로 재연결 시도 간격 증가
    final delay = Duration(seconds: _reconnectAttempts * 2);
    Timer(delay, () {
      if (_isCurrent(generation)) _connect();
    });
  }

  void dispose() {
    _isDisposed = true;
    _tickerController.close();
    _disposeChannel();
  }

  void _onData(dynamic data) {
    try {
      Map<String, dynamic> decodedData;

      // 데이터 타입에 따라 안전하게 처리
      if (data is String) {
        decodedData = jsonDecode(data);
      } else if (data is List<int>) {
        decodedData = jsonDecode(utf8.decode(data));
      } else {
        Logger.log('WebSocketService: 예상치 못한 데이터 타입: ${data.runtimeType}');
        return;
      }

      PriceResponse? priceResponse;

      switch (_exchangeType) {
        case ExchangeType.upbit:
          if (decodedData['trade_price'] != null) {
            priceResponse = UpbitResponse.fromJson(decodedData);
          }
          break;
        case ExchangeType.binance:
          if (decodedData['c'] != null) {
            priceResponse = BinanceResponse.fromJson(decodedData);
          }
          break;
        case ExchangeType.bitflyer:
          if (decodedData['method'] == 'channelMessage') {
            final message = decodedData['params']['message'];
            if (message != null) {
              priceResponse = BitflyerResponse.fromJson(message);
            }
          }
          break;
      }

      if (priceResponse != null && !_tickerController.isClosed) {
        _tickerController.add(priceResponse);
      }
    } catch (e) {
      Logger.log('WebSocketService: 데이터 처리 오류: $e');
    }
  }

  void _onError(int generation, Object error) {
    if (!_isCurrent(generation)) return;

    Logger.log('WebSocketService: WebSocket 오류: $error');
    // 네트워크 관련 오류인지 확인
    if (error is SocketException || error.toString().contains('Connection')) {
      Logger.log('WebSocketService: 네트워크 연결 오류 - 재연결 시도');
      _scheduleReconnect(generation);
    } else {
      Logger.log('WebSocketService: 기타 오류 - 연결 종료');
      _disposeChannel();
    }
  }

  void _onDone(int generation) {
    if (!_isCurrent(generation)) return;

    Logger.log('WebSocketService: WebSocket 연결 종료');
    _scheduleReconnect(generation);
  }

  void _sendPing(int generation) {
    if (!_isCurrent(generation)) return;

    try {
      _channel?.sink.add('PING');
    } catch (e) {
      Logger.log('WebSocketService: PING 전송 실패: $e');
      _scheduleReconnect(generation);
    }
  }

  void _disposeChannel() {
    _pingTimer?.cancel();
    _pingTimer = null;

    if (_channel != null) {
      try {
        _channel!.sink.close();
      } catch (e) {
        Logger.log('WebSocketService: 채널 종료 중 오류: $e');
      }
      _channel = null;
    }
  }
}

// 공통 인터페이스
abstract class PriceResponse {
  int get tradePrice;
}

// Upbit 응답 클래스
class UpbitResponse extends PriceResponse {
  final int _tradePrice;

  UpbitResponse({required int tradePrice}) : _tradePrice = tradePrice;

  factory UpbitResponse.fromJson(Map<String, dynamic> json) {
    return UpbitResponse(tradePrice: (json['trade_price']).toInt());
  }

  @override
  int get tradePrice => _tradePrice;
}

// Binance 응답 클래스
class BinanceResponse extends PriceResponse {
  final int _tradePrice;

  BinanceResponse({required int tradePrice}) : _tradePrice = tradePrice;

  factory BinanceResponse.fromJson(Map<String, dynamic> json) {
    // Binance는 문자열로 가격을 제공하므로 double로 변환 후 정수로 변환
    final priceData = json['c'];
    double price;

    if (priceData is String) {
      price = double.parse(priceData);
    } else if (priceData is num) {
      price = priceData.toDouble();
    } else {
      throw FormatException('Invalid price format: $priceData');
    }

    return BinanceResponse(tradePrice: price.toInt());
  }

  @override
  int get tradePrice => _tradePrice;
}

// Bitflyer 응답 클래스
class BitflyerResponse extends PriceResponse {
  final int _tradePrice;

  BitflyerResponse({required int tradePrice}) : _tradePrice = tradePrice;

  factory BitflyerResponse.fromJson(Map<String, dynamic> json) {
    // Bitflyer는 ltp (Last Traded Price) 필드를 사용
    final priceData = json['ltp'];
    double price;

    if (priceData is String) {
      price = double.parse(priceData);
    } else if (priceData is num) {
      price = priceData.toDouble();
    } else {
      throw FormatException('Invalid price format: $priceData');
    }

    return BitflyerResponse(tradePrice: price.toInt());
  }

  @override
  int get tradePrice => _tradePrice;
}

// WebSocketService 팩토리 클래스
class WebSocketServiceFactory {
  /// [openChannel]은 테스트가 연결 구현을 주입할 때만 사용한다.
  /// 생략하면 기존과 같이 [WebSocketChannel.connect]로 거래소에 연결한다.
  static WebSocketService create(
    FiatCode fiatCode, {
    @visibleForTesting WebSocketChannel Function(Uri uri)? openChannel,
  }) {
    switch (fiatCode) {
      case FiatCode.KRW:
        return WebSocketService(exchangeType: ExchangeType.upbit, openChannel: openChannel);
      case FiatCode.USD:
        return WebSocketService(exchangeType: ExchangeType.binance, symbol: 'btcusdt', openChannel: openChannel);
      case FiatCode.JPY:
        return WebSocketService(exchangeType: ExchangeType.bitflyer, openChannel: openChannel);
      case FiatCode.EUR:
        return WebSocketService(exchangeType: ExchangeType.binance, symbol: 'btceur', openChannel: openChannel);
      default:
        throw ArgumentError('$fiatCode는 거래소 웹소켓을 지원하지 않습니다. CoinGecko를 사용하세요.');
    }
  }
}
