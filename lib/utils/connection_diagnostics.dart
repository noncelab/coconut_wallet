import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:coconut_wallet/utils/logger.dart';

class ConnectionDiagnostics {
  static const String tag = '[#798]';

  static void log(String message) => Logger.log('$tag $message');

  static String describe(Object error) {
    if (error is SocketException) {
      final os = error.osError;
      return 'SocketException(message: ${error.message}, errno: ${os?.errorCode}, osMessage: ${os?.message}, '
          'address: ${error.address?.address}, port: ${error.port})';
    }
    if (error is TimeoutException) {
      return 'TimeoutException(duration: ${error.duration})';
    }
    return '${error.runtimeType}: $error';
  }

  static Future<void> run(String host, int port) async {
    log('--- diagnostics start host=$host port=$port hostLength=${host.length} '
        'parsedIp=${InternetAddress.tryParse(host)?.address}');
    await _logInterfaces();
    await _logLookup(host);
    await _probe(host, port);
    log('--- diagnostics end');
  }

  static Future<void> _logInterfaces() async {
    try {
      final interfaces = await NetworkInterface.list(includeLinkLocal: false, type: InternetAddressType.any);
      for (final interface in interfaces) {
        final addresses = interface.addresses.map((a) => '${a.type.name}:${a.address}').join(', ');
        log('interface ${interface.name}: $addresses');
      }
    } catch (e) {
      log('interface list failed: ${describe(e)}');
    }
  }

  static Future<void> _logLookup(String host) async {
    if (InternetAddress.tryParse(host) != null) return;
    for (final type in [InternetAddressType.IPv4, InternetAddressType.IPv6, InternetAddressType.any]) {
      final stopwatch = Stopwatch()..start();
      try {
        final result = await InternetAddress.lookup(host, type: type).timeout(const Duration(seconds: 10));
        log('lookup ${type.name} ${stopwatch.elapsedMilliseconds}ms: ${result.map((a) => a.address).join(', ')}');
      } catch (e) {
        log('lookup ${type.name} failed ${stopwatch.elapsedMilliseconds}ms: ${describe(e)}');
      }
    }
  }

  static Future<void> _probe(String host, int port) async {
    final stopwatch = Stopwatch()..start();
    Socket? socket;
    try {
      socket = await Socket.connect(host, port, timeout: const Duration(seconds: 20));
      log('probe connect ok ${stopwatch.elapsedMilliseconds}ms '
          'local=${socket.address.address}:${socket.port} remote=${socket.remoteAddress.address}:${socket.remotePort}');

      final firstLine = socket.cast<List<int>>().transform(utf8.decoder).transform(const LineSplitter()).first;
      socket.writeln(json.encode({
        'id': 1,
        'jsonrpc': '2.0',
        'method': 'server.version',
        'params': ['coconut-wallet', '1.4'],
      }));
      final response = await firstLine.timeout(const Duration(seconds: 15));
      log('probe server.version ok ${stopwatch.elapsedMilliseconds}ms: $response');
    } catch (e) {
      log('probe failed ${stopwatch.elapsedMilliseconds}ms: ${describe(e)}');
    } finally {
      socket?.destroy();
    }
  }
}
