import 'dart:io';
import 'package:coconut_lib/coconut_lib.dart';
import 'package:flutter/foundation.dart';
import 'package:coconut_wallet/utils/logger.dart';

abstract class SocketFactory {
  Future<Socket> createSocket(String host, int port);

  Future<SecureSocket> createSecureSocket(String host, int port, {String? publicKey});
}

class DefaultSocketFactory implements SocketFactory {
  @override
  Future<Socket> createSocket(String host, int port) {
    return Socket.connect(host, port);
  }

  @override
  Future<SecureSocket> createSecureSocket(String host, int port, {String? publicKey}) {
    Logger.log(
        'SocketFactory: Creating secure socket to $host:$port, hasPublicKey: ${publicKey != null}');

    return SecureSocket.connect(
      host,
      port,
      onBadCertificate: (X509Certificate cert) {
        Logger.log('SocketFactory: Bad certificate detected for $host:$port');
        Logger.log('SocketFactory: Certificate subject: ${cert.subject}');
        Logger.log('SocketFactory: Certificate issuer: ${cert.issuer}');

        // 자체 서명된 인증서인지 확인
        if (cert.subject == cert.issuer) {
          Logger.log('SocketFactory: Self-signed certificate detected, allowing connection');
          return true; // 자체 서명된 인증서 허용
        }

        // 개발 모드나 regtest 환경에서는 모든 인증서 허용
        if (kDebugMode || host.contains('regtest') || NetworkType.currentNetworkType.isTestnet) {
          Logger.log('SocketFactory: Allowing bad certificate for development/test environment');
          return true;
        }

        // 그 외에는 거부
        Logger.log('SocketFactory: Rejecting bad certificate for production environment');
        return false;
      },
    );
  }
}
