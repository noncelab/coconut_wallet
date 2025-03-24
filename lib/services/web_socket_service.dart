import 'dart:async';
import 'dart:convert';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:uuid/uuid.dart';

class WebSocketService {
  final String _url = 'wss://api.upbit.com/websocket/v1';
  final Uuid _uuid = const Uuid();
  WebSocketChannel? _channel;
  int _reconnectAttempts = 0;
  Timer? _pingTimer;

  final StreamController<UpbitResponse?> _tickerController =
      StreamController.broadcast();
  Stream<UpbitResponse?> get tickerStream => _tickerController.stream;

  WebSocketService() {
    _connect();
  }

  void _connect() {
    _disposeChannel();

    _channel = WebSocketChannel.connect(Uri.parse(_url));

    final request = _buildRequest();
    _channel?.sink.add(jsonEncode(request));

    _channel?.stream.listen(
      _onData,
      onError: _onError,
      onDone: _onDone,
    );

    _pingTimer = Timer.periodic(const Duration(seconds: 10), _sendPing);
  }

  List<Map<String, dynamic>> _buildRequest() {
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
      final decodedData = jsonDecode(utf8.decode(data));
      if (decodedData is Map<String, dynamic> &&
          decodedData['trade_price'] != null) {
        final ticker = UpbitResponse.fromJson(decodedData);
        _tickerController.add(ticker);
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

class UpbitResponse {
  final int tradePrice;

  UpbitResponse({required this.tradePrice});

  factory UpbitResponse.fromJson(Map<String, dynamic> json) {
    return UpbitResponse(
      tradePrice: (json['trade_price']).toInt(),
    );
  }
}
