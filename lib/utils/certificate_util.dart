import 'dart:io';

import 'package:crypto/crypto.dart';

/// TLS 인증서 지문(fingerprint) 계산 유틸
///
/// 커스텀 Electrum 서버의 인증서 핀닝에서 사용
/// 인증서의 신뢰 판단 기준으로 인증서 DER 바이트 전체의 SHA-256 해시만 사용한다.
class CertificateUtil {
  const CertificateUtil._();

  static String sha256Fingerprint(X509Certificate certificate) {
    final digest = sha256.convert(certificate.der);
    return digest.bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join(':').toUpperCase();
  }
}
