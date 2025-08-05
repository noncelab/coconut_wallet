import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:coconut_wallet/constants/isolate_constants.dart';
import 'package:coconut_wallet/constants/network_constants.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/services/network/socket/socket_factory.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:flutter/services.dart';

class SocketManager {
  /// Socket
  SocketFactory socketFactory;
  Socket? _socket;
  SocketConnectionStatus _connectionStatus = SocketConnectionStatus.reconnecting;
  int _connectionAttempts = 0;
  final int _maxConnectionAttempts;

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

  /// On Connection Lost callback
  void Function()? onConnectionLost;

  /// On Connection Failed callback
  void Function()? onConnectionFailed;

  /// [factory]: 테스트용 모킹 객체를 주입하기 위해 만들었으나, Tor를 지원하기 위해 확장 클래스로 사용 <br/>
  /// [maxConnectionAttempts]: 최대 연결 시도 횟수, default: 30 <br/>
  /// [reconnectDelaySeconds]: 재연결 주기, default: 10 (s) <br/>
  SocketManager({SocketFactory? factory, int maxConnectionAttempts = kSocketMaxConnectionAttempts})
      : socketFactory = factory ?? DefaultSocketFactory(),
        _maxConnectionAttempts = maxConnectionAttempts {
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

  // .onion 주소인 경우 타임아웃을 길게 설정
  Duration getConnectionTimeout(bool isOnionHost, bool isTailscale) {
    if (isOnionHost) {
      return kIsolateInitTimeoutForOnion;
    } else if (isTailscale) {
      return kIsolateInitTimeout;
    } else {
      return kIsolateInitTimeout;
    }
  }

  Future<bool> connect(String host, int port, {bool ssl = true}) async {
    _host = host;
    _port = port;
    _ssl = ssl;

    final isOnionHost = _isOnionAddress(host);
    _ssl = isOnionHost ? false : ssl;

    Logger.log('SocketManager: Connecting to $host:$port (SSL: $_ssl)');

    if (_connectionAttempts >= _maxConnectionAttempts) {
      _connectionStatus = SocketConnectionStatus.terminated;
      return false;
    }

    ++_connectionAttempts;

    if (_connectionStatus != SocketConnectionStatus.reconnecting) {
      return false;
    }

    _connectionStatus = SocketConnectionStatus.connecting;

    final isTailscale = await _detectTailscaleNetwork();

    final connectionTimeout = getConnectionTimeout(isOnionHost, isTailscale);

    try {
      // ssl false이거나 tailscale이 감지되는 경우, 일반 연결 사용
      if (!_ssl || isTailscale || isOnionHost) {
        Logger.log('Socket connection: $_host:$_port');
        _socket = await socketFactory.createSocket(_host, _port, timeout: connectionTimeout);
      } else {
        Logger.log('Secure Socket connection: $_host:$_port (SSL: $_ssl, Tailscale: $isTailscale)');
        _socket = await socketFactory.createSecureSocket(_host, _port);
      }

      _connectionStatus = SocketConnectionStatus.connected;
      _connectionAttempts = 0;
      _socket!.listen(_onData, onError: _onError, onDone: _onDone, cancelOnError: true);
    } catch (e) {
      Logger.error('Socket connection failed: $e');
      _connectionStatus = SocketConnectionStatus.terminated;
      onConnectionLost?.call();
      return false;
    }
    return true;
  }

  bool _isOnionAddress(String host) {
    return host.toLowerCase().endsWith('.onion');
  }

  Future<bool> _detectTailscaleNetwork() async {
    try {
      final interfaces = await NetworkInterface.list();
      final tailscaleIps = <String>[];

      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (_isTailscaleIP(addr.address)) {
            tailscaleIps.add(addr.address);
            Logger.log('🌐 Tailscale IP Detected: ${addr.address} (${interface.name})');
            return true;
          }
        }
      }
    } catch (e) {
      Logger.log('❌ Tailscale IP Not Detected');
      return false;
    }
    return false;
  }

  /// Tailscale IP 범위 확인
  bool _isTailscaleIP(String ip) {
    try {
      final parts = ip.split('.');
      if (parts.length != 4) return false;

      final firstOctet = int.tryParse(parts[0]);
      final secondOctet = int.tryParse(parts[1]);

      if (firstOctet == null || secondOctet == null) return false;

      // 100.64.0.0/10 범위: 100.64.x.x ~ 100.127.x.x
      return firstOctet == 100 && secondOctet >= 64 && secondOctet <= 127;
    } catch (e) {
      return false;
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
    Logger.log('Socket connection closed');
    _connectionStatus = SocketConnectionStatus.terminated;
    onConnectionLost?.call();
  }

  void _onError(error) {
    Logger.error('Socket connection error: $error');
    _connectionStatus = SocketConnectionStatus.terminated;
    onConnectionLost?.call();
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
