class ElectrumServer {
  final String host;
  final int port;
  final bool ssl;
  final bool useTor;
  final String? torProxyHost; // 기본값: 127.0.0.1
  final int? torProxyPort; // 기본값: 9050

  const ElectrumServer(
    this.host,
    this.port,
    this.ssl, {
    this.useTor = false,
    this.torProxyHost,
    this.torProxyPort,
  });

  factory ElectrumServer.custom(String host, int port, bool ssl,
      {bool useTor = false, String? torProxyHost, int? torProxyPort}) {
    return ElectrumServer(host, port, ssl,
        useTor: useTor, torProxyHost: torProxyHost, torProxyPort: torProxyPort);
  }

  String get effectiveTorProxyHost => torProxyHost ?? '127.0.0.1';
  int get effectiveTorProxyPort => torProxyPort ?? 9050;

  bool get isOnionAddress => host.endsWith('.onion');
}
