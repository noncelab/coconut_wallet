import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:coconut_wallet/constants/network_constants.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/services/network/socket/socket_factory.dart';
import 'package:coconut_wallet/utils/logger.dart';

class SocketManager {
  /// Socket
  final SocketFactory socketFactory;
  Socket? _socket;
  SocketConnectionStatus _connectionStatus = SocketConnectionStatus.reconnecting;
  int _connectionAttempts = 0;
  final int _maxConnectionAttempts;
  final int _reconnectDelaySeconds;

  SocketConnectionStatus get connectionStatus => _connectionStatus;

  /// Connection info
  late String _host;
  late int _port;
  late bool _ssl;

  /// JSON parse
  final StreamController<String> _streamController = StreamController();
  final StringBuffer _buffer = StringBuffer();

  /// Response
  final Map<int, Completer<dynamic>> _completerMap = {};
  final Map<String, Function(String, String?)> _scriptSubscribeCallbacks =
      {}; // ScriptPubKey -> Callback

  /// On Reconnect callback
  void Function()? onReconnect;

  /// [factory]: 테스트용 모킹 객체를 주입하기 위한 클래스로 실제 사용 시 별도로 지정하지 않아도 됨 <br/>
  /// [maxConnectionAttempts]: 최대 연결 시도 횟수, default: 30 <br/>
  /// [reconnectDelaySeconds]: 재연결 주기, default: 10 (s) <br/>
  SocketManager(
      {SocketFactory? factory,
      int maxConnectionAttempts = kSocketMaxConnectionAttempts,
      int reconnectDelaySeconds = kSocketReconnectDelaySeconds})
      : socketFactory = factory ?? DefaultSocketFactory(),
        _maxConnectionAttempts = maxConnectionAttempts,
        _reconnectDelaySeconds = reconnectDelaySeconds {
    _streamController.stream.listen(_handleResponse);
  }

  setCompleter(int id, Completer completer) {
    _completerMap[id] = completer;
  }

  setSubscriptionCallback(String scriptReverseHash, Function(String, String?) callback) {
    _scriptSubscribeCallbacks[scriptReverseHash] = callback;
  }

  removeSubscriptionCallback(String scriptReverseHash) {
    _scriptSubscribeCallbacks.remove(scriptReverseHash);
  }

  Future<void> connect(String host, int port, {bool ssl = true}) async {
    _host = host;
    _port = port;
    _ssl = ssl;

    if (_connectionAttempts >= _maxConnectionAttempts) {
      _connectionStatus = SocketConnectionStatus.terminated;
      return;
    }

    ++_connectionAttempts;

    if (_connectionStatus != SocketConnectionStatus.reconnecting) {
      return;
    }

    _connectionStatus = SocketConnectionStatus.connecting;
    try {
      if (ssl) {
        _socket = await socketFactory.createSecureSocket(host, port);
      } else {
        _socket = await socketFactory.createSocket(host, port);
      }
      _connectionStatus = SocketConnectionStatus.connected;
      _connectionAttempts = 0;
      _socket!.listen(_onData, onError: _onError, onDone: _onDone, cancelOnError: true);
    } catch (e) {
      _connectionStatus = SocketConnectionStatus.reconnecting;
      _scheduleReconnect(host, port, ssl: ssl);
    }
  }

  Future<void> disconnect() async {
    await _socket?.close();
    _connectionStatus = SocketConnectionStatus.terminated;
  }

  void _onData(Uint8List data) {
    _streamController.add(utf8.decode(data));
  }

  void _onDone() {
    _connectionStatus = SocketConnectionStatus.terminated;
  }

  void _onError(error) {
    _connectionStatus = SocketConnectionStatus.reconnecting;
    _scheduleReconnect(_host, _port, ssl: _ssl);
  }

