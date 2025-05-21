import 'dart:io';

import 'package:coconut_wallet/utils/logger.dart';

/// Electrum 서버의 연결 가능 상태를 확인하는 유틸리티
class ElectrumHealthChecker {
  /// Electrum 서버와의 TCP 연결을 확인합니다.
  /// @param host 서버 호스트명 (예: blockstream.info)
  /// @param port 포트 번호 (예: 700)
  /// @return 연결 가능 여부
  static Future<bool> checkConnection(
    String host,
    int port, {
    Duration timeout = const Duration(seconds: 5),
    bool isSSL = false,
  }) async {
    try {
      Socket socket;
      if (isSSL) {
        final secureSocket = await SecureSocket.connect(
          host,
          port,
          timeout: timeout,
        );
        socket = secureSocket;
      } else {
        socket = await Socket.connect(
          host,
          port,
          timeout: timeout,
        );
      }
      await socket.close();
      return true;
    } catch (e) {
      Logger.log('[ERROR] Electrum connection failed for $host:$port (SSL: $isSSL): $e');
      return false;
    }
  }
}
