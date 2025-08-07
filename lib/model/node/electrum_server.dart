class ElectrumServer {
  final String host;
  final int port;
  final bool ssl;

  const ElectrumServer(this.host, this.port, this.ssl);

  factory ElectrumServer.custom(String host, int port, bool ssl) {
    return ElectrumServer(host, port, host.contains('.onion') ? false : ssl);
  }
}