  Future<void> send(String data) async {
    if (_connectionStatus != SocketConnectionStatus.connected) {
      throw const SocketException('Socket is not connected');
    }
    try {
      _socket!.writeln(data);
    } catch (e) {
      _connectionStatus = SocketConnectionStatus.reconnecting;
      rethrow;
    }
  }

  void _scheduleReconnect(String host, int port, {bool ssl = true}) {
    Future.delayed(Duration(seconds: _reconnectDelaySeconds), () {
      connect(host, port, ssl: ssl).then((any) {
        onReconnect?.call();
      });
    });
  }

  void _handleResponse(String data) {
    _buffer.write(data);
    _processBuffer();
  }

  void _processBuffer() {
    String bufferString = _buffer.toString();
    if (bufferString.isEmpty) return;

    List<Map<String, dynamic>> jsonObjects = _extractJsonObjects(bufferString);

    for (var jsonObject in jsonObjects) {
      _processJsonObject(jsonObject);
    }
  }

  List<Map<String, dynamic>> _extractJsonObjects(String input) {
    List<Map<String, dynamic>> result = [];
    int startPos = input.indexOf('{');
    if (startPos == -1) {
      _buffer.clear();
      return result;
    }

    int endPos = -1;
    int currentPos = startPos;
    int braceCount = 0;
    bool inString = false;

    for (int i = currentPos; i < input.length; i++) {
      var char = input[i];

      if (char == '"' && (i == 0 || input[i - 1] != '\\')) {
        inString = !inString;
        continue;
      }

      if (!inString) {
        if (char == '{') {
          braceCount++;
        } else if (char == '}') {
          braceCount--;

          if (braceCount == 0) {
            endPos = i;
            String jsonString = input.substring(startPos, endPos + 1);

            try {
              Map<String, dynamic> jsonObject = json.decode(jsonString);
              result.add(jsonObject);

              int nextStartPos = input.indexOf('{', endPos + 1);
              if (nextStartPos == -1) {
                _buffer.clear();
                break;
              } else {
                startPos = nextStartPos;
                i = nextStartPos - 1;
                braceCount = 0;
              }
            } catch (e) {
              Logger.log('JSON 파싱 오류: $e, JSON: ${_truncateForLogging(jsonString)}');

              int nextStartPos = input.indexOf('{', endPos + 1);
              if (nextStartPos == -1) {
                _buffer.clear();
                break;
              } else {
                startPos = nextStartPos;
                i = nextStartPos - 1;
                braceCount = 0;
              }
            }
          }
        }
      }
    }

    if (braceCount > 0 && startPos < input.length) {
      _buffer.clear();
      _buffer.write(input.substring(startPos));
    } else {
      _buffer.clear();
    }

    return result;
  }

  String _truncateForLogging(String text, {int maxLength = 200}) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}... (총 ${text.length}자)';
  }

  void _processJsonObject(Map<String, dynamic> jsonObject) {
    try {
      final id = jsonObject['id'];
      final method = jsonObject['method'];

      if (id != null && _completerMap.containsKey(id)) {
        if (!_completerMap[id]!.isCompleted) {
          _completerMap[id]!.complete(jsonObject);
        } else {
          Logger.log('이미 완료된 Completer (ID: $id)에 결과를 전달하려고 시도했습니다.');
        }
        _completerMap.remove(id);
      } else if (method == 'blockchain.scripthash.subscribe') {
        if (jsonObject['params'] != null && jsonObject['params'].length >= 2) {
          final scriptReversedHash = jsonObject['params'][0];
          final status = jsonObject['params'][1];
          final callback = _scriptSubscribeCallbacks[scriptReversedHash];
          if (callback != null) {
            callback(scriptReversedHash, status);
          }
        } else {
          Logger.log('유효하지 않은 구독 이벤트: $jsonObject');
        }
      } else if (id != null) {
        Logger.log('ID: $id에 대한 처리기가 없습니다: $jsonObject');
      }
    } catch (e) {
      Logger.log('JSON 객체 처리 중 오류 발생: $e, 객체: $jsonObject');
    }
  }
}
