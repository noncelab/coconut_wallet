class ElectrumServer {
  final String host;
  final int port;
  final bool ssl;

  /// 사용자가 명시적으로 신뢰를 승인한 인증서의 SHA-256 지문
  /// 기본 제공 서버는 항상 null이며, OS 표준 인증서 검증만 적용된다.
  /// 커스텀(자체 호스팅) 서버에서 인증서 검증이 실패했을 때만 사용자가 지문을 확인하고 승인한 경우에 채워지며,
  /// 이후 연결에서는 이 지문과 정확히 일치하는 인증서만 허용된다.
  final String? pinnedCertFingerprint;

  const ElectrumServer(this.host, this.port, this.ssl, {this.pinnedCertFingerprint});

  factory ElectrumServer.custom(String host, int port, bool ssl, {String? pinnedCertFingerprint}) {
    return ElectrumServer(
      host,
      port,
      host.contains('.onion') ? false : ssl,
      pinnedCertFingerprint: pinnedCertFingerprint,
    );
  }

  ElectrumServer copyWith({String? host, int? port, bool? ssl, String? pinnedCertFingerprint}) {
    return ElectrumServer(
      host ?? this.host,
      port ?? this.port,
      ssl ?? this.ssl,
      pinnedCertFingerprint: pinnedCertFingerprint ?? this.pinnedCertFingerprint,
    );
  }
}
