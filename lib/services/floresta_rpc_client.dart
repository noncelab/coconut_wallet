import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:coconut_wallet/utils/logger.dart';

class FlorestaRpcClient {
  final String _host;
  final int _port;
  final bool _ssl;
  late final http.Client _client;

  String get _baseUrl {
    final scheme = _ssl ? 'https' : 'http';
    return '$scheme://$_host:$_port';
  }

  FlorestaRpcClient(this._host, this._port, this._ssl) {
    _client = http.Client();
  }

  Future<Map<String, dynamic>> _call(
    String method,
    List<dynamic> params, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final requestBody = {
      'jsonrpc': '2.0',
      'id': DateTime.now().microsecondsSinceEpoch,
      'method': method,
      'params': params,
    };

    try {
      final response = await _client
          .post(
            Uri.parse(_baseUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(requestBody),
          )
          .timeout(timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data.containsKey('error') && data['error'] != null) {
          throw FlorestaRpcException('$method failed: ${data['error']}');
        }
        return data;
      } else {
        throw FlorestaRpcException('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      if (e is FlorestaRpcException) rethrow;
      Logger.error('FlorestaRpcClient: $_baseUrl $method failed: $e');
      throw FlorestaRpcException('$method: $e');
    }
  }

  Future<void> loadDescriptor(String descriptor) async {
    final checksum = descriptor.contains('#') ? descriptor.split('#').last : 'none';
    Logger.log('FlorestaRpcClient: calling loaddescriptor on $_baseUrl');
    Logger.log('FlorestaRpcClient: descriptor length=${descriptor.length}, checksum=$checksum');
    await _call('loaddescriptor', [descriptor]);
    Logger.log('FlorestaRpcClient: loaddescriptor registered successfully');
  }

  Future<List<Map<String, dynamic>>> listDescriptors() async {
    final result = await _call('listdescriptors', []);
    final descriptors = result['result'] as List<dynamic>? ?? [];
    return descriptors.cast<Map<String, dynamic>>();
  }

  Future<void> rescan({int? startHeight}) async {
    final params = <dynamic>[];
    if (startHeight != null) {
      params.add(startHeight);
    }
    await _call('rescan', params);
    Logger.log('FlorestaRpcClient: rescan triggered');
  }

  Future<bool> checkConnection({Duration timeout = const Duration(seconds: 5)}) async {
    try {
      await _call('listdescriptors', [], timeout: timeout);
      Logger.log('FlorestaRpcClient: RPC connection ok on $_baseUrl');
      return true;
    } catch (e) {
      Logger.error('FlorestaRpcClient: RPC connection failed on $_baseUrl: $e');
      return false;
    }
  }

  void close() {
    _client.close();
  }
}

class FlorestaRpcException implements Exception {
  final String message;
  FlorestaRpcException(this.message);

  @override
  String toString() => 'FlorestaRpcException: $message';
}
