import 'dart:async';
import 'dart:io';
import 'package:coconut_wallet/utils/certificate_util.dart';
import 'package:coconut_wallet/utils/logger.dart';

abstract class SocketFactory {
  Future<Socket> createSocket(String host, int port, {Duration timeout});

  /// [pinnedFingerprint]가 주어지면, OS 표준 인증서 검증에 실패하더라도
  /// 실제 인증서의 SHA-256 지문이 [pinnedFingerprint]와 정확히 일치할 때만 연결을 허용
  /// null이면 표준 검증 실패 시 항상 연결을 거부한다.(기본 제공 서버는 항상 null이어야 한다)
  Future<SecureSocket> createSecureSocket(String host, int port, {String? pinnedFingerprint});

  /// 서버가 제시하는 인증서만 확인하기 위한 임시 연결(연결을 실제로 사용하지 않음)
  /// 커스텀 서버 등록 시 사용자에게 지문을 보여주고 신뢰 여부를 확인받는 용도로만 쓰인다.
  Future<X509Certificate?> peekCertificate(String host, int port, {Duration timeout});
}

class DefaultSocketFactory implements SocketFactory {
  @override
  Future<Socket> createSocket(String host, int port, {Duration timeout = const Duration(seconds: 3)}) {
    Logger.log('SocketFactory: Creating socket to $host:$port, timeout: $timeout}');
    return Socket.connect(host, port, timeout: timeout);
  }

  @override
  Future<SecureSocket> createSecureSocket(String host, int port, {String? pinnedFingerprint}) {
    Logger.log(
      'SocketFactory: Creating secure socket to $host:$port, hasPinnedFingerprint: ${pinnedFingerprint != null}',
    );

    return SecureSocket.connect(
      host,
      port,
      onBadCertificate: (X509Certificate cert) {
        if (pinnedFingerprint == null) {
          Logger.log('SocketFactory: No pinned fingerprint for $host:$port, rejecting untrusted certificate');
          return false;
        }

        final actualFingerprint = CertificateUtil.sha256Fingerprint(cert);
        final isMatch = actualFingerprint == pinnedFingerprint;
        Logger.log(
          isMatch
              ? 'SocketFactory: Certificate fingerprint matches pinned value for $host:$port'
              : 'SocketFactory: Certificate fingerprint mismatch for $host:$port, rejecting',
        );
        return isMatch;
      },
    );
  }

  @override
  Future<X509Certificate?> peekCertificate(
    String host,
    int port, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    SecureSocket? socket;
    try {
      socket = await SecureSocket.connect(host, port, onBadCertificate: (_) => true, timeout: timeout);
      return socket.peerCertificate;
    } finally {
      unawaited(socket?.close());
    }
  }
}
