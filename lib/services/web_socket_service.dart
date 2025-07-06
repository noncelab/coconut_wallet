import 'dart:async';
import 'dart:convert';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:uuid/uuid.dart';

enum ExchangeType {
  upbit,
  binance,
}

class WebSocketService {
  final ExchangeType _exchangeType;
  final Uuid _uuid = const Uuid();
  WebSocketChannel? _channel;
  int _reconnectAttempts = 0;
  Timer? _pingTimer;

  final StreamController<PriceResponse?> _tickerController = StreamController.broadcast();
  Stream<PriceResponse?> get tickerStream => _tickerController.stream;

  WebSocketService({required ExchangeType exchangeType}) : _exchangeType = exchangeType {
    _connect();
  }

  String get _url {
    switch (_exchangeType) {
      case ExchangeType.upbit:
        return 'wss://api.upbit.com/websocket/v1';
      case ExchangeType.binance:
        return 'wss://stream.binance.com:9443/ws/btcusdt@ticker';
    }
  }

  void _connect() {
    _disposeChannel();

    _channel = WebSocketChannel.connect(Uri.parse(_url));

    if (_exchangeType == ExchangeType.upbit) {
      final request = _buildUpbitRequest();
      _channel?.sink.add(jsonEncode(request));
    }

    _channel?.stream.listen(
      _onData,
      onError: _onError,
      onDone: _onDone,
    );

    // Binance는 ping이 필요하지 않으므로 Upbit만 ping 전송
    if (_exchangeType == ExchangeType.upbit) {
      _pingTimer = Timer.periodic(const Duration(seconds: 10), _sendPing);
    }
  }

  List<Map<String, dynamic>> _buildUpbitRequest() {
    return [
      {"ticket": _uuid.v4()},
      {
        "type": "ticker",
        "codes": ["KRW-BTC"]
      }
    ];
  }

  void _reconnect() {
    if (_reconnectAttempts < 5) {
      _reconnectAttempts++;
      Logger.log('Reconnecting... ($_reconnectAttempts/5)');

      _connect();
    } else {
      Logger.log('Max reconnect attempts reached');
    }
  }

  void dispose() {
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
        Logger.log('Unexpected data type: ${data.runtimeType}');
        return;
      }

      PriceResponse? priceResponse;

      switch (_exchangeType) {
        case ExchangeType.upbit:
          if (decodedData is Map<String, dynamic> && decodedData['trade_price'] != null) {
            priceResponse = UpbitResponse.fromJson(decodedData);
          }
          break;
        case ExchangeType.binance:
          if (decodedData is Map<String, dynamic> && decodedData['c'] != null) {
            priceResponse = BinanceResponse.fromJson(decodedData);
          }
          break;
      }

      if (priceResponse != null && !_tickerController.isClosed) {
        _tickerController.add(priceResponse);
      }
    } catch (e) {
      Logger.log('Data processing error: $e');
    }
  }

  void _onError(error) {
    Logger.log('WebSocket error: $error');
    _reconnect();
  }

  void _onDone() {
    Logger.log('WebSocket closed');
  }

  void _sendPing(Timer timer) {
    try {
      _channel?.sink.add('PING');
    } catch (e) {
      Logger.log('Failed to send PING: $e');
      _reconnect();
    }
  }

  void _disposeChannel() {
    _pingTimer?.cancel();
    _pingTimer = null;

    if (_channel != null) {
      _channel!.sink.close();
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
    return UpbitResponse(
      tradePrice: (json['trade_price']).toInt(),
    );
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

    return BinanceResponse(
      tradePrice: price.toInt(),
    );
  }

  @override
  int get tradePrice => _tradePrice;
}

// WebSocketService 팩토리 클래스
class WebSocketServiceFactory {
  static WebSocketService create(FiatCode fiatCode) {
    switch (fiatCode) {
      case FiatCode.KRW:
        return WebSocketService(exchangeType: ExchangeType.upbit);
      case FiatCode.USD:
        return WebSocketService(exchangeType: ExchangeType.binance);
      default:
        // 기본값은 KRW
        return WebSocketService(exchangeType: ExchangeType.upbit);
    }
  }
}
